<?php

$project = $_GET['project'];
$subproject = $_GET['subproject'];

if ($project) {

	if ($subproject) {
		$location = "#{WEBSVN_FULL_URL}";
	}
	else {
		$location = "#{WEBSVN_URL}";
	}

}
else {

	$location = "${SITE_URL}/index.html";

}

header('Location: '.$location);

?>
