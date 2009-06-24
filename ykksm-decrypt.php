<?php

# Written by Simon Josefsson <simon@josefsson.org>.
# Copyright (c) 2009 Yubico AB
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
#   * Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#
#   * Redistributions in binary form must reproduce the above
#     copyright notice, this list of conditions and the following
#     disclaimer in the documentation and/or other materials provided
#     with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

include 'ykksm-config.php';
include 'ykksm-utils.php';

openlog("ykksm", LOG_PID, $logfacility)
  or die("ERR Syslog open error\n");

$otp = $_REQUEST["otp"];
if (!$otp) {
  syslog(LOG_INFO, "No OTP provided");
  die("ERR No OTP provided\n");
 }

if (!preg_match("/^([cbdefghijklnrtuv]{0,16})([cbdefghijklnrtuv]{32})$/",
		$otp, $matches)) {
  syslog(LOG_INFO, "Invalid OTP format: $otp");
  die("ERR Invalid OTP format\n");
 }
$id = $matches[1];
$modhex_ciphertext = $matches[2];

$dbconn = mysql_connect($dbhost, $dbuser, $dbpasswd);
if (!$dbconn) {
  syslog(LOG_ERR, "Database connect error: " . mysql_error());
  die("ERR Database error\n");
 }
$db_selected = mysql_select_db($dbname);
if (!$db_selected) {
  syslog(LOG_ERR, "Database select error: " . mysql_error());
  die("ERR Database error\n");
 }

$sql = "SELECT aesKey, internalName FROM yubikeys " .
       "WHERE publicName = '$id' AND active";
$result = mysql_query($sql);
if (!$result) {
  syslog(LOG_ERR, "Database query error: " . mysql_error());
  die("ERR Database error\n");
 }

if (mysql_num_rows($result) != 1) {
  syslog(LOG_INFO, "Unknown yubikey: " . $otp);
  die("ERR Unknown yubikey\n");
 }

$row = mysql_fetch_assoc($result);
$aesKey = $row['aesKey'];
$internalName = $row['internalName'];

$ciphertext = modhex2hex($modhex_ciphertext);
$plaintext = aes128ecb_decrypt($aesKey, $ciphertext);

$uid = substr($plaintext, 0, 12);
if (strcmp($uid, $internalName) != 0) {
  syslog(LOG_ERR, "UID error: $otp $plaintext: $uid vs $internalName");
  die("ERR Corrupt OTP\n");;
 }

if (!crc_is_good($plaintext)) {
  syslog(LOG_ERR, "CRC error: $otp: $plaintext");
  die("ERR Corrupt OTP\n");
 }

# Mask out interesting fields
$counter = substr($plaintext, 14, 2) . substr($plaintext, 12, 2);
$low = substr($plaintext, 18, 2) . substr($plaintext, 16, 2);
$high = substr($plaintext, 20, 2);
$use = substr($plaintext, 22, 2);

$out = "OK counter=$counter low=$low high=$high use=$use";

syslog(LOG_INFO, "SUCCESS OTP $otp PT $plaintext $out")
  or die("ERR Log error\n");

print "$out\n";

mysql_close()
  or syslog(LOG_ERR, "Database close error (otp $otp): " . mysql_error());

?>
