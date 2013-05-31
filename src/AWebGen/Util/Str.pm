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

package AWebGen::Util::Str;

@ISA = ('Exporter');
@EXPORT = qw( &protectQuote &protectQQuote &isnum &isint &isfloat &isneg &isinf &isnan 
	      &urlencode &urldecode &urlsplit &urlmerge &htmldecode &htmlencode 
	      &striphtmltags &removeCStrings &restoreCStrings &text2htmllist
	      &makeNotExpandable &makeExpandable ) ;
@EXPORT_OK = qw();
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);
my $VERSION = "2.0" ;

use Carp;

use constant TRUE => (1==1);
use constant FALSE => (1==0);

use constant IS_NUMBER_IN_UV => 0x01; #number within UV range - not necessarily an integer
use constant IS_NUMBER_GREATER_THAN_UV_MAX => 0x02; #number is greater than UV_MAX
use constant IS_NUMBER_NOT_INT => 0x04; #saw . or E notation
use constant IS_NUMBER_NEG => 0x08; #leading minus sign
use constant IS_NUMBER_INFINITY => 0x10; #Infinity
use constant IS_NUMBER_NAN => 0x20; #NaN - not a number

# Translation table
my %HTML_ENTITY_CODES = ( 'nbsp'       => 160, #no-break space = non-breaking space
			  'iexcl'      => 161, #inverted exclamation mark, U+00A1 ISOnum
			  'cent'       => 162, #cent sign
			  'pound'      => 163, #pound sign
			  'curren'     => 164, #currency sign
			  'yen'        => 165, #yen sign = yuan sign
			  'brvbar'     => 166, #broken bar = broken vertical bar
			  'sect'       => 167, #section sign
			  'uml'        => 168, #diaeresis = spacing diaeresis,
			  'copy'       => 169, #copyright sign
			  'ordf'       => 170, #feminine ordinal indicator
			  'laquo'      => 171, #left-pointing double angle quotation mark
			  'not'        => 172, #not sign
			  'shy'        => 173, #soft hyphen = discretionary hyphen
			  'reg'        => 174, #registered sign = registered trade mark sign
			  'macr'       => 175, #macron = spacing macron = overline = APL overbar
			  'deg'        => 176, #degree sign
			  'plusmn'     => 177, #plus-minus sign = plus-or-minus sign
			  'sup2'       => 178, #superscript two = superscript digit two = squared
			  'sup3'       => 179, #superscript three = superscript digit three = cubed
			  'acute'      => 180, #acute accent = spacing acute
			  'micro'      => 181, #micro sign
			  'para'       => 182, #pilcrow sign = paragraph sign
			  'middot'     => 183, #middle dot = Georgian comma = Greek middle dot
			  'cedil'      => 184, #cedilla = spacing cedilla
			  'sup1'       => 185, #superscript one = superscript digit one
			  'ordm'       => 186, #masculine ordinal indicator
			  'raquo'      => 187, #right-pointing double angle quotation mark = right pointing guillemet
			  'frac14'     => 188, #vulgar fraction one quarter = fraction one quarter
			  'frac12'     => 189, #vulgar fraction one half = fraction one half
			  'frac34'     => 190, #vulgar fraction three quarters = fraction three quarters
			  'iquest'     => 191, #inverted question mark = turned question mark
			  'Agrave'     => 192, #latin capital letter A with grave = latin capital letter A grave
			  'Aacute'     => 193, #latin capital letter A with acute
			  'Acirc'      => 194, #latin capital letter A with circumflex
			  'Atilde'     => 195, #latin capital letter A with tilde
			  'Auml'       => 196, #latin capital letter A with diaeresis
			  'Aring'      => 197, #latin capital letter A with ring above = latin capital letter A ring
			  'AElig'      => 198, #latin capital letter AE = latin capital ligature AE
			  'Ccedil'     => 199, #latin capital letter C with cedilla
			  'Egrave'     => 200, #latin capital letter E with grave
			  'Eacute'     => 201, #latin capital letter E with acute
			  'Ecirc'      => 202, #latin capital letter E with circumflex
			  'Euml'       => 203, #latin capital letter E with diaeresis
			  'Igrave'     => 204, #latin capital letter I with grave
			  'Iacute'     => 205, #latin capital letter I with acute
			  'Icirc'      => 206, #latin capital letter I with circumflex
			  'Iuml'       => 207, #latin capital letter I with diaeresis
			  'ETH'        => 208, #latin capital letter ETH
			  'Ntilde'     => 209, #latin capital letter N with tilde
			  'Ograve'     => 210, #latin capital letter O with grave
			  'Oacute'     => 211, #latin capital letter O with acute
			  'Ocirc'      => 212, #latin capital letter O with circumflex
			  'Otilde'     => 213, #latin capital letter O with tilde
			  'Ouml'       => 214, #latin capital letter O with diaeresis
			  'times'      => 215, #multiplication sign
			  'Oslash'     => 216, #latin capital letter O with stroke = latin capital letter O slash
			  'Ugrave'     => 217, #latin capital letter U with grave
			  'Uacute'     => 218, #latin capital letter U with acute
			  'Ucirc'      => 219, #latin capital letter U with circumflex
			  'Uuml'       => 220, #latin capital letter U with diaeresis
			  'Yacute'     => 221, #latin capital letter Y with acute
			  'THORN'      => 222, #latin capital letter THORN
			  'szlig'      => 223, #latin small letter sharp s = ess-zed
			  'agrave'     => 224, #latin small letter a with grave = latin small letter a grave
			  'aacute'     => 225, #latin small letter a with acute
			  'acirc'      => 226, #latin small letter a with circumflex
			  'atilde'     => 227, #latin small letter a with tilde
			  'auml'       => 228, #latin small letter a with diaeresis
			  'aring'      => 229, #latin small letter a with ring above = latin small letter a ring
			  'aelig'      => 230, #latin small letter ae = latin small ligature ae
			  'ccedil'     => 231, #latin small letter c with cedilla
			  'egrave'     => 232, #latin small letter e with grave
			  'eacute'     => 233, #latin small letter e with acute
			  'ecirc'      => 234, #latin small letter e with circumflex
			  'euml'       => 235, #latin small letter e with diaeresis
			  'igrave'     => 236, #latin small letter i with grave
			  'iacute'     => 237, #latin small letter i with acute
			  'icirc'      => 238, #latin small letter i with circumflex
			  'iuml'       => 239, #latin small letter i with diaeresis
			  'eth'        => 240, #latin small letter eth
			  'ntilde'     => 241, #latin small letter n with tilde
			  'ograve'     => 242, #latin small letter o with grave
			  'oacute'     => 243, #latin small letter o with acute
			  'ocirc'      => 244, #latin small letter o with circumflex
			  'otilde'     => 245, #latin small letter o with tilde
			  'ouml'       => 246, #latin small letter o with diaeresis
			  'divide'     => 247, #division sign
			  'oslash'     => 248, #latin small letter o with stroke = latin small letter o slash
			  'ugrave'     => 249, #latin small letter u with grave
			  'uacute'     => 250, #latin small letter u with acute
			  'ucirc'      => 251, #latin small letter u with circumflex
			  'uuml'       => 252, #latin small letter u with diaeresis
			  'yacute'     => 253, #latin small letter y with acute
			  'thorn'      => 254, #latin small letter thorn
			  'yuml'       => 255, #latin small letter y with diaeresis
			  'quot'       => 34, #quotation mark = APL quote
			  'amp'        => 38, #ampersand
			  'lt'         => 60, #less-than sign
			  'gt'         => 62, #greater-than sign
			  'OElig'      => 338, #latin capital ligature OE
			  'oelig'      => 339, #latin small ligature oe
			  'Scaron'     => 352, #latin capital letter S with caron
			  'scaron'     => 353, #latin small letter s with caron
			  'Yuml'       => 376, #latin capital letter Y with diaeresis
			  'circ'       => 710, #modifier letter circumflex accent
			  'tilde'      => 732, #small tilde
			) ;

