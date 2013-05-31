<?php
	// Image size
	$imgWidth = 180;
	$imgHeight = 50;

	// Start the session
	session_start();

	// Set of valid letters
	$validLetters = "123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";

	// Code generation
	$code = '';
	while(strlen($code) != 6) {
	   $code .= $validLetters[rand(0,strlen($validLetters))];
	}

	// Save the code in the session
	$_SESSION['ml_code'] = $code; 

	// Create an empty image
	$img = imageCreate($imgWidth, $imgHeight) or die ("Can't create GD image");

	// Select the backgorund color
	//$background_color = imagecolorallocate ($img, 238, 238, 238);
	$background_color = imagecolorallocate ($img, 255, 255, 255);

	// Select the foreground color
	$foreground_color = imagecolorallocate ($img, 0, 0, 0);

	// Load and select font
	$font = imageloadfont('./secimg.gdf');

	// Code of the font
	//$font = 5;

	// Force header to avoid cahing of the picture
	header('Expires: Mon, 26 Jul 1997 05:00:00 GMT');
	header('Cache-Control: no-store, no-cache, must-revalidate');
	header('Cache-Control: post-check=0, pre-check=0', false);
	header("Content-type: image/jpeg");

	// Put the code on the picture
	imageString($img, $font, ($imgWidth-imageFontWidth($font) * strlen("$code"))/2, $imgHeight-imageFontHeight($font), $code, $foreground_color);

	// Force the quality of the picture to 30% to avoid
	// robot reading. Display the result.
	imagejpeg($img,'',30);

	// Free memory
	imageDestroy($img);
?>
