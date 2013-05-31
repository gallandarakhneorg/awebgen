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

package AWebGen::PHP::Spip;

@ISA = ('Exporter');
@EXPORT = qw( &phppage_spip_do &phppage_spip ) ;
@EXPORT_OK = qw();
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);
my $VERSION = "2.0" ;

use Carp;
use File::Spec;
use AWebGen::Config::Db;
use AWebGen::Db::Text;
use AWebGen::Util::File;
use AWebGen::Util::Output;

use constant DB_FILENAME => 'spip.txt';

#------------------------------------------------------
#
# SPIP WRAPPING
#
#------------------------------------------------------

sub phppage_spip(\%) {
	my $dt_file = File::Spec->catfile(getDatabaseDir(),DB_FILENAME);
	my $phpfile = File::Spec->catfile(getScriptDir(),'AWebGen','PHP','spip.php');
	confess("PHP model 'spip.php' was not found or readable") unless (-r "$phpfile");

	my @database = extractTextDB(readFile("$dt_file"));

	my $pages = "";
	my $authors = "";
	my $errorpage = "";

	foreach my $db (@database) {
		if ($db->{'PAGE_ID'}) {
			$pages .= '$pages[\''.$db->{'PAGE_ID'}.'\'] = \''.$db->{'TARGET'}.'\'; # '.$db->{'COMMENT'}."\n";
		}
		elsif ($db->{'AUTHOR_ID'}) {
			$authors .= '$authors[\''.$db->{'AUTHOR_ID'}.'\'] = \''.$db->{'TARGET'}.'\'; # '.$db->{'COMMENT'}."\n";
		}
		elsif ($db->{'ERROR_PAGE'}) {
			$errorpage .= $db->{'ERROR_PAGE'};
		}
	}

	my $targetfile = File::Spec->catfile(getWorkingDir(),'spip.php');
	local *OUT;
	local *IN;
	open(*IN,"< $phpfile") or confess("$phpfile: $!\n");
	open(*OUT,"> $targetfile") or confess("$targetfile: $!\n");
	
	while (my $line = <IN>) {
		if ($pages) {
			$line =~ s/\#\{PAGES\}/$pages/g;
		}
		if ($authors) {
			$line =~ s/\#\{AUTHORS\}/$authors/g;
		}
		if ($errorpage) {
			$line =~ s/\#\{ERROR_PAGE\}/$errorpage/g;
		}
		print OUT $line;
	}

	close(*OUT);
	close(*IN);
	1;
}

sub phppage_old_spip_article($) {
	my $targetfile = shift || croak("no spip filename");
	local *OUT;
	open(*OUT,"> $targetfile") or confess("$targetfile: $!\n");
	print OUT "<?php\n";
	print OUT "\$location = \"./spip.php?article\".\$_GET['id_article'];\n";
	print OUT "header(\"Location: \$location\");\n";
	print OUT "?>\n";
	close(*OUT);
	1;
}

sub phppage_old_spip_rubrique($) {
	my $targetfile = shift || croak("no spip filename");
	local *OUT;
	open(*OUT,"> $targetfile") or confess("$targetfile: $!\n");
	print OUT "<?php\n";
	print OUT "\$location = \"./spip.php?rubrique\".\$_GET['id_rubrique'];\n";
	print OUT "header(\"Location: \$location\");\n";
	print OUT "?>\n";
	close(*OUT);
	1;
}

sub phppage_old_spip_auteur($) {
	my $targetfile = shift || croak("no spip filename");
	local *OUT;
	open(*OUT,"> $targetfile") or confess("$targetfile: $!\n");
	print OUT "<?php\n";
	print OUT "\$location = \"./spip.php?auteur\".\$_GET['id_auteur'];\n";
	print OUT "header(\"Location: \$location\");\n";
	print OUT "?>\n";
	close(*OUT);
	1;
}

sub phppage_old_spip(\%) {
	phppage_old_spip_article(File::Spec->catfile(getWorkingDir(),'article.php'));
	phppage_old_spip_article(File::Spec->catfile(getWorkingDir(),'article.php3'));
	phppage_old_spip_rubrique(File::Spec->catfile(getWorkingDir(),'rubrique.php'));
	phppage_old_spip_rubrique(File::Spec->catfile(getWorkingDir(),'rubrique.php3'));
	phppage_old_spip_auteur(File::Spec->catfile(getWorkingDir(),'auteur.php'));
	phppage_old_spip_auteur(File::Spec->catfile(getWorkingDir(),'auteur.php3'));
}

sub phppage_spip_do(\%) {
	my $dt_file = File::Spec->catfile(getDatabaseDir(),DB_FILENAME);
	if (-r "$dt_file") {
		verb(1,"Generating Spip wrapper");
		phppage_spip(%{$_[0]});
		verb(1,"Generating Spip wrapper for old Spip versions");
		phppage_old_spip(%{$_[0]});
	}
}

1;
__END__
