#!/bin/bash
#title           :teamcity-install.sh
#description     :The script to install TeamCity 9.x
#more            :https://confluence.jetbrains.com/display/TCD9/Installing+and+Configuring+the+TeamCity+Server
#author	         :Tomas Pecserke
#date            :2016-05-03T14:43+0100
#usage           :/bin/bash teamcity-install.sh
#tested-version  :9.1.6
#tested-distros  :Ubuntu 16.04

TEAMCITY_VERSION=9.1.6
TEAMCITY_FILENAME=TeamCity-$TEAMCITY_VERSION
TEAMCITY_ARCHIVE_NAME=$TEAMCITY_FILENAME.tar.gz
TEAMCITY_DOWNLOAD_ADDRESS=https://download.jetbrains.com/teamcity/$TEAMCITY_ARCHIVE_NAME

INSTALL_DIR=/opt
TEAMCITY_DIR=$INSTALL_DIR/teamcity

TEAMCITY_USER="teamcity"
TEAMCITY_GROUP="teamcity"
TEAMCITY_SERVICE="teamcity"

TEAMCITY_SERVICE_STARTUP_TIMEOUT=240
TEAMCITY_SERVICE_SHUTDOWN_TIMEOUT=30

if [ $EUID -ne 0 ]; then
  echo "This script must be run as root."
  exit 1
fi

if [ ! -x /bin/systemctl ]; then
  echo "Systemd not found. This script uses systemd service to manage TeamCity."
  exit 1
fi

if [ $(java -version 2>&1 | head -n 1 | grep 1.8 -c) -ne 1 ]; then
  echo "Java 1.8 is required."
  exit 1
fi

echo "Downloading: $TEAMCITY_DOWNLOAD_ADDRESS..."
cd /tmp
if [ -e "$TEAMCITY_ARCHIVE_NAME" ]; then
  echo 'TeamCity archive already exists.'
else
  curl -L -O $TEAMCITY_DOWNLOAD_ADDRESS
  if [ $? -ne 0 ]; then
    echo "Not possible to download TeamCity."
    exit 1
  fi
fi

echo "Creating user and group..."
getent group $TEAMCITY_GROUP > /dev/null || \
  groupadd $TEAMCITY_GROUP
getent passwd $TEAMCITY_USER > /dev/null || \
  useradd -s /bin/false -g $TEAMCITY_GROUP -d $INSTALL_DIR $TEAMCITY_USER

echo "Installation..."
mkdir $TEAMCITY_DIR -p
tar -xzf $TEAMCITY_ARCHIVE_NAME -C $TEAMCITY_DIR --strip-components=1
chown -R $TEAMCITY_USER:$TEAMCITY_GROUP $TEAMCITY_DIR
chown -R $TEAMCITY_USER:$TEAMCITY_GROUP $TEAMCITY_DIR/

echo "Registering service..."
cat > /etc/systemd/system/$TEAMCITY_SERVICE.service << "EOF"
[Unit]
Description=TeamCity continuous integration and deployment server
After=network.target

[Service]
Type=forking

ExecStart=$TEAMCITY_DIR/bin/runAll.sh start
ExecStop=$TEAMCITY_DIR/bin/runAll.sh stop

User=$TEAMCITY_USER
Group=$TEAMCITY_GROUP

[Install]
WantedBy=multi-user.target
EOF

sed -i -e 's,$TEAMCITY_DIR,'$TEAMCITY_DIR',g' /etc/systemd/system/$TEAMCITY_SERVICE.service
sed -i -e 's,$TEAMCITY_USER,'$TEAMCITY_USER',g' /etc/systemd/system/$TEAMCITY_SERVICE.service
sed -i -e 's,$TEAMCITY_GROUP,'$TEAMCITY_GROUP',g' /etc/systemd/system/$TEAMCITY_SERVICE.service

systemctl daemon-reload
systemctl enable $TEAMCITY_SERVICE

echo "Starting service..."
systemctl start $TEAMCITY_SERVICE
