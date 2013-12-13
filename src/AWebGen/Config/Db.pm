# Copyright (C) 2008-13  Stephane Galland <galland@arakhne.org>
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

package AWebGen::Config::Db;

@ISA = ('Exporter');
@EXPORT = qw( &getCmdLineOpt &setCmdLineOpt &parseCmdLine &getConstant &setConstant 
              &isIgnorableFile &setRootDir &getRootDir &getAllConstants
	      &getPage &setPage &getAllPages &setWorkingDir &getWorkingDir
	      &getConfigPath &getIncludeDir &getDatabaseDir &getTestDir
	      &setTestDir &addIgnorableFile &isExpandableFile &addUnexpandableFile
	      &pushInDefaultArray &getDefaultArrays &pushInDefaultHash &getDefaultHashs
              &setScriptDir &getScriptDir &mkDatabaseFilename &mkIncludedFilename
            ) ;
@EXPORT_OK = qw();
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);
my $VERSION = "3.0" ;

use Carp;
use File::Basename;
use File::Spec;
use Getopt::Long;
use AWebGen::Release;

use constant DIRSEP => File::Spec->catfile('','');
use constant TRUE => (1==1);
use constant FALSE => (1==0);

my $SCRIPTDIR = undef;
my $ROOTDIR = undef;
my $WORKINGDIR = undef;

my %CMDLINEOPTS = ('verbose' => 0,
		   'rss' => 'news',
		   'autoscript' => TRUE,
                  );

my @FILES_TO_EXCLUDE = (
	'*~', '*.bak', '/.awebgen', '*.old'
);

my @FILES_TO_IGNORE = (	
);

my %CONSTANTS = (
        'NEWS_DB' => 'news',
	'GENERATOR' => "Arakhn&ecirc;.org Offline Generator v".getVersionNumber(),
	'YEAR' => 1900+(localtime())[5],
	'TODAY' => scalar(localtime),
	'MAIN_MENU_SELECTION' => 'home',
	'SUBMENU_SELECTION' => 'none',
	'LAST_UPDATE_DATE' => '###LAST_UPDATE_DATE###',
	'DIFFERED_GENERATOR' => "Arakhn&ecirc;.org Offline Generator v###AWEBGEN_VERSION###",
	'SITE_IMG' => '${IMG}/header.png',
	'CSS_FILE' => '${ROOT}/default.css',
	'EMAIL_CRYPT_KEY' => "|CHEZ|",
);

my %PAGES = (
	'home' => { 'url' => '${ROOT}/index.html',
                    'label' => '${SITE_NAME}',
                    'short' => '${SITE_NAME}',
                    'parent' => undef,
		  },
);

my $TESTDIR = '../test';

my %ARRAYS = ();
my %HASHS = ();

sub getPage($) {
	my $name = shift || confess("no page name");
	return $PAGES{"$name"};
}

sub setPage($$$$;$$$) {
	my $name = shift || confess("no page name");
	my $url = shift || confess("no page url");
	my $label = shift || confess("no page label");
	my $short = shift || "$label";
	my $parent = shift || "";
	my $snap = shift || "";
	my $misc = shift || [];
	$PAGES{"$name"} = { 'url' => "$url", 'label' => "$label", 'short' => "$short", 'parent' => $parent, 'misc' => $misc, 'snap' => $snap };
}

sub getAllPages() {
	return \%PAGES;
}

sub getCmdLineOpt($) {
	my $name = shift || confess("no command line option name");
	return $CMDLINEOPTS{"$name"};
}

sub setCmdLineOpt($$) {
	my $name = shift || confess("no command line option name");
	$CMDLINEOPTS{"$name"} = $ _[0];
}

sub parseCmdLine() {
	Getopt::Long::Configure("bundling") ;
	if (!GetOptions( 'v+' => \$CMDLINEOPTS{'verbose'},
		         'test' => \$CMDLINEOPTS{'test'},
			 'rss=s' => \$CMDLINEOPTS{'rss'},
			 'norss' => sub { $CMDLINEOPTS{'rss'} = undef; },
			 'maintenance' => \$CMDLINEOPTS{'maintenance'},
			 'mirror=s' => \$CMDLINEOPTS{'mirror'},
			 'password=s' => \$CMDLINEOPTS{'password'},
			 'nomirror' => sub { delete $CMDLINEOPTS{'mirror'}; },
			 'f' => \$CMDLINEOPTS{'force-mirror'},
			 'autoscript!' => \$CMDLINEOPTS{'autoscript'},
			 'announce=s' => \$CMDLINEOPTS{'announce'},
			 'noannounce' => sub { delete $CMDLINEOPTS{'announce'}; },
			 'style=s' => \$CMDLINEOPTS{'style'},
			 'stylelist' => \$CMDLINEOPTS{'stylelist'},
			 'version' => \$CMDLINEOPTS{'version'},
		)) {
		exit(1);
	}
}

