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

package AWebGen::Mirror::MirrorVariables;

@ISA = ('Exporter');
@EXPORT = qw( &replaceMirroringVariablesInFile &replaceMirroringVariables ) ;
@EXPORT_OK = qw();
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);
my $VERSION = "2.0" ;

use Carp;
use File::Basename;
use File::Spec;
use AWebGen::Config::Db;
use AWebGen::Util::File;
use AWebGen::Release;

# Replace mirroring variables
# $_[0]: string which must be updated
# $_[1]: site's path
# $_[2]: checksum and last date info on each page
sub replaceMirroringVariables($$\%) {
	my $now = scalar(localtime);

	if (exists $_[2]->{$_[1]}{'last_change'} && $_[2]->{$_[1]}{'last_change'}) {
		$now = scalar(localtime($_[2]->{$_[1]}{'last_change'}));
	}

	my $version = getVersionNumber();
	$_[0] =~ s/\Q###LAST_UPDATE_DATE###\E/$now/sg;
	$_[0] =~ s/\Q###AWEBGEN_VERSION###\E/$version/sg;

	my $hashs = getDefaultHashs();
	if (exists $hashs->{'###AWEBGEN_DIFFERED_CONTENT###'}) {
		my $differedContent = $hashs->{'###AWEBGEN_DIFFERED_CONTENT###'} || {};
		foreach my $k (keys %{$differedContent}) {
			my $content = $differedContent->{"$k"}{$_[1]} || '';
			$_[0] =~ s/\Q###AWEBGEN_DIFFERED_CONTENT_$k###\E/$content/sg;
		}
	}
}

# Replace mirroring variables
# $_[0]: filename
# $_[1]: site's path
# $_[2]: checksum and last date info on each page
sub replaceMirroringVariablesInFile($$\%) {
	my $filename = shift;
	my $sitepath = shift;
	my $content = readFile("$filename");

	replaceMirroringVariables($content, $sitepath, %{$_[0]});
	writeFile("$filename", "$content");
}

1;
__END__
