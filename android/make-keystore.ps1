# Generate a release keystore for signing the APK.
#
# Run from C:\dev\water-app-mobile\android (or anywhere — the script
# uses absolute paths). You'll be prompted twice for a password —
# remember it; if you lose it you can never push an update to an
# already-published app under this signing identity.
#
# Output:
#   android/app/upload-keystore.jks
#   android/key.properties (auto-generated, gitignored)

$ErrorActionPreference = 'Stop'

$javaHome = [Environment]::GetEnvironmentVariable('JAVA_HOME', 'Machine')
if (-not $javaHome) { $javaHome = [Environment]::GetEnvironmentVariable('JAVA_HOME', 'User') }
if (-not $javaHome) {
    Write-Host 'JAVA_HOME not set. Install the JDK first.' -ForegroundColor Red
    exit 1
}

$keytool = Join-Path $javaHome 'bin\keytool.exe'
if (-not (Test-Path $keytool)) {
    Write-Host "keytool not found at $keytool" -ForegroundColor Red
    exit 1
}

$keystorePath = 'C:\dev\water-app-mobile\android\app\upload-keystore.jks'
$keyAlias = 'upload'
$dname = 'CN=HydroTrack, OU=Mobile, O=vovafes, L=Berlin, S=Berlin, C=DE'

if (Test-Path $keystorePath) {
    Write-Host "Keystore already exists at $keystorePath" -ForegroundColor Yellow
    $reply = Read-Host 'Overwrite? (y/N)'
    if ($reply -ne 'y') { exit 0 }
    Remove-Item $keystorePath
}

Write-Host 'Generating release keystore. You will be prompted for a password —' -ForegroundColor Cyan
Write-Host 'use the same one for both the keystore and the key for simplicity.' -ForegroundColor Cyan
Write-Host ''

$pass = Read-Host -AsSecureString 'Choose a keystore password (min 6 chars)'
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($pass)
$plain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

if ($plain.Length -lt 6) {
    Write-Host 'Password must be at least 6 characters.' -ForegroundColor Red
    exit 1
}

& $keytool -genkey -v `
    -keystore $keystorePath `
    -keyalg RSA `
    -keysize 2048 `
    -validity 10000 `
    -alias $keyAlias `
    -storepass $plain `
    -keypass $plain `
    -dname $dname

if ($LASTEXITCODE -ne 0) {
    Write-Host 'keytool failed.' -ForegroundColor Red
    exit 1
}

# Write key.properties so Gradle picks the keystore up automatically.
# Use forward slashes: in .properties files Java treats `\` as the start
# of an escape sequence, so a path like `C:\dev\...\upload-keystore.jks`
# triggers "Malformed \uxxxx encoding". Forward slashes work fine on
# Windows JVMs.
$keystoreForProps = $keystorePath -replace '\\', '/'
$keyProps = @"
storePassword=$plain
keyPassword=$plain
keyAlias=$keyAlias
storeFile=$keystoreForProps
"@

$propsPath = 'C:\dev\water-app-mobile\android\key.properties'
Set-Content -Path $propsPath -Value $keyProps -Encoding ASCII

Write-Host ''
Write-Host "Keystore written: $keystorePath" -ForegroundColor Green
Write-Host "key.properties written: $propsPath" -ForegroundColor Green
Write-Host ''
Write-Host 'BOTH files are gitignored. Back up the .jks somewhere safe — if you'
Write-Host 'lose it you can never sign a Play Store update under the same identity.'
