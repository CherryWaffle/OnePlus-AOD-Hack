<#
.SYNOPSIS
    Build the AOD Keep-On app with plain Android SDK tools (no Gradle), optionally install it.

.DESCRIPTION
    Needs the Android SDK (build-tools and a platform with android.jar) and a JDK 17+.
    Output: app\build\AodKeepOn.apk.

    The APK is signed with a local key in app\keystore\signing.jks, protected by a random
    password in app\keystore\password.txt. Both are created on the first build and are
    git-ignored. Back them up: Android only installs updates signed with the same key.

.EXAMPLE
    .\app\build.ps1            # build only
.EXAMPLE
    .\app\build.ps1 -Install   # build, then install over USB with app\install.ps1
.EXAMPLE
    .\app\build.ps1 -Prebuilt  # build, then copy to prebuilt\ with its SHA-256 (maintainers)
#>
param(
    [switch]$Install,
    [switch]$Prebuilt,
    [string]$Serial
)

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot

function Stop-Setup([string]$Message) {
    Write-Host $Message -ForegroundColor Red
    exit 1
}

# --- Tools -------------------------------------------------------------------
$sdk = @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT, (Join-Path $env:LOCALAPPDATA 'Android\Sdk')) |
    Where-Object { $_ -and (Test-Path (Join-Path $_ 'build-tools')) } | Select-Object -First 1
if (-not $sdk) { Stop-Setup 'Android SDK not found. Install Android Studio and open it once (it downloads the SDK), or set ANDROID_HOME.' }

$buildTools = Get-ChildItem (Join-Path $sdk 'build-tools') -Directory |
    Where-Object { Test-Path (Join-Path $_.FullName 'd8.bat') } |
    Sort-Object { [version]($_.Name -replace '-.*$', '') } | Select-Object -Last 1 -ExpandProperty FullName
$androidJar = Get-ChildItem (Join-Path $sdk 'platforms') -Directory |
    Where-Object { Test-Path (Join-Path $_.FullName 'android.jar') } |
    Where-Object { $_.Name -match '^android-\d+' } |
    Sort-Object { [int]($_.Name -replace '^android-(\d+).*$', '$1') } |
    Select-Object -Last 1 | ForEach-Object { Join-Path $_.FullName 'android.jar' }
if (-not $buildTools -or -not $androidJar) { Stop-Setup 'Need Android build-tools and a platform (android.jar) in the SDK. Open Android Studio once, or install them with its SDK Manager.' }

$jdk = @($env:JAVA_HOME, "$env:ProgramFiles\Android\Android Studio\jbr") |
    Where-Object { $_ -and (Test-Path (Join-Path $_ 'bin\javac.exe')) } | Select-Object -First 1
if (-not $jdk) {
    $javacCmd = Get-Command javac -ErrorAction SilentlyContinue
    if (-not $javacCmd) { Stop-Setup 'JDK 17+ not found. Install Android Studio (it includes one) or set JAVA_HOME.' }
    $jdk = Split-Path (Split-Path $javacCmd.Source)
}
# d8.bat and apksigner.bat use JAVA_HOME / PATH.
$env:JAVA_HOME = $jdk
$env:PATH = (Join-Path $jdk 'bin') + ';' + $env:PATH

function Invoke-Tool([string]$Name, [scriptblock]$Command) {
    # The SDK tools print progress on stderr; only the exit code means failure.
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $Command 2>&1 | ForEach-Object { "$_" }
    }
    finally {
        $ErrorActionPreference = $previous
    }
    if ($LASTEXITCODE) { throw "$Name failed (exit $LASTEXITCODE)." }
}

# --- Build -------------------------------------------------------------------
$out = Join-Path $here 'build'
Remove-Item $out -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force (Join-Path $out 'classes'), (Join-Path $out 'dex') | Out-Null

$sources = @(Get-ChildItem (Join-Path $here 'src') -Recurse -Filter *.java | ForEach-Object FullName)
Invoke-Tool 'javac' { & (Join-Path $jdk 'bin\javac.exe') --release 11 -encoding UTF-8 -nowarn -cp $androidJar -d (Join-Path $out 'classes') @sources }

$classes = @(Get-ChildItem (Join-Path $out 'classes') -Recurse -Filter *.class | ForEach-Object FullName)
Invoke-Tool 'd8' { & (Join-Path $buildTools 'd8.bat') --release --min-api 30 --lib $androidJar --output (Join-Path $out 'dex') @classes }