# The characters which are displayed for each HTML entity (including &amp; &gt; &lt; &quot; )
my %HTML_ENTITY_CHARS = (  'amp'          => '&',
			   'gt'           => '<',
			   'lt'           => '>',
			   'quot'         => '"',
			   'nbsp'         => ' ',
			   'Ocirc'        => 'Ô',
			   'szlig'        => 'ß',
			   'micro'        => 'µ',
			   'para'         => '¶',
			   'not'          => '¬',
			   'sup1'         => '¹',
			   'oacute'       => 'ó',
			   'Uacute'       => 'Ú',
			   'middot'       => '·',
			   'ecirc'        => 'ê',
			   'pound'        => '£',
			   'scaron'       => 'š',
			   'ntilde'       => 'ñ',
			   'igrave'       => 'ì',
			   'atilde'       => 'ã',
			   'thorn'        => 'þ',
			   'Euml'         => 'Ë',
			   'Ntilde'       => 'Ñ',
			   'Auml'         => 'Ä',
			   'plusmn'       => '±',
			   'raquo'        => '»',
			   'THORN'        => 'Þ',
			   'laquo'        => '«',
			   'Eacute'       => 'É',
			   'divide'       => '÷',
			   'Uuml'         => 'Ü',
			   'Aring'        => 'Å',
			   'ugrave'       => 'ù',
			   'Egrave'       => 'È',
			   'Acirc'        => 'Â',
			   'oslash'       => 'ø',
			   'ETH'          => 'Ð',
			   'iacute'       => 'í',
			   'Ograve'       => 'Ò',
			   'Oslash'       => 'Ø',
			   'frac34'       => '3/4',
			   'Scaron'       => 'Š',
			   'eth'          => 'ð',
			   'icirc'        => 'î',
			   'ordm'         => 'º',
			   'ucirc'        => 'û',
			   'reg'          => '®',
			   'tilde'        => '~',
			   'aacute'       => 'á',
			   'Agrave'       => 'À',
			   'Yuml'         => 'Ÿ',
			   'times'        => '×',
			   'deg'          => '°',
			   'AElig'        => 'Æ',
			   'Yacute'       => 'Ý',
			   'Otilde'       => 'Õ',
			   'circ'         => '^',
			   'sup3'         => '³',
			   'oelig'        => 'œ',
			   'frac14'       => '1/4',
			   'Ouml'         => 'Ö',
			   'ograve'       => 'ò',
			   'copy'         => '©',
			   'shy'          => '­',
			   'iuml'         => 'ï',
			   'acirc'        => 'â',
			   'iexcl'        => '¡',
			   'Iacute'       => 'Í',
			   'Oacute'       => 'Ó',
			   'ccedil'       => 'ç',
			   'frac12'       => '1/2',
			   'Icirc'        => 'Î',
			   'eacute'       => 'é',
			   'egrave'       => 'è',
			   'euml'         => 'ë',
			   'Ccedil'       => 'Ç',
			   'OElig'        => 'Œ',
			   'Atilde'       => 'Ã',
			   'ouml'         => 'ö',
			   'cent'         => '¢',
			   'Aacute'       => 'Á',
			   'sect'         => '§',
			   'Ugrave'       => 'Ù',
			   'aelig'        => 'æ',
			   'ordf'         => 'ª',
			   'yacute'       => 'ý',
			   'Ecirc'        => 'Ê',
			   'auml'         => 'ä',
			   'macr'         => '¯',
			   'iquest'       => '¿',
			   'sup2'         => '²',
			   'Ucirc'        => 'Û',
			   'aring'        => 'å',
			   'Igrave'       => 'Ì',
			   'yen'          => '¥',
			   'uuml'         => 'ü',
			   'otilde'       => 'õ',
		   	   'uacute'       => 'ú',
			   'yuml'         => 'ÿ',
			   'ocirc'        => 'ô',
			   'Iuml'         => 'Ï',
			   'agrave'       => 'à',
			) ;

