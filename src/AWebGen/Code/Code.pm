# (C) 2008-09  Stephane Galland <galland@arakhne.org>
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

package AWebGen::Code::Code;

@ISA = ('Exporter');
@EXPORT = qw( ) ;
@EXPORT_OK = qw( %INSTRUCTIONS %HTML_CONSTANTS %FIELD_INSTRUCTIONS );
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION %INSTRUCTIONS %HTML_CONSTANTS %FIELD_INSTRUCTIONS );
my $VERSION = "5.0" ;

use Carp;
use File::Spec;
use AWebGen::Config::Db;
use AWebGen::Code::LocalContext;
use AWebGen::Code::Exec;
use AWebGen::Util::File;
use AWebGen::Util::Str;
use AWebGen::Util::Output;
use AWebGen::Db::Text;

use constant TRUE => (1==1);
use constant FALSE => (1==0);

# HTML constant entities
our %HTML_CONSTANTS = (
	'&obrace;' => '{',
	'&cbrace;' => '}',
	'&obracket;' => '[',
	'&cbracket;' => ']',
	'&oparent;' => '(',
	'&cparent;' => ')',
	'&dollar;' => '$',
	'&star;' => '*',
	'&col;' => ':',
	'&column;' => ':',
);

# Instructions.
# The prototype of a command is "<return type>(<parameter_prototype>)".
# Parameter Format:
#   $            is a mandatory parameter (ie, empty parameter is disallowed)
#   #            is a optional parameter (ie, empty parameter is allowed)
#   []           indicates an optional part
#   :            default parameter separator
#   other        is a mandatory character
# Return Type Format:
#   #            return nothing (-void-).
#   $            return a scalar value.
#   @            return an array of scalars.
#   %            return a set of key-value pairs.
# Invocation description:
# 'run' => name of the Perl function to invoke.
#          This function takes the following parameters:
#               1) local context,
#               2-n) list of the n-1 macro's parameters.
# 'callback' => name of the Perl function to invoke.
#               This function takes the following parameters:
#                    1) local context,
#                    2) macro's name,
#                    3) static/constant parameters (depending on the macro definition) in a reference,
#                    4-n) list of the n-4 macro's parameters.
our %INSTRUCTIONS = (
	'BEGIN' => {		'proto' => '$($)',
				'run' => "run_BEGIN" },
	'CONTACT_FORM' => {	'proto' => '$($[:#:#:#:#:#])',
				'run' => "run_CONTACT_FORM" },
	'COPYRIGHT_STRING' => {	'proto' => '$([$])',
				'run' => "run_COPYRIGHT_STRING" },
	'DEF' => { 		'proto' => '#($=#)',
				'run' => "run_DEF",
				'includedefs' => TRUE },
	'DEFMACRO' => { 	'proto' => '#($=#)',
				'run' => "run_DEFMACRO",
				'expandparams' => TRUE },
	'DEFUSE' => {		'proto' => '$($=#)',
				'run' => "run_DEFUSE",
				'includedefs' => TRUE },
	'DIFFERED' => {		'proto' => '$($:$)',
				'run' => "run_DIFFERED" },
	'EMAIL' => {		'proto' => '$($[:$])',
				'run' => "run_EMAIL" },
	'EMAIL_CRYPT' => {	'proto' => '$($)',
				'run' => "run_EMAIL_CRYPT" },
	'EMAIL_DECRYPT' => {	'proto' => '$($)',
				'run' => "run_EMAIL_DECRYPT" },
	'END' => { 		'proto' => '$($)',
				'run' => "run_END" },
	'FAILURE' => { 		'proto' => '$($)',
				'expandparams' => TRUE,
				'run' => "run_FAILURE",
				'includedefs' => TRUE },
	'FOREACH' => { 		'proto' => '$($[:$])',
				'expandparams' => TRUE,
				'run' => "run_FOREACH" },
	'GET' => {		'proto' => '$($)',
				'run' => 'run_GET' },
	'IF' => {		'proto' => '$($:#[:#])',
				'expandparams' => TRUE,
				'run' => "run_IF",
				'includedefs' => TRUE },
	'IFDB' => {		'proto' => '$($:#[:#])',
				'expandparams' => TRUE,
				'run' => "run_IFDB" },
	'IFDEF' => {		'proto' => '$($:#[:#])',
				'expandparams' => TRUE,
				'run' => "run_IFDEF",
				'includedefs' => TRUE },
	'IFMAINTENANCE' => {	'proto' => '$(#[:#])',
				'expandparams' => TRUE,
				'run' => "run_IFMAINTENANCE",
				'includedefs' => TRUE },
	'INCLUDE' => {		'proto' => '$($)',
				'run' => "run_INCLUDE" },
	'INCLUDEDEFS' => {	'proto' => '$($)',
				'run' => "run_INCLUDEDEFS" },
	'LENGTH' => {		'proto' => '$($)',
				'run' => "run_LENGTH" },
	'LINK' => {		'proto' => '$($[:$])',
				'run' => "run_LINK" },
	'LOGENTRY' => {		'proto' => '$($:$:$:$:$)',
				'expandparams' => TRUE,
				'run' => "run_LOGENTRY" },
	'PAGE' => {		'proto' => '$($)',
				'run' => "run_PAGE" },
	'PAGELABEL' => {	'proto' => '$($)',
				'run' => "run_PAGELABEL" },
	'PAGELINK' => {		'proto' => '$($[:$])',
				'run' => "run_PAGELINK" },
	'PAGEPARENT' => {	'proto' => '$($)',
				'run' => "run_PAGEPARENT" },
	'PAGESHORTLABEL' => {	'proto' => '$($)',
				'run' => "run_PAGESHORTLABEL" },
	'PROVIDE' => { 		'proto' => '#($=#)',
				'run' => "run_PROVIDE",
				'includedefs' => TRUE },
	'PROVIDEUSE' => {	'proto' => '$($=#)',
				'run' => "run_PROVIDEUSE",
				'includedefs' => TRUE },
	'REMOVETAGS' => {	'proto' => '$($[:$])',
				'run' => "run_REMOVETAGS"},
	'REPLACE' => {		'proto' => '$($:#:#)',
				'run' => "run_REPLACE" },
	'JAVASCRIPT' => { 	'proto' => '$($)',
				'run' => "run_JAVASCRIPT",
				'expandparams' => TRUE },
	'STR' => { 		'proto' => '$($)',
				'run' => "run_STR" },
	'STYLIZE' => {		'proto' => '$($)',
				'run' => "run_STYLIZE" },
	'TEXTLIST' => {		'proto' => '$($[:$:$])',
				'run' => 'run_TEXT2HTMLLIST' },
	'UNDEF' => { 		'proto' => '#($)',
				'run' => "run_UNDEF",
				'includedefs' => TRUE },
	'URLDECODE' => {	'proto' => '$($)',
				'run' => "run_URLDECODE" },
	'URLENCODE' => {	'proto' => '$($)',
				'run' => "run_URLENCODE" },
	'VALUE' => {		'proto' => '$($[:#])',
				'expandparams' => TRUE,
				'run' => "run_VALUE",
				'includedefs' => TRUE },
	'WHILE' => {		'proto' => '$($[:$])',
				'run' => "run_WHILE",
				'expandparams' => TRUE },
);

