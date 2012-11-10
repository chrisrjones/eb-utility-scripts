#!/bin/bash

echo Defaults:root \!requiretty >> /etc/sudoers
sudo -s

cd /home/ec2-user

SERVER_NAME=`uname -n`
SPLUNK_HOME="/opt/splunkforwarder"
SPLUNK_INDEXERS="ec2-75-101-131-33.compute-1.amazonaws.com:9997,ec2-23-21-126-55.compute-1.amazonaws.com:9997"
SPLUNK_DEPLOY_SERVER="ec2-23-21-126-56.compute-1.amazonaws.com:8089"
SPLUNK_ADMIN_USER="admin"
APPLICATION_NAME=`$APPLICATION_NAME`
SPLUNK_ADMIN_PASSWORD="pkT&(,5("
SPLUNK_LICENSE="sscheel@pbs.org;OE8sO6O7QaA7EhGfXr1kfemOcXJEgofk3pEytcv++EsqUfO43IYFPK6qwX5QI0GVsPNOw6mu3BjcBtzsn10supQOojSGZrQXxCStRDbRlutwEzDl/TUK00PuHcx446G7vjYmyNWv3oeHR3VijeE5AI7tomWqCp9NvtH7p+rF+ePupcAtBBBxYvMeZEsHJdVSNyK+EXL5nUkIwJctzHsfGYYW8wgCdROYJdroQ+F2bqCVrTpAPqqrN3zLPA2jxgugWwhAILb+jayu1p2s2tAHjfwIHO4AROEBSe52GxXzeJavFYFXUScc2w7wTNx5qSb4KZ+IDqOdfuRUiUUNuLC/9A=="

# dump environmental variables
echo "Dump environmental variables"
echo env

# Skip if no Splunk receiver is specified
if [ -z "$SPLUNK_INDEXERS" ]; then
  echo "No Splunk receiver is specified (SPLUNK_INDEXERS is empty). Skipping Splunk install."
  logger -t RightScale "No Splunk receiver is specified (SPLUNK_INDEXERS is empty). Skipping Splunk install."
  exit 0 # Leave with a smile ...
fi

#
# Set default values
#
if [ -z "$SPLUNK_HOME" ]; then
	SPLUNK_HOME=/opt/splunkforwarder
    echo $SPLUNK_HOME
fi

# uninstall existing new universal forwarder
if [ -d $SPLUNK_HOME ] ; then
     echo "Existing installation detected at $SPLUNK_HOME...removing..."
     killall splunkd
     rm -rf $SPLUNK_HOME
     userdel -f splunk
     rm -rf /home/splunk
fi

# uninstall existing old style forwarder
if [ -d /opt/splunk ] ; then
     echo "Existing installation detected at /opt/splunk...removing..."
     killall splunkd
     rm -rf /opt/splunk
     userdel -f splunk
     rm -rf /home/splunk
fi
set -e

echo "Installing Splunk server software in $SPLUNK_HOME"
arch=`uname -m`
conf_dir=$SPLUNK_HOME/etc/system/local
cert_path=$SPLUNK_HOME/etc/auth

#echo "Creating user: splunk"
useradd splunk

echo "Installing Splunk"
wget https://s3.amazonaws.com/pbs.sourcerepository/splunkforwarder-5.0-140868-Linux-i686.tgz -O splunkforwarder.tgz
tar -xf splunkforwarder.tgz
mv splunkforwarder /opt/

# Set admin user creds
echo "Setting one time admin credentials..."

cat<<EOF > $conf_dir/user-seed.conf
[user_info]
USERNAME = $SPLUNK_ADMIN_USER
PASSWORD = $SPLUNK_ADMIN_PASSWORD
EOF

echo "Installing license..."
echo "$SPLUNK_LICENSE" > $SPLUNK_HOME/etc/splunk.license

echo "Configuring outputs.conf"

cat<<EOF > $conf_dir/outputs.conf
[tcpout:default]
server=$SPLUNK_INDEXERS
sslCertPath=$cert_path/server.pem
sslPassword=password
sslRootCAPath=$cert_path/cacert.pem
sslVerifyServerCert=true
sslCommonNameToCheck=SplunkServerDefaultCert
altCommonNameToCheck=SplunkAltName
EOF

echo "Configuring props.conf"

cat<<EOF > $conf_dir/props.conf
[source::/var/log/httpd/access_log]
sourcetype = $APPLICATION_NAME
EOF

echo "Starting Splunk"
echo $SPLUNK_HOME
$SPLUNK_HOME/bin/splunk start splunkd --accept-license

echo "Start at reboot"
$SPLUNK_HOME/bin/splunk enable boot-start

echo "Configure to be deploy client"
/opt/splunkforwarder/bin/splunk set deploy-poll $SPLUNK_DEPLOY_SERVER -auth $SPLUNK_ADMIN_USER:$SPLUNK_ADMIN_PASSWORD

echo "Configuring inputs.conf"
echo "Setting inputs.conf host name to $SERVER_NAME"
sed -i -e "s/^host =.*$/host = $SERVER_NAME/" $SPLUNK_HOME/etc/system/local/inputs.conf

echo "Splunk restarting one last time"
$SPLUNK_HOME/bin/splunk restart splunkd

echo "Splunk installation completed"
touch $SPLUNK_HOME/.installed