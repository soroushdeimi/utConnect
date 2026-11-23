# Run as Administrator: .\selftest.ps1
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Please run selftest.ps1 as Administrator!" -ForegroundColor Red
    exit 1
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$OutFile   = "$ScriptDir\selftest.txt"
$LogFile   = "C:\ProgramData\utConnect\ut-wifi-login.log"
$LoginScript = "C:\ProgramData\utConnect\ut-wifi-login.ps1"
$CurlExe   = "$env:SystemRoot\System32\curl.exe"

$output = & {
    $ts = Get-Date -Format "HH:mm:ss"
    Write-Output "start $ts"
    $mark = if (Test-Path $LogFile) { (Get-Content $LogFile).Count } else { 0 }

    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $LoginScript --logout
    Start-Sleep -Seconds 4

    $afterLogout = (& $CurlExe -s -m 5 "http://captive.apple.com/hotspot-detect.html" 2>$null) -join "`n"
    if ($afterLogout.Length -gt 120) { $afterLogout = $afterLogout.Substring(0, 120) }
    Write-Output "after logout: $afterLogout"

    Start-ScheduledTask -TaskName "UTConnect-WifiLogin"
    for ($i = 0; $i -lt 12; $i++) {
        Start-Sleep -Seconds 3
        if (Test-Path $LogFile) {
            $newLines = Get-Content $LogFile | Select-Object -Skip $mark
            if ($newLines -match "login ok") { break }
        }
    }

    Write-Output "--- log since start"
    if (Test-Path $LogFile) {
        Get-Content $LogFile | Select-Object -Skip $mark
    }

    $check = (& $CurlExe -s -m 5 "http://captive.apple.com/hotspot-detect.html" 2>$null) -join "`n"
    if ($check -match "Success") {
        Write-Output "RESULT: online"
    } else {
        Write-Output "RESULT: still offline -> forced login"
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $LoginScript --force
        if (Test-Path $LogFile) {
            Get-Content $LogFile -Tail 2
        }
    }
}

$output | Set-Content -Path $OutFile -Encoding UTF8
Write-Host "done: $OutFile" -ForegroundColor Green
