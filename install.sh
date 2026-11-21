#!/bin/bash
# Run:  sudo ./install.sh      (asks for your UT username/password; nothing is echoed or logged)
set -e
load() {  # bootout is async (the logout daemon sends a logout on SIGTERM first):
  # wait until the old job is really gone, then retry bootstrap
  launchctl bootout system/com.utconnect.$1 2>/dev/null || true
  for _ in $(seq 1 20); do
    launchctl print system/com.utconnect.$1 >/dev/null 2>&1 || break
    sleep 1
  done
  for _ in 1 2 3 4 5; do
    launchctl bootstrap system /Library/LaunchDaemons/com.utconnect.$1.plist 2>/dev/null && return 0
    sleep 1
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
if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != root ]; then   # let this user run the login script without a password
  printf '%s ALL=(root) NOPASSWD: /usr/local/libexec/ut-wifi-login\n' "$SUDO_USER" > /etc/sudoers.d/ut-wifi-login.tmp
  chmod 440 /etc/sudoers.d/ut-wifi-login.tmp
  if visudo -cf /etc/sudoers.d/ut-wifi-login.tmp >/dev/null; then mv /etc/sudoers.d/ut-wifi-login.tmp /etc/sudoers.d/ut-wifi-login; else rm -f /etc/sudoers.d/ut-wifi-login.tmp; echo "sudoers rule skipped"; fi
fi
load ut-wifi-login
load ut-wifi-logout
echo "installed. test: sudo /usr/local/libexec/ut-wifi-login --force ; tail /var/log/ut-wifi-login.log"
