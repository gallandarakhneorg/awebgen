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

package AWebGen::Code::LocalContext;

@ISA = ('Exporter');
@EXPORT = qw( &createLocalContext &openLocalContext &closeLocalContext 
	      &getLCInstruction &putLCInstructionSet
	      &getLCConstant &putLCConstant &getLCField &putLCField
	      &getLCArray &getLCHash
	      &getLCPageIds &getLCPageUrl &getLCPageLabel &getLCPageShortLabel
	      &getLCPage &getLCPageParent
            ) ;
@EXPORT_OK = qw();
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);
my $VERSION = "2.0" ;

use Carp;
use File::Basename;
use AWebGen::Config::Db;

use constant TRUE => (1==1);
use constant FALSE => (1==0);

# Create an reply a local context data structure
# $_[0]: path of the current file on the site
# $_[1]: relative path to go to the root directory of the site
# $_[2]: hash that is containing the command set to use.
# $_   : reply the local context data structure.
sub createLocalContext($$$) {
	my $sitepath = shift || confess('no site path');
	my $toroot = shift || confess('no path to root');
	my $inst_set = shift || confess('no instruction set to root');
	return {'root' => getRootDir(),
		'toroot' => "$toroot",
		'system' => getWorkingDir(),
		'site' => $sitepath,
		'sitedir' => dirname($sitepath),
		'includes' => getIncludeDir(),
		'databases' => getDatabaseDir(),
		'inst_set' => [ $inst_set ],
		'stack' => [ {
				'OVERRIDE-PARENT-CONTEXT' => FALSE,
				'INST-INDEX' => 0,
			     } ],
	};
}

# Open a local context
# $_[0]: current local context
# $_[1]: TRUE if the DEF macros may change parent's context, otherwise FALSE
sub openLocalContext($;$) {
	my $localContext = shift || confess('no local context');
	my $overrideParent = shift || FALSE;
	my $idx = @{$localContext->{'inst_set'}};
	push @{$localContext->{'stack'}}, {
		'OVERRIDE-PARENT-CONTEXT' => $overrideParent,
		'INST-INDEX' => $idx,
	};
}

# Close a local context
# $_[0]: current local context
sub closeLocalContext($) {
	my $localContext = shift || confess('no local context');
	my $h = pop @{$localContext->{'stack'}};
	my $instIndex = $h->{'INST-INDEX'} || 0;
	while (@{$localContext->{'inst_set'}}>$instIndex) {
		pop @{$localContext->{'inst_set'}};
	}
}

# Replies the last defined instruction for the given id.
# $_[0]: current local context
# $_[1]: name of the instruction
# $_   : the instruction definition as an hash or undef
sub getLCInstruction($$) {
	my $localContext = shift || confess('no local context');
	my $instName = shift || confess('no instruction name');
	if ($localContext->{'inst_set'}) {
		for(my $i=$#{$localContext->{'inst_set'}}; $i>=0; $i--) {
			if ($localContext->{'inst_set'}[$i]
			    && $localContext->{'inst_set'}[$i]{"$instName"}) {
				return $localContext->{'inst_set'}[$i]{"$instName"};
			}
		}
	}
	return undef;
}

# Push the last defined instruction for the given id.
# $_[0]: current local context
# $_[1]: the set of instructions to push
sub putLCInstructionSet($$) {
	my $localContext = shift || confess('no local context');
	my $set = shift;
	if ($set) {
		$localContext->{'inst_set'} = [] unless ($localContext->{'inst_set'});
		push @{$localContext->{'inst_set'}}, $set;
	}
}

# Extract the last defined constant with the given name from the local context
# $_[0]: current local context
# $_[1]: name of the constant
# $_[2]: value family
# $_   : value or undef
sub getLCValue($$$) {
	my $localContext = shift || confess('no local context');
	my $cst = shift || confess('no constant name');
	my $family = shift || confess('no value family');
	$cst = uc("$cst");
	my $i = $#{$localContext->{'stack'}};
	while ($i>=0) {
		if (exists $localContext->{'stack'}[$i]{"$family"}{"$cst"}) {
			return $localContext->{'stack'}[$i]{"$family"}{"$cst"};
		}
		$i --;
	}
	return undef;
}

