<?php

function extractSnapId($full) {
	if (preg_match('/^[^|]+\|(.*)$/', $full, $matches)) {
		return $matches[1];
	}
	return $full;
}

function extractSnapFlet($full) {
	if (preg_match('/^([^|]+)\|/', $full, $matches)) {
		return $matches[1];
	}
	return null;
}

$project = $_GET['project'];
$subproject = $_GET['subproject'];
$directory = $_GET['dir'];
$groupId = $_GET['groupId'];
$artifactId = $_GET['artifactId'];
$flet = $_GET['flet'];

if ($project) {

	$keys = array(
			${FOREACH:PAGE(snap):'$1$' => "$2$",}
	);
	if ($subproject) {
		$name = "$project";
		$subname = extractSnapId($keys[strtolower($subproject)]);
		if (!$flet) {
			$flet = extractSnapFlet($keys[strtolower($subproject)]);
		}
	}
	else {
		$name = extractSnapId($keys[strtolower($project)]);
		if (!$flet) {
			$flet = extractSnapFlet($keys[strtolower($project)]);
		}
	}

	if (!$flet) {
		$flet = substr(strtolower($name),0,1);
	}

	if ($name && $flet) {
		if ($subname) {
			$location = "#{SNAP_URL_SUBPROJECT}";
		}
		else {
			$location = "#{SNAP_URL}";
		}
	}

}
elseif ($groupId && $artifactId) {
	$groupPath = str_replace(".","/","$groupId");
	$dirversion = $_GET['version'];
	$jarversion = $dirversion;
	if ($dirversion) {
		$rType = $_GET['type'];
		if ($rType == "devel") {
			$originalDirVersion = "$dirversion";
			$dirversion .= "-SNAPSHOT";
			$searchDir = "#{MAVEN_REPOSITORY_DIR}";
			$jarversion = '';
			if ($searchDir) {
				$dir_handle = @opendir("$searchDir") or die("Unable to open $searchDir");
				$max = -1;
				while ($file = readdir($dir_handle)) {
					if (preg_match("/^$artifactId\-[^-]+\-([0-9\.]+)\-([0-9]+)\.jar/", $file, $matches)) {
						$vernumber = $matches[1];
						$idx = $matches[2];
						if ($idx>$max) {
							$jarversion = "$originalDirVersion-".$vernumber."-".$idx;
							$max = $idx;
						}
					}
				}
				closedir($dir_handle);
			}
		}
		elseif ($rType == "javadoc") {
			$jarversion .= "-javadoc";
		}
		elseif ($rType == "source") {
			$jarversion .= "-sources";
		}
		if ($jarversion) {
			$location = "#{MAVEN_REPOSITORY_VERSION_WITH_JAR}";
		}
		else {
			$location = "#{MAVEN_REPOSITORY_VERSION}";
		}
	}
	else {
		$location = "#{MAVEN_REPOSITORY}";
	}
}
elseif ($directory) {

	if (!$flet) {
		$flet = substr($directory,0,1);
	}
	$name = $directory;

	if ($name && $flet) {
		if ($subname) {
			$location = "#{SNAP_URL_SUBPROJECT}";
		}
		else {
			$location = "#{SNAP_URL}";
		}
	}
}

if (!$location) {
	$location = '${SITE_URL}/index.html';
}

header('Location: '.$location);

?>
