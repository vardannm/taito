$projectDirectory = Split-Path $PSScriptRoot -Parent
$dartExecutable = Join-Path $projectDirectory '.tools/flutter/bin/cache/dart-sdk/bin/dart.exe'
Push-Location $projectDirectory
try {
  & $dartExecutable 'tool/register_classic_levels.dart'
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  & $dartExecutable format 'lib/classic_levels.dart' 'lib/classic_levels'
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  & (Join-Path $PSScriptRoot 'flutter.ps1') test --no-pub 'tool/bake_mode_previews.dart'
  $registrationExitCode = $LASTEXITCODE
}
finally { Pop-Location }
exit $registrationExitCode
