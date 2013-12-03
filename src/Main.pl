#!/usr/bin/perl -w
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

use strict;

use Carp;
use Cwd;
use File::Basename;
use File::Spec;
use File::Copy;
use File::Find;
use File::Temp qw/tempdir/;
use File::Path;

#------------------------------------------------------
#
# Initialization code
#
#------------------------------------------------------
my $PERLSCRIPTDIR ;
my $PERLSCRIPTNAME ;
BEGIN{
  # Where is this script?
  $PERLSCRIPTDIR = "$0";
  my $scriptdir = dirname( $PERLSCRIPTDIR );
  while ( -e $PERLSCRIPTDIR && -l $PERLSCRIPTDIR ) {
    $PERLSCRIPTDIR = readlink($PERLSCRIPTDIR);
    if ( substr( $PERLSCRIPTDIR, 0, 1 ) eq '.' ) {
      $PERLSCRIPTDIR = File::Spec->catfile( $scriptdir, "$PERLSCRIPTDIR" ) ;
    }
    $scriptdir = dirname( $PERLSCRIPTDIR );
  }
  $PERLSCRIPTNAME = basename( $PERLSCRIPTDIR ) ;
  $PERLSCRIPTDIR = dirname( $PERLSCRIPTDIR ) ;
  $PERLSCRIPTDIR = File::Spec->rel2abs( "$PERLSCRIPTDIR" );
  # Push the path where the script is to retreive the arakhne.org packages
  push(@INC,"$PERLSCRIPTDIR");
}

use AWebGen::Config::Db;
use AWebGen::Config::File;
use AWebGen::Util::Output;
use AWebGen::Code::Exec;
use AWebGen::RSS::Exec;
use AWebGen::PHP::Pages;
use AWebGen::Mirror::Checksum;
use AWebGen::Mirror::MirrorVariables;
use AWebGen::Mirror::Exec;
use AWebGen::Announce::Exec;
use AWebGen::Style::Exec;
use AWebGen::Release;

# Save the script root directory
setScriptDir("$PERLSCRIPTDIR");

# Detect the root directory
my $rootdir = getcwd(); #File::Spec->rel2abs(dirname($0));
if ($ARGV[0] && -d "$ARGV[0]") {
	$rootdir = $ARGV[0];
}
setRootDir($rootdir);

# Read default config file
readConfigFile();

# Read the theme's config file
{
	my $themeFile = File::Spec->catfile("$rootdir","theme","config.xml");
	if (-r "$themeFile") {
		readConfigFile("$themeFile");
	}
}

# Parse the command line
parseCmdLine();

# Test if version message may be displayed
if (getCmdLineOpt('version')) {
	print "awebgen ".getVersionNumber()." (".getVersionDate().")\n";
	getVersionDate() =~ /^\s*([0-9]+)\s*\//;
	my $year = "$1";
	print "Copyright (c) 2008-$year ".getAuthorName()." <".getAuthorEmail().">\n";
	exit(0);
}

# Test if a style may be install
if (getCmdLineOpt('style')) {
	verb(1,"Installing style '".getCmdLineOpt('style')."'");
	installStyle(getCmdLineOpt('style'));
	exit(0);
}

# Create the tmp directory
my $tmpdir = tempdir( CLEANUP => 1 );
setWorkingDir($tmpdir);

# Invoked by File::Find
my %findResult;
sub findMatch {
	my $rpath = "$File::Find::fullname";
	if (-f "$rpath") {
		my $path = "$rpath";
		$path =~ s/^\Q$rootdir\E//;
		if (($path)&&(!isIgnorableFile("$path"))) {
			$findResult{"$rpath"} = "$path";
		}
	}
}

# Find file in the directories
sub findFiles($@) {
	my %findopt = ( no_chdir => 1,
			follow => 1,
			wanted => \&findMatch,
		      );
	%findResult = ();
	find(\%findopt,@_);
	return %findResult;
}

# Get all files to copy
verb(1,"Find all the candidate for upload");
my %files = findFiles("$rootdir");