# Extract the last defined constant with the given name from the local context
# $_[0]: current local context
# $_[1]: name of the constant
# $_   : value or undef
sub getLCConstant($$) {
	my $localContext = shift || confess('no local context');
	my $cst = shift || confess('no constant name');
	$cst = uc("$cst");

	if ($cst eq 'ROOT') {
		return $localContext->{'toroot'};
	}

	my $value = getLCValue($localContext,$cst,'constants');
	if (!defined($value)) {
		$value = getConstant("$cst")
	}
	return $value;
}

# Extract the last defined field with the given name from the local context
# $_[0]: current local context
# $_[1]: name of the field
# $_   : value or undef
sub getLCField($$) {
	my $localContext = shift || confess('no local context');
	my $fld = shift || confess('no field name');
	$fld = uc("$fld");
	return getLCValue($localContext,$fld,'fields');
}

# Extract the last defined array with the given name from the local context
# $_[0]: current local context
# $_[1]: name of the array
# $_   : value or undef
sub getLCArray($$) {
	my $localContext = shift || confess('no local context');
	my $array = shift || confess('no array name');
	my $v = getLCValue($localContext,$array,'arrays');
	if (!defined($v)) {
		my $a = getDefaultArrays();
		if ($a && exists $a->{$array}) {
			$v = $a->{$array};
		}
	}
	return $v;
}

# Extract the last defined hash with the given name from the local context
# $_[0]: current local context
# $_[1]: name of the hash
# $_   : value or undef
sub getLCHash($$) {
	my $localContext = shift || confess('no local context');
	my $hash = shift || confess('no hash name');
	my $v = getLCValue($localContext,$hash,'hashs');
	if (!defined($v)) {
		my $a = getDefaultHashs();
		if ($a && exists $a->{$hash}) {
			$v = $a->{$hash};
		}
	}
	return $v;
}

# Put a value in the current context
# $_[0]: family
# $_[1]: current local context
# $_[2]: name of the constant
# $_[3]: value of the constant
# $_[4]: TRUE if the instruction must be put in the lastest context,
#        otherwise it will be put according to the parent context overriding flag.
sub putLCValue {
	my $family = shift || confess('no family');
	my $localContext = shift || confess('no local context');
	my $cst = shift || confess('no constant name');
	my $value = shift;
	my $inLastContext = shift || FALSE;
	$cst = uc("$cst");
	my $lastContextIdx = $#{$localContext->{'stack'}};
	if ((!$inLastContext) && $localContext->{'stack'}[$lastContextIdx]{'OVERRIDE-PARENT-CONTEXT'}) {
		# Search for a parent context which is owning the value
		my $i = $lastContextIdx;
		while ($i>=0) {
			if (exists $localContext->{'stack'}[$i]{"$family"}{"$cst"}) {
				# Found the value in parent context
				if (defined($value)) {
					$localContext->{'stack'}[$i]{"$family"}{"$cst"} = $value;
				}
				else {
					delete $localContext->{'stack'}[$i]{"$family"}{"$cst"};
				}
				return TRUE;
			}
			$i --;
		}
	}

	# Put value in lastest context
	if (defined($value)) {
		$localContext->{'stack'}[$lastContextIdx]{"$family"}{"$cst"} = $value;
	}
	elsif (exists $localContext->{'stack'}[$lastContextIdx]{"$family"}{"$cst"}) {
		delete $localContext->{'stack'}[$lastContextIdx]{"$family"}{"$cst"};
	}
	return TRUE;
}

# Put a constant value in the current context
# $_[0]: current local context
# $_[1]: name of the constant
# $_[2]: value of the constant
# $_[3]: TRUE if the instruction must be put in the lastest context,
#        otherwise it will be put according to the parent context overriding flag.
sub putLCConstant($$;$$) {
	my $localContext = shift || confess('no local context');
	my $cst = shift || confess('no constant name');
	my $value = shift;
	my $inLastContext = shift || FALSE;
	
	$cst = uc("$cst");
	if ($cst eq 'ROOT') {
		if ($value) {
			$localContext->{'toroot'} = "$value";
		}
	}
	else {
		return putLCValue('constants', $localContext, $cst, $value, $inLastContext);
	}
}

