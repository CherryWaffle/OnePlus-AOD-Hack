# Shared ADB helpers for the OnePlus AOD scripts. Dot-source it:
#   . (Join-Path $PSScriptRoot 'lib\AdbCommon.ps1')

$KeyguardService = 'com.android.systemui/.keyguard.KeyguardService'

function Find-Adb {
    $cmd = Get-Command adb -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
    if (Test-Path $sdk) { return $sdk }
    throw 'adb not found. Install Android SDK platform-tools and put adb on PATH.'
}

# Picks the one connected, authorized phone (or the one matching $Serial) and
# remembers it for Invoke-PhoneAdb / Invoke-PhoneShell.
function Connect-AodPhone([string]$Serial) {
    # Read adb output as UTF-8 so non-ASCII setting values survive.
    try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

    $script:Adb = Find-Adb
    $devices = @(& $script:Adb devices | Select-Object -Skip 1 | Where-Object { $_ -match '\S' } | ForEach-Object {
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

    $script:PhoneSerial = $dev.Serial
    $script:PhoneModel = "$(Invoke-PhoneShell 'getprop ro.product.model')".Trim()
    $build = "$(Invoke-PhoneShell 'getprop ro.build.display.id')".Trim()
    Write-Host "Phone: $($script:PhoneModel)  build $build"
}

function Invoke-PhoneAdb { & $script:Adb -s $script:PhoneSerial @args }

function Invoke-PhoneShell([string]$Command) { Invoke-PhoneAdb shell $Command }
