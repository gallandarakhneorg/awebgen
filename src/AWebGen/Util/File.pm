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

package AWebGen::Util::File;

@ISA = ('Exporter');
@EXPORT = qw( &canondir &readFile &writeFile &getTempWorkingDirectory &copyDir ) ;
@EXPORT_OK = qw();
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);
my $VERSION = "3.0" ;

use Carp;
use File::Spec;
use File::Copy;
use File::Temp qw/tempdir/;

use constant TRUE => (1==1);
use constant FALSE => (1==0);

my $tmpDir = undef;

# Remove the . and .. from the given path
sub canondir($) {
	my $path = shift || '.';
	my @elts = File::Spec->splitdir("$path");
	my @r = ();
	for(my $i=0; $i<=$#elts; $i++) {
		if ($elts[$i] eq File::Spec->curdir()) {
			# Ignore '.'
		}
		elsif ($elts[$i] eq File::Spec->updir()) {
			# Remove last component
			if (@r) {
				pop @r;
			}
		}
		else {
			push @r, $elts[$i];
		}
	}
	my $canonpath = File::Spec->catdir(@r);
	return $canonpath;
}

# Read the content of a file.
sub readFile($) {
	my $abspath = shift;
	local *HTMLFILE;
	my $content = '';
	open(*HTMLFILE, "< $abspath") or confess("$abspath: $!\n");
	while (my $line = <HTMLFILE>) {
		$content .= $line;
	}
	close(*HTMLFILE);
	return $content;
}

# Write the content of a file.
sub writeFile($$) {
	my $abspath = shift;
	my $content = shift;
	local *HTMLFILE;
	open(*HTMLFILE, "> $abspath") or confess("$abspath: $!\n");
	print HTMLFILE "$content";
	close(*HTMLFILE);
}

# Get working directory
sub getTempWorkingDirectory() {
	if (!$tmpDir) {
		$tmpDir = tempdir( CLEANUP => 1 );
	}
	return $tmpDir;
}

# Copy the files (excluding subdirectories) in a directory to another
sub copyDir($$) {
	my $src = shift || carp("no source directory");
	my $tgt = shift || carp("no target directory");

	local *SRC;

	opendir(*SRC, "$src") or return FALSE;
	while (my $f = readdir(*SRC)) {
		if ($f ne File::Spec->curdir && $f ne File::Spec->updir) {
			my $sfn = File::Spec->catfile("$src", "$f");
			my $tfn = File::Spec->catfile("$tgt", "$f");
			copy("$sfn","$tfn") or return FALSE;
		}
	}
	closedir(*SRC);

	return TRUE;
}

1;
__END__
