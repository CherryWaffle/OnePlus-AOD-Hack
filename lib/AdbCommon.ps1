# Shared ADB helpers for the OnePlus AOD scripts. Dot-source it:
#   . (Join-Path $PSScriptRoot 'lib\AdbCommon.ps1')

$KeyguardService = 'com.android.systemui/.keyguard.KeyguardService'

# Settings snapshots live in <repo>\backups (git-ignored).
$BackupRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'backups'

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

function Invoke-PhoneAdb {
    # adb prints progress (and some errors) on stderr. Return it as text so Windows
    # PowerShell doesn't turn it into a terminating error; callers check results.
    $ErrorActionPreference = 'Continue'
    & $script:Adb -s $script:PhoneSerial @args 2>&1 | ForEach-Object { "$_" }
}

function Invoke-PhoneShell([string]$Command) { Invoke-PhoneAdb shell $Command }

# Saves `settings list` for secure, global and system to
# backups\<model>_<timestamp>\. With -IfMissing it does nothing when a snapshot
# for this phone model already exists.
function Save-SettingsSnapshot([switch]$IfMissing) {
    $existing = @(Get-ChildItem $BackupRoot -Directory -Filter "$($script:PhoneModel)_*" -ErrorAction SilentlyContinue)
    if ($IfMissing -and $existing.Count -gt 0) { return }

    $dir = Join-Path $BackupRoot ('{0}_{1:yyyyMMdd-HHmmss}' -f $script:PhoneModel, (Get-Date))
    New-Item -ItemType Directory -Force $dir | Out-Null
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    foreach ($ns in 'secure', 'global', 'system') {
        $lines = [string[]]@(Invoke-PhoneShell "settings list $ns")
        if ($lines.Count -eq 0) { throw "settings list $ns returned nothing." }
        [System.IO.File]::WriteAllLines((Join-Path $dir "$ns.txt"), $lines, $utf8)
    }
    Write-Host "Saved settings snapshot: $dir"
}