sub getConstant($) {
	my $name = shift || confess("no constant name");
	return $CONSTANTS{"$name"};
}

sub setConstant($$) {
	my $name = shift || confess("no constant name");
	$CONSTANTS{"$name"} = $_[0];
}

sub getAllConstants() {
	return \%CONSTANTS;
}

# Replies if the given file must be ignored
sub isIgnorableFile($) {
	my $full = shift || confess("isIgnorableFile() requires a parameter");
	my $basename = basename("$full");
	my $dirname = dirname("$full");
	my $sep = DIRSEP;
	foreach my $pattern (@FILES_TO_EXCLUDE) {
		my $p = "$pattern";
		$p =~ s/\./\\./g;
		$p =~ s/\+/\\+/g;
		$p =~ s/\*/.+/g;
		$p =~ s/\?/.?/g;

		if ($pattern =~ /\Q$sep\E/) {
			if ($full =~ /^$p$/ || $dirname =~ /^$p/ ) {
				return TRUE;
			}
		}
		elsif ($basename =~ /^$p$/) {
			return TRUE;
		}
	}
	return FALSE;
}

# Replies if the given file must be expanded
sub isExpandableFile($) {
	my $full = shift || confess("isExpandableFile() requires a parameter");
	my $basename = basename("$full");
	my $dirname = dirname("$full");
	my $sep = DIRSEP;
	foreach my $pattern (@FILES_TO_IGNORE) {
		my $p = "$pattern";
		$p =~ s/\./\\./g;
		$p =~ s/\+/\\+/g;
		$p =~ s/\*/.+/g;
		$p =~ s/\?/.?/g;

		if ($pattern =~ /\Q$sep\E/) {
			if ($full =~ /^$p$/ || $dirname =~ /^$p/ ) {
				return FALSE;
			}
		}
		elsif ($basename =~ /^$p$/) {
			return FALSE;
		}
	}
	return TRUE;
}

sub addIgnorableFile($) {
	my $pattern = shift || confess("no pattern");
	push @FILES_TO_EXCLUDE, "$pattern";
}

sub addUnexpandableFile($) {
	my $pattern = shift || confess("no pattern");
	push @FILES_TO_IGNORE, "$pattern";
}

sub getConfigFileName($) {
	my $path = shift || confess("no path");
	return File::Spec->catfile($path,'.awebgen','config');
}

sub setRootDir($) {
	my $path = shift || confess("no path");
	$ROOTDIR = $path;
}

sub getRootDir() {
	return $ROOTDIR;
}

sub getConfigPath() {
	return File::Spec->catfile($ROOTDIR,'.awebgen');
}

sub getIncludeDir() {
	return File::Spec->catfile(getConfigPath(),'includes');
}

sub getDatabaseDir() {
	return File::Spec->catfile(getConfigPath(),'db');
}

sub setWorkingDir($) {
	my $path = shift || confess("no path");
	$WORKINGDIR = $path;
}

sub getWorkingDir() {
	return $WORKINGDIR;
}

sub setTestDir($) {
	my $path = shift || confess("no path");
	$TESTDIR = $path;
}

sub getTestDir() {
	return undef unless($TESTDIR);
	if (File::Spec->file_name_is_absolute($TESTDIR)) {
		return "$TESTDIR";
	}
	else {
		return File::Spec->catfile($ROOTDIR,$TESTDIR);
	}
}

sub pushInDefaultArray($$) {
	my $array = shift || confess("no array name");
	my $value = shift || '';
	if (!$ARRAYS{$array}) {
		$ARRAYS{$array} = [];
	}
	push @{$ARRAYS{$array}}, $value;
}

sub pushInDefaultHash($$$) {
	confess('no enough arguments: '.@_.'!=3') unless (@_==3);
	my $hash = shift || confess("no hash name");
	my $key = shift || confess("no key name");
	my $value = shift || '';
	$HASHS{$hash}{$key} = $value;
}

sub getDefaultArrays() {
	return \%ARRAYS;
}

sub getDefaultHashs() {
	return \%HASHS;
}

sub setScriptDir($) {
	my $path = shift || confess("no path");
	$SCRIPTDIR = $path;
}

sub getScriptDir() {
	return $SCRIPTDIR;
}

sub mkDatabaseFilename($) {
	my $shtml = shift || confess("no database name");
	return File::Spec->catfile(getDatabaseDir(),"$shtml.txt");
}

sub mkIncludedFilename($) {
	my $shtml = shift || confess("no shtml name");
	return File::Spec->catfile(getIncludeDir(),"$shtml.shtml");
}

1;
__END__
