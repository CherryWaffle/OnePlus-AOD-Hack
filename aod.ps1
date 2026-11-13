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
.EXAMPLE
    .\aod.ps1 watch    # live view for 30 s: ambient light (lux) -> AOD brightness (nits)
#>
param(
    [ValidateSet('on', 'off', 'status', 'watch')]
    [string]$Action = 'on',
    [string]$Serial,
    [int]$Seconds = 30
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\AdbCommon.ps1')
Connect-AodPhone $Serial

switch ($Action) {
    'on' {
        Invoke-PhoneShell "dumpsys activity service $KeyguardService debug keep_aod_on 1" | Out-Null
        Write-Host 'keep_aod_on = 1. Full-screen AOD will no longer time out (until the next reboot).'
        Write-Host 'Check: lock the phone, wait ~15 s, then run: .\aod.ps1 status'
    }
    'off' {
        Invoke-PhoneShell "dumpsys activity service $KeyguardService debug keep_aod_on 0" | Out-Null
        Write-Host 'keep_aod_on = 0. Stock AOD timeout restored (a reboot also does this).'
    }
    'status' {
        $pattern = 'keep aod on for test|onEnergySavingNotifyHide|hideByTimeoutReceiver|PanoramicAodController-->onDreamingStarted'
        $hits = @(Invoke-PhoneAdb logcat -d -v time | Select-String -Pattern $pattern | Select-Object -Last 12)
        if ($hits.Count -eq 0) {
            Write-Host 'No AOD events in the log. The phone log buffer is small and rolls over within a minute:'
            Write-Host 'lock the phone with full-screen AOD selected, wait ~15 s, run status again (or use: .\aod.ps1 watch).'
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
    'watch' {
        Write-Host "Watching AOD for $Seconds s. Lock the phone, then shine a light at the top of the screen"
        Write-Host '(the light sensor sits under the display near the front camera).'
        # timeout runs on the phone, so the stream ends by itself.
        Invoke-PhoneShell "timeout $Seconds logcat -T 1 -v time -s SystemUi--Aod:I" | ForEach-Object {
            $time = if ($_ -match '^\S+\s+(\d\d:\d\d:\d\d)') { $Matches[1] } else { '' }
            if ($_ -match 'lightValue=([\d.]+).*?Nit=\s*([\d.]+)') {
                '{0}  light {1,6:N0} lux  ->  AOD {2,5:N1} nits' -f $time, [double]$Matches[1], [double]$Matches[2]
            }
            elseif ($_ -match 'keep aod on for test') {
                "$time  timeout fired, skipped (keep_aod_on is active)"
            }
            elseif ($_ -match 'onEnergySavingNotifyHide') {
                "$time  timeout fired, AOD hidden (keep_aod_on is off)"
            }
            elseif ($_ -match 'onDreamingStarted, aod type') {
                "$time  AOD started"
            }
        }
        Write-Host 'Done.'
    }
}
