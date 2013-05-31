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

package AWebGen::Config::File;

@ISA = ('Exporter');
@EXPORT = qw( &getConfigFileName &readConfigFile
            ) ;
@EXPORT_OK = qw();
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);
my $VERSION = "2.0" ;

use Carp;
use File::Spec;
use Net::Ifconfig::Wrapper;
use XML::Parser;
use AWebGen::Config::Db;

use constant TRUE => (1==1);
use constant FALSE => (1==0);
use constant DIRSEP => File::Spec->catfile('','');

sub xmlEq($$) {
	return lc($_[0]||'') eq lc($_[1]||'');
}

sub getAttr($$) {
	if (exists $_[0]->{$_[1]}) { return $_[0]->{$_[1]}; }
	if (exists $_[0]->{lc($_[1])}) { return $_[0]->{lc($_[1])}; }
	if (exists $_[0]->{uc($_[1])}) { return $_[0]->{uc($_[1])}; }
	return undef;
}

sub getConfigFileName() {
	return File::Spec->catfile(getConfigPath(),'config');
}

sub getXMLChild($\@) {
	my $name = shift;
	for(my $i=1; $i<=$#{$_[0]}; $i+=2) {
		if ("$_[0][$i]" eq "0") {
			# Raw text
		}
		else {
			# Tag
			if (xmlEq($_[0][$i], $name)) {
				return $_[0][$i+1];
			}
		}
	}
	return undef;
}

sub getXMLChildAt($$) {
	my $name = $_[0][1+($_[1]*2)];
	my $value = $_[0][1+($_[1]*2)+1];
	if (defined($name)) {
		return ($name,$value);
	}
	else {
		return ();
	}
}

sub dec2bin {
	my $str = unpack("B32", pack("N", shift));
	$str =~ s/^0+(?=\d)//;   # otherwise you'll get leading zeros
	return $str;
}

sub bin2dec {
	return unpack("N", pack("B32", substr("0" x 32 . shift, -32)));
}

sub mkmask($) {
	my $mask = shift || '0';
	my $m = '';
	for(my $i=0; $i<$mask; $i++) {
		$m .= '0';
	}
	for(my $i=$mask; $i<32; $i++) {
		$m = "1$m";
	}
	my @m = (	substr($m,0,8),
			substr($m,8,8),
			substr($m,16,8),
			substr($m,24,8) );

	foreach my $n (@m) {
		$n = bin2dec($n);
	}

	return join('.',@m);
}

sub mkBroadcast($$) {
	my $ip = shift;
	my $mask = shift;
	my @ei = split(/\./,$ip);
	my @em = split(/\./,$mask);
	my @r = ();
	for(my $i=0; ($i<@ei) && ($i<@em); $i++) {
		my $rm = (~(int($em[$i])))&(0xFF);
		my $fi = ($ei[$i] & $em[$i]) | $rm;
		push @r, $fi;
	}
	return join('.',@r);
}

sub isValidNetwork($) {
	my $ip = shift || croak('no ip given');
	my $mask = '255.255.255.255';

	if ($ip =~ /^([0-9]+(?:\.[0-9]+){3})\/([0-9]+(?:\.[0-9]+){3})$/) {
		($ip,$mask) = ("$1","$2");
	}
	elsif ($ip =~ /^([0-9]+(?:\.[0-9]+){3})\/([0-9]+)$/) {
		($ip,$mask) = ("$1","$2");
		$mask = mkmask($mask);
	}

	my $ipInfo = Net::Ifconfig::Wrapper::Ifconfig('list','','','');
	if ($ipInfo) {
		my $bc = mkBroadcast($ip,$mask);
		while (my ($interface,$ivalue) = each(%{$ipInfo})) {
			if ($ivalue->{'inet'}) {
				while (my ($localIp,$localMask) = each(%{$ivalue->{'inet'}})) {
					my $localBc = mkBroadcast($localIp,$localMask);
					if ($localBc eq $bc) {
						return $interface;
					}
				}
			}
		}
	}
	return '';
}

sub checkProfile($\%$) {
	my $profile = shift;
	my $validProfiles = shift;
	my $defaultProfile = shift;
	return TRUE unless ($profile);
	return $validProfiles->{$profile} || ($profile eq $defaultProfile);
}