our %FIELD_INSTRUCTIONS = (
	'FIELD' => {		'proto' => '$($[|#])',
				'run' => "run_FIELD" },
	'IFFIELD' => {		'proto' => '$($:#[:#])',
				'expandparams' => TRUE,
				'run' => "run_IFFIELD" },
);

sub evaluatePerlCondition($$) {
	my $localContext = shift || confess('no local context');
	my $condition = shift || '';
	$condition =~ s/\$([a-zA-Z0-9_]+)/
			"'".protectQuote("\$\{$1\}")."'";
		/ges;

	$condition = AWebGen::Code::Exec::codeReplaceInLocalContext($localContext,$condition);
	my $c = eval("$condition");
	confess("$@") if ($@);

	return $c;
}

sub run_BEGIN {
	my $localContext = shift || confess('no local context');
	my $shtml = shift || confess('no shtml name');
	my $file = File::Spec->catfile(getIncludeDir(),"s$shtml.shtml");
	return readFile("$file");
}

sub run_DEF {
	my $localContext = shift || confess('no local context');
	my $name = shift || confess('no constant name');
	my $value = shift || '';
	$value =~ s/\s+$//;
	$value =~ s/^\s+//;
	putLCConstant($localContext,$name,$value);
	return undef;
}

sub run_PROVIDE {
	my $localContext = shift || confess('no local context');
	my $name = shift || confess('no constant name');
	my $value = shift || '';
	$value =~ s/\s+$//;
	$value =~ s/^\s+//;
	my $currentValue = getLCConstant($localContext,"$name");
	if (!defined($currentValue)) {
		putLCConstant($localContext,$name,$value);
	}
	return undef;
}

sub run_UNDEF {
	my $localContext = shift || confess('no local context');
	my $name = shift || confess('no constant name');
	putLCConstant($localContext,$name,undef);
	return undef;
}

