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

package AWebGen::Mirror::Checksum;

@ISA = ('Exporter');
@EXPORT = qw( &getLocalChecksums &saveLocalChecksums &computeChecksums &matchChecksumsForMirror &synchronizeLocalChecksumDates ) ;
@EXPORT_OK = qw();
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);
my $VERSION = "1.0" ;

use Carp;

use constant TRUE => (1==1);
use constant FALSE => (1==0);

use Digest::MD5 qw/ md5_hex /;
use Compress::Zlib;
use File::Spec;
use AWebGen::Util::Output;
use AWebGen::Config::Db;
use AWebGen::Util::File;

# Replies the path to the local checksum file
sub getChecksumFilename() {
	return File::Spec->catfile(getConfigPath(),'md5.list');
}

# Replies the checksums from the local directory
# $_[0]: directory to explore
# $_[1]: checksum data structure to fill
# $_[2]: map of already known checksums
sub computeChecksums($\%\%;$) {
	my $dir = shift || croak('no directory');
	my $cs = shift;
	my $existingcs = shift;
	my $md5label = shift || 'md5_local';
	my $root = "$dir";
	my $now = int(time);

	if ($md5label ne 'md5_local' && $md5label ne 'md5_remote') {
		$md5label = 'md5_local';
	}

	my $omd5label = ($md5label eq 'md5_local') ? 'md5_remote' : 'md5_local';

	my @dirs = ( $dir );

	while (@dirs) {
		$dir = shift @dirs;
		local *DIR;
		opendir(*DIR,"$dir") or croak("$dir: $!\n");
		while (my $file = readdir(*DIR)) {
			if ($file ne File::Spec->curdir() && $file ne File::Spec->updir()) {
				my $fullpath = File::Spec->catfile($dir,$file);
				if (-d "$fullpath") {
					push @dirs, "$fullpath";
				}
				elsif (-f "$fullpath") {
					my $k = "$fullpath";
					$k =~ s/^\Q$root\E//s;
					my $md5checksum = md5_hex(readFile("$fullpath"));
					if ($md5label eq 'md5_local') {
						$cs->{"$k"}{$md5label} = $md5checksum;
					}
					elsif ((!$existingcs->{"$k"}{$md5label})||
					       ($existingcs->{"$k"}{$md5label} ne $md5checksum)) {
						$cs->{"$k"}{$md5label} = $md5checksum;
						$cs->{"$k"}{'uploadable'} = TRUE;
						$cs->{"$k"}{'changed'} = $existingcs->{"$k"}{'changed'} || FALSE;
						$cs->{"$k"}{'removable'} = $existingcs->{"$k"}{'removable'} || FALSE;
					}
					else {
						$cs->{"$k"}{$md5label} = $existingcs->{"$k"}{$md5label};
						$cs->{"$k"}{'changed'} = $existingcs->{"$k"}{'changed'} || FALSE;
						$cs->{"$k"}{'removable'} = $existingcs->{"$k"}{'removable'} || FALSE;
					}
					if (exists $existingcs->{"$k"}{$omd5label}) {
						$cs->{"$k"}{$omd5label} = $existingcs->{"$k"}{$omd5label} || '';
					}
					else {
						$cs->{"$k"}{$omd5label} = '';
					}
					if (exists $existingcs->{"$k"}{'last_change'}) {
						$cs->{"$k"}{'last_change'} = $existingcs->{"$k"}{'last_change'} || $now;
					}
					else {
						$cs->{"$k"}{'last_change'} = $now;
					}
				}
			}
		}
		closedir(*DIR);
	}
}

# Update the last change date for the checksums.
# $_[0]: checksum data structure to update
# $_[1]: current checksums on file system
sub synchronizeLocalChecksumDates(\%\%) {
	my $cs = shift;
	my $fscs = shift;
	my $now = int(time);

	my %removed = ();
	foreach my $k (keys %{$cs}) {
		$removed{"$k"} = undef;
	}

	foreach my $k (keys %{$fscs}) {
		my $currentmd5 = $fscs->{"$k"}{'md5_local'};
		if (exists $cs->{"$k"}{'md5_local'} && $cs->{"$k"}{'md5_local'}) {
			delete $removed{"$k"};
			if ($cs->{"$k"}{'md5_local'} ne "$currentmd5") {
				# Updated file
				$cs->{"$k"}{'md5_local'} = "$currentmd5";
				$cs->{"$k"}{'last_change'} = $now;
				$cs->{"$k"}{'changed'} = TRUE;
				$cs->{"$k"}{'uploadable'} = TRUE;
			}
			elsif (!defined($cs->{"$k"}{'last_change'})) {
				$cs->{"$k"}{'last_change'} = $now;
			}
		}
		else {
			# Added file
			$cs->{"$k"}{'md5_local'} = "$currentmd5";
			$cs->{"$k"}{'md5_remote'} = '';
			$cs->{"$k"}{'last_change'} = $now;
			$cs->{"$k"}{'changed'} = TRUE;
			$cs->{"$k"}{'uploadable'} = TRUE;
			delete $removed{"$k"};
		}
	}

	foreach my $k (keys %removed) {
		$cs->{"$k"}{'last_change'} = $now;
		$cs->{"$k"}{'changed'} = TRUE;
		$cs->{"$k"}{'removable'} = TRUE;
	}
}

# Parse a string to extract checksums
sub parseChecksums($\%$) {
	my $text = shift || croak('no content text');
	my $checksums = shift;
	my $defaultDate = shift;
	foreach my $line (split(/[\n\r]+/,$text)) {
		if ($line =~ /^\s*(.*?)\s*\=\>\s*([a-zA-Z0-9]+)\s*\|\s*([0-9a-zA-Z]+)\s*\|\s*([0-9]+)/s) {
			my ($file, $md5a, $md5b, $lastchange) = ("$1","$2", "$3", "$4");
			$checksums->{"$file"}{'md5_local'} = "$md5a";
			$checksums->{"$file"}{'md5_remote'} = $md5b || '';
			$checksums->{"$file"}{'last_change'} = $lastchange || $defaultDate;
		}
		else {
			warm("unrecognized line in checksum database:\n $line\n");
		}
	}
}

# Replies the checksums from the local directory
# $_[0] : default 'last_change' date if not set.
sub getLocalChecksums(;$) {
	my $defaultDate = shift || undef;
	my %checksums = ();

	my $fn = getChecksumFilename();

	my $content;

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

	if ($content) {
		parseChecksums($content,%checksums,$defaultDate);
	}

	return %checksums;
}

# Save the checksums into the local directory
sub saveLocalChecksums(\%) {
	my $cs = shift || {};

	my $fn = getChecksumFilename();

	#unlink("$fn");
	#unlink("$fn.gz");	

	my @files = keys %{$cs};

	my $gz = gzopen("$fn.gz","wb") || croak("$fn.gz: $!");
	foreach my $file (@files) {
		verb(3,"Saving checksum for $file\n");
		my $md5a = $cs->{"$file"}{'md5_local'} || undef;
		my $md5b = $cs->{"$file"}{'md5_remote'} || undef;
		my $lastChange = $cs->{"$file"}{'last_change'} || undef;
		croak("no local md5 for $file") unless ($md5a);
		croak("no remote md5 for $file") unless ($md5b);
		croak("no last_change for $file") unless (defined($lastChange));
		$gz->gzwrite("$file => $md5a | $md5b | $lastChange\n");
	}
	$gz->gzclose();
}

1;
__END__
