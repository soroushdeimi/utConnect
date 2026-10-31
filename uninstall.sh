#!/bin/bash
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
launchctl bootout system/com.utconnect.ut-wifi-login 2>/dev/null
launchctl bootout system/com.utconnect.ut-wifi-logout 2>/dev/null
rm -f /Library/LaunchDaemons/com.utconnect.ut-wifi-login.plist /Library/LaunchDaemons/com.utconnect.ut-wifi-logout.plist /usr/local/libexec/ut-wifi-login /usr/local/libexec/ut-wifi-logout-on-exit
rm -rf /usr/local/etc/ut-wifi-login /var/log/ut-wifi-login.log
echo removed