sub run_DEFUSE {
	my $localContext = shift || confess('no local context');
	my $name = shift || confess('no constant name');
	my $value = shift || '';
	$value =~ s/\s+$//;
	$value =~ s/^\s+//;
	putLCConstant($localContext,$name,$value);
	return "$value";
}

sub run_PROVIDEUSE {
	my $localContext = shift || confess('no local context');
	my $name = shift || confess('no constant name');
	my $value = shift || '';
	$value =~ s/\s+$//;
	$value =~ s/^\s+//;
	my $currentValue = getLCConstant($localContext,"$name");
	if (!$currentValue) {
		putLCConstant($localContext,$name,$value);
		$currentValue = $value;
	}
	return "$currentValue";
}

sub run_EMAIL {
	my $localContext = shift || confess('no local context');
	my $email = shift || confess('no email address');
	my $label = shift || '';
	$email = run_EMAIL_CRYPT($localContext, $email);
	$label = $email unless ($label);
	my $key = getLCConstant($localContext, "EMAIL_CRYPT_KEY");
	return "<a href=\"mailto:$email\" title=\"You must replace $key by @\">$label</a>";
}

sub run_EMAIL_CRYPT {
	my $localContext = shift || confess('no local context');
	my $email = shift || confess('no email address');
	my $key = getLCConstant($localContext, "EMAIL_CRYPT_KEY");
	$email =~ s/@/$key/sg;
	return "$email";
}

sub run_EMAIL_DECRYPT {
	my $localContext = shift || confess('no local context');
	my $email = shift || confess('no email address');
	my $key = getLCConstant($localContext, "EMAIL_CRYPT_KEY");
	$email =~ s/\Q$key\E/@/sg;
	return "$email";
}

sub run_END {
	my $localContext = shift || confess('no local context');
	my $shtml = shift || confess('no shtml name');
	my $file = File::Spec->catfile(getIncludeDir(),"e$shtml.shtml");
	return readFile("$file");
}

sub run_FIELD {
	my $localContext = shift || confess('no local context');
	my $field = shift || confess('no field name');
	my $defaultValue = shift;
	my $fieldValue = getLCField($localContext,$field);
	if (defined($fieldValue)) {
		return "$fieldValue";
	}
	elsif (defined($defaultValue)) {
		return "$defaultValue";
	}
	else {
		warm("no value found for the field '$field'");
		return "#ERR#\{FIELD $field\}";
	}
}

sub run_FOREACH_DB {
	my $localContext = shift || confess('no local context');
	my $dbName = shift || confess('no database name');
	my $min = int(shift || 0);
	my $max = int(shift || -1);
	my $htmlCode = shift;

	my $dbFile = mkDatabaseFilename("$dbName");
	(-r "$dbFile") || croak("$dbFile: $!");

	my @entries = extractTextDB(readFile("$dbFile"));

	$max = $#entries if ($max<$min);

	if (!defined($htmlCode)) {
		my $shtmlFile = mkIncludedFilename("$dbName");
		(-r "$shtmlFile") || croak("$shtmlFile: $!");
		$htmlCode = readFile("$shtmlFile") || '';
	}

	my $expanded = '';
	for(my $i=$min; $i<=$max; $i++) {
		my $code = "$htmlCode";
		openLocalContext($localContext);
		putLCConstant($localContext,'LOOPINDEX',$i);
		while (my ($k,$v) = each (%{$entries[$i]})) {
			putLCField($localContext,$k,$v);
		}
		putLCInstructionSet($localContext,\%FIELD_INSTRUCTIONS);
		$code = AWebGen::Code::Exec::codeReplaceInLocalContext($localContext,$code);
		closeLocalContext($localContext);
		$expanded .= AWebGen::Code::Exec::codeReplaceCommand($localContext,'STYLIZE',$code);
	}

	return "$expanded";
}

