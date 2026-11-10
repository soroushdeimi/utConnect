# Run as Administrator: .\update.ps1 (updates scripts/tasks, keeps saved credentials)
$ErrorActionPreference = "Stop"

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Please run update.ps1 as Administrator!" -ForegroundColor Red
    exit 1
}

$BaseDir = "C:\ProgramData\utConnect"
$CredFile = "$BaseDir\credentials"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not (Test-Path $CredFile)) {
    Write-Host "No credentials yet: run install.ps1 first." -ForegroundColor Yellow
    exit 1
}

Copy-Item -Path "$ScriptDir\ut-wifi-login.ps1" -Destination "$BaseDir\ut-wifi-login.ps1" -Force
Write-Host "Updated utConnect script successfully." -ForegroundColor Green
