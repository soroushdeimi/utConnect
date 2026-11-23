# Run as Administrator: .\debug.ps1 -> writes debug.txt next to this script
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Please run debug.ps1 as Administrator!" -ForegroundColor Red
    exit 1
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$OutFile   = "$ScriptDir\debug.txt"
$CurlExe   = "$env:SystemRoot\System32\curl.exe"

$cfg = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -ne $null } | Select-Object -First 1
$ip  = ($cfg.IPv4Address | Select-Object -First 1).IPAddress
$gw  = ($cfg.IPv4DefaultGateway | Select-Object -First 1).NextHop
$ifIndex = $cfg.InterfaceIndex

$output = & {
    Write-Output "ip=$ip gw=$gw ifIndex=$ifIndex"
    & route.exe DELETE 80.66.179.8 >$null 2>&1
    if ($gw) {
        & route.exe ADD 80.66.179.8 MASK 255.255.255.255 $gw METRIC 1 IF $ifIndex >$null 2>&1
    }
    $urls = @(
        "http://captive.apple.com/hotspot-detect.html",
        "http://neverssl.com",
        "http://example.com",
        "https://internet.ut.ac.ir/portal",
        "https://internet.ut.ac.ir/login",
        "http://internet.ut.ac.ir/",
        "http://$gw/"
    )
    foreach ($u in $urls) {
        Write-Output ""
        Write-Output "=== $u"
        $res = (& $CurlExe -s -i -m 8 --interface $ip $u 2>$null) -join "`n"
        if ($res.Length -gt 600) { $res = $res.Substring(0, 600) }
        Write-Output $res
    }
    & route.exe DELETE 80.66.179.8 >$null 2>&1
}

$output | Set-Content -Path $OutFile -Encoding UTF8
Write-Host "done: $OutFile" -ForegroundColor Green
