# Auto-login to the University of Tehran Wi-Fi captive portal (FortiGate) on Windows.
# Runs as SYSTEM from Task Scheduler on network events.
# Usage: powershell.exe -ExecutionPolicy Bypass -File ut-wifi-login.ps1 [--force | --logout]

param(
    [string]$Mode = ""
)

$PortalHost = "internet.ut.ac.ir"
$PortalIP   = "80.66.179.8"
$ProbeUrl   = "http://captive.apple.com/hotspot-detect.html"
$BaseDir    = "C:\ProgramData\utConnect"
$CredFile   = "$BaseDir\credentials"
$LogFile    = "$BaseDir\ut-wifi-login.log"
$LockDir    = "$BaseDir\ut-wifi-login.lock"
$StateFile  = "$BaseDir\ut-wifi-login.state"
$CurlExe    = "$env:SystemRoot\System32\curl.exe"

if (-not (Test-Path $BaseDir)) {
    New-Item -ItemType Directory -Path $BaseDir -Force | Out-Null
}

function Write-Log {
    param([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "$ts $Message" -Encoding UTF8
}

# Clean stale lock if older than 2 minutes
if (Test-Path $LockDir) {
    $lockAge = (Get-Date) - (Get-Item $LockDir).CreationTime
    if ($lockAge.TotalSeconds -gt 120) {
        Remove-Item -Path $LockDir -Recurse -Force -ErrorAction SilentlyContinue
    } else {
        exit 0
    }
}

try {
    New-Item -ItemType Directory -Path $LockDir -ErrorAction Stop | Out-Null
} catch {
    exit 0
}

function Get-WifiNetInfo {
    $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object {
        $_.Status -eq 'Up' -and (
            $_.InterfaceDescription -match 'Wi-Fi|Wireless|802\.11|WLAN' -or
            $_.Name -match 'Wi-Fi|Wireless|WLAN' -or
            $_.MediaType -eq 'Native 802.11'
        )
    }
    if (-not $adapters) {
        $adapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' }
    }
    foreach ($adapter in $adapters) {
        $cfg = Get-NetIPConfiguration -InterfaceIndex $adapter.ifIndex -ErrorAction SilentlyContinue
        $ip  = ($cfg.IPv4Address | Where-Object { $_.IPAddress -and $_.IPAddress -notlike '169.254.*' } | Select-Object -First 1).IPAddress
        $gw  = ($cfg.IPv4DefaultGateway | Select-Object -First 1).NextHop
        if ($ip) {
            return @{
                IP      = $ip
                GW      = $gw
                IfIndex = $adapter.ifIndex
                Name    = $adapter.Name
            }
        }
    }
    return $null
}

function Set-PortalRoute {
    param([string]$Gw, [int]$IfIndex)
    & route.exe DELETE $PortalIP >$null 2>&1
    if ($Gw -and $IfIndex) {
        & route.exe ADD $PortalIP MASK 255.255.255.255 $Gw METRIC 1 IF $IfIndex >$null 2>&1
    }
}

function Invoke-PortalCurl {
    param(
        [string]$LocalIP,
        [int]$Timeout = 8,
        [string[]]$ExtraArgs,
        [string]$StdinData = $null
    )
    $baseArgs = @("-s", "-m", "$Timeout", "--interface", $LocalIP, "--resolve", "${PortalHost}:443:${PortalIP}") + $ExtraArgs
    if ($null -ne $StdinData) {
        return ($StdinData | & $CurlExe @baseArgs 2>$null) -join "`n"
    } else {
        return (& $CurlExe @baseArgs 2>$null) -join "`n"
    }
}

function Invoke-Probe {
    param([string]$LocalIP)
    return (& $CurlExe -s -m 6 --interface $LocalIP -w "|CURLOK" $ProbeUrl 2>$null) -join "`n"
}

function Save-State {
    param([string]$IP, [string]$GW, [string]$Status)
    $unixEpoch = [DateTime]::Parse("1/1/1970").ToUniversalTime()
    $epoch = [int]((Get-Date).ToUniversalTime() - $unixEpoch).TotalSeconds
    Set-Content -Path $StateFile -Value "$IP $GW $epoch $Status" -Encoding ASCII
}

function Show-FailureNotification {
    param([string]$Text)
    try {
        & msg.exe * /TIME:10 "UT Wi-Fi: $Text" >$null 2>&1
    } catch {}
}

try {
    $tries = if ($Mode -eq "--logout") { 1 } else { 25 }
    $net = $null
    for ($i = 0; $i -lt $tries; $i++) {
        $net = Get-WifiNetInfo
        if ($net -and $net.IP) { break }
        Start-Sleep -Seconds 1
    }

    if (-not $net -or -not $net.IP) { exit 0 }
    $ip = $net.IP
    $gw = $net.GW
    $ifIndex = $net.IfIndex

    if (-not $gw) {
        Write-Log "$ip has no router yet"
        exit 0
    }

    # Debounce duplicate runs on an already-settled state
    if ([string]::IsNullOrEmpty($Mode) -and (Test-Path $StateFile)) {
        $rawState = (Get-Content $StateFile -Raw -ErrorAction SilentlyContinue).Trim()
        $parts = $rawState -split '\s+'
        if ($parts.Count -ge 4) {
            $s_ip = $parts[0]
            $s_gw = $parts[1]
            $s_t  = [int]$parts[2]
            $s_r  = $parts[3]
            $unixEpoch = [DateTime]::Parse("1/1/1970").ToUniversalTime()
            $nowEpoch = [int]((Get-Date).ToUniversalTime() - $unixEpoch).TotalSeconds
            $age = $nowEpoch - $s_t
            if ("$s_ip $s_gw" -eq "$ip $gw") {
                if (($s_r -eq "ok" -and $age -lt 20) -or ($s_r -eq "fail" -and $age -lt 30)) {
                    exit 0
                }
            }
        }
    }

    if ($Mode -eq "--logout") {
        Set-PortalRoute -Gw $gw -IfIndex $ifIndex
        $code = Invoke-PortalCurl -LocalIP $ip -Timeout 4 -ExtraArgs @("-o", "NUL", "-w", "%{http_code}", "https://$PortalHost/logout?")
        Write-Log "logout ($ip): http $code"
        Remove-Item -Path $StateFile -Force -ErrorAction SilentlyContinue
        exit 0
    }

    # Probe captive portal (up to 10 tries, handling roaming mid-run)
    $ok = $false
    $p = ""
    for ($i = 0; $i -lt 10; $i++) {
        $curNet = Get-WifiNetInfo
        $curIp = if ($curNet) { $curNet.IP } else { $null }
        if ($curIp -ne $ip) {
            if (-not $curIp) {
                Write-Log "lost Wi-Fi mid-run (had $ip)"
                Save-State -IP $ip -GW $gw -Status "fail"
                exit 0
            }
            Write-Log "roamed $ip -> $curIp"
            $ip = $curIp
            $gw = $curNet.GW
            $ifIndex = $curNet.IfIndex
            if (-not $gw) { Start-Sleep -Seconds 1; continue }
        }
        $p = Invoke-Probe -LocalIP $ip
        if ($p -like "*|CURLOK") {
            if ($p -match "Success|window\.location") {
                $ok = $true
                break
            }
        } else {
            $p = ""
        }
        Start-Sleep -Seconds 2
    }

    $p = $p -replace '\|CURLOK$', ''
    if ($Mode -ne "--force" -and $p -match "Success") {
        Write-Log "online ($ip via $gw): nothing to do"
        Save-State -IP $ip -GW $gw -Status "ok"
        exit 0
    }
    if ([string]::IsNullOrEmpty($p)) {
        Write-Log "no reply from $ip via $gw after 10 tries (network still settling or down)"
        Save-State -IP $ip -GW $gw -Status "fail"
        exit 0
    }

    $url = ""
    if ($p -match "window\.location=[`"']([^`"']+)[`"']") {
        $url = $Matches[1]
    }
    if (-not $url.StartsWith("https://$PortalHost")) {
        $snippet = ($p -replace '[\r\n]+', ' ')
        if ($snippet.Length -gt 160) { $snippet = $snippet.Substring(0, 160) }
        Write-Log "no UT portal on $ip via $gw; raw reply: $snippet"
        Save-State -IP $ip -GW $gw -Status "fail"
        exit 0
    }

    Set-PortalRoute -Gw $gw -IfIndex $ifIndex
    $page = Invoke-PortalCurl -LocalIP $ip -Timeout 8 -ExtraArgs @("-L", $url)
    for ($i = 0; $i -lt 2; $i++) {
        if ($page -match 'name="magic"') { break }
        if ($page -match "window\.location=[`"']([^`"']+)[`"']") {
            $next = $Matches[1]
            $page = Invoke-PortalCurl -LocalIP $ip -Timeout 8 -ExtraArgs @("-L", $next)
        } else {
            break
        }
    }

    if ($page -notmatch 'name="magic"') {
        $snippet = ($page -replace '[\r\n]+', ' ')
        if ($snippet.Length -gt 120) { $snippet = $snippet.Substring(0, 120) }
        Write-Log "no login form at $url ($ip via $gw): $snippet"
        Save-State -IP $ip -GW $gw -Status "fail"
        exit 1
    }

    if (-not (Test-Path $CredFile)) {
        Write-Log "credentials file missing"
        Save-State -IP $ip -GW $gw -Status "fail"
        exit 1
    }
    $credLines = Get-Content -Path $CredFile -Encoding UTF8
    $user = if ($credLines.Count -ge 1) { $credLines[0] } else { "" }
    $pass = if ($credLines.Count -ge 2) { $credLines[1] } else { "" }
    if ([string]::IsNullOrEmpty($user) -or [string]::IsNullOrEmpty($pass)) {
        Write-Log "credentials file empty"
        Save-State -IP $ip -GW $gw -Status "fail"
        exit 1
    }

    function Escape-CurlCfg([string]$s) {
        return $s.Replace('\', '\\').Replace('"', '\"')
    }

    function Submit-Login([string]$HtmlPage) {
        $flat = $HtmlPage -replace '[\r\n]+', ' '
        $magic = if ($flat -match 'name="magic"\s+value="([^"]*)"') { $Matches[1] } else { "" }
        $redir = if ($flat -match 'name="4Tredir"\s+value="([^"]*)"') { $Matches[1] } else { "" }
        $cfg = @(
            "data-urlencode = `"4Tredir=$(Escape-CurlCfg $redir)`""
            "data-urlencode = `"magic=$(Escape-CurlCfg $magic)`""
            "data-urlencode = `"username=$(Escape-CurlCfg $user)`""
            "data-urlencode = `"password=$(Escape-CurlCfg $pass)`""
        ) -join "`n"
        return Invoke-PortalCurl -LocalIP $ip -Timeout 10 -ExtraArgs @("-K", "-", "https://$PortalHost/") -StdinData $cfg
    }

    $resp = Submit-Login -HtmlPage $page
    for ($i = 0; $i -lt 5; $i++) {
        if ((Invoke-Probe -LocalIP $ip) -match "Success") {
            Write-Log "login ok ($ip via $gw)"
            Save-State -IP $ip -GW $gw -Status "ok"
            exit 0
        }
        Start-Sleep -Seconds 1
    }

    $why = ($resp -replace '<[^>]*>', ' ' -replace '\s+', ' ').Trim()
    if ($why.Length -gt 160) { $why = $why.Substring(0, 160) }

    if ($why -match '(?i)device|session|concurrent|limit|دستگاه|نشست|مجاز') {
        Write-Log "login failed ($ip via $gw), looks like a device/session limit: logging out and retrying once: $why"
        Invoke-PortalCurl -LocalIP $ip -Timeout 4 -ExtraArgs @("-o", "NUL", "https://$PortalHost/logout?") | Out-Null
        Start-Sleep -Seconds 2
        $page2 = Invoke-PortalCurl -LocalIP $ip -Timeout 8 -ExtraArgs @("-L", $url)
        if ($page2 -match 'name="magic"') {
            $resp = Submit-Login -HtmlPage $page2
            for ($i = 0; $i -lt 5; $i++) {
                if ((Invoke-Probe -LocalIP $ip) -match "Success") {
                    Write-Log "login ok after logout retry ($ip via $gw)"
                    Save-State -IP $ip -GW $gw -Status "ok"
                    exit 0
                }
                Start-Sleep -Seconds 1
            }
            $why = ($resp -replace '<[^>]*>', ' ' -replace '\s+', ' ').Trim()
            if ($why.Length -gt 160) { $why = $why.Substring(0, 160) }
        }
    }

    Write-Log "login failed ($ip via $gw): $why"
    Save-State -IP $ip -GW $gw -Status "fail"
    Show-FailureNotification "Login failed - too many devices? Check acct.ut.ac.ir"
    exit 1
} catch {
    try { Write-Log "unexpected error: $_" } catch {}
    exit 1
} finally {
    Remove-Item -Path $LockDir -Recurse -Force -ErrorAction SilentlyContinue
    & route.exe DELETE $PortalIP >$null 2>&1
}
