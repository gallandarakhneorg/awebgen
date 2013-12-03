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

package AWebGen::Code::Exec;

@ISA = ('Exporter');
@EXPORT = qw( &codeReplaceInFile &codeReplaceCommand &codeReplaceConstant );
@EXPORT_OK = qw();
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);
my $VERSION = "2.0" ;

use Carp;
use File::Basename;
use File::Spec;
use AWebGen::Util::Str;
use AWebGen::Util::File;
use AWebGen::Util::Output;
use AWebGen::Code::LocalContext;
use AWebGen::Code::Code qw/ %INSTRUCTIONS %HTML_CONSTANTS /;

use constant TRUE => (1==1);
use constant FALSE => (1==0);
use constant DIRSEP => File::Spec->catdir('','');

use constant UNPROTECTED => 0;
use constant PROTECTED => 1;
use constant BRACE_PROTECTED => 2;

# Replies if the given name is runnable according to rectricted expansions.
# $_[0] : local context
# $_[1] : name
# $_[2] : indicates if the given name is for a constant macro or not.
# $_    : TRUE or FALSE
sub isExpandable($$$) {
	my $localContext = shift;
	my $name = shift || '';
	my $isConstant = shift;

	if ($isConstant) {
		return TRUE;
	}

	my $allowExpansion = TRUE;
	if ($localContext->{'restricted-expansion'}) {
		my $inst = getLCInstruction($localContext, "$name");
		$allowExpansion = ($inst) && ($inst->{'includedefs'});
	}

	return $allowExpansion;
}

