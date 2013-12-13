# Copyright (C) 2009  Stephane Galland <galland@arakhne.org>
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

package AWebGen::Style::Exec;

@ISA = ('Exporter');
@EXPORT = qw( &installStyle ) ;
@EXPORT_OK = qw();
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);
my $VERSION = "0.1" ;

use Carp;
use File::Spec;
use File::Path;
use File::Copy;

use AWebGen::Config::Db;
use AWebGen::Util::Output;
use AWebGen::Util::File;

use constant TRUE => (1==1);
use constant FALSE => (1==0);

sub installStyleFrom($$) {
	my $styleName = shift || carp("no style name given");
	my $rootDir = shift || carp("no search directory given");
	my $targetDir = File::Spec->catfile(getRootDir(), "theme");

	verb(2, "Installing style '$styleName' from '$rootDir'");

	my $themeDir = File::Spec->catfile("$rootDir", "themes", "$styleName");

	if (-d "$themeDir") {

		if ( -d "$targetDir" ) {
			verb(2, "Removing previous theme directory");
			rmtree("$targetDir") or die("$targetDir: $!\n");
		}

		my $includeDir = File::Spec->catfile("$themeDir", "includes");
		if (-d "$includeDir") {
			verb(2, "Installing included pattern files");
			my $tDir = getIncludeDir();
			if ( -d "$tDir" ) {
				rmtree("$tDir") or die("$tDir: $!\n");
			}
			mkpath(["$tDir"], 0, 0700) or confess("mkpath|$tDir: $!\n");
			copyDir("$includeDir","$tDir") or die("$includeDir: $!\n");
		}

		my $cssDir = File::Spec->catfile("$themeDir", "css");
		if (-d "$cssDir") {
			verb(2, "Installing CSS files");
			my $tDir = File::Spec->catfile("$targetDir","css");
			if ( ! -d "$tDir" ) {
				mkpath(["$tDir"], 0, 0700) or confess("mkpath|$tDir: $!\n");
			}
			copyDir("$cssDir","$tDir") or die("$cssDir: $!\n");
		}

		my $imageDir = File::Spec->catfile("$themeDir", "images");
		if (-d "$imageDir") {
			verb(2, "Installing image files");
			my $tDir = File::Spec->catfile("$targetDir","images");
			if ( ! -d "$tDir" ) {
				mkpath(["$tDir"], 0, 0700) or confess("mkpath|$tDir: $!\n");
			}
			copyDir("$imageDir","$tDir") or die("$imageDir: $!\n");
		}

		my $fontDir = File::Spec->catfile("$themeDir", "fonts");
		if (-d "$fontDir") {
			verb(2, "Installing font files");
			my $tDir = File::Spec->catfile("$targetDir","fonts");
			if ( ! -d "$tDir" ) {
				mkpath(["$tDir"], 0, 0700) or confess("mkpath|$tDir: $!\n");
			}
			copyDir("$imageDir","$tDir") or die("$imageDir: $!\n");
		}
		my $configFile = File::Spec->catfile("$themeDir", "config.xml");
		if (-f "$configFile") {
			verb(2, "Installing configuration file");
			my $tFile = File::Spec->catfile("$targetDir","config.xml");
			copy("$configFile","$tFile") or die("$configFile: $!\n");
		}

		return TRUE;

	}

	return FALSE;
}

# $_[0] : style name
sub installStyle($) {
	my $styleName = shift || carp("no style name given");
	my $rootDir = getRootDir();
	my $scriptDir = getScriptDir();

	if (!installStyleFrom("$styleName", "$rootDir")) {
		if (!installStyleFrom("$styleName", "$scriptDir")) {
			die("Unable to install style '$styleName'\n");
		}
	}

	return TRUE;
}

1;
__END__
