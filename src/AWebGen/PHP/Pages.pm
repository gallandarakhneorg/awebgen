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

package AWebGen::PHP::Pages;

@ISA = ('Exporter');
@EXPORT = qw( &phppage_generate ) ;
@EXPORT_OK = qw();
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);
my $VERSION = "2.0" ;

use Carp;
use File::Spec;
use AWebGen::PHP::Redirect;
use AWebGen::PHP::Spip;
use AWebGen::PHP::Empty;
use AWebGen::PHP::Websvn;
use AWebGen::PHP::Snap;
use AWebGen::PHP::MailingList;
use AWebGen::PHP::SendMessage;

sub phppage_generate(\%) {
	phppage_redirect_do(%{$_[0]});
	phppage_spip_do(%{$_[0]});
	phppage_empty_do(%{$_[0]});
	phppage_websvn_do(%{$_[0]});
	phppage_snap_do(%{$_[0]});
	phppage_mailinglist_do(%{$_[0]});
	phppage_sendmessage_do(%{$_[0]});
}

1;
__END__
