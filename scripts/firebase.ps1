param([Parameter(ValueFromRemainingArguments = $true)][string[]]$FirebaseArguments)
$projectDirectory = Split-Path $PSScriptRoot -Parent
$firebaseEntryPoint = Join-Path $projectDirectory '.tools/firebase-cli/node_modules/firebase-tools/lib/bin/firebase.js'
if (-not (Test-Path -LiteralPath $firebaseEntryPoint)) {
  throw 'Firebase CLI missing. Run npm.cmd install --prefix .tools/firebase-cli firebase-tools from the project folder.'
}
# Keep the CLI's sign-in credentials in the ignored local tools directory.
$previousConfigDirectory = $env:XDG_CONFIG_HOME
$env:XDG_CONFIG_HOME = Join-Path $projectDirectory '.tools/firebase-config'
Push-Location $projectDirectory
try { & node $firebaseEntryPoint @FirebaseArguments; $firebaseExitCode = $LASTEXITCODE }
finally {
  Pop-Location
  $env:XDG_CONFIG_HOME = $previousConfigDirectory
}
exit $firebaseExitCode
