# Copyright (C) 2008-09  Stephane Galland <galland@arakhne.org>
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

package AWebGen::RSS::Exec;

@ISA = ('Exporter');
@EXPORT = qw( &generateRSS ) ;
@EXPORT_OK = qw();
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);
my $VERSION = "2.0" ;

use Carp;

use AWebGen::Config::Db;
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

# Generate RSS flow
# $_[0] : name of the rss output file
# $_[1] : name of the news database
# Return: the array (absolute file, relative file) of the generated RSS.
sub generateRSS($$) {
	my $rssName = shift || croak('no rss name');
	my $dbName = shift || croak('no news database');
	my $systemdir = getRootDir();
	my $targetdir = getWorkingDir();
	my $sitepath = "/$rssName.rss";

	my $filename = mkDatabaseFilename("$dbName");
	(-r "$filename") || croak("$filename: $!\n");
	my @entries = extractTextDB(readFile("$filename"));

	$filename = File::Spec->catfile("$targetdir","$rssName.rss");

	my $localContext = createLocalContext("$sitepath",".",\%INSTRUCTIONS);

	local *RSS;
	open(*RSS,"> $filename") or croak("$filename: $!\n");
	print RSS "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n";
	print RSS "<rss version=\"2.0\">\n";
	print RSS "  <channel>\n";
	print RSS "    <title>".cleanString(getLCConstant($localContext,'SITE_NAME'))."</title>\n";
	print RSS "    <description>News for the ".cleanString(getLCConstant($localContext,'SITE_NAME'))." community</description>\n";
	print RSS "    <lastBuildDate>".cleanString('###LAST_UPDATE_DATE###')."</lastBuildDate>\n";
	print RSS "    <pubDate>".cleanString('###LAST_UPDATE_DATE###')."</pubDdate>\n";
	print RSS "    <link>".cleanString(getLCConstant($localContext,'SITE_URL'))."</link>\n";
	print RSS "    <ttl>1440</ttl>\n";

	
	# Force the ${ROOT} to be prefixed by the URL
	putLCConstant($localContext, 'ROOT', getLCConstant($localContext,'SITE_URL'));

	foreach my $entry (@entries) {
		print RSS "    <item>\n";
		if ($entry->{'DATE'}) {
			my $content = $entry->{'DATE'};
			openLocalContext($localContext);
			$content = cleanString(AWebGen::Code::Exec::codeReplaceInLocalContext($localContext,$content));
			closeLocalContext($localContext);
			print RSS "      <pubDate>$content</pubDate>\n";
		}
		if ($entry->{'TITLE'}) {
			my $content = $entry->{'TITLE'};
			openLocalContext($localContext);
			$content = cleanString(AWebGen::Code::Exec::codeReplaceInLocalContext($localContext,$content));
			closeLocalContext($localContext);
			print RSS "      <title>$content</title>\n";
		}
		if ($entry->{'TEXT'}) {
			my $content = $entry->{'TEXT'};
			openLocalContext($localContext);
			$content = cleanString(AWebGen::Code::Exec::codeReplaceInLocalContext($localContext,$content));
			closeLocalContext($localContext);
			print RSS "      <description>$content</description>\n";
		}
		if ($entry->{'LINK'}) {
			my $content = $entry->{'LINK'};
			openLocalContext($localContext);
			$content = cleanString(AWebGen::Code::Exec::codeReplaceInLocalContext($localContext,$content));
			closeLocalContext($localContext);
			print RSS "      <link>$content</link>\n";
		}
		if ($entry->{'AUTHOR'}) {
			my $content = $entry->{'AUTHOR'} || '${AUTHOR}';
			openLocalContext($localContext);
			$content = cleanString(AWebGen::Code::Exec::codeReplaceInLocalContext($localContext,$content));
			closeLocalContext($localContext);
			print RSS "      <author>$content</author>\n";
		}
		print RSS "    </item>\n";
	}

	print RSS "  </channel>\n";
	print RSS "</rss>\n";
	close(*RSS);

	return ($filename, $sitepath);
}

1;
__END__