sub __sort($$$$$$) {
	my $localContext = shift;
	my $perlcond = shift || '';
	my $a = shift || '';
	my $b = shift || '';
	my $va = shift;
	my $vb = shift;

	if ($perlcond =~ /^\s*(.+?)\s*((?:<=>)|(?:cmp))\s*(.+?)\s*$/s) {
		my $p1 = scalar($1 || '');
		my $p2 = scalar($3 || '');
		my $op = scalar($2 || 'cmp');

		$p1 =~ s/\$1\$/\%a\%/gs;
		$p1 =~ s/\$2\$/\%b\%/gs;
		$p1 =~ s/\$3\$/\%va\%/gs if (defined($va));
		$p1 =~ s/\$4\$/\%vb\%/gs if (defined($vb));

		$p2 =~ s/\$1\$/\%a\%/gs;
		$p2 =~ s/\$2\$/\%b\%/gs;
		$p2 =~ s/\$3\$/\%va\%/gs if (defined($va));
		$p2 =~ s/\$4\$/\%vb\%/gs if (defined($vb));

		$p1 =~ s/\$([a-zA-Z0-9_]+)/\$\{$1\}/gs;
		$p2 =~ s/\$([a-zA-Z0-9_]+)/\$\{$1\}/gs;

		$p1 =~ s/\$\{([a-zA-Z0-9_]+)\}/\$\{$1\}/gs;
		$p2 =~ s/\$\{([a-zA-Z0-9_]+)\}/\$\{$1\}/gs;
		
		$p1 =~ s/\%a\%/$a/gs;
		$p1 =~ s/\%b\%/$b/gs;
		$p1 =~ s/\%va\%/$va/gs if (defined($va));
		$p1 =~ s/\%vb\%/$vb/gs if (defined($vb));

		$p2 =~ s/\%a\%/$a/gs;
		$p2 =~ s/\%b\%/$b/gs;
		$p2 =~ s/\%va\%/$va/gs if (defined($va));
		$p2 =~ s/\%vb\%/$vb/gs if (defined($vb));

		$p1 = AWebGen::Code::Exec::codeReplaceInLocalContext($localContext,$p1);
		$p2 = AWebGen::Code::Exec::codeReplaceInLocalContext($localContext,$p2);

		$p1 = "'".protectQuote(lc($p1 || ''))."'";
		$p2 = "'".protectQuote(lc($p2 || ''))."'";

		$op = 'cmp';
		my $c = eval("($p1) $op ($p2)");
		confess("$@") if ($@);

		return $c;
	}
	return 0;
}

sub run_FOREACH_SORTED {
	my $localContext = shift || confess('no local context');
	my $type = shift;
	my $name = shift || confess('no data structure name');
	my $condition = shift || '$1$ <=> $2$';
	my $htmlCode = shift;

	if (!$htmlCode) {
		warm("no html code in a \$\{FOREACH(SORTED)\}");
		$htmlCode = '';
	}

	my $isArray = TRUE;
	my $isHash = TRUE;
	if ($type && $type eq '@') {
		$isHash = FALSE;
	}
	elsif ($type && $type eq '%') {
		$isArray = FALSE;
	}

	if ($isArray) {
		my $array = getLCArray($localContext, "$name");
		if ($array) {
			my @elts = (@{$array});

			@elts = sort {
				(__sort($localContext,"$condition","$a","$b",undef,undef));
			} @elts;

			my $generatedCode = '';
			foreach my $arrayelt (@elts) {
				my $code = "$htmlCode";
				$code =~ s/\$\$/$arrayelt/sg;
				$code =~ s/\$\{LOOPELT\}/$arrayelt/sg;
				$code =~ s/\$LOOPELT/$arrayelt/sg;
				$generatedCode .= "$code";
			}
			return AWebGen::Code::Exec::codeReplaceCommand($localContext,'STYLIZE',"$generatedCode");
		}
	}

	if ($isHash) {
		my $hash = getLCHash($localContext, "$name");
		if ($hash) {
			my @keys = keys %{$hash};

			@keys = sort {
				(__sort($localContext,"$condition","$a","$b",$hash->{$a},$hash->{$b}));
			} @keys;

			my $generatedCode = '';
			foreach my $k (@keys) {
				my $code = "$htmlCode";
				$code =~ s/\$\$/$k/sg;
				$code =~ s/\$1\$/$k/sg;
				$code =~ s/\$\{LOOPKEY\}/$k/sg;
				$code =~ s/\$LOOPKEY/$k/sg;
				$code =~ s/\$2\$/$hash->{$k}/sg;
				$code =~ s/\$\{LOOPVAL\}/$hash->{$k}/sg;
				$code =~ s/\$LOOPVAL/$hash->{$k}/sg;
				$generatedCode .= "$code";
			}
			return AWebGen::Code::Exec::codeReplaceCommand($localContext,'STYLIZE',"$generatedCode");
		}
	}

	return '';
}

sub run_FOREACH_HTML {
	my $localContext = shift || confess('no local context');
	my $htmlName = shift || confess('no shtml name');
	my $min = int(shift || 0);
	my $max = int(shift || -1);
	my $dbContent = shift || '';

	my @entries = extractTextDB($dbContent);

	$max = $#entries if ($max<$min);

	my $shtmlFile = mkIncludedFilename("$htmlName");
	(-r "$shtmlFile") || croak("$shtmlFile: $!");
	my $htmlCode = readFile("$shtmlFile") || '';

	my $expanded = '';
	for(my $i=$min; $i<=$max; $i++) {
		my $code = "$htmlCode";
		openLocalContext($localContext);
		putLCConstant($localContext,'LOOPINDEX',$i);
		while (my ($k,$v) = each (%{$entries[$i]})) {
			putLCField($localContext,$k,$v);
		}
		putLCInstructionSet($localContext,\%FIELD_INSTRUCTIONS);
		$code = AWebGen::Code::Exec::codeReplaceInLocalContext($localContext,$code);
		closeLocalContext($localContext);
		$expanded .= AWebGen::Code::Exec::codeReplaceCommand($localContext,'STYLIZE',$code);
	}

	return "$expanded";
}

