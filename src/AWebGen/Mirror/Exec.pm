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

package AWebGen::Mirror::Exec;

@ISA = ('Exporter');
@EXPORT = qw( &mirrorSite  &computeMirrorState ) ;
@EXPORT_OK = qw();
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);
my $VERSION = "3.1" ;

use Carp;
use File::Basename;
use Net::FTP;
use AWebGen::Util::Output;

use constant TRUE => (1==1);
use constant FALSE => (1==0);
use constant DIRSEP => File::Spec->catfile('','');

# Do upload
# $_[0]: total count of files 
# $_[1]: count of treated files 
# $_[2]: ftp url
# $_[3]: local root directory
# $_[4]: password
# @: list of files to upload
sub upload($$$$$@) {
	my $countOfFiles = shift || 0;
	my $countOfTFiles = shift || 0;
	my $url = shift || croak('no url');
	my $root = shift || croak('no root directory');
	my $dpasswd = shift || '';

	if (@_) {
		verb(2,"Uploading files");
		my ($login,$passwd,$host,$port,$remoteroot);

		# Parse URL
		if ($url =~ /^\s*ftp:\/\/(?:([a-zA-Z_0-9.]+)(?:\:([\@]+))?\@)?([a-zA-Z_0-9\.]+)(?:([0-9]+))?(\/.*?)\s*$/) {
			($login,$passwd,$host,$port,$remoteroot) = ($1,$2,$3,$4,$5);
		}
		else {
			croak("unsupported url format: $url");
		}

		my $ftp = Net::FTP->new("$host") or croak("Cannot connect to $host: $@");
		$ftp->login("$login",$passwd || $dpasswd || '') or croak("Cannot login with $login: ", $ftp->message);

		$ftp->binary();
		my $progress = $countOfTFiles;

		foreach my $file (@_) {
			my $percent = int(($progress*100)/$countOfFiles);
			my $dir = dirname("$file");
			my $path;
			if ($dir eq DIRSEP) {
				$path = "$remoteroot";
			}
			else {
				$path = File::Spec->catfile($remoteroot, $dir);
			}
			my $lfile = File::Spec->catfile("$root","$file");
			$ftp->mkdir("$path", TRUE);
			$ftp->cwd("$path") or croak("Cannot change working directory $path: ", $ftp->message);
			verb(2,"[$percent\%] Uploading $file -> $path");
			$ftp->put("$lfile") or croak("Cannot upload ($lfile): ", $ftp->message);

			$progress ++;
		}

		$ftp->quit();
	}
}

# Do remote remove
# $_[0]: total count of files 
# $_[1]: count of treated files 
# $_[2]: ftp url
# $_[3]: password
# @: list of files to rmeove
sub remoteRemove($$$$@) {
	my $countOfFiles = shift || 0;
	my $countOfTFiles = shift || 0;
	my $url = shift || croak('no url');
	my $dpasswd = shift || '';

	if (@_) {
		verb(2,"Removing remote files");
		my ($login,$passwd,$host,$port,$remoteroot);

		# Parse URL
		if ($url =~ /^\s*ftp:\/\/(?:([a-zA-Z_0-9]+)(?:\:([\@]+))?\@)?([a-zA-Z_0-9\.]+)(?:([0-9]+))?(\/.*?)\s*$/) {
			($login,$passwd,$host,$port,$remoteroot) = ($1,$2,$3,$4,$5);
		}
		else {
			croak("unsupported url format: $url");
		}

		my $ftp = Net::FTP->new("$host") or croak("Cannot connect to $host: $@");
		$ftp->login("$login",$passwd || $dpasswd || '') or croak("Cannot login with $login: ", $ftp->message);

		my $progress = $countOfTFiles;

		foreach my $file (@_) {
			my $percent = int(($progress*100)/$countOfFiles);
			my $dir = dirname("$file");
			my $base = basename("$file");
			my $path;
			if ($dir eq DIRSEP) {
				$path = "$remoteroot";
			}
			else {
				$path = File::Spec->catfile($remoteroot, $dir);
			}
			$ftp->cwd("$path") or croak("Cannot change working directory $path: ", $ftp->message);
			verb(2,"[$percent\%] Removing $base from $path");
			$ftp->delete($base) or warm("Cannot remove $base: ", $ftp->message);

			# Remove the directory if empty.
			my $rmTree = TRUE;
			while ($rmTree) {
				my @content = $ftp->ls();
				if (@content) {
					$rmTree = FALSE;
				}
				else {
					$base = basename("$path");
					$path = dirname("$path");
					$ftp->cwd("$path") or croak("Cannot change working directory $path: ", $ftp->message);
					verb(2,"[$percent\%]Removing empty directory $base");
					$ftp->rmdir("$base") or croak("Cannot remove directory $base from $path: ", $ftp->message);
					$rmTree = (($path) && ($path ne '/'));
				}
			}

			$progress ++;
		}

		$ftp->quit();
	}
}

# Mirror the generated website with the given URL
# $_[0]: local directory
# $_[1]: remote location
# $_[2]: password
# $_[3]: Checksums
sub mirrorSite($$$\%) {
	my $localdir = shift || croak('no local directory');
	my $url = shift || croak('no url');
	my $password = shift || '';
	my $checksums = shift || {};

	verb(1,"Mirror the directory to $url");

	# Extract list of files
	my @toremove = ();
	my @toupload = ();
	foreach my $file (keys %{$checksums}) {
		if ($checksums->{"$file"}{'uploadable'}) {
			push @toupload, "$file";
		}
		elsif ($checksums->{"$file"}{'removable'}) {
			push @toremove, "$file";
		}
	}

	my $total = @toupload + @toremove;

	upload($total,0,$url,$localdir,$password,@toupload);
	remoteRemove($total,@toupload,$url,$password,@toremove);
}

# Replies the count of pages changed, to upload and to remove.
sub computeMirrorState(\%) {
	my $checksums = shift || {};

	my $contentChanged = 0;
	my $toremove = 0;
	my $toupload = 0;
	foreach my $file (keys %{$checksums}) {
		if ($checksums->{"$file"}{'changed'}) {
			verb(3,"changed: $file\n");
			$contentChanged ++;
		}
		if ($checksums->{"$file"}{'uploadable'}) {
			verb(3,"uploadable: $file\n");
			$toupload ++;
		}
		elsif ($checksums->{"$file"}{'removable'}) {
			verb(3,"removable: $file\n");
			$toremove ++;
		}
	}
	return ($contentChanged,$toupload,$toremove);
}

1;
__END__
