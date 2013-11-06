#!/bin/bash
set -e
set -x

packages="help2man apache2 libapache2-mod-php5 php5-mcrypt curl"

if [ "x$DB" = "xmysql" ]; then
  dbuser=travis
  packages="$packages php5-mysql"

  mysql -u $dbuser -e 'create database ykksm;'
  mysql -u $dbuser ykksm < ykksm-db.sql

  dbrun="mysql -u $dbuser ykksm -e"
elif [ "x$DB" = "xpgsql" ]; then
  dbuser=postgres
  packages="$packages php5-pgsql"

  psql -U $dbuser -c 'create database ykksm;'
  psql -U $dbuser ykksm < ykksm-db.sql

  dbrun="psql -U $dbuser ykksm -c"
else
  echo "unknown DB $DB"
  exit 1
fi

sudo apt-get update -qq
sudo apt-get install -qq -y $packages

git submodule update --init
sudo make install symlink
sudo sh -c "echo 'include_path = "/etc/yubico/ksm:/usr/share/ykksm"' > /etc/php5/conf.d/ykksm.ini"
sudo chmod a+r /usr/share/yubikey-ksm/* /etc/yubico/ksm/*
cat > config-db.php << EOF
<?php
\$dbuser = '$dbuser';
\$dbpass = '';
\$dbname = 'ykksm';
\$dbtype = '$DB';
?>
EOF
sudo mv config-db.php /etc/yubico/ksm/

$dbrun "insert into yubikeys (publicname,internalname,aeskey,serialnr,created,lockcode,creator) values('idkfefrdhtru','609963eae7b5','c68c9df8cbfe7d2f994cb904046c7218',0,0,'','');"

sudo /etc/init.d/apache2 restart

find $HOME/.phpenv

set +e

curl --silent http://localhost/wsapi/decrypt?otp=idkfefrdhtrutjduvtcjbfeuvhehdvjjlbchtlenfgku | grep -q "^OK counter=0001 low=8d40 high=0f use=00"
if [ $? != 0 ]; then
  curl "http://localhost/wsapi/decrypt?otp=idkfefrdhtrutjduvtcjbfeuvhehdvjjlbchtlenfgku"
  sudo tail /var/log/apache2/error.log /var/log/apache2/access.log /var/log/auth.log
  exit 1
else
  echo "Success!"
fi