sub run_FOREACH_PAGE {
	my $localContext = shift || confess('no local context');
	my $pagePart = shift || confess('no page\'s part');
	my $min = int(shift || 0);
	my $max = int(shift || -1);
	my $htmlCode = shift || '';

	if ($pagePart ne 'url' && $pagePart ne 'short' && $pagePart ne 'label' && $pagePart ne 'misc'
	    && $pagePart ne 'parent' && $pagePart ne 'snap') {
		warm("invalid field name '$pagePart' for \${FOREACH:PAGE($pagePart)}");
		return '';
	}

	my @keys = getLCPageIds($localContext);
	@keys = sort @keys;

	$max = $#keys if ($max<$min);

	$htmlCode =~ s/\$\$/\$\{LOOPKEY\}/sg;
	$htmlCode =~ s/\$1\$/\$\{LOOPKEY\}/sg;
	$htmlCode =~ s/\$2\$/\$\{LOOPVAL\}/sg;

	my $expanded = '';
	for(my $i=$min; $i<=$max; $i++) {
		my $page = getLCPage($localContext,$keys[$i]);
		if ($page && $page->{$pagePart}) {
			my $vals;
			if ($pagePart eq 'misc') {
				$vals = $page->{'misc'} || [];
			}
			else {
				$vals = [ $page->{$pagePart} ];
			}
			if ($vals) {
				foreach my $v (@{$vals}) {
					my $code = "$htmlCode";
					openLocalContext($localContext);
					putLCConstant($localContext,'LOOPINDEX',$i);
					putLCConstant($localContext,'LOOPKEY',$keys[$i]);
					putLCConstant($localContext,'LOOPVAL',($v||''));
					$code = AWebGen::Code::Exec::codeReplaceInLocalContext($localContext,$code);
					closeLocalContext($localContext);
					$expanded .= AWebGen::Code::Exec::codeReplaceCommand($localContext,'STYLIZE',$code);
				}
			}
		}
	}

	return "$expanded";
}

sub run_FOREACH {
	my $localContext = shift || confess('no local context');
	my $condition = shift || confess('no condition');
	my $htmlCode = shift;

	if ($condition =~ /^\s*DB\s*\(\s*([a-zA-Z0-9-_]+)\s*\)\s*(?:\[([0-9]+)\.\.([0-9]+)\])?\s*$/si) {
		my ($dbName,$min,$max) = ($1,$2,$3);
		return run_FOREACH_DB($localContext,$dbName,$min,$max,$htmlCode);
	}
	elsif ($condition =~ /^\s*SORTED\s*\(\s*([\%\@])?([a-zA-Z0-9-_]+)\s*\)\s*(?:\[([^\]]*)\])?\s*$/si) {
		my ($type,$name,$cond) = ($1,$2,$3);
		return run_FOREACH_SORTED($localContext,$type,$name,$cond,$htmlCode);
	}
	elsif ($condition =~ /^\s*HTML\s*\(\s*([a-zA-Z0-9-_]+)\s*\)\s*(?:\[([0-9]+)\.\.([0-9]+)\])?\s*$/si) {
		my ($htmlName,$min,$max) = ($1,$2,$3);
		return run_FOREACH_HTML($localContext,$htmlName,$min,$max,$htmlCode);
	}
	elsif ($condition =~ /^\s*PAGE\s*\(\s*([a-zA-Z0-9-_]+)\s*\)\s*(?:\[([0-9]+)\.\.([0-9]+)\])?\s*$/si) {
		my ($pagePart,$min,$max) = ($1,$2,$3);
		return run_FOREACH_PAGE($localContext,$pagePart,$min,$max,$htmlCode);
	}
	else {
		croak("unrecognized FOREACH condition: $condition");
	}
}

sub run_WHILE {
	my $localContext = shift || confess('no local context');
	my $condition = shift || confess('no condition');
	my $htmlCode = shift;
	my $expanded = '';
	my $i = 0;
	my $code;
	while (evaluatePerlCondition($localContext,$condition)) {
		openLocalContext($localContext,TRUE);
		putLCConstant($localContext,'LOOPINDEX',$i,TRUE);
		$code = AWebGen::Code::Exec::codeReplaceInLocalContext($localContext,$htmlCode);
		closeLocalContext($localContext);
		$expanded .= ($code||'');
		$i++;
	}

	return "$expanded";
}

