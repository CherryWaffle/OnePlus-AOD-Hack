<#
.SYNOPSIS
    Undo everything this project changes on the phone.

.DESCRIPTION
    1. Turns SystemUI's keep_aod_on flag off. This is the only thing aod.ps1 changes,
       and it lives in memory (a reboot clears it too).
    2. Uninstalls the AOD Keep-On app if it is installed, since it would turn the flag
       back on at the next boot.
    3. Compares AOD-related settings (keys containing aod / doze / ambient / panoramic)
       with the oldest snapshot from backup.ps1 and lists every difference.
       aod.ps1 never writes settings, so differences normally come from changes you
       made yourself in the Settings app (for example picking a different AOD style).
       Pass -ApplySettings to write the snapshot values back anyway.

.EXAMPLE
    .\restore.ps1                          # flag off + list setting differences
.EXAMPLE
    .\restore.ps1 -ApplySettings           # also put AOD-related settings back to the snapshot
.EXAMPLE
    .\restore.ps1 -ApplySettings -WhatIf   # show what would run, change nothing
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Serial,
    # Snapshot folder to compare with. Default: oldest backups\<model>_* folder.
    [string]$Snapshot,
    [switch]$ApplySettings
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\AdbCommon.ps1')
Connect-AodPhone $Serial

function Read-Settings([string[]]$Lines) {
    $map = New-Object System.Collections.Hashtable ([System.StringComparer]::Ordinal)
    foreach ($line in $Lines) {
        $i = $line.IndexOf('=')
        if ($i -le 0) { continue }
        $value = $line.Substring($i + 1)
        if ($value -ceq 'null') { $value = $null }
        $map[$line.Substring(0, $i)] = $value
    }
    $map
}

# Single-quote a value for the phone's sh.
function ConvertTo-ShellQuoted([string]$Value) { "'" + $Value.Replace("'", "'\''") + "'" }

# 1. The runtime flag.
if ($PSCmdlet.ShouldProcess('SystemUI', 'set keep_aod_on 0')) {
    Invoke-PhoneShell "dumpsys activity service $KeyguardService debug keep_aod_on 0" | Out-Null
    Write-Host 'keep_aod_on = 0: stock AOD timeout restored.'
}

# 2. The on-phone app, which would set the flag again at the next boot.
$appPackage = 'aodhack.keepon'
if (@(Invoke-PhoneShell "pm list packages $appPackage") -contains "package:$appPackage") {
    if ($PSCmdlet.ShouldProcess($appPackage, 'uninstall the AOD Keep-On app')) {
        Invoke-PhoneAdb uninstall $appPackage | Out-Null
        Write-Host 'Uninstalled the AOD Keep-On app.'
    }
}

# 3. Settings, compared with the snapshot.
if (-not $Snapshot) {
    $Snapshot = Get-ChildItem $BackupRoot -Directory -Filter "$($script:PhoneModel)_*" -ErrorAction SilentlyContinue |
        Sort-Object Name | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $Snapshot) {
    Write-Host 'No settings snapshot found (backup.ps1 makes one). Nothing else to compare.'
}
else {
    Write-Host "Comparing AOD-related settings with snapshot: $(Split-Path $Snapshot -Leaf)"
    $keyPattern = '(?i)aod|doze|ambient|panoramic'
    $commands = New-Object System.Collections.Generic.List[string]
    foreach ($ns in 'secure', 'global', 'system') {
        $file = Join-Path $Snapshot "$ns.txt"
        if (-not (Test-Path $file)) { continue }
        $before = Read-Settings (Get-Content $file -Encoding UTF8)
        $now = Read-Settings @(Invoke-PhoneShell "settings list $ns")
        $keys = @($before.Keys) + @($now.Keys) | Where-Object { $_ -match $keyPattern } | Sort-Object -Unique
        foreach ($key in $keys) {
            $b = $before[$key]; $n = $now[$key]
            if ($b -ceq $n) { continue }
            $show = { param($v) if ($null -eq $v) { '<unset>' } elseif ($v.Length -gt 60) { $v.Substring(0, 57) + '...' } else { $v } }
            Write-Host ('  {0,-6} {1}: {2} -> snapshot {3}' -f $ns, $key, (& $show $n), (& $show $b))
            if ($null -eq $b) { $commands.Add("settings delete $ns $key") }
            else { $commands.Add("settings put $ns $key $(ConvertTo-ShellQuoted $b)") }
        }
    }

    if ($commands.Count -eq 0) {
        Write-Host '  No differences.'
    }
    elseif (-not $ApplySettings) {
        Write-Host "  $($commands.Count) difference(s). Left as they are; run with -ApplySettings to write the snapshot values back."
    }
    elseif ($PSCmdlet.ShouldProcess("$($commands.Count) AOD-related settings", 'write snapshot values back')) {
        # Values can hold quotes and JSON, so run them from a script file on the phone
        # instead of passing them through Windows argument quoting.
        $tmp = [System.IO.Path]::GetTempFileName()
        try {
            [System.IO.File]::WriteAllText($tmp, (($commands -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding($false)))
            Invoke-PhoneAdb push $tmp /data/local/tmp/aod-restore.sh | Out-Null
            Invoke-PhoneShell 'sh /data/local/tmp/aod-restore.sh; rm -f /data/local/tmp/aod-restore.sh'
        }
        finally {
            Remove-Item $tmp -ErrorAction SilentlyContinue
        }
        Write-Host "  Wrote $($commands.Count) setting(s) back from the snapshot."
    }
    elseif ($WhatIfPreference) {
        $commands | ForEach-Object { "  would run: $_" }
    }
}

Write-Host ''
Write-Host 'Not touched (these scripts never change them): Developer options and USB debugging.'
Write-Host 'To remove this PC''s access: Developer options > Revoke USB debugging authorizations.'
