# Copyright (C) 2008-10  Stephane Galland <galland@arakhne.org>
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

package AWebGen::PHP::Snap;

@ISA = ('Exporter');
@EXPORT = qw( &phppage_snap_do ) ;
@EXPORT_OK = qw();
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);
my $VERSION = "2.0" ;

use Carp;
use File::Spec;
use AWebGen::Config::Db;
use AWebGen::Util::Output;
use AWebGen::Code::Exec;

#------------------------------------------------------
#
# WEBSVN WRAPPING
#
#------------------------------------------------------

sub phppage_snap(\%) {
	my $phpfile = File::Spec->catfile(getScriptDir(),'AWebGen','PHP','snap.php');
	confess("PHP model 'snap.php' was not found or readable") unless (-r "$phpfile");

	my $snapUrl = getConstant('SNAP_URL');

	my $snapUrlWS = getConstant('SNAP_URL_SUBPROJECT');
	if( !$snapUrlWS) {
		$snapUrlWS = "$snapUrl";
	}

	$snapUrl =~ s/\$\{FLET\}/\".\$flet.\"/g;
	$snapUrl =~ s/\$\{NAME\}/\".\$name.\"/g;

	$snapUrlWS =~ s/\$\{FLET\}/\".\$flet.\"/g;
	$snapUrlWS =~ s/\$\{NAME\}/\".\$name.\"/g;
	$snapUrlWS =~ s/\$\{SUBNAME\}/\".\$subname.\"/g;

	my $mavenRepository = getConstant('MAVEN_REPOSITORY');
	if ($mavenRepository !~ /\/$/) {
		$mavenRepository .= '/';
	}
	$mavenRepository .= "\$groupPath/\$artifactId";

	my $mavenRepositoryVersion = "$mavenRepository/\$dirversion/";
	my $mavenRepositoryVersionJar = "$mavenRepository/\$dirversion/\$artifactId-\$jarversion.jar";
	my $mavenRepositoryDir = File::Spec->catfile(
		(getConstant('MAVEN_REPOSITORY_DIR') || ''),
		"\$groupPath", "\$artifactId", "\$dirversion");

	my $targetfile = File::Spec->catfile(getWorkingDir(),'snap.php');
	local *OUT;
	local *IN;
	open(*IN,"< $phpfile") or confess("$phpfile: $!\n");
	open(*OUT,"> $targetfile") or confess("$targetfile: $!\n");
	
	while (my $line = <IN>) {
		$line =~ s/\#\{SNAP_URL\}/$snapUrl/g;
		$line =~ s/\#\{SNAP_URL_SUBPROJECT\}/$snapUrlWS/g;
		$line =~ s/\#\{MAVEN_REPOSITORY\}/$mavenRepository/g;
		$line =~ s/\#\{MAVEN_REPOSITORY_VERSION\}/$mavenRepositoryVersion/g;
		$line =~ s/\#\{MAVEN_REPOSITORY_VERSION_WITH_JAR\}/$mavenRepositoryVersionJar/g;
		$line =~ s/\#\{MAVEN_REPOSITORY_DIR\}/$mavenRepositoryDir/g;
		print OUT $line;
	}

	close(*OUT);
	close(*IN);

	codeReplaceInFile("$targetfile","/snap.php");
	$_[0]->{$targetfile} = '/snap.php';

	1;
}

sub phppage_snap_do(\%) {
	my $svnUrl = getConstant('SNAP_URL');
	if ($svnUrl) {
		verb(1,"Generating Snap download page");
		phppage_snap(%{$_[0]});
	}
}

1;
__END__
