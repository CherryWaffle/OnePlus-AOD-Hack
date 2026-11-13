<#
.SYNOPSIS
    Save a snapshot of the phone's settings (secure, global, system).

.DESCRIPTION
    Writes backups\<model>_<timestamp>\{secure,global,system}.txt next to this script.
    restore.ps1 compares against the OLDEST snapshot for the phone model, so take one
    before changing anything. aod.ps1 on takes one automatically the first time.

    The backups folder is git-ignored: snapshots hold the phone's own settings.

.EXAMPLE
    .\backup.ps1
#>
param([string]$Serial)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\AdbCommon.ps1')
Connect-AodPhone $Serial
Save-SettingsSnapshot