# Copy the files
verb(1,"Copy the files of the site");
my %copiedfiles = ();
while (my ($abspath, $sitepath) = each(%files)) {
	my $basename = basename("$sitepath");
	my $dirname = dirname("$sitepath");
	my $targetdir = File::Spec->catdir("$tmpdir", "$dirname");
	my $targetfile = File::Spec->catfile("$targetdir","$basename");
	if ( ! -d "$targetdir" ) {
		mkpath(["$targetdir"], 0, 0700) or confess("mkpath|$targetdir: $!\n");
	}
	verb(3,"$abspath->$targetfile\n");
	copy("$abspath", "$targetfile") or confess("copy|$abspath: $!\n");
	my $ldir = dirname("$targetfile");
	chmod(0755, "$ldir") or croak("$ldir: $!\n");
	chmod(0644, "$targetfile") or croak("$targetfile: $!\n");
	$copiedfiles{"$targetfile"} = "$sitepath";
}

# Replace macro commands in the HTML files
verb(1,"CMS variable replacement under progress");
while (my ($abspath, $sitepath) = each(%copiedfiles)) {
	if ((($sitepath =~ /\.html$/)||(($sitepath =~ /\.shtml$/))||(($sitepath =~ /\.php$/)))
            &&(isExpandableFile($sitepath))) {
		verb(2,"Replacement in $abspath");
		codeReplaceInFile("$abspath","$sitepath");
	}
}

# Generate the default scripts if necessary
if (getCmdLineOpt('autoscript')) {
	phppage_generate(%copiedfiles);
}

# Get the page's checksums
verb(1,"Computing page checksums");
my %pageChecksums = getLocalChecksums();
my %currentPageChecksums = ();
computeChecksums("$tmpdir", %currentPageChecksums, %pageChecksums);
synchronizeLocalChecksumDates(%pageChecksums, %currentPageChecksums);

# Replace differed constants
verb(1,"Finalizing pages");
while (my ($abspath, $sitepath) = each(%copiedfiles)) {
	if ((($sitepath =~ /\.html$/)||($sitepath =~ /\.shtml$/)||($sitepath =~ /\.php$/))
            &&(isExpandableFile($sitepath))) {
		verb(2,"Finalizing $abspath");
		replaceMirroringVariablesInFile("$abspath","$sitepath",%pageChecksums);
	}
}

# Generate the RSS
if (getCmdLineOpt('rss')) {
	verb(1,"Generating RSS flow for '".getCmdLineOpt('rss')."'");
	my ($absFile, $rssFile) = generateRSS(getCmdLineOpt('rss'), getConstant('NEWS_DB'));
	if ($absFile && $rssFile) {
		verb(2,"Finalizing $absFile");
		replaceMirroringVariablesInFile("$absFile","$rssFile",%pageChecksums);
	}
}

# Create the testing directory if necessary
if (getCmdLineOpt('test')) {
	verb(1,"Creating the test directory");
	my $testdir = getTestDir();
	if ($testdir) {
		rmtree(["$testdir"]);
		system("cd $tmpdir; tar cfz /tmp/test.tar.gz .");
		mkpath(["$testdir"], 0, 0700) or confess("mkpath|$testdir: $!\n");
		system("cd $testdir; tar xfz /tmp/test.tar.gz");
		unlink("/tmp/test.tar.gz");
	}
}

# Compute the checksums of the uploadable files
%currentPageChecksums = ();
computeChecksums("$tmpdir", %currentPageChecksums, %pageChecksums, 'md5_remote');

my ($contentChanged,$toupload, $toremove) = computeMirrorState(%currentPageChecksums);
verb(1,"Page stats:\n");
verb(1,"\tchanged:\t$contentChanged\n");
verb(1,"\tuploadable:\t$toupload\n");
verb(1,"\tremovable:\t$toremove\n");

# Do the mirror if necessary
if (getCmdLineOpt('mirror')) {
	mirrorSite($tmpdir,getCmdLineOpt('mirror'),getCmdLineOpt('password'),%currentPageChecksums);
	verb(2,"Update checksums in local database");
	saveLocalChecksums(%currentPageChecksums);
}
else {
	verb(1,"MIRRORING IS DISABLED\n");
}

# Do the announcements if necessary
if (getCmdLineOpt('announce')) {
	emailAnnounce(getConstant('NEWS_DB'));
}

exit(0);

1;
__END__
