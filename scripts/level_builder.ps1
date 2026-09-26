param([int]$Port = 8765)
$projectDirectory = Split-Path $PSScriptRoot -Parent
$dartExecutable = Join-Path $projectDirectory '.tools/flutter/bin/cache/dart-sdk/bin/dart.exe'
Push-Location $projectDirectory
try { & $dartExecutable 'tool/level_builder.dart' $Port; $builderExitCode = $LASTEXITCODE }
finally { Pop-Location }
exit $builderExitCode
