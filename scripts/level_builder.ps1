param([int]$Port = 8765, [switch]$NoBrowser, [switch]$Stop)
$projectDirectory = Split-Path $PSScriptRoot -Parent
$dartExecutable = Join-Path $projectDirectory '.tools/flutter/bin/cache/dart-sdk/bin/dart.exe'
$url = "http://127.0.0.1:$Port"

# -Stop: end every running builder (any port) and its launcher windows.
if ($Stop) {
  $builders = @(Get-CimInstance Win32_Process | Where-Object {
    $_.ProcessId -ne $PID -and $_.CommandLine -match 'level_builder\.(dart|ps1|cmd)' -and $_.CommandLine -notmatch '-Stop'
  })
  foreach ($process in $builders) { Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue }
  Write-Host "Stopped $($builders.Count) Level Builder process(es). Nothing is running now."
  exit 0
}

if (-not (Test-Path $dartExecutable)) {
  Write-Host "Dart SDK not found at $dartExecutable" -ForegroundColor Red
  Write-Host 'Install the Flutter SDK into .tools/flutter first.'
  exit 1
}

# Already running: just open it instead of failing with "port in use".
try {
  Invoke-WebRequest "$url/api/levels" -UseBasicParsing -TimeoutSec 1 | Out-Null
  Write-Host "Level Builder is already running: $url"
  if (-not $NoBrowser) { Start-Process $url }
  exit 0
} catch {}

# Open the browser as soon as the server answers (first start compiles for a few seconds).
if (-not $NoBrowser) {
  Start-Job -ArgumentList $url {
    param($url)
    for ($i = 0; $i -lt 240; $i++) {
      try { Invoke-WebRequest "$url/api/levels" -UseBasicParsing -TimeoutSec 1 | Out-Null; Start-Process $url; return }
      catch { Start-Sleep -Milliseconds 500 }
    }
  } | Out-Null
}

Write-Host 'Starting Level Builder... the browser opens when it is ready. Close this window to stop.'
Push-Location $projectDirectory
try { & $dartExecutable 'tool/level_builder.dart' $Port; $builderExitCode = $LASTEXITCODE }
finally { Pop-Location }
exit $builderExitCode