# Protect the quote char
sub protectQuote($) {
	my $txt = shift || '';
	$txt =~ s/[']/\\'/sg;
	return $txt;
}

# Protect the double quote char
sub protectQQuote($) {
	my $txt = shift || '';
	$txt =~ s/["]/\\"/sg;
	return $txt;
}

# Replies if the parameter is a number
sub isnum($) {
    return 0 unless defined (my $val = shift);
    # stringify - ironically, looks_like_number always returns 1 unless
    # arg is a string
    return is_num($val . '');
}

# Replies if the parameter is an integer
sub isint($) {
    my $isnum = isnum(shift());
    return ($isnum == IS_NUMBER_IN_UV) ? 1 : ($isnum == IS_NUMBER_INFINITY) ? -1 : 0;
}

# Replies if the parameter is a floating number
sub isfloat($) {
    return (isnum(shift()) & IS_NUMBER_NOT_INT) ? TRUE : FALSE;
}

# Replies if the parameter is a negative number
sub isneg($) {
    return (isnum(shift()) & IS_NUMBER_NEG) ? TRUE : FALSE;
}

# Replies if the parameter is an infinity number
sub isinf($) {
    return (isnum(shift()) & IS_NUMBER_INFINITY) ? TRUE : FALSE;
}

# Replies if the parameter is not a number
sub isnan($) {
    return (isnum(shift()) & IS_NUMBER_NAN) ? TRUE : FALSE;
}

# URL encoding
sub urlencode($) {
    my $string = shift || '';
    $string =~ s/(\W)/"%" . unpack("H2", $1)/ges;
    return "$string";
 }

# URL decoding
sub urldecode {
    my $string = shift || '';
    $string =~ tr/+/ /;
    $string =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/ges;
    return "$string";
}

# Split a url string into there components.
sub urlsplit($) {
	my $url = shift || '';
	my %p = ();
	if ($url =~ 
		m!^\s*                  # perhaps leading white space
                (http|https|ftp|ssh|sftp|svn|svn\+ssh|smb|file)://     # protocol
                ([^:/]+)                # server
                (?:(\d+))?              # port
                (/[^\#\?]+?)            # page
                (.*?)	                # params
                \s*$
                !xi) {
		%p = (	'protocol' => $1 || '',
			'server' => $2 || '',
			'port' => $3 || '',
			'page' => $4 || '',
			'params' => $5 || '',
		      );
		my %ports = (
				http => 80,
				https => 443,
				ftp => 21,
				ssh => 22,
				sftp => 115,
				svn => 3690,
				'svn+ssh' => 22,
			    );
		if (!$p{'port'} || $p{'port'}<=0) {
			if ($p{'protocol'} && exists $ports{$p{'protocol'}}) {
				$p{'port'} = $ports{$p{'protocol'}};
			}
			else {
				delete $p{'port'};
			}
		}
		else {
			delete $p{'port'};
		}

		if ($p{'params'}) {
			my $ps = $p{'params'};
			$p{'params'} = FALSE;
			if ($ps =~ /^(.*)\#\s*(.*?)\s*$/) {
				$p{'anchor'} = "$2" if ($2);
				$ps = $1 || '';
			}
			if ($ps && $ps =~ /^\?(.*?)$/) {
				my @t = split(/\s*\&\s*/, ($1 || ''));
				if (@t) {
					foreach my $p (@t) {
						if ($p =~ /^\s*([^=]+?)\s*\=\s*(.*?)\s*$/) {
							$p{'params'}{"$1"} = urldecode("$2");
						}
						else {
							$p{'params'}{"$p"} = '';
						}
					}
				}
			}
		}
		else {
			$p{'params'} = FALSE;
		}
	}
	else {
		%p = (	'protocol' => 'file',
			'server' => '',
			'port' => '',
			'page' => "$url",
			'params' => '',
		      );
	}

	delete $p{'params'} unless ($p{'params'});

        return %p;
}

# Merge URL components
sub urlmerge(\%) {
	my $comps = shift || croak("no components");
	my $url = ($comps->{'protocol'} || 'file').'://';
	if ($comps->{'server'}) {
		$url .= $comps->{'server'};
	}
	if ($comps->{'port'}) {
		$url .= ":".$comps->{'ports'};
	}
	if ($comps->{'page'}) {
		$url .= $comps->{'page'};
	}
	if ($comps->{'params'}) {
		my $ps = '';
		while (my ($k,$v) = each(%{$comps->{'params'}})) {
			$ps .= ($ps) ? "&" : "?";
			$ps .= urlencode($k);
			if ($v) {
				$ps .= "=".urlencode($v);
			}
		}
		$url .= "$ps";
	}
	if ($comps->{'anchor'}) {
		$url .= "#".$comps->{'anchor'};
	}
	return "$url";
}

# Replace HTML entities by there corresponding characters
sub htmldecode($) {
	my $s = shift || '';
	while (my ($k,$v) = each(%HTML_ENTITY_CODES)) {
		$s =~ s/\&\Q$v\E;/$HTML_ENTITY_CHARS{$k}/gs;
	}
	while (my ($k,$v) = each(%HTML_ENTITY_CHARS)) {
		$s =~ s/\&\Q$k\E;/$v/gs;
	}
	return "$s";
}

# Replace characters by there corresponding HTML entities
sub htmlencode($) {
	my $s = shift || '';
	while (my ($k,$v) = each(%HTML_ENTITY_CHARS)) {
		$s =~ s/\Q$v\E/\&$k;/gs;
	}
	return "$s";
}

# Remove the HTML tags
sub striphtmltags($) {
	my $s = shift || '';
	my $h = {};
	my $r = removeCStrings("$s", $h);

	$r =~ s/\<[^>]*?\>//gs;

	return restoreCStrings("$r",$h);
}

# Replace strings \"\" by CONSTANTS.
# Return the modified string. Fill the second 
# parameter with constant mapping.
# $_[0] : string to analyze and modify
# $_[1] : constant mapping (hashtable)
sub removeCStrings($;$) {
	my $str = shift || '';
	$str = "$str";
	my $hash = shift;
	my $idx=0;

	while ($str =~ /AWEBGENSTRING_$idx/) {
		$idx++;
	}

	my $r = '';
	my $ls = '';
	my $instr = FALSE;

	while ($str =~ /^(.*?)\"(.*)$/s) {
		my ($prev,$next) = ($1,$2);
		if ($instr) {
			if ($prev =~ /\\$/s) {
				# Protected string
				$ls .= "$prev\"";
			}
			else {
				$instr = FALSE;
				$r .= "{AWEBGENSTRING_$idx}";
				$hash->{"AWEBGENSTRING_$idx"} = "$ls$prev";
				$idx ++;
				$ls = '';
			}
		}
		else {
			$r .= "$prev";
			$instr = TRUE;
		}
		$str = $next;
	}

	return $r.($str||'');
}

# Replace strings CONSTANTS by \"\" values.
# Return the modified string.
# $_[0] : string to analyze and modify
# $_[1] : constant mapping (hashtable)
sub restoreCStrings($$) {
	my $str = shift || '';
	my $hash = shift;
	return "$str" unless($hash);
	my $r = "$str";
	foreach my $k (keys %{$hash}) {
		$r =~ s/\Q{$k}\E/\"$hash->{$k}\"/sg;
	}
	return "$r";
}

# Parse a textual list (with '*' and '-') and replies the equivalent HTML list.
# $_[0] : string to analyze
# $_[1] : <ul> class
# $_[2] : <ul> subclass
sub text2htmllist($;$$) {
	my $str = shift || '';
	my $ulclass = shift || '';
	my $ulsubclass = shift || '';

	my $expanded = '';
	my @entries = split(/^\s*\*\s*/m,"$str");
	my $eadded = FALSE;

	my $first = shift @entries;
	$first =~ s/^\s+//s;
	$first =~ s/\s+$//s;
	$expanded .= "$first" if ($first);

	foreach my $entry (@entries) {
		$entry =~ s/^\s+//s;
		$entry =~ s/\s+$//s;
		if ($entry) {
			if (!$eadded) {
				$eadded = TRUE;
				$expanded .= "<ul".($ulclass?" class=\"$ulclass\"":"").">";
			}
			$expanded .= "<li>";
			if ($entry =~ /^\s*\-\s*/m) {
				my @subentries = split(/^\s*\-\s*/m,"$entry");
				my $seadded = FALSE;
				$first = shift @subentries;
				$first =~ s/^\s+//s;
				$first =~ s/\s+$//s;
				$expanded .= "$first" if ($first);
				foreach my $subentry (@subentries) {
					$subentry =~ s/^\s+//s;
					$subentry =~ s/\s+$//s;
					if ($subentry) {
						if (!$seadded) {
							$expanded .= "<ul".($ulsubclass?" class=\"$ulsubclass\"":"").">";
							$seadded = TRUE;
						}
						$expanded .= "<li>$subentry</li>\n";
					}
				}
				$expanded .= "</ul>\n" if ($seadded);
			}
			else {
				$expanded .= "$entry";
			}
			$expanded .= "</li>";
		}
	}

	if ($eadded) {
		$expanded .= "</ul>";
	}

	return "$expanded";
}

# Make not expandable
# $_[0] : name
# $_[1] : params
# $_    : str
sub makeNotExpandable($;$) {
	my $name = shift || '';
	my $params = shift || '';
	if ($name) {
		if ($params) {
			my $p = ":$params";
			$p =~ s/:/\&protectcolumn;/sg;
			return "\$#PROTECT[$name$p]PROTECT#";
		}
		else {
			return "\$#PROTECT[$name]PROTECT#";
		}
	}
	return '';
}

# Make expandable
# $_[0] : text
# $_    : str
sub makeExpandable($) {
	my $str = shift || '';
	if ($str) {
		$str =~ s/\&protectcolumn;/:/gs;
		$str =~ s/\$\#PROTECT\[/\${/gs;
		$str =~ s/]PROTECT#/}/gs;
		return "$str";
	}
	return '';
}

1;
__END__
