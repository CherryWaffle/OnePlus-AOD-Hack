<#
.SYNOPSIS
    Build the AOD Keep-On app with plain Android SDK tools (no Gradle), optionally install it.

.DESCRIPTION
    Needs the Android SDK (build-tools and a platform with android.jar) and a JDK 17+.
    Output: app\build\AodKeepOn.apk.

    The APK is signed with a local key in app\keystore\ (created on the first build,
    git-ignored). Keep it: Android only installs updates signed with the same key.

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

$keystore = Join-Path $here 'keystore\signing.jks'
if (-not (Test-Path $keystore)) {
    New-Item -ItemType Directory -Force (Split-Path $keystore) | Out-Null
    Invoke-Tool 'keytool' {
        & (Join-Path $jdk 'bin\keytool.exe') -genkeypair -keystore $keystore -storepass android -keypass android `
            -alias aodkeepon -keyalg RSA -keysize 2048 -validity 10000 -dname 'CN=AOD Keep-On'
    }
}
$apk = Join-Path $out 'AodKeepOn.apk'
Invoke-Tool 'apksigner' {
    & (Join-Path $buildTools 'apksigner.bat') sign --ks $keystore --ks-pass pass:android --key-pass pass:android --out $apk $aligned
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
