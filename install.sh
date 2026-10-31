#!/bin/bash
# Run:  sudo ./install.sh      (asks for your UT username/password; nothing is echoed or logged)
set -e
load() {  # bootout is async; wait for it, then retry bootstrap
  launchctl bootout system/com.utconnect.$1 2>/dev/null || true
  for _ in 1 2 3 4 5; do
    sleep 1
    launchctl bootstrap system /Library/LaunchDaemons/com.utconnect.$1.plist 2>/dev/null && return 0
  done
  launchctl bootstrap system /Library/LaunchDaemons/com.utconnect.$1.plist
}
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
cd "$(dirname "$0")"
read -r -p "UT username: " u
read -r -s -p "UT password: " p; echo
mkdir -p /usr/local/libexec /usr/local/etc/ut-wifi-login
install -m 755 -o root -g wheel ut-wifi-login /usr/local/libexec/ut-wifi-login
umask 077
printf '%s\n%s\n' "$u" "$p" > /usr/local/etc/ut-wifi-login/credentials
chown root:wheel /usr/local/etc/ut-wifi-login/credentials; chmod 600 /usr/local/etc/ut-wifi-login/credentials
install -m 755 -o root -g wheel ut-wifi-logout-on-exit /usr/local/libexec/ut-wifi-logout-on-exit
install -m 644 -o root -g wheel com.utconnect.ut-wifi-login.plist com.utconnect.ut-wifi-logout.plist /Library/LaunchDaemons/
load ut-wifi-login
load ut-wifi-logout
echo "installed. test: sudo /usr/local/libexec/ut-wifi-login --force ; tail /var/log/ut-wifi-login.log"
