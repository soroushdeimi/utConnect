#!/bin/bash
# sudo ./debug.sh  -> writes debug.txt next to this script (no credentials involved)
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
cd "$(dirname "$0")"; out=debug.txt
gw=$(ipconfig getoption en0 router)
{
echo "ip=$(ipconfig getifaddr en0) gw=$gw"
route -n delete -host 80.66.179.8 >/dev/null 2>&1; route -n add -host 80.66.179.8 "$gw"
for u in http://captive.apple.com/hotspot-detect.html http://neverssl.com http://example.com https://internet.ut.ac.ir/portal https://internet.ut.ac.ir/login http://internet.ut.ac.ir/ http://$gw/; do
  echo; echo "=== $u"
  curl -s -i -m 8 --interface en0 "$u" | head -c 600
done
route -n delete -host 80.66.179.8 >/dev/null 2>&1
} > "$out" 2>&1
chown "$SUDO_USER" "$out"; echo "done: $out"
