#!/bin/sh
# run: sudo install-daemon.sh
cp init.d/firealarm /etc/init.d/firealarm
chmod +x /etc/init.d/firealarm
update-rc.d firealarm defaults