sub run_GET {
	my $localContext = shift || confess('no local context');
	my $var = shift || confess("no variable specified");

	if ($var && $var =~ /^\s*\@\s*([a-zA-Z0-9_+\-#]+)\s*\[\s*([0-9]+)\s*\]\s*$/) {
		my ($var,$idx) = ("$1","$2");
		my $array = getLCArray($localContext,$var);
		if ($array) {
			return ($array->[$idx] || '');
		}
	}
	elsif ($var && $var =~ /^\s*\%\s*([a-zA-Z0-9_+\-#]+)\s*\[(.+?)\]\s*$/) {
		my ($var,$idx) = ("$1","$2");
		my $hash = getLCHash($localContext,$var);
		if ($hash) {
			return ($hash->{$idx} || '');
		}
	}

	warm("invalid variable name '$var' for \${GET}");
	return '';
}

sub run_IF {
	my $localContext = shift || confess('no local context');
	my $condition = shift || confess("no condition code");
	my $thenCode = shift || '';
	my $elseCode = shift || '';
	my $code = (evaluatePerlCondition($localContext,$condition))
		? "$thenCode" : "$elseCode";
	return AWebGen::Code::Exec::codeReplaceInLocalContext($localContext,$code);
}

sub run_IFDEF {
	my $localContext = shift || confess('no local context');
	my $varname = shift || confess("no variable name code");
	my $thenCode = shift || '';
	my $elseCode = shift || '';
	my $code = (defined(getLCConstant($localContext,"$varname")))
		? "$thenCode" : "$elseCode";
	return AWebGen::Code::Exec::codeReplaceInLocalContext($localContext,$code);
}

sub run_IFDB {
	my $localContext = shift || confess('no local context');
	my $database = shift || confess('no database name');
	my $thenCode = shift || '';
	my $elseCode = shift || '';
	my $dbFile = mkDatabaseFilename("$database");
	my $code = ((-r "$dbFile") ? "$thenCode" : "$elseCode");
	return AWebGen::Code::Exec::codeReplaceInLocalContext($localContext,$code);
}

sub run_IFFIELD {
	my $localContext = shift || confess('no local context');
	my $field = shift || confess('no field name');
	my $thenCode = shift || '';
	my $elseCode = shift || '';
	my $fieldValue = getLCField($localContext,$field);
	my $code = (defined($fieldValue)) ? "$thenCode" : "$elseCode";
	return AWebGen::Code::Exec::codeReplaceInLocalContext($localContext,$code);
}

sub run_IFMAINTENANCE {
	my $localContext = shift || confess('no local context');
	my $thenCode = shift || '';
	my $elseCode = shift || '';
	my $code;
	if (getCmdLineOpt('maintenance')) {
		$code = "$thenCode";
	}
	else {
		$code = "$elseCode";
	}
	if ($code) {
		return AWebGen::Code::Exec::codeReplaceInLocalContext($localContext,$code);
	}
	return '';
}

sub run_INCLUDE {
	my $localContext = shift || confess('no local context');
	my $shtml = shift || confess('no shtml name');
	my $file = File::Spec->catfile(getIncludeDir(),"$shtml.shtml");
	return readFile("$file");
}

sub run_INCLUDEDEFS {
	my $localContext = shift || confess('no local context');
	my $file = shift || confess('no file name');
	$file = File::Spec->catfile($localContext->{'root'},$localContext->{'sitedir'},"$file");
	my $fileContent = readFile("$file");

	$localContext->{'restricted-expansion'} = TRUE;

	openLocalContext($localContext);

	AWebGen::Code::Exec::codeReplaceInLocalContext($localContext,$fileContent);

	my $lastContextIdx = $#{$localContext->{'stack'}};
	my $lastContextRef = $localContext->{'stack'}[$lastContextIdx]{'constants'};

	my %vars = ();
	while (my ($k,$v) = each(%{$lastContextRef})) {
		$vars{$k} = makeExpandable($v);
	}

	closeLocalContext($localContext);
	$localContext->{'restricted-expansion'} = undef;

	while (my ($k,$v) = each(%vars)) {
		putLCConstant($localContext, $k, $v);
	}

	return '';
}

sub run_LENGTH {
	my $localContext = shift || confess('no local context');
	my $name = shift || confess('no array name');
	my $array = getLCArray($localContext, "$name");
	if ($array) {
		return int(@{$array});
	}
	return 0;
}

sub run_LINK {
	my $localContext = shift || confess('no local context');
	my $url = shift || confess('no url name');
	my $label = shift || "$url";
	return "<a href=\"$url\">$label</a>";
}

sub run_STR {
	my $localContext = shift || confess('no local context');
	my $txt = shift || '';
	$txt = protectQuote("$txt");
	$txt = protectQQuote("$txt");
	$txt = AWebGen::Code::Exec::codeReplaceInLocalContext($localContext,$txt);	
	return $txt;
}

sub run_LOGENTRY {
	my $localContext = shift || confess('no local context');
	my $softId = shift || confess('no software id');
	my $version = shift || confess('no software version');
	my $author = shift || confess('no log author');
	my $date = shift || confess('no log date');
	my $log = shift || '';

	my $expanded = AWebGen::Code::Exec::codeReplaceCommand($localContext,'STYLIZE',text2htmllist("$log"));

	if ($expanded) {
		$expanded = join("\n", "<p><div class=\"logheader\">Version $version ($date)</div>",
		                       "<div class=\"logauthor\">$author</div>",
		                       "<div class=\"logentries\">$expanded</div></p>");
	}

	return "{$expanded}";
}

sub run_PAGE {
	my $localContext = shift || confess('no local context');
	my $pageId = shift || confess('no pageId');
	$pageId =~ s/^\s+//;
	$pageId =~ s/\s+$//;
	return getLCPageUrl($localContext,$pageId);
}

sub run_PAGELABEL {
	my $localContext = shift || confess('no local context');
	my $pageId = shift || confess('no pageId');
	$pageId =~ s/^\s+//;
	$pageId =~ s/\s+$//;
	return getLCPageLabel($localContext,$pageId);
}

sub run_PAGELINK {
	my $localContext = shift || confess('no local context');
	my $pageId = shift || confess('no pageId');
	my $outputType = lc(shift || 'html');
	$pageId =~ s/^\s+//;
	$pageId =~ s/\s+$//;
	croak("invalid output type '$outputType'. Supported are: html")
		unless ($outputType eq 'html');
	my $url = getLCPageUrl($localContext,$pageId);
	my $label = getLCPageLabel($localContext,$pageId);
	if ($url) {
		$label = $url unless ($label);
		if ($outputType eq 'html') {
			return "<a href=\"$url\">$label</a>";
		}
	}
	elsif ($label) {
		return "$label";
	}
	return "";
}

sub run_PAGESHORTLABEL {
	my $localContext = shift || confess('no local context');
	my $pageId = shift || confess('no pageId');
	$pageId =~ s/^\s+//;
	$pageId =~ s/\s+$//;
	return getLCPageShortLabel($localContext,$pageId);
}

sub run_PAGEPARENT {
	my $localContext = shift || confess('no local context');
	my $pageId = shift || confess('no pageId');
	$pageId =~ s/^\s+//;
	$pageId =~ s/\s+$//;
	return getLCPageParent($localContext,$pageId);
}

sub run_URLDECODE {
	my $localContext = shift || confess('no local context');
	my $url = shift || confess('no url');
	my $ud = urldecode("$url");
	return "$ud";
}

sub run_URLENCODE {
	my $localContext = shift || confess('no local context');
	my $url = shift || confess('no url');
	my $ue = urlencode("$url");
	return "$ue";
}

sub run_COPYRIGHT_STRING {
	my $localContext = shift || confess('no local context');
	my $name = shift || getLCConstant($localContext,'SITE_NAME');
	my $cfy = getLCConstant($localContext,'COPYRIGHT_FIRST_YEAR');
	my $year = getLCConstant($localContext,'YEAR');
	if ($cfy) {
		return "\&copy; $cfy-$year $name";
	}
	else {
		return "\&copy; $year $name";
	}
}

sub run_REMOVETAGS {
	my $localContext = shift || confess('no local context');
	my $htmlCode = shift || '';
	return striphtmltags("$htmlCode");
}

my $testId = 0;
sub callback_DEFMACRO {
	my $localContext = shift || confess('no local context');
	my $macroName = shift || confess('no macro name');
	my $macroParams = shift;
	my @macroParams = @{$macroParams};
	my $expanded = (pop @macroParams) || '';

	# Replace parameters
	for(my $i=0; $i<@macroParams; $i++) {
		my $pName = $macroParams[$i];
		my $pValue = $_[$i] || '';
		$expanded =~ s/\Q$pName\E/$pValue/gs;
	}

	#$expanded = AWebGen::Code::Exec::codeReplaceInLocalContext($localContext,$expanded);	

	return "$expanded";
}

sub run_DEFMACRO {
	my $localContext = shift || confess('no local context');
	my $macroProto= shift || '';
	my $macroCode= shift || '';
	my $macroName;
	my @macroParameters = ();
	if ($macroProto =~ /^\s*([a-zA-Z0-9_]+)\s*\(\s*((?:\$[a-zA-Z0-9_]+)(?:\s*,\s*\$[a-zA-Z0-9_]+)*)\s*\)\s*$/s) {
		$macroName = "$1";
		my $params = "$2";
		@macroParameters = split(/\s*,\s*/, $params);
	}
	else {
		confess('invalid macro prototype for DEFMACRO');
	}

	if ($macroCode) {
		my $proto = '$($';
		for(my $i=1; $i<@macroParameters; $i++) {
			$proto .= ':$';
		}
		$proto .= ')';
		push @macroParameters, $macroCode;
		putLCInstructionSet($localContext,
			{
				"$macroName" => { 	'proto' => "$proto",
							'callback' => "callback_DEFMACRO",
							'callback_params' => \@macroParameters,
							'expandparams' => TRUE },
			});
	}

	return '';
}

sub run_TEXT2HTMLLIST {
	my $localContext = shift || confess('no local context');
	my $text= shift || '';
	my $ulclass = shift;
	my $ulsubclass = shift;
	return AWebGen::Code::Exec::codeReplaceCommand($localContext,'STYLIZE',text2htmllist("$text",$ulclass,$ulsubclass));
}

sub run_VALUE {
	my $localContext = shift || confess('no local context');
	my $varname = shift || confess('no constant name');
	my $defaultValue = shift || '';
	my $varvalue = getLCConstant($localContext,"$varname");
	my $code = (defined($varvalue)) ? "$varvalue" : "$defaultValue";
	return AWebGen::Code::Exec::codeReplaceInLocalContext($localContext,$code);
}

sub run_REPLACE {
	my $localContext = shift || confess('no local context');
	my $toReplace = shift || confess('no string to replace');
	my $replacement = shift || '';
	my $code = shift || '';
	$code =~ s/\Q$toReplace\E/$replacement/gs;
	return "$code";
}

sub run_STYLIZE {
	my $localContext = shift || confess('no local context');
	my $text = shift || '';
	return $text;
}

sub run_FAILURE {
	my $localContext = shift || confess('no local context');
	my $text = shift || '';
	print STDERR "********************** FAILURE\n";
	print STDERR "$text\n";
	print STDERR "********************** FAILURE\n";
	exit(234);
}

sub run_JAVASCRIPT {
	my $localContext = shift || confess('no local context');
	my $code = shift || '';
	return join('',
		"<script type=\"text/javascript\">&shtmlcomment;\n",
		"$code",
		"//&ehtmlcomment;\n</script>");
}

sub run_CONTACT_FORM {
	my $localContext = shift || confess('no local context');
	my $email = shift || confess('no email given');
	my $sender = shift || '';
	my $subject = shift || '';
	my $content = shift || '';
	my $source_url = shift || $localContext->{'site'};
	my $additionalHtml = shift || '';

	setConstant("GENERATE_SEND_MESSAGE_SCRIPT","true");

	return join("\n",
		"<form method=\"post\" action=\"\${ROOT}/sendmessage.php\">",
		"<input type=\"hidden\" name=\"email\" value=\"".run_EMAIL_CRYPT($localContext,"$email")."\" />",
		"<input type=\"hidden\" name=\"url\" value=\"$source_url\" />",
		"<p><label for=\"sender\">Your email:</label>&nbsp;<input type=\"text\" size=\"30\" name=\"sender\" value=\"$sender\" /></p>",
		"<p><label for=\"subject\">Subject:</label>&nbsp;<input type=\"text\" size=\"30\" name=\"subject\" value=\"$subject\" /></p>",
		"<p><label for=\"message\">Message:</label><br />",
		"<textarea cols=\"50\" rows=\"15\" name=\"message\">$content</textarea></p>",
		"$additionalHtml",
		"<p><input style=\"margin-top:5px;\" type=\"submit\" name=\"action\" value=\"Send\" /></p>",
		"</form>");
}

sub run_DIFFERED {
	my $localContext = shift || confess('no local context');
	my $id = shift || confess('no differed content identifier');
	my $content = shift || '';
	my $site = $localContext->{'site'} || confess('no site path');
	if ($content) {
		my $hashs = getDefaultHashs();
		$hashs->{'###AWEBGEN_DIFFERED_CONTENT###'}{"$id"}{"$site"} = $content;
		return '###AWEBGEN_DIFFERED_CONTENT_'.$id.'###';
	}
	return '';
}

1;
__END__
