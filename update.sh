#!/bin/bash
# sudo ./update.sh  -> re-installs scripts/daemons, keeps the saved credentials
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
[ -f /usr/local/etc/ut-wifi-login/credentials ] || { echo "no credentials yet: run install.sh"; exit 1; }
install -m 755 -o root -g wheel ut-wifi-login ut-wifi-logout-on-exit /usr/local/libexec/
install -m 644 -o root -g wheel com.utconnect.ut-wifi-login.plist com.utconnect.ut-wifi-logout.plist /Library/LaunchDaemons/
load ut-wifi-login
load ut-wifi-logout
echo updated
