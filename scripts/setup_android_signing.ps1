param()

$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path $PSScriptRoot -Parent
$propertiesPath = Join-Path $projectDirectory 'android/key.properties'
$keystoreDirectory = Join-Path $projectDirectory 'android/keystore'
$keystorePath = Join-Path $keystoreDirectory 'rollrise-upload.jks'

if ((Test-Path -LiteralPath $propertiesPath) -or
    (Test-Path -LiteralPath $keystorePath)) {
    throw 'Signing files already exist. Refusing to replace the upload key or credentials.'
}

$keytoolPath = (Get-Command keytool.exe -ErrorAction Stop).Source
New-Item -ItemType Directory -Force -Path $keystoreDirectory | Out-Null
$passwordBytes = [byte[]]::new(48)
$randomGenerator = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$randomGenerator.GetBytes($passwordBytes)
$randomGenerator.Dispose()
$signingPassword = [Convert]::ToBase64String($passwordBytes)

try {
    # Pass the password through a short-lived process environment variable,
    # rather than putting the secret on the keytool command line or in output.
    $env:ROLLRISE_UPLOAD_KEY_PASSWORD = $signingPassword
    & $keytoolPath -genkeypair -noprompt -keystore $keystorePath `
        -storetype JKS -alias upload -keyalg RSA -keysize 3072 -validity 10000 `
        -dname 'CN=Rollrise Upload, OU=Android Release, O=VHT Games, C=AM' `
        -storepass:env ROLLRISE_UPLOAD_KEY_PASSWORD `
        -keypass:env ROLLRISE_UPLOAD_KEY_PASSWORD
    if ($LASTEXITCODE -ne 0) { throw 'Upload key generation failed.' }

    $propertiesContent = @(
        "storePassword=$signingPassword"
        "keyPassword=$signingPassword"
        'keyAlias=upload'
        'storeFile=../keystore/rollrise-upload.jks'
    ) -join "`n"
    [System.IO.File]::WriteAllText(
        $propertiesPath, $propertiesContent + "`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    Write-Output 'Android upload signing configured. Credentials were not printed.'
    Write-Output 'Back up android/keystore/rollrise-upload.jks and android/key.properties securely outside this checkout.'
} finally {
    Remove-Item Env:ROLLRISE_UPLOAD_KEY_PASSWORD -ErrorAction SilentlyContinue
    $signingPassword = $null
    [Array]::Clear($passwordBytes, 0, $passwordBytes.Length)
}
