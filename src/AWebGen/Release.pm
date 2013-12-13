# Copyright (C) 2008-2013  Stephane Galland <galland@arakhne.org>
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

package AWebGen::Release;

@ISA = ('Exporter');
@EXPORT = qw( &getVersionNumber &getVersionDate &getBugReportURL
	      &getAuthorName &getAuthorEmail &getMainURL 
	      &getContributors ) ;
@EXPORT_OK = qw();
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);
my $VERSION = "9.0" ;

#------------------------------------------------------
#
# DEFINITIONS
#
#------------------------------------------------------

my $AWEBGEN_VERSION      = $VERSION ;
my $AWEBGEN_DATE         = '2013/12/13' ;
my $AWEBGEN_BUG_URL      = 'mailto:bugreport@arakhne.org' ;
my $AWEBGEN_AUTHOR       = 'Stephane GALLAND' ;
my $AWEBGEN_AUTHOR_EMAIL = 'galland@arakhne.org' ;
my $AWEBGEN_URL          = 'http://www.arakhne.org/awebgen/' ;
my %AWEBGEN_CONTRIBS     = ( #'email' => 'Name',
			    ) ;

#------------------------------------------------------
#
# Functions
#
#------------------------------------------------------

sub getVersionNumber() {
  return $AWEBGEN_VERSION ;
}

sub getVersionDate() {
  return $AWEBGEN_DATE ;
}

sub getBugReportURL() {
  return $AWEBGEN_BUG_URL ;
}

sub getAuthorName() {
  return $AWEBGEN_AUTHOR ;
}

sub getAuthorEmail() {
  return $AWEBGEN_AUTHOR_EMAIL ;
}

sub getMainURL() {
  return $AWEBGEN_URL ;
}

sub getContributors() {
  return %AWEBGEN_CONTRIBS ;
}

1;
__END__
