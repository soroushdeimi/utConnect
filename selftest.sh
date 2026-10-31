#!/bin/bash
# sudo ./selftest.sh -> logs out, posts the real network-change event, waits, writes selftest.txt.
# Never leaves you offline: if the daemon did not log in, it runs one forced login at the end.
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
cd "$(dirname "$0")"; out=selftest.txt; L=/var/log/ut-wifi-login.log
{
echo "start $(date +%T)  ip=$(ipconfig getifaddr en0)"
runs0=$(launchctl print system/com.utconnect.ut-wifi-login | awk '/runs =/{print $3}')
mark=$(wc -l < "$L" 2>/dev/null || echo 0)
/usr/local/libexec/ut-wifi-login --logout; sleep 4
echo "after logout: $(curl -s -m 5 --interface en0 http://captive.apple.com/hotspot-detect.html | head -c 120)"
notifyutil -p com.apple.system.config.network_change
for i in $(seq 1 12); do sleep 3; tail -n +$((mark+2)) "$L" | grep -q 'login ok' && break; done
echo "daemon runs: $runs0 -> $(launchctl print system/com.utconnect.ut-wifi-login | awk '/runs =/{print $3}')"
echo "--- log since start"; tail -n +$((mark+1)) "$L"
if curl -s -m 5 --interface en0 http://captive.apple.com/hotspot-detect.html | grep -q Success; then echo "RESULT: online"; else
  echo "RESULT: still offline -> forced login"; /usr/local/libexec/ut-wifi-login --force; tail -n 2 "$L"; fi
} > "$out" 2>&1
chown "$SUDO_USER" "$out"; echo "done: $out"
