# Run as Administrator: .\uninstall.ps1
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Please run uninstall.ps1 as Administrator!" -ForegroundColor Red
    exit 1
}

Unregister-ScheduledTask -TaskName "UTConnect-WifiLogin" -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName "UTConnect-WifiLogout" -Confirm:$false -ErrorAction SilentlyContinue
Remove-Item -Path "C:\ProgramData\utConnect" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "Removed utConnect, scheduled tasks, and stored credentials." -ForegroundColor Green
