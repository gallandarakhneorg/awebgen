<?php
$url = $_GET['url'];
$encodedurl = urlencode("$url");
$html_content = <<<ENDHTMLCONTENT
#{PAGE_CONTENT}
ENDHTMLCONTENT;

print $html_content;
?>
