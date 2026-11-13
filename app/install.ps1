<#
.SYNOPSIS
    Install the AOD Keep-On app on the phone over USB, with its one-time DUMP permission.

.DESCRIPTION
    Installs prebuilt\AodKeepOn.apk by default (or the APK given with -Apk) using
    `adb install -r -g`. The -g grants DUMP during the install; ColorOS 17 blocks a later
    `pm grant` from ADB. Needs only adb, not the Android SDK.

.EXAMPLE
    .\app\install.ps1                               # install the prebuilt APK
.EXAMPLE
    .\app\install.ps1 -Apk .\app\build\AodKeepOn.apk # install your own build
#>
param(
    [string]$Apk = (Join-Path (Split-Path $PSScriptRoot -Parent) 'prebuilt\AodKeepOn.apk'),
    [string]$Serial
)

$ErrorActionPreference = 'Stop'
$package = 'aodhack.keepon'
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'lib\AdbCommon.ps1')

if (-not (Test-Path $Apk)) { Stop-Setup "APK not found: $Apk" }
Connect-AodPhone $Serial

Write-Host "Installing $(Split-Path $Apk -Leaf) ..."
$output = @(Invoke-PhoneAdb install -r -g $Apk)
if ($LASTEXITCODE -or -not ($output -match '^Success')) {
    $output | Select-Object -Last 3 | ForEach-Object { Write-Host "  $_" }
    if ($output -match 'UPDATE_INCOMPATIBLE|signatures do not match') {
        Stop-Setup 'The app on the phone was signed with a different key. Uninstall AOD Keep-On from the phone, then run this again.'
    }
    Stop-Setup 'Install failed (see above).'
}

$isGranted = { @(Invoke-PhoneShell "dumpsys package $package") -match 'android\.permission\.DUMP: granted=true' }
$replies = @()
if (-not (& $isGranted)) {
    # Older builds may still accept a direct grant.
    $replies = @(Invoke-PhoneShell "pm grant $package android.permission.DUMP") +
        @(Invoke-PhoneShell "pm grant $package android.permission.PACKAGE_USAGE_STATS")
}
if (& $isGranted) {
    Write-Host 'Installed with the DUMP permission. Open "AOD Keep-On" on the phone and choose Always or On a schedule.' -ForegroundColor Green
}
else {
    $replies | Where-Object { $_ -match 'SecurityException' } | Select-Object -First 1 |
        ForEach-Object { Write-Host "Phone refused: $($_ -replace '^.*SecurityException:\s*', '')" }
    Write-Host 'Installed, but the DUMP permission was not granted, so the app cannot set the flag.'
    Write-Host 'If Developer options has "Disable permission monitoring", turn it on and run this again.'
    exit 1
}
