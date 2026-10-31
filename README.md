# utConnect

Auto-login to the University of Tehran (UT) Wi-Fi captive portal (FortiGate),
and auto-logout on shutdown/restart. macOS and Windows.

- Runs from `launchd` only when the network actually changes (or the machine shuts
  down) — no background polling, no idle CPU/RAM use.
- Only acts when the gateway's captive-portal redirect actually points at
  `internet.ut.ac.ir`. On any other Wi-Fi it does nothing.
- Routes portal traffic directly over Wi-Fi, so it works even if a VPN/tunnel app
  is running and would otherwise swallow the connection.
- If login fails with a "too many devices / sessions" style error, it logs itself
  out of the account's other sessions once and retries.
- Everything it does is written to `/var/log/ut-wifi-login.log`.

## macOS

### Install

```bash
git clone https://github.com/soroushdeimi/utConnect
cd utConnect
sudo ./install.sh
```

`install.sh` will ask for your UT username and password interactively
(nothing is echoed to the screen, nothing is printed to any log). They're
stored only in `/usr/local/etc/ut-wifi-login/credentials`, readable only by
root (`chmod 600`), and are never committed to this repo or sent anywhere
except the university's own login form at `internet.ut.ac.ir`.

To change the saved username/password later, just run `sudo ./install.sh`
again — it overwrites the credentials file.

### Update (after pulling new changes, keeps existing credentials)

```bash
git pull
sudo ./update.sh
```

### Test

```bash
sudo ./selftest.sh
```

Logs out, triggers the same network-change event the daemon listens for, waits
for it to log back in on its own, and reports the result. Falls back to a
forced login at the end so you're never left offline. Output goes to
`selftest.txt` (git-ignored — it can contain your current local IP).

### Uninstall

```bash
sudo ./uninstall.sh
```

Removes both launchd daemons, the scripts, and the stored credentials.

## Windows

> Community-contributed port. The logic mirrors the macOS script exactly
> (same portal-detection, login and retry behavior), but — unlike the macOS
> version above — it hasn't been run end-to-end on a real Windows machine yet.
> Run `selftest.bat` after installing and check the log before relying on it.

### Install

Open PowerShell or Command Prompt in the `windows` folder and run as
**Administrator** (right-click → *Run as administrator*):

```bat
git clone https://github.com/soroushdeimi/utConnect
cd utConnect\windows
install.bat
```

It will ask for your UT username and password interactively (nothing is
echoed to the screen). They're stored in `C:\ProgramData\utConnect\credentials`,
locked down via `icacls` to `SYSTEM` and `Administrators` only, and are never
committed to this repo or sent anywhere except `internet.ut.ac.ir`.

This also registers two scheduled tasks (Task Scheduler, running as `SYSTEM`):
one that logs in on network-connect events, and one that logs out on
shutdown/restart **and sleep**.

To change the saved username/password later, just run `install.bat` again.

### Update (after pulling new changes, keeps existing credentials)

```bat
git pull
update.bat
```

### Test

Run as **Administrator**:

```bat
selftest.bat
```

Same idea as the macOS test: logs out, kicks the login task, waits for it to
log back in, and reports the result. Output goes to `selftest.txt`, and the
full log is at `C:\ProgramData\utConnect\ut-wifi-login.log`.

### Uninstall

Run as **Administrator**:

```bat
uninstall.bat
```

Removes both scheduled tasks, the scripts, and the stored credentials.

See [`windows/README-windows.md`](windows/README-windows.md) for more detail.

## How it works

The portal is a FortiGate captive portal. While unauthenticated, any plain
HTTP request gets back a JavaScript redirect to `/fgtauth?<token>`, which
leads to a login form with hidden `magic` and `4Tredir` fields. The script
fetches that form, extracts those fields, and submits `username`/`password`
along with them as a normal POST — the same request your browser would send.

On macOS, two `launchd` jobs do this:

- `com.utconnect.ut-wifi-login` — triggered by `com.apple.system.config.network_change`;
  waits for an IP, checks whether the portal still thinks you're authenticated,
  and logs in if not.
- `com.utconnect.ut-wifi-logout` — an idle process that only exists to catch
  `SIGTERM` on shutdown and send a logout request first.

On Windows, two Task Scheduler tasks do the equivalent: one triggered by
network-connect events (`NetworkProfile`/`WLAN-AutoConfig` event logs) plus
logon, the other by shutdown/restart and sleep events, both running as
`SYSTEM`.

## Scope

Only logs into UT's own portal with your own account, the same way your browser
does manually. It doesn't bypass or work around authentication in any way.

## Note if you already installed an earlier version

Earlier test builds used the label `com.sush.*` instead of `com.utconnect.*`.
Before installing this version, remove the old one:

```bash
sudo launchctl bootout system/com.sush.ut-wifi-login 2>/dev/null
sudo launchctl bootout system/com.sush.ut-wifi-logout 2>/dev/null
sudo rm -f /Library/LaunchDaemons/com.sush.ut-wifi-login.plist /Library/LaunchDaemons/com.sush.ut-wifi-logout.plist
```
