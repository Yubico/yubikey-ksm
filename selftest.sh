#!/bin/bash
set -e
set -x

if [ "x$DB" = "xmysql" ]; then
  dbuser=travis

  mysql -u $dbuser -e 'create database ykksm;'
  mysql -u $dbuser ykksm < ykksm-db.sql

  dbrun="mysql -u $dbuser ykksm -e"
elif [ "x$DB" = "xpgsql" ]; then
  dbuser=postgres

  psql -U $dbuser -c 'create database ykksm;'
  psql -U $dbuser ykksm < ykksm-db.sql

  dbrun="psql -U $dbuser ykksm -c"
elif [ "x$DB" = "xsqlite" ]; then
  dbuser=""

  dbfile=`mktemp`
  sqlite3 $dbfile < ykksm-db.sql
  sed -i "s,^.*db_dsn.*$,\$db_dsn = \"sqlite:$dbfile\";," ykksm-config.php

  dbrun="sqlite3 $dbfile"
else
  echo "unknown DB $DB"
  exit 1
fi

cat > config-db.php << EOF
<?php
\$dbuser = '$dbuser';
\$dbpass = '';
\$dbname = 'ykksm';
\$dbtype = '$DB';
?>
EOF
sudo mkdir -p /etc/yubico/ksm/
sudo chmod 0755 /etc/yubico/ksm/
sudo mv config-db.php /etc/yubico/ksm/

$dbrun "insert into yubikeys (publicname,internalname,aeskey,serialnr,created,lockcode,creator) values('idkfefrdhtru','609963eae7b5','c68c9df8cbfe7d2f994cb904046c7218',0,0,'','');"

set +e

echo '' | php -B "\$_REQUEST = array('otp' => 'idkfefrdhtrutjduvtcjbfeuvhehdvjjlbchtlenfgku');" -F ykksm-decrypt.php | grep -q "^OK counter=0001 low=8d40 high=0f use=00"
if [ $? != 0 ]; then
  echo '' | php -B "\$_REQUEST = array('otp' => 'idkfefrdhtrutjduvtcjbfeuvhehdvjjlbchtlenfgku');" -F ykksm-decrypt.php
  sudo tail /var/log/auth.log
  exit 1
else
  echo "Success 1"
fi

echo '' | php -B "\$_REQUEST = array('otp' => 'idkfefrdhtrutjduvtcjbfeuvhehdvjjlbchtlenfgkv');" -F ykksm-decrypt.php | grep -q "^ERR Corrupt OTP"
if [ $? != 0 ]; then
  echo '' | php -B "\$_REQUEST = array('otp' => 'idkfefrdhtrutjduvtcjbfeuvhehdvjjlbchtlenfgkv');" -F ykksm-decrypt.php
  sudo tail /var/log/auth.log
  exit 1
else
  echo "Success 2"
fi

echo '' | php -B "\$_REQUEST = array('otp' => 'cdkfefrdhtrutjduvtcjbfeuvhehdvjjlbchtlenfgkv');" -F ykksm-decrypt.php | grep -q "^ERR Unknown yubikey"
if [ $? != 0 ]; then
  echo '' | php -B "\$_REQUEST = array('otp' => 'cdkfefrdhtrutjduvtcjbfeuvhehdvjjlbchtlenfgkv');" -F ykksm-decrypt.php
  sudo tail /var/log/auth.log
  exit 1
else
  echo "Success 3"
fi

echo '' | php -B "\$_REQUEST = array('otp' => 'idkfefrdhtrutjduvtcjbfeuvhehdvjjlbchtlenfgku'); \$_SERVER = array('HTTP_ACCEPT' => 'application/json');" -F ykksm-decrypt.php | grep -q '^{"counter":"0001","low":"8d40","high":"0f","use":"00"}'
if [ $? != 0 ]; then
  echo '' | php -B "\$_REQUEST = array('otp' => 'idkfefrdhtrutjduvtcjbfeuvhehdvjjlbchtlenfgku'); \$_SERVER = array('HTTP_ACCEPT' => 'application/json');" -F ykksm-decrypt.php
  sudo tail /var/log/auth.log
  exit 1
else
  echo "Success 4"
fi

echo '' | php -B "\$_REQUEST = array('otp' => 'idkfefrdhtrutjduvtcjbfeuvhehdvjjlbchtlenfgkv'); \$_SERVER = array('HTTP_ACCEPT' => 'application/json');" -F ykksm-decrypt.php | grep -q '^{"status":"ERR Corrupt OTP"}'
if [ $? != 0 ]; then
  echo '' | php -B "\$_REQUEST = array('otp' => 'idkfefrdhtrutjduvtcjbfeuvhehdvjjlbchtlenfgkv'); \$_SERVER = array('HTTP_ACCEPT' => 'application/json');" -F ykksm-decrypt.php
  sudo tail /var/log/auth.log
  exit 1
else
  echo "Success 5"
fi

echo '' | php -B "\$_REQUEST = array('otp' => 'cdkfefrdhtrutjduvtcjbfeuvhehdvjjlbchtlenfgkv'); \$_SERVER = array('HTTP_ACCEPT' => 'application/json');" -F ykksm-decrypt.php | grep -q '^{"status":"ERR Unknown yubikey"}'
if [ $? != 0 ]; then
  echo '' | php -B "\$_REQUEST = array('otp' => 'cdkfefrdhtrutjduvtcjbfeuvhehdvjjlbchtlenfgkv'); \$_SERVER = array('HTTP_ACCEPT' => 'application/json');" -F ykksm-decrypt.php
  sudo tail /var/log/auth.log
  exit 1
else
  echo "Success 6"
fi

sudo mv /etc/yubico/ksm/config-db.php /etc/yubico/ksm/config-db.php.moved
sed -i "s,^.*db_dsn.*$,\$db_dsn      = \"$dbtype:dbname=$dbname;host=127.0.0.1\";," ykksm-config.php
echo '' | php -B "\$_REQUEST = array('otp' => 'idkfefrdhtrutjduvtcjbfeuvhehdvjjlbchtlenfgku');" -F ykksm-decrypt.php | grep -q "^ERR Database error"
if [ $? != 0 ]; then
  echo '' | php -B "\$_REQUEST = array('otp' => 'idkfefrdhtrutjduvtcjbfeuvhehdvjjlbchtlenfgku');" -F ykksm-decrypt.php
  sudo tail /var/log/auth.log
  exit 1
else
  echo "Success 7"
fi

echo '' | php -B "\$_REQUEST = array('otp' => 'cdkfefrdhtrutjduvtcjbfeuvhehdvjjlbchtlenfgkv'); \$_SERVER = array('HTTP_ACCEPT' => 'application/json');" -F ykksm-decrypt.php | grep -q '^{"status":"ERR Database error"}'
if [ $? != 0 ]; then
  echo '' | php -B "\$_REQUEST = array('otp' => 'cdkfefrdhtrutjduvtcjbfeuvhehdvjjlbchtlenfgkv'); \$_SERVER = array('HTTP_ACCEPT' => 'application/json');" -F ykksm-decrypt.php
  sudo tail /var/log/auth.log
  exit 1
else
  echo "Success 8"
fi
sudo mv /etc/yubico/ksm/config-db.php.moved /etc/yubico/ksm/config-db.php
sed -i "s,^.*db_dsn.*$,\$db_dsn = \"sqlite:$dbfile\";," ykksm-config.php
