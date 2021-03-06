#!/bin/sh

CWD=`pwd`

sed -i.orig "s|WORKING_DIR|$CWD|"

echo "Which user does your web server run as?"
read username

chown $username spool templates css

echo "Where do we copy the ledger-smb-httpd.conf file to?"
read location
cp ledgersmb-httpd.conf $location

echo "Please restart your web server for the changes to take effect."
