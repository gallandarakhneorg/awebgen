<?php

// Translation from SPIP to offline CMS
$pages = array();
#{PAGES}

$authors = array();
#{AUTHORS}

// Code
$redirectPage = '';

# Author pages
if ($_GET['page'] == 'auteur') {
	if ($authors[$_GET['id_auteur']]) {
		$redirectPage = $authors[$_GET['id_auteur']];
	}
}
if (!$redirectPage) {
	foreach($authors as $authorid => $authorurl) {
		if (array_key_exists("auteur$authorid",$_GET)) {
			$redirectPage = $authorurl;
			break;
		}
	}
}

# Article pages
if ((!$redirectPage)&&($_GET['page'] == 'article')) {
	if ($pages["article".$_GET['id_article']]) {
		$redirectPage = $pages["article".$_GET['id_article']];
	}
}

# Rubrique pages
if ((!$redirectPage)&&($_GET['page'] == 'rubrique')) {
	if ($pages["rubrique".$_GET['id_rubrique']]) {
		$redirectPage = $pages["rubrique".$_GET['id_rubrique']];
	}
}

# Standard pages
if (!$redirectPage) {
	foreach($pages as $name=>$url) {
		if (array_key_exists("$name",$_GET)) {
			$redirectPage = $url;
			break;
		}
	}
}

# Do the redirection
if ($redirectPage) {
	header("Location: ./redirect.php?url=".urlencode($redirectPage));
}
else {
	header("Location: #{ERROR_PAGE}");
}

?>
