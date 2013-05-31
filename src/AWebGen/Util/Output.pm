# Copyright (C) 2008  Stephane Galland <galland@arakhne.org>
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

package AWebGen::Util::Output;

@ISA = ('Exporter');
@EXPORT = qw( &verb &warm ) ;
@EXPORT_OK = qw();
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);
my $VERSION = "0.1" ;

use AWebGen::Config::Db;

# Display the message if under verbose
sub verb($@) {
	my $level = shift;
	if (getCmdLineOpt('verbose')>=$level) {
		foreach my $m (@_) {
			print "$m";
			if ($m !~ /[\r\n]$/s) {
				print "\n";
			}
		}
	}
}

# Display the warning message
sub warm($@) {
	print "WARNING: ";
	foreach my $m (@_) {
		print "$m";
		if ($m !~ /[\r\n]$/s) {
			print "\n";
		}
	}
}

1;
__END__
