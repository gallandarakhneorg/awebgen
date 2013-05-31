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

package AWebGen::PHP::MailingList;

@ISA = ('Exporter');
@EXPORT = qw( &phppage_mailinglist_do ) ;
@EXPORT_OK = qw();
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);
my $VERSION = "1.0" ;

use Carp;
use File::Copy;
use AWebGen::Util::Output;
use AWebGen::Util::File;
use AWebGen::Code::Exec;
use AWebGen::Config::Db;

use constant MAILINGLISTKEY => 'mailinglists';
use constant MODEL_FILENAME => 'fullpage.shtml';
use constant TITLE => 'Mailing List';
use constant HEADER => '';
use constant TEXT => '$page_content';

#------------------------------------------------------
#
# REDIRECT WRAPPING
#
#------------------------------------------------------

sub phppage_mailinglist(\%) {
	my $hashs = getDefaultHashs();
	my $k = MAILINGLISTKEY;
	$hashs = $hashs->{$k};
	return 1 unless ($hashs);

	my $mlAddress = getConstant('ML_ADDRESS');
	return 1 unless ($mlAddress);

	$mlAddress =~ s/\$\{NAME\}/\$ml_name/sg;
	my $mlReqAddress = getConstant('ML_REQUEST_ADDRESS');
	if ($mlReqAddress) {
		$mlReqAddress =~ s/\$\{NAME\}/\$ml_name/sg;
	}
	else {
		$mlReqAddress = $mlAddress;
	}

	my $mlphpfile = File::Spec->catfile(getScriptDir(),'AWebGen','PHP','ml.php');
	confess("PHP model 'ml.php' was not found or readable") unless (-r "$mlphpfile");
	my $imgphpfile = File::Spec->catfile(getScriptDir(),'AWebGen','PHP','secimg.php');
	confess("PHP model 'secimg.php' was not found or readable") unless (-r "$imgphpfile");
	my $ttfphpfile = File::Spec->catfile(getScriptDir(),'AWebGen','PHP','secimg.gdf');
	confess("PHP model 'secimg.ttf' was not found or readable") unless (-r "$ttfphpfile");
	my $dt_file = File::Spec->catfile(getIncludeDir(),MODEL_FILENAME);

	my $dtContent = readFile("$dt_file");
	return 1 unless ($dtContent);

	verb(1,"Generating the mailing list script");
	{
		my $txt = TITLE;
		$dtContent =~ s/\#\{PAGE_TITLE\}/$txt/g;
		$txt = HEADER;
		$dtContent =~ s/\#\{PAGE_HEADER\}/$txt/g;
		$txt = TEXT;
		$dtContent =~ s/\#\{PAGE_CONTENT\}/$txt/g;
	}

	my $targetfile = File::Spec->catfile(getWorkingDir(),'ml.php');
	local *OUT;
	local *IN;
	open(*IN,"< $mlphpfile") or confess("$mlphpfile: $!\n");
	open(*OUT,"> $targetfile") or confess("$targetfile: $!\n");
	
	while (my $line = <IN>) {
		$line =~ s/\#\{ML_ADDRESS\}/$mlAddress/g;
		$line =~ s/\#\{ML_REQUEST_ADDRESS\}/$mlReqAddress/g;
		$line =~ s/\#\{PAGE_CONTENT\}/$dtContent/g;
		print OUT $line;
	}

	close(*OUT);
	close(*IN);

	codeReplaceInFile("$targetfile","/ml.php");
	$_[0]->{$targetfile} = '/ml.php';

	$targetfile = File::Spec->catfile(getWorkingDir(),'secimg.php');
	if (! -f "$targetfile") {
		verb(1,"Copying security image script");
		copy($imgphpfile,$targetfile) or confess("$targetfile: $!");
	}

	$targetfile = File::Spec->catfile(getWorkingDir(),'secimg.gdf');
	if (! -f "$targetfile") {
		verb(1,"Copying security image font");
		copy($ttfphpfile,$targetfile) or confess("$targetfile: $!");
	}

	1;
}

sub phppage_mailinglist_do(\%) {
	my $hashs = getDefaultHashs();
	my $k = MAILINGLISTKEY;
	if ($hashs && $hashs->{$k}) {
		phppage_mailinglist(%{$_[0]});
	}
}

1;
__END__
