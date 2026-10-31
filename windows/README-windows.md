# utConnect for Windows

Auto-login to the University of Tehran (UT) Wi-Fi captive portal (FortiGate) on Windows, and auto-logout on shutdown/restart/sleep.

- **Zero background polling:** Uses Windows Task Scheduler Event Triggers (`Microsoft-Windows-NetworkProfile/Operational` Event ID `10000` and `WLAN-AutoConfig` Event ID `8001`) so it runs *only* when your network state changes.
- **Smart detection:** Only acts when the gateway's captive-portal redirect points to `internet.ut.ac.ir`. On any other Wi-Fi network it exits immediately.
- **VPN-proof:** Temporarily routes portal traffic (`80.66.179.8`) directly over the Wi-Fi gateway so active VPN/TUN clients don't swallow the portal handshake.
- **Session-limit recovery:** If login fails with a concurrent device/session limit error, it automatically logs out stale sessions once and retries.
- **Full logging:** Writes activity logs to `C:\ProgramData\utConnect\ut-wifi-login.log`.

## Install

Right-click **`install.bat`** and select **Run as administrator** (or run `.\install.ps1` inside an Administrator PowerShell window).

It will interactively prompt for your UT username and password (nothing is echoed to the screen). Credentials are saved to `C:\ProgramData\utConnect\credentials` with strict NTFS ACL permissions (`SYSTEM` and `Administrators` only).

## Test / Force Login

Right-click **`selftest.bat`** and select **Run as administrator**, or run manually in an Administrator PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File C:\ProgramData\utConnect\ut-wifi-login.ps1 --force
Get-Content C:\ProgramData\utConnect\ut-wifi-login.log -Tail 10
```

## Uninstall

Right-click **`uninstall.bat`** and select **Run as administrator**.
