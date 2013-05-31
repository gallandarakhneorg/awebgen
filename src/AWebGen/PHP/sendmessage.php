<?php

$sender = $_POST['sender'];
$useremail = $_POST['email'];
$subject = $_POST['subject'];
$message = $_POST['message'];
$source_url = $_POST['url'];

// Decrypt email
$useremail = trim(strtolower(str_replace("${EMAIL_CRYPT_KEY}", "@", "$useremail")));

if (!$sender) {
	$sender = "Anonymous Sender <anonymous@nowhere.com>";
}
elseif (!preg_match("#[a-z0-9._-]+\@[a-z0-9._-]{2,}\.[a-z]{2,4}#", $sender)) {
	$sender .= "$sender <anonymous@nowhere.com>";
}

$page_header = '';

// Start session
session_start();

// Check if code is existing and valid
$wrongCode = FALSE;
if (!isset($_SESSION['ml_code'])||strlen($_SESSION['ml_code'])!=6) {
	$wrongCode = TRUE;
}
elseif ($_SESSION['ml_code'] != $_POST['ml_code']) {
	$wrongCode = TRUE;
}

if (!$wrongCode) {

	// Good code

	// Check valid email
	if ((!empty($useremail))&&
	    (preg_match("#^[a-z0-9._-]+\@[a-z0-9._-]{2,}\.[a-z]{2,4}$#", $useremail))) {

		$mailHeader = "From: $sender\nTo: $useremail\n";

		if (@mail("$useremail","[${SITE_NAME}] $subject","$message",$mailHeader)) {
			$page_content = "<p>Your message was sent to the member.</p>";
		}
		else {
			$page_content = "<p>The mailing server could not be contacted. Please try ".
					"later or contact the ".
					"<a href=\"mailto:${ADMIN_EMAIL}\">administrator</a>.</p>";
		}
	}
	else {

		$page_content = "<p>The receiver email is invalid. I can't proceed your request.</p>";
	}

	// Destroy the session
	session_unset();
	session_destroy();

	if ($source_url) {
		$page_header .= "<meta http-equiv=\"Refresh\" content=\"5;url=$source_url\">\n";
		$page_content .= "<p>You will be redirected in 5 seconds to <a href=\"$source_url\">$source_url</a>.</p>";
	}
}
else {
	//Wrong code


	$additionalHtml = "<p><font color=\"red\">You must enter the following code to proceed your message.</font><br>"
			."<img src=\"${ROOT}/secimg.php\" align=\"center\" alt=\"Code Picture\">&nbsp;"
			."<input type=\"text\" size=\"10\" name=\"ml_code\" /></p>";

	$page_content = <<<ENDHTMLCONTENT
${CONTACT_FORM:$useremail:$sender:$subject:$message:$source_url:$additionalHtml}
ENDHTMLCONTENT;
}

//--------------------
// Format the page
$html_content = <<<ENDHTMLCONTENT
#{PAGE_CONTENT}
ENDHTMLCONTENT;

print $html_content;

?>
