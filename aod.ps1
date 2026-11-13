<#
.SYNOPSIS
    All-day full-screen AOD for the OnePlus 12 (ColorOS / OxygenOS 16-17). No root.

.DESCRIPTION
    Sets SystemUI's hidden debug flag keep_aod_on, which makes the AOD "energy saving"
    hide (the ~5-10 s cutoff on full-screen / panoramic AOD) get skipped.
    The flag lives in SystemUI's memory, so re-run "on" after every reboot.

.EXAMPLE
    .\aod.ps1 on       # keep full-screen AOD on (re-run after every reboot)
.EXAMPLE
    .\aod.ps1 off      # restore the stock timeout
.EXAMPLE
    .\aod.ps1 status   # show the latest AOD hide / keep-on log lines
#>
param(
    [ValidateSet('on', 'off', 'status')]
    [string]$Action = 'on',
    [string]$Serial
)

$ErrorActionPreference = 'Stop'
$KeyguardService = 'com.android.systemui/.keyguard.KeyguardService'

function Find-Adb {
    $cmd = Get-Command adb -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
    if (Test-Path $sdk) { return $sdk }
    throw 'adb not found. Install Android SDK platform-tools and put adb on PATH.'
}

$adb = Find-Adb

$devices = @(& $adb devices | Select-Object -Skip 1 | Where-Object { $_ -match '\S' } | ForEach-Object {
        $parts = $_ -split '\s+'
        [pscustomobject]@{ Serial = $parts[0]; State = $parts[1] }
    })
if ($Serial) { $devices = @($devices | Where-Object { $_.Serial -eq $Serial }) }

if ($devices.Count -eq 0) {
    throw 'No phone found. Plug it in over USB with USB debugging on (or connect wireless debugging).'
}
if ($devices.Count -gt 1) {
    throw ("Several devices connected; pick one with -Serial: " + (($devices | ForEach-Object Serial) -join ', '))
}
$dev = $devices[0]
if ($dev.State -eq 'unauthorized') {
    throw 'Phone is unauthorized: unlock it and tap Allow on the USB debugging prompt (tick "Always allow").'
}
if ($dev.State -ne 'device') {
    throw "Phone state is '$($dev.State)', expected 'device'."
}

function Invoke-Shell([string]$command) {
    & $adb -s $dev.Serial shell $command
}

$model = (Invoke-Shell 'getprop ro.product.model').Trim()
$build = (Invoke-Shell 'getprop ro.build.display.id').Trim()
Write-Host "Phone: $model  build $build"

switch ($Action) {
    'on' {
        Invoke-Shell "dumpsys activity service $KeyguardService debug keep_aod_on 1" | Out-Null
        Write-Host 'keep_aod_on = 1. Full-screen AOD will no longer time out (until the next reboot).'
        Write-Host 'Check: lock the phone, wait ~15 s, then run: .\aod.ps1 status'
    }
    'off' {
        Invoke-Shell "dumpsys activity service $KeyguardService debug keep_aod_on 0" | Out-Null
        Write-Host 'keep_aod_on = 0. Stock AOD timeout restored (a reboot also does this).'
    }
    'status' {
        $pattern = 'keep aod on for test|onEnergySavingNotifyHide|hideByTimeoutReceiver|PanoramicAodController-->onDreamingStarted'
        $hits = @(& $adb -s $dev.Serial logcat -d -v time | Select-String -Pattern $pattern | Select-Object -Last 12)
        if ($hits.Count -eq 0) {
            Write-Host 'No AOD events in the log yet. Lock the phone with full-screen AOD selected, wait ~15 s, retry.'
        }
        else {
            $hits | ForEach-Object { $_.Line }
            if ($hits[-1].Line -match 'keep aod on for test') {
                Write-Host "`nActive: the last AOD hide was skipped."
            }
            elseif ($hits[-1].Line -match 'onEnergySavingNotifyHide') {
                Write-Host "`nNot active: the last AOD was hidden by the timeout. Run: .\aod.ps1 on"
            }
        }
    }
}
