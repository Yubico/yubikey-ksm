<?php
//ykksm will use the configuration stored in /etc/yubico/ksm/config-db.php, if that file exists. If it does not exist, the below values will be used.

if(!include '/etc/yubico/ksm/config-db.php') {
	$dbuser='ykksmreader';
	$dbpass='yourpassword';
	$basepath='';
	$dbname='ykksm';
	$dbserver='';
	$dbport='';
	$dbtype='mysql';
}

$db_dsn      = "$dbtype:dbname=$dbname;host=127.0.0.1";
$db_username = $dbuser;
$db_password = $dbpass;
$db_options  = array();
$logfacility = LOG_AUTH;
?>
