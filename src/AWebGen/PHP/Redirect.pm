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

package AWebGen::PHP::Redirect;

@ISA = ('Exporter');
@EXPORT = qw( &phppage_redirect_do &phppage_redirect ) ;
@EXPORT_OK = qw();
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);
my $VERSION = "1.0" ;

use Carp;
use File::Spec;
use AWebGen::Config::Db;
use AWebGen::Util::File;
use AWebGen::Util::Output;
use AWebGen::Code::Exec;

use constant MODEL_FILENAME => 'fullpage.shtml';
use constant TITLE => 'Page location has changed';
use constant DELAY => 5;
use constant HEADER => '<meta http-equiv="Refresh" content="'.DELAY.';url=$url">';
use constant TEXT => '<p>The location of the page has changed. Please update our bookmark.</p><p>New location: <a href="$url">$url</a>. You will be redirected in '.DELAY.' seconds.</p>';

#------------------------------------------------------
#
# REDIRECT WRAPPING
#
#------------------------------------------------------

sub phppage_redirect(\%) {
	my $dt_file = File::Spec->catfile(getIncludeDir(),MODEL_FILENAME);
	my $phpfile = File::Spec->catfile(getScriptDir(),'AWebGen','PHP','redirect.php');
	confess("PHP model 'redirect.php' was not found or readable") unless (-r "$phpfile");

	my $dtContent = readFile("$dt_file");
	return 1 unless ($dtContent);

	{
		my $txt = TITLE;
		$dtContent =~ s/\#\{PAGE_TITLE\}/$txt/g;
		$txt = HEADER;
		$dtContent =~ s/\#\{PAGE_HEADER\}/$txt/g;
		$txt = TEXT;
		$dtContent =~ s/\#\{PAGE_CONTENT\}/$txt/g;
	}

	my $targetfile = File::Spec->catfile(getWorkingDir(),'redirect.php');
	local *OUT;
	local *IN;
	open(*IN,"< $phpfile") or confess("$phpfile: $!\n");
	open(*OUT,"> $targetfile") or confess("$targetfile: $!\n");
	
	while (my $line = <IN>) {
		$line =~ s/\#\{PAGE_CONTENT\}/$dtContent/g;
		print OUT $line;
	}

	close(*OUT);
	close(*IN);

	codeReplaceInFile("$targetfile","/redirect.php");
	$_[0]->{$targetfile} = '/redirect.php';

	1;
}

sub phppage_redirect_do(\%) {
	my $dt_file = File::Spec->catfile(getIncludeDir(),MODEL_FILENAME);
	if (-r "$dt_file") {
		verb(1,"Generating redirection page");
		phppage_redirect(%{$_[0]});
	}
}

1;
__END__