# Put a field value in the current context
# $_[0]: current local context
# $_[1]: name of the constant
# $_[2]: value of the constant
# $_[3]: TRUE if the instruction must be put in the lastest context,
#        otherwise it will be put according to the parent context overriding flag.
sub putLCField($$;$$) {
	return putLCValue('fields', @_);
}

# Replies the identifiers of all the registered pages.
# $_[0]: current local context
# $_   : array of identifiers
sub getLCPageIds($) {
	my $localContext = shift || confess('no local context');

	my %allids = ();

	my $pages = getAllPages();
	if ($pages) {
		foreach my $k (keys %{$pages}) {
			$allids{$k} = TRUE;
		}
	}

	for(my $i=0; $i<=$#{$localContext->{'stack'}}; $i++) {
		if ($localContext->{'stack'}[$i]{'pages'}) {
			foreach my $k (keys %{$localContext->{'stack'}[$i]{'pages'}}) {
				$allids{$k} = TRUE;
			}
		}
	}

	return keys %allids;
}

# Extract URL of a page from the local context
# $_[0]: current local context
# $_[1]: id of the page
# $_   : value or undef
sub getLCPageUrl($$) {
	my $localContext = shift || confess('no local context');
	my $page = shift || confess('no page identifier');

	my $value = getLCValue($localContext,$page,'pages');
	if (!defined($value)) {
		$value = getPage("$page");
	}
	if ($value && $value->{'url'}) {
		return $value->{'url'};
	}
	else {
		return '';
	}
}

# Extract label of a page from the local context
# $_[0]: current local context
# $_[1]: id of the page
# $_   : value or undef
sub getLCPageLabel($$) {
	my $localContext = shift || confess('no local context');
	my $page = shift || confess('no page identifier');

	my $value = getLCValue($localContext,$page,'pages');
	if (!defined($value)) {
		$value = getPage("$page");
	}
	if ($value && $value->{'label'}) {
		return $value->{'label'};
	}
	else {
		return '';
	}
}

# Extract label of a page from the local context
# $_[0]: current local context
# $_[1]: id of the page
# $_   : value or undef
sub getLCPageShortLabel($$) {
	my $localContext = shift || confess('no local context');
	my $page = shift || confess('no page identifier');

	my $value = getLCValue($localContext,$page,'pages');
	if (!defined($value)) {
		$value = getPage("$page");
	}
	if ($value && $value->{'short'}) {
		return $value->{'short'};
	}
	else {
		return '';
	}
}

# Extract parent of a page from the local context
# $_[0]: current local context
# $_[1]: id of the page
# $_   : value or undef
sub getLCPageParent($$) {
	my $localContext = shift || confess('no local context');
	my $page = shift || confess('no page identifier');

	my $value = getLCValue($localContext,$page,'pages');
	if (!defined($value)) {
		$value = getPage("$page");
	}
	if ($value && $value->{'parent'}) {
		return $value->{'parent'};
	}
	else {
		return '';
	}
}

# Extract misc data of a page from the local context
# $_[0]: current local context
# $_[1]: id of the page
# $_   : value or undef
sub getLCPageMisc($$) {
	my $localContext = shift || confess('no local context');
	my $page = shift || confess('no page identifier');

	my $value = getLCValue($localContext,$page,'pages');
	if (!defined($value)) {
		$value = getPage($page);
	}
	if ($value && $value->{'misc'}) {
		return $value->{'misc'};
	}
	return [];
}

# Extract a page from the local context
# $_[0]: current local context
# $_[1]: id of the page
# $_   : a page or undef
sub getLCPage($$) {
	my $localContext = shift || confess('no local context');
	my $page = shift || confess('no page identifier');

	my $value = getLCValue($localContext,$page,'pages');
	if (!defined($value)) {
		$value = getPage($page);
	}
	return $value || undef;
}

1;
__END__