$base = Join-Path $out 'base.apk'
Invoke-Tool 'aapt2 link' { & (Join-Path $buildTools 'aapt2.exe') link -o $base -I $androidJar --manifest (Join-Path $here 'AndroidManifest.xml') }

Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::Open($base, 'Update')
try {
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, (Join-Path $out 'dex\classes.dex'), 'classes.dex') | Out-Null
}
finally {
    $zip.Dispose()
}

$aligned = Join-Path $out 'aligned.apk'
Invoke-Tool 'zipalign' { & (Join-Path $buildTools 'zipalign.exe') -p -f 4 $base $aligned }

# --- Signing key -------------------------------------------------------------
# signing.jks and its random password.txt stay in app\keystore\ (git-ignored). Passwords
# reach keytool and apksigner through environment variables, never the command line.
$keystore = Join-Path $here 'keystore\signing.jks'
$passwordFile = Join-Path $here 'keystore\password.txt'
$keytool = Join-Path $jdk 'bin\keytool.exe'

if (-not (Test-Path $passwordFile)) {
    if (-not (Test-Path $keystore)) {
        New-Item -ItemType Directory -Force (Split-Path $keystore) | Out-Null
    }
    $bytes = New-Object byte[] 24
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $env:AOD_KS_NEW = -join ($bytes | ForEach-Object { $_.ToString('x2') })
    # Save the new password before touching the key, so a failure can't lose it.
    $pending = "$passwordFile.new"
    [System.IO.File]::WriteAllText($pending, $env:AOD_KS_NEW)
    try {
        if (Test-Path $keystore) {
            # Keys from earlier versions of this script used the password "android".
            # Give them the random one; the key and its certificate stay the same.
            $env:AOD_KS_OLD = 'android'
            Invoke-Tool 'keytool -storepasswd' {
                & $keytool -storepasswd -keystore $keystore -storepass:env AOD_KS_OLD -new:env AOD_KS_NEW
            }
            Write-Host 'Signing key moved from the old default password to a random one in app\keystore\password.txt.'
        }
        else {
            Invoke-Tool 'keytool -genkeypair' {
                & $keytool -genkeypair -keystore $keystore -storetype PKCS12 -storepass:env AOD_KS_NEW `
                    -keypass:env AOD_KS_NEW -alias aodkeepon -keyalg RSA -keysize 2048 -validity 10000 `
                    -dname 'CN=AOD Keep-On'
            }
        }
    }
    catch {
        # keytool failed, so the key still has its old password: drop the unused new one.
        Remove-Item $pending -ErrorAction SilentlyContinue
        throw
    }
    finally {
        Remove-Item Env:AOD_KS_OLD, Env:AOD_KS_NEW -ErrorAction SilentlyContinue
    }
    # Only now that the key uses it does the new password become password.txt.
    Move-Item $pending $passwordFile
}
elseif (-not (Test-Path $keystore)) {
    Stop-Setup 'app\keystore\password.txt exists but signing.jks is missing. Restore the key from your backup.'
}

$apk = Join-Path $out 'AodKeepOn.apk'
$env:AOD_KS_PASS = [System.IO.File]::ReadAllText($passwordFile).Trim()
try {
    Invoke-Tool 'apksigner' {
        & (Join-Path $buildTools 'apksigner.bat') sign --ks $keystore --ks-pass env:AOD_KS_PASS `
            --key-pass env:AOD_KS_PASS --out $apk $aligned
    }
}
finally {
    Remove-Item Env:AOD_KS_PASS -ErrorAction SilentlyContinue
}
Write-Host "Built: $apk"

# --- Publish / install -------------------------------------------------------
if ($Prebuilt) {
    $dest = Join-Path (Split-Path $here -Parent) 'prebuilt'
    New-Item -ItemType Directory -Force $dest | Out-Null
    Copy-Item $apk (Join-Path $dest 'AodKeepOn.apk') -Force
    $hash = (Get-FileHash (Join-Path $dest 'AodKeepOn.apk') -Algorithm SHA256).Hash.ToLower()
    [System.IO.File]::WriteAllText((Join-Path $dest 'SHA256.txt'), "$hash  AodKeepOn.apk`n")
    Write-Host "Updated prebuilt\AodKeepOn.apk (SHA-256 $hash)"
}

if ($Install) {
    & (Join-Path $here 'install.ps1') -Apk $apk -Serial $Serial
    exit $LASTEXITCODE
}
