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

package AWebGen::PHP::Websvn;

@ISA = ('Exporter');
@EXPORT = qw( &phppage_websvn_do ) ;
@EXPORT_OK = qw();
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);
my $VERSION = "1.0" ;

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

sub phppage_websvn(\%) {
	my $phpfile = File::Spec->catfile(getScriptDir(),'AWebGen','PHP','websvn.php');
	confess("PHP model 'websvn.php' was not found or readable") unless (-r "$phpfile");

	my $svnUrl = getConstant('WEBSVN_URL');
	my $fullSvnUrl = getConstant('WEBSVN_FULL_URL');
	$fullSvnUrl = "$svnUrl" if (!$fullSvnUrl);

	$svnUrl =~ s/\$\{PROJECT\}/\$project/g;
	$fullSvnUrl =~ s/\$\{PROJECT\}/\$project/g;
	$fullSvnUrl =~ s/\$\{SUBPROJECT\}/\$subproject/g;

	my $targetfile = File::Spec->catfile(getWorkingDir(),'websvn.php');
	local *OUT;
	local *IN;
	open(*IN,"< $phpfile") or confess("$phpfile: $!\n");
	open(*OUT,"> $targetfile") or confess("$targetfile: $!\n");
	
	while (my $line = <IN>) {
		$line =~ s/\#\{WEBSVN_URL\}/$svnUrl/g;
		$line =~ s/\#\{WEBSVN_FULL_URL\}/$fullSvnUrl/g;
		print OUT $line;
	}

	close(*OUT);
	close(*IN);

	codeReplaceInFile("$targetfile","/websvn.php");
	$_[0]->{$targetfile} = '/websvn.php';

	1;
}

sub phppage_websvn_do(\%) {
	my $svnUrl = getConstant('WEBSVN_URL');
	if ($svnUrl) {
		verb(1,"Generating Websvn redirection");
		phppage_websvn(%{$_[0]});
	}
}

1;
__END__
