# Copyright (C) 2008  Stephane Galland <galland@arakhne.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; see the file COPYING.  If not, write to
# the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA.

package AWebGen::Announce::Exec;

@ISA = ('Exporter');
@EXPORT = qw( &emailAnnounce ) ;
@EXPORT_OK = qw();
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);
my $VERSION = "0.1" ;

use Carp;
use File::Spec;
use Digest::MD5 qw/ md5_hex /;
use Compress::Zlib;
use Net::SMTP;

use AWebGen::Config::Db;
use AWebGen::Util::Output;
use AWebGen::Util::File;
use AWebGen::Util::Str;
use AWebGen::Db::Text;
use AWebGen::Code::LocalContext;
use AWebGen::Code::Code qw/ %INSTRUCTIONS %HTML_CONSTANTS /;

# Clean string by removing HTML/XML tags
sub cleanString($) {
	my $s = shift || '';
	# Replacing <li></li>
	$s =~ s/\n<li[^>]*>/\n- /gs;
	$s =~ s/<li[^>]*>/\n- /gs;
	# Remove open tags
	$s =~ s/<[a-zA-Z]+[^>]*>//gs;
	# Remove close tags
	$s =~ s/<\/[a-zA-Z]+[^>]*>//gs;
	# Replacing HTML constants
	while (my ($k,$v) = each(%HTML_CONSTANTS)) {
		$s =~ s/\Q$k\E/$v/gs;
	}
	# HTML decoding
	$s = htmldecode("$s");
	return urldecode("$s");
}

sub getAnnouncedFilename() {
	return File::Spec->catfile(getConfigPath(),'announces.md5');
}

sub parseAnnounceMD5($) {
	my $text = shift || '';
	my @md5 = split(/[\n\r]+/, "$text");
	my @m = ();
	foreach my $md5 (@md5) {
		$md5 =~ s/^\s+//;
		$md5 =~ s/\s+$//;
		if ($md5) {
			push @m, "$md5";
		}
	}
	return @m;
}

sub getAnnouncedEntries() {
	my $fn = getAnnouncedFilename();
	my $content = "";
	if (-f "$fn.gz") {
		my $gz = gzopen("$fn.gz","rb") || croak("$fn.gz: $!");
		my ($buffer, $red);
		$content = '';
		while (($red = $gz->gzread($buffer))>0) {
			$content .= "$buffer";
			$buffer = undef;
		}
		$gz->gzclose();
	}
	elsif (-f "$fn") {
		$content = readFile("$fn");
	}

	return parseAnnounceMD5($content);
}

sub saveAnnouncedEntries(@) {
	my $fn = getAnnouncedFilename();
	unlink("$fn");
	unlink("$fn.gz");	
	my $gz = gzopen("$fn.gz","wb") || croak("$fn.gz: $!");
	$gz->gzwrite(join("\n", @_));
	$gz->gzclose();
}

sub computeMD5(@) {
	my %md5 = ();
	my $txt;
	my $i=0;
	foreach my $e (@_) {
		$txt = '['.($e->{'DATE'}||'').']['.($e->{'TITLE'}||'').']['.($e->{'TEXT'}||'').']';
		$md5{md5_hex("$txt")} = $i;
		$i++;
	}
	return %md5;
}

sub buildAnnounceMessage($\%\@) {
	my $format = shift;
	my $txt = '';
	if (%{$_[0]}) {
		my $localContext = createLocalContext("/announces",".",\%INSTRUCTIONS);
		putLCConstant($localContext, 'ROOT', getLCConstant($localContext,'SITE_URL'));

		$txt .= '<h1>' if ($format eq 'html');
		$txt .= getLCConstant($localContext,'SITE_NAME')." Announcements";
		$txt .= '</h1><dl>' if ($format eq 'html');
		foreach my $idx (values %{$_[0]}) {
			my $e = $_[1]->[$idx];
			if ($e) {
				openLocalContext($localContext);
				my $title = cleanString(AWebGen::Code::Exec::codeReplaceInLocalContext($localContext, $e->{'TITLE'}));
				closeLocalContext($localContext);
				openLocalContext($localContext);
				my $text = cleanString(AWebGen::Code::Exec::codeReplaceInLocalContext($localContext, $e->{'TEXT'}));
				closeLocalContext($localContext);
				if ($format eq 'html') {
					$txt .= "<dt><strong>[".$e->{'DATE'}."]&nbsp;$title";
					$txt .= "</strong></dt><dd>$text</dd>";
				}
				else {
					$txt .= "-----------------\n";
					$txt .= "[".cleanString($e->{'DATE'})."] ".cleanString($title)."\n";
					$txt .= "-----------------\n";
					$txt .= cleanString($text)."\n\n";
				}
			}
		}
		$txt .= '</dl>' if ($format eq 'html');
	}
	return $txt;
}

# Send announces by email
# $_[0]: name of the news database
sub emailAnnounce($) {
	my $newsDb = shift || croak('no news database');
	# Get and check format
	my $format = getConstant('announce-format');
	if ($format ne 'html') {
		$format = 'text';
	}
	# Get announcement email
	my $email = getCmdLineOpt('announce');
	return 0 unless ($email);

	verb(2,"Updating announced news");

	# Get news
	my $filename = mkDatabaseFilename("$newsDb");
	(-r "$filename") || croak("$filename: $!\n");
	my @entries = extractTextDB(readFile("$filename"));
		
	# Get already announced news
	my @announcedEntries = getAnnouncedEntries();

	# Compute MD5 for news
	my %md5s = computeMD5(@entries);

	# Remove already announced news
	foreach my $e (@announcedEntries) {
		delete $md5s{$e};
	}

	# Build announce message
	my $announce = buildAnnounceMessage($format,%md5s,@entries);

	# Add newly announced news to the list of announced news
	foreach my $e (keys %md5s) {
		push @announcedEntries, "$e";
	}

	# Send email
	my $smtp = getConstant('SMTP_SERVER');
	verb(3,"SMTP server = $smtp");
	verb(3,"Announcement = ".($announce?"yes":"no"));
	if ($smtp && $announce) {
		verb(2,"Send announcement email to $email");
		my $from = getConstant('SMTP_SENDER') || $email;
		my $subject = "Announcement";
		$smtp = Net::SMTP->new("$smtp", Timeout => 120);
		confess("null \$smtp object") unless (defined($smtp));
		$smtp->mail("$email");
		$smtp->to("$email");
		$smtp->data();
		$smtp->datasend("To: $email\n");
		$smtp->datasend("From: $from\n");
		$smtp->datasend("X-Mailer: Perl Sendmail \n");
		$smtp->datasend("Subject: $subject\n");
		if ($format eq 'html') {
			$smtp->datasend("Content-type: text/html\n");
		}
		$smtp->datasend("Content-Transfer-Encoding: 7bit\n");
		$smtp->datasend("\n");
		$smtp->datasend("$announce\n");
		$smtp->dataend();
		$smtp->quit();

		# Save the announced entries in the local file
		verb(2,"Save announcements for further uses");
		saveAnnouncedEntries(@announcedEntries);
	}
}

1;
__END__
