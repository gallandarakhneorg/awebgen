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

package AWebGen::Db::Text;

@ISA = ('Exporter');
@EXPORT = qw( &extractTextDB ) ;
@EXPORT_OK = qw();
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);
my $VERSION = "0.1" ;

# Read a database
sub extractTextDB($) {
	my $content = shift;
	my @result = ();
	$content =~ s/^\s*\.\s*\#.*$/./mg;
	my @entries = split(/^\s*\.\s*$/m, "$content");
	foreach my $entry (@entries) {
		my %fields = ();
		my @lines = split(/[\n\r]+/, "$entry");
		my $mergeto = undef;
		foreach my $line (@lines) {
			$line =~ s/^\s+/ /;
			$line =~ s/\s+$//;
			if ($line =~ /^\s*([a-zA-Z0-9_]+)\s*=\s*(.*)$/) {
				my $name = uc("$1");
				my $value = "$2";
				$fields{"$name"} = $value || '';
				$mergeto = "$name";
			}
			elsif ($mergeto) {
				$line .= "\n"  if ($fields{"$mergeto"});
				$fields{"$mergeto"} .= $line;
			}
		}
		if (%fields) {
			push @result, \%fields;
		}
	}
	return @result;
}

1;
__END__
