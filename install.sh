#!/usr/bin/sh

# run: sudo install.sh

cp firealarm.rb /etc/init.d/firealarm
chmod +x /etc/init.d/firealarm
update-rc.d firealarm defaults
