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

package AWebGen::PHP::Empty;

@ISA = ('Exporter');
@EXPORT = qw( &phppage_empty_do ) ;
@EXPORT_OK = qw();
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);
my $VERSION = "1.0" ;

use constant TRUE => (1==1);
use constant FALSE => (1==0);

use Carp;
use File::Spec;
use File::Copy;
use AWebGen::Config::Db;
use AWebGen::Util::Output;
use AWebGen::Code::Exec;

#------------------------------------------------------
#
# REDIRECT WRAPPING
#
#------------------------------------------------------

sub phppage_empty($) {
	my $targetdir = shift || confess('no target dir');
	my $phpfile = File::Spec->catfile(getScriptDir(),'AWebGen','PHP','empty.php');
	confess("PHP model 'empty.php' was not found or readable") unless (-r "$phpfile");

	my $targetfile = File::Spec->catfile("$targetdir",'index.php');
	my $workingdir = getWorkingDir();
	my $htmltarget = "$targetfile";
	$htmltarget =~ s/^\Q$workingdir\E//;

	copy("$phpfile", "$targetfile") or confess("$phpfile: $!\n");
	codeReplaceInFile("$targetfile","$htmltarget");

	1;
}

sub phppage_empty_do(\%) {
	verb(1,"Generating redirections to root");
	my $dir = getWorkingDir();
	local *DIR;
	my @dirs = ($dir);
	while (@dirs) {
		$dir = shift @dirs;
		opendir(*DIR,"$dir") or confess("$dir: $!\n");
		my $foundindex = FALSE;
		while (my $entry = readdir(*DIR)) {
			my $abs = File::Spec->catfile("$dir","$entry");
			if ($entry ne File::Spec->curdir() && $entry ne File::Spec->updir()) {
				if (-d "$abs") {
					push @dirs, "$abs";
				}
				elsif (-f "$abs" && $entry =~ /^index\.[a-z]+$/) {
					$foundindex = TRUE;
				}
			}
		}
		closedir(*DIR);
		if (!$foundindex) {
			phppage_empty("$dir");
		}
	}
}

1;
__END__
