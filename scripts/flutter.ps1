param([Parameter(ValueFromRemainingArguments = $true)][string[]]$FlutterArguments)
$projectDirectory = Split-Path $PSScriptRoot -Parent
$env:PUB_CACHE = Join-Path $projectDirectory '.pub-cache'
$androidSdkDirectory = Join-Path $projectDirectory '.tools/android-sdk'
if (Test-Path -LiteralPath $androidSdkDirectory) { $env:ANDROID_HOME = $androidSdkDirectory }
$env:GRADLE_USER_HOME = Join-Path $projectDirectory '.tools/gradle-cache'
$flutterExecutable = Join-Path $projectDirectory '.tools/flutter/bin/flutter.bat'
if (-not (Test-Path -LiteralPath $flutterExecutable)) {
  throw 'Flutter SDK missing. Install Flutter and use its flutter command directly.'
}
Push-Location $projectDirectory
try { & $flutterExecutable @FlutterArguments; $flutterExitCode = $LASTEXITCODE }
finally { Pop-Location }
exit $flutterExitCode
