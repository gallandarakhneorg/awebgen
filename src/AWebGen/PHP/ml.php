<?php

$ml_name = $_POST['ml'];
$ml = "#{ML_ADDRESS}";
$ml_req = "#{ML_REQUEST_ADDRESS}";

$user = strtolower($_POST['mail']);

$action = strtolower($_POST['action']);
if ($action != "subscribe" && $action != "unsubscribe") {
	$action = "subscribe";
}

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
	if ((!empty($ml_name))&&
	    (!empty($user))&&
	    (preg_match("#^[a-z0-9._-]+@[a-z0-9._-]{2,}\.[a-z]{2,4}$#", $user))) {

		$mailHeader = "From: $user\n";

		if (@mail("$ml_req","$action","$action $ml",$mailHeader)) {
			if ($action == 'subscribe') {
				$page_content = "<p>Your subscription request to the mailing list $ml ".
						"was sent to the server.</p>".
						"<p>Yo will receive a confirmation email into your mailbox ".
						"$user. Please follow the instruction to finalize your ".
						"inscription.</p>";
			}
			else {
				$page_content = "<p>Your unsubscription request to the mailing list $ml ".
						"was sent to the server.</p>".
						"<p>Yo will receive a confirmation email into your mailbox ".
						"$user. Please follow the instruction to finalize your ".
						"removal from the mailing list.</p>";
			}
		}
		else {
			$page_content = "<p>The mailing server could not be contacted. Please try ".
					"later or contact the ".
					"<a href=\"mailto:contact_at_arakhne.org\">administrator</a>.</p>".
					"<p>Mailing list: $ml</p>".
					"<p>Email: $user</p>".
					"<p>Action: ".$_POST['action']."</p>";
		}
	}
	else {

		$page_content = "<p>One of the given informations is invalid. I can't proceed ".
				"your request.</p>".
				"<p>Mailing list: $ml</p>".
				"<p>Email: $user</p>".
				"<p>Action: ".$_POST['action']."</p>";
	}

	// Destroy the session
	session_unset();
	session_destroy();
}
else {
	//Wrong code

	$ml_list = array(
		${FOREACH:SORTED(%mailinglists)[$1$<=>$2$]:'$1$' => '$2$',}
	);

	$ml_list_html = '';
	foreach($ml_list as $ml_id => $ml_address) {
		$ml_list_html .= "<option value=\"$ml_id\" ";
		if ($ml_id == $ml_name) {
			$ml_list_html .= " selected";
		}
		$ml_list_html .= ">$ml_address</option>";
	}

	$action_html = "<input style=\"margin-top:5px; font-size:10px;\" type=\"submit\" name=\"action\" value=\"";
	$action_html .= $_POST['action'];
	$action_html .= "\" />";

	$page_content = <<<ENDHTMLCONTENT
		<form method="post" action="./ml.php">
		      <label for="ml_code">Type the following code to continue:</label><br />
		      <img src="./secimg.php" alt="Code Picture" /><br />
                      <label for="ml_code">Code:</label><input type="text" size="6" name="ml_code" /><br />
                      <label for="name">Email:</label><input type="text" size="12" name="mail" value="$user" /><br />
		      <label for="ml">Mailing List:</label>
		      <select name="ml">
			$ml_list_html
		      </select><br />
		      $action_html
		</form>
ENDHTMLCONTENT;
}

//--------------------
// Format the page
$html_content = <<<ENDHTMLCONTENT
#{PAGE_CONTENT}
ENDHTMLCONTENT;

print $html_content;

?>