# Extract parameter values according to a prototype.
# In a prototype the following characters are used:
# $ for each mandatory parameter value;
# # for each optional parameter value;
# : is the default parameter separator
# the others characters are separating strings between the parameter values.
# The prototype of a command is "<return type>(<parameter_prototype>)".
#
# $_[0] : name of the command associated to the given prototype
# $_[1] : prototype
# $_[2] : parameters in a string
# $_    : return the array of parameters
sub extractParamValues($$$) {
	my $cmdname = shift || confess('no command name');
	my $proto = shift || confess('no prototype');
	my $params = shift || '';
	my @values = ();

	croak('invalid parameter prototype: '.$proto)
		unless ($proto =~ /^([\$\%\@\#])\((.*)\)$/s);
	my $returnType = "$1";
	$proto = "$2";

	my $count = 0;
	while ($proto =~ /[\$\#]/sg) {
		$count ++;
	}

	my $re = "$proto";
	$re =~ s/([^\$\#\[\]])/\\$1/sg;
	$re =~ s/\[(.*?)\]/(?:$1)?/sg;
	if ($count>1) {
		$re =~ s/\$/(.+?)/sg;
		$re =~ s/\#/(.*?)/sg;
	}
	else {
		$re =~ s/\$/(.+)/sg;
		$re =~ s/\#/(.*)/sg;
	}
	# Remove text between braces, brackets, and parenthesis
	# to avoid them to be analyzed wrontgly as parameters
	my @innerBlocks = ();
	my $aParams = "$params";
	while ($aParams =~ /(?:\{.*\})|(?:\[.*\])|(?:\(.*\))/s) {
		$aParams =~ s/((?:\{[^\{\[\(\}\]\)]*\})|(?:\[[^\{\[\(\}\]\)]*\])|(?:\([^\{\[\(\}\]\)]*\)))/
				push @innerBlocks, "$1";
				"<INNER".($#innerBlocks).">";
				/ges;
	}

	eval {
		if ($aParams =~ /^$re$/s) {
			for(my $i=1; $i<=$count; $i++) {
				$values[$i-1] = eval('$'.$i);
			}
		}
	};

	croak("invalid call to \$\{$cmdname\}: found ".@values." parameters but requiring $count parameters. Parameter string is:\n\n$params\n\n")
		unless (@values==$count);

	# Put back the inner blocks
	foreach my $v (@values) {
		if (defined($v)) {
			while ($v =~ /\Q<INNER\E[0-9]+\Q>\E/) {
				$v =~ s/\Q<INNER\E([0-9]+)\Q>\E/$innerBlocks[$1]/gs;
			}
		}
	}

	return ($returnType,@values);
}

# Invoked to expand a command only
# $_[0] : local context
# $_[1] : command name
# $_[2] : the parameters' string
# $_    : return the expanded string
sub codeReplaceCommand($$;$) {
	my $localContext = shift;
	my $name = shift;
	my $params = shift || '';

	$name = uc("$name");

	my $allowExpansion = isExpandable($localContext,"$name",FALSE);

	if ($allowExpansion) {
		my $inst = getLCInstruction($localContext,"$name");

		if ($inst) {

			my ($returnType, @paramValues) = extractParamValues(
								"$name",
								$inst->{'proto'},
								"$params");

			my $expanded;
			if ($inst->{'run'}) {
				eval('$expanded = AWebGen::Code::Code::'.
				     $inst->{'run'}.
				     '($localContext,@paramValues);');
				if ($@) {
					croak("$@");
				}
			}
			elsif ($inst->{'callback'}) {
				my $staticParameters = $inst->{'callback_params'};
				eval('$expanded = AWebGen::Code::Code::'.
				     $inst->{'callback'}.
				     '($localContext,"$name",$staticParameters,@paramValues);');
				if ($@) {
					croak("$@");
				}
			}
			else {
				confess("don't known how to expand $name macro");
			}

			if ($returnType eq '#') {
				if ($expanded) {
					warm("macro $name has returned a value but is supported to return void.");
				}
				return '';
			}
			elsif ($returnType eq '@') {
				my $r = "<ul>\n";
				foreach my $e (@{$expanded}) {
					$r .= "<li>$e</li>\n";
				}
				$r .= "</ul>\n";
				return "$r";
			}
			elsif ($returnType eq '%') {
				my $r = "<dl>\n";
				while (my ($k,$v) = each(%{$expanded})) {
					$r .= "<dt>$k</dt><dd>$v</dd>\n";
				}
				$r .= "</dl>\n";
				return "$r";
			}
			else {
				return "$expanded";
			}
		}

		warm("Unable to find the command '$name' with params '$params'");
		return "#ERR#\{$name\}\}";
	}
	else {
		return makeNotExpandable($name,$params);
	}
}

# Invoked to expand a constant only
# $_[0] : local context
# $_[1] : constant name
# $_    : return the expanded string
sub codeReplaceConstant($$) {
	my $localContext = shift;
	my $content = shift;

	my $allowExpansion = isExpandable($localContext,$content,TRUE);

	if ($allowExpansion) {
		my $value = getLCConstant($localContext,$content);

		if (defined($value)) {
			return "$value";
		}
		else {
			warm("Unable to find the constant '$content'");
			return "#ERR#\{$content\}";
		}
	}
	else {
		return makeNotExpandable("$content");
	}
}

# Invoked to expand a command only
# $_[0] : local context
# $_[1] : string to expand (should contain a command)
# $_    : return the expanded string
sub codeExecCommand($$) {
	my $localContext = shift;
	my $content = shift;
	my $expanded;

	# Extract the command name
	if ($content =~ /^([a-zA-Z0-9_]+)(.*)$/s) {
		my $command = "$1";
		my $content = "$2";

		if ($content =~ /^\:(.*)$/s) {
			# Function replacement
			my $params = $1;
			$expanded = codeReplaceCommand($localContext,"$command","$params");
		}
		else {
			my $inst = getLCInstruction($localContext,uc("$command"));
			if ($inst) {
				# Function replacement
				$expanded = codeReplaceCommand($localContext,"$command");
			}
			else {
				# Constant replacement
				$expanded = codeReplaceConstant($localContext,"$command");
			}
		}
	}
	else {
		$expanded = "\${$content}";
	}

	return $expanded;
}

# Invoked to replace macros on a string from a new local context.
# $_[0] : local context.
# $_[1] : text to replace in.
# $_[2] : debug flag (boolean)
sub codeReplaceInLocalContext($$;$) {
	my $localContext = shift;
	my $content = shift;
	my $debugFlags = shift;
	my @attemptedBlockClosingSymbols = ();
	my @protectedMode = ( UNPROTECTED );
	my @stack = ( '' );
	
	# Search first function or block
	while ($content =~ /^(.*?)((?:\<\?php)|(?:\<\?asp)|(?:\?\>)|(?:\$\{)|(?:\{\{)|(?:\}\})|[:\{\[\]\}\(\)])(.*)$/sg) {
		my $prev = $1;
		my $sep = $2;
		my $rest = $3;
		my $expanded = '';

		$stack[$#stack] .= "${prev}";

		my $istop = @attemptedBlockClosingSymbols == 0;

		if (($sep eq '<?php')||($sep eq '<?asp')) {
			push @attemptedBlockClosingSymbols, '?>';
			push @protectedMode, BRACE_PROTECTED;
			$expanded = $sep;
		}
		elsif ($sep eq '?>') {
			my $s = $attemptedBlockClosingSymbols[$#attemptedBlockClosingSymbols] || '';
			if ("$s" eq '?>') {
				pop @attemptedBlockClosingSymbols;
				pop @protectedMode;
			}
			$expanded = $sep;
		}
		elsif ($sep eq '${') {
			my $protectedmode = $protectedMode[$#protectedMode];
			if ((($protectedmode == UNPROTECTED)
			     ||($protectedmode == BRACE_PROTECTED))
			    && ($rest =~ /^([a-zA-Z0-9_]+)\:/s)) {
				# Check if the command expands its parameters
				# or if they must be expanded by the default
				# algorithm
				my $cmd = "$1";
				my $inst = getLCInstruction($localContext,$cmd);
				if ($inst && $inst->{'expandparams'}) {
					$protectedmode = PROTECTED;
				}
			}
			push @attemptedBlockClosingSymbols, '}$';
			push @protectedMode, $protectedmode;
			push @stack, '';
		}
		elsif ($sep eq '{{') {
			push @attemptedBlockClosingSymbols, '}}';
			push @protectedMode, $protectedMode[$#protectedMode];
			push @stack, '';
			openLocalContext($localContext);
			$expanded = '{{';
		}
		elsif ($sep eq '}}') {
			my $expected = $attemptedBlockClosingSymbols[$#attemptedBlockClosingSymbols];
			if ($expected eq '}' || $expected eq '}$') {
				$rest = "} }${rest}";
			}
			elsif ($expected ne '}}') {
				croak("expected '}}'");
			}
			else {
				pop @protectedMode;
				my $stack = pop @stack;
				closeLocalContext($localContext);
				$expanded = "${stack}\}\}";
			}
		}
		elsif ($sep eq ':') {
			my $functionBlock = ((@attemptedBlockClosingSymbols)
			                    &&($attemptedBlockClosingSymbols[$#attemptedBlockClosingSymbols])
			                    &&($attemptedBlockClosingSymbols[$#attemptedBlockClosingSymbols] eq '}$'));
			$expanded = ($functionBlock) ? ':' : '&column;';
		}
		elsif ($sep eq '{') {
			push @attemptedBlockClosingSymbols, '}';
			push @protectedMode, $protectedMode[$#protectedMode];
			push @stack, '';
			openLocalContext($localContext);
		}
		elsif ($sep eq '[') {
			push @attemptedBlockClosingSymbols, ']';
			push @protectedMode, $protectedMode[$#protectedMode];
			push @stack, '';
		}
		elsif ($sep eq '(') {
			push @attemptedBlockClosingSymbols, ')';
			push @protectedMode, $protectedMode[$#protectedMode];
			push @stack, '';
		}
		elsif ($sep eq '}' || $sep eq ')' || $sep eq ']') {
			if (@attemptedBlockClosingSymbols &&
                            ($attemptedBlockClosingSymbols[$#attemptedBlockClosingSymbols] =~ /^\Q$sep\E/)) {
				# Closing the last opened block
				my $as = $attemptedBlockClosingSymbols[$#attemptedBlockClosingSymbols];
				my $stack = pop @stack;
				pop @protectedMode;
				my $protectedmode = $protectedMode[$#protectedMode];
				pop @attemptedBlockClosingSymbols;
				# Expand the string
				if ($as =~ /\$$/) {
					if ($protectedmode != PROTECTED) {
						my $r = codeExecCommand($localContext,"$stack");
						# Test if something wrong was replied
						if ($r =~ /^\#ERR\#\{.*\}$/) {
							$expanded = "$r";
						}
						else {
							# Do not put the result of the command in $expanded
							# but in the $rest, because the just expanded command
							# could produce inner commands. These commands
							# will be expanded in there turn because they will
							# extracted from the rest of the content
							$rest = "${r}${rest}";
						}
					}
					else {
						# Put back the command because is was protected
						$expanded = "\$\{$stack\}";
					}
				}
				elsif ($sep eq ')') {
					$expanded = "($stack)";
				}
				elsif ($sep eq ']') {
					$expanded = "[$stack]";
				}
				else {
					if ($protectedmode) {
						$expanded = "\{$stack\}";
					}
					else {
						$expanded = "$stack";
					}
					closeLocalContext($localContext);
				}
			}
		}
		else {
			confess("unrecognized symbol: '$sep'\n");
		}

		# Save the expanded string into the stack or the final result
		# depending of the current block-level
		$stack[$#stack] .= "${expanded}";

		$content = "$rest";
	}

	$content = $stack[0]."${content}";

	return "$content";
}

# Invoked to replace macros on a string with a TOP context
# $_[0] : path of the file on the website.
# $_[1] : text to replace in.
sub codeReplaceInTopContext($$) {
	my $sitepath = shift;
	my $content = shift;

	# Build the relative path to the root directory
	my $sep = DIRSEP;
	my $updir = File::Spec->updir();
	my $toroot = dirname("$sitepath");
	if ($toroot eq $sep) {
		$toroot = File::Spec->curdir();
	}
	else {
		$toroot =~ s/^\Q$sep\E//;
		$toroot =~ s/[^$sep]+/$updir/g;
	}

	# Build the top context
	my $localContext = createLocalContext("$sitepath","$toroot",\%INSTRUCTIONS);

	$content = codeReplaceInLocalContext($localContext,$content);

	# Replace protected blocks
	$content =~ s/\{\{//gs;
	$content =~ s/\}\}//gs;

	# Replace dedicated html entities
	while (my ($k,$v) = each(%HTML_CONSTANTS)) {
		$content =~ s/\Q$k\E/$v/sg;
	}

	return $content;
}

# Invoked to replace macros in a file
# $_[0] : absolute path of the file
# $_[1] : site path of the file.
sub codeReplaceInFile($$) {
	my $abspath = shift;
	my $sitepath = shift;
	my $content = readFile("$abspath");

	$content = codeReplaceInTopContext($sitepath,$content);

	# Cleaning HTML
	$content =~ s/\Q<!--\E(\[.*?\]\>.*?)\Q-->\E/\&shtmlcomment;$1\&ehtmlcomment;/sg;
	$content =~ s/\Q<!--\E.*?\Q-->\E//sg;
	$content =~ s/^\s+//mg;
	$content =~ s/\s+$//mg;
	$content =~ s/ {2,}/ /sg;
	$content =~ s/\t+/ /sg;
	$content =~ s/[\n\r\f]+/\n/sg;
	$content =~ s/\s+>/>/sg;
	$content =~ s/\s+<\//<\//sg;
	$content =~ s/>\s+</></sg;
	$content =~ s/\Q&shtmlcomment;\E/<!--/sg;
	$content =~ s/\Q&ehtmlcomment;\E/-->/sg;

	writeFile("$abspath", "$content");
}

1;
__END__