sub readConfigFile(;$) {
	my $filename = shift || '';

	if (!$filename) {
		$filename = getConfigFileName();
	}

	my $parser = new XML::Parser(Style => 'Tree');
        my $tree = $parser->parsefile("$filename");

	confess("invalid config file: invalid root '".$tree->[0]."'") unless (xmlEq($tree->[0], 'AWEBGEN'));

	# Extract profiles
	my %validProfiles = ();
	my $defaultProfile = '';
	{
		my $xmlProfiles = getXMLChild('PROFILES', @{$tree->[1]});
		if ($xmlProfiles) {
			my $i = 0;
			my @child = getXMLChildAt($xmlProfiles,$i);
			while (@child) {
				if (xmlEq("$child[0]", "PROFILE")) {
					my $name = getAttr($child[1][0],'name');
					my $default = getAttr($child[1][0],'default') || 'no';
					if (lc("$default") eq 'yes') {
						$defaultProfile = $name;
					}
					else {
						my $j = 0;
						my @subchild = getXMLChildAt($child[1],$j);
						while (@subchild) {
							if ($subchild[0] && (xmlEq("$subchild[0]", "NETWORK"))) {
								my $ip = getAttr($subchild[1][0],'ip');
								my $interface = isValidNetwork($ip);
								if ($interface) {
									$validProfiles{$name} = ($interface | '');
								}
							}
							$j++;
							@subchild = getXMLChildAt($child[1],$j);
						}
					}
				}
				$i++;
				@child = getXMLChildAt($xmlProfiles,$i);
			}
		}
	}

	{
		my $xmlConstants = getXMLChild('CONSTANTS', @{$tree->[1]});
		if ($xmlConstants) {
			my $i = 0;
			my @child = getXMLChildAt($xmlConstants,$i);
			while (@child) {
				if (xmlEq("$child[0]", "CONSTANT")) {
					my $name = getAttr($child[1][0],'id');
					my $value = getAttr($child[1][0],'value');
					my $profile = getAttr($child[1][0],'profile') || '';
					if (checkProfile($profile,%validProfiles,$defaultProfile)) {
						setConstant($name,$value);
					}
				}
				$i++;
				@child = getXMLChildAt($xmlConstants,$i);
			}
		}
	}

	{
		my $xmlPages = getXMLChild('PAGES', @{$tree->[1]});
		if ($xmlPages) {
			my $i = 0;
			my @child = getXMLChildAt($xmlPages,$i);
			while (@child) {
				if (xmlEq("$child[0]", "PAGE")) {
					my $name = getAttr($child[1][0],'id');
					my $url = getAttr($child[1][0],'url');
					my $label = getAttr($child[1][0],'label');
					my $shortlabel = getAttr($child[1][0],'short');
					my $pushable = getAttr($child[1][0],'push');
					my $parent = getAttr($child[1][0],'parent') || '';
					my $snap = getAttr($child[1][0],'snap') || '';
					my $misc = getAttr($child[1][0],'misc') || '';
					my $profile = getAttr($child[1][0],'profile') || '';
					if (checkProfile($profile,%validProfiles,$defaultProfile)) {

						if ($misc) {
							my @miscs = split(/\s*,\s*/,$misc);
							$misc = \@miscs;
						}

						setPage($name,$url,$label,$shortlabel,$parent,$snap,$misc);

						if ($pushable) {
							my @pushables = split(/\s*,\s*/,$pushable);
							foreach my $p (@pushables) {
								pushInDefaultArray($p,$name);
							}
						}

						if ($parent) {
							pushInDefaultArray($parent,$name);
						}
					}
				}
				$i++;
				@child = getXMLChildAt($xmlPages,$i);
			}
		}
	}

	{
		my $xmlPages = getXMLChild('IGNORES', @{$tree->[1]});
		if ($xmlPages) {
			my $i = 0;
			my @child = getXMLChildAt($xmlPages,$i);
			my $pattern;
			while (@child) {
				if (xmlEq("$child[0]", "EXPAND")) {
					$pattern = getAttr($child[1][0],'pattern');
					my $profile = getAttr($child[1][0],'profile') || '';
					if (checkProfile($profile,%validProfiles,$defaultProfile)) {
						addUnexpandableFile("$pattern");
					}
				}
				elsif (xmlEq("$child[0]", "MIRROR")) {
					$pattern = getAttr($child[1][0],'pattern');
					my $profile = getAttr($child[1][0],'profile') || '';
					if (checkProfile($profile,%validProfiles,$defaultProfile)) {
						addIgnorableFile("$pattern");
					}
				}
				$i++;
				@child = getXMLChildAt($xmlPages,$i);
			}
		}
	}

	{
		my $xmlMirror = getXMLChild('MIRROR', @{$tree->[1]});
		if ($xmlMirror) {
			my $url = getAttr($xmlMirror->[0],'url');
			my $profile = getAttr($xmlMirror->[0],'profile') || '';
			if (checkProfile($profile,%validProfiles,$defaultProfile)) {
				if ($url) {
					setCmdLineOpt('mirror',$url);
				}
				my $pwd = getAttr($xmlMirror->[0],'password');
				if ($pwd) {
					setCmdLineOpt('password',$pwd);
				}
			}
		}
	}

	{
		my $xmlAnnounce = getXMLChild('ANNOUNCE', @{$tree->[1]});
		if ($xmlAnnounce) {
			my $email = getAttr($xmlAnnounce->[0],'email');
			my $profile = getAttr($xmlAnnounce->[0],'profile') || '';
			if (checkProfile($profile,%validProfiles,$defaultProfile)) {
				if ($email && $email =~ /^[a-zA-Z0-9_\-\.]+\@(?:[a-zA-Z0-9_\-]+\.)+[a-zA-Z0-9_\-]+$/s) {
					setCmdLineOpt('announce',$email);
				}
				my $format = getAttr($xmlAnnounce->[0],'format');
				if ($format) {
					setConstant('announce-format',$format);
				}
			}
		}
	}

	{
		my $xmlArrays = getXMLChild('ARRAYS', @{$tree->[1]});
		if ($xmlArrays) {
			my $i = 0;
			my @child = getXMLChildAt($xmlArrays,$i);
			while (@child) {
				if ($child[0] && (xmlEq("$child[0]", "ARRAY"))) {
					my $arrayId = getAttr($child[1][0],'name');
					my $profile = getAttr($child[1][0],'profile') || '';
					if (checkProfile($profile,%validProfiles,$defaultProfile)) {
						if ($arrayId) {
							my $arrayContent = '';
							if ("$child[1][1]" eq '0') {
								$arrayContent = $child[1][2];
							}
							pushInDefaultArray("$arrayId","$arrayContent");
						}
						else {
							croak("no 'name' value for an ARRAY tag\n");
						}
					}
				}
				$i++;
				@child = getXMLChildAt($xmlArrays,$i);
			}
		}
	}

	{
		my $xmlHashs = getXMLChild('HASHS', @{$tree->[1]});
		if ($xmlHashs) {
			my $i = 0;
			my @child = getXMLChildAt($xmlHashs,$i);
			while (@child) {
				if ($child[0] && (xmlEq("$child[0]", "HASH"))) {
					my $hashId = getAttr($child[1][0],'name');
					my $profile = getAttr($child[1][0],'profile') || '';
					if (checkProfile($profile,%validProfiles,$defaultProfile)) {
						if ($hashId) {
							my $j = 0;
							my @subchild = getXMLChildAt($child[1],$j);
							while (@subchild) {
								if ($subchild[0] && (xmlEq("$subchild[0]", "PAIR"))) {
									my $pairKey = getAttr($subchild[1][0],'key');
									if ($pairKey) {
										my $pairContent = '';
										if ("$subchild[1][1]" eq '0') {
											$pairContent = $subchild[1][2];
										}
										pushInDefaultHash("$hashId","$pairKey","$pairContent");
									}
									else {
										croak("no 'key' value for a PAIR tag\n");
									}
								}
								$j++;
								@subchild = getXMLChildAt($child[1],$j);
							}
						}
						else {
							croak("no 'name' value for a HASH tag\n");
						}
					}
				}
				$i++;
				@child = getXMLChildAt($xmlHashs,$i);
			}
		}
	}
}

1;
__END__
