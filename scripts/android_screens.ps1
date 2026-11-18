<#
Google Play screenshots from the Android Emulator.

  .\scripts\android_screens.ps1 setup              # create the three emulators (once)
  .\scripts\android_screens.ps1 start phone        # phone | tablet-7 | tablet-10
  .\scripts\android_screens.ps1 install            # install the capture APK on the running emulator
  .\scripts\android_screens.ps1 shot 01-precision  # save the current screen

Shots land in release/google-play/emulator-<date>/<device>/<name>.png at the
emulator's exact resolution (1080x1920, 1440x2560, 1800x3200; all 9:16).
Build the capture APK first (all Classic levels open, test ads, debug only):
  .\scripts\flutter.ps1 build apk --debug --no-pub --target-platform android-x64 --dart-define=GILT_UNLOCK_ALL_LEVELS=true
#>
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [ValidateSet('setup', 'start', 'install', 'shot', 'stop')]
  [string]$Action,
  [Parameter(Position = 1)]
  [string]$Name
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$sdk = Join-Path $root '.tools\android-sdk'
$env:ANDROID_SDK_ROOT = $sdk
$env:ANDROID_HOME = $sdk
$env:ANDROID_AVD_HOME = Join-Path $root '.tools\android-avd'
$adb = Join-Path $sdk 'platform-tools\adb.exe'
$emulator = Join-Path $sdk 'emulator\emulator.exe'
$avdmanager = Get-ChildItem (Join-Path $sdk 'cmdline-tools') -Recurse -Filter avdmanager.bat | Select-Object -First 1
$image = 'system-images;android-36;google_apis;x86_64'

# id -> width, height, density (logical width 360 / 720 / 900 dp, as in the store renders)
$devices = [ordered]@{
  'phone'     = @(1080, 1920, 480)
  'tablet-7'  = @(1440, 2560, 320)
  'tablet-10' = @(1800, 3200, 320)
}
function AvdName($id) { "rollrise-$id" }

switch ($Action) {
  'setup' {
    New-Item -ItemType Directory -Force $env:ANDROID_AVD_HOME | Out-Null
    foreach ($id in $devices.Keys) {
      $w, $h, $dpi = $devices[$id]
      $avd = AvdName $id
      'no' | & $avdmanager.FullName create avd --force -n $avd -k $image | Out-Null
      $config = Join-Path $env:ANDROID_AVD_HOME "$avd.avd\config.ini"
      $settings = @{
        'hw.lcd.width' = $w; 'hw.lcd.height' = $h; 'hw.lcd.density' = $dpi
        'skin.name' = "${w}x$h"; 'skin.dynamic' = 'yes'
        'hw.keyboard' = 'yes'; 'hw.gpu.enabled' = 'yes'; 'hw.gpu.mode' = 'auto'
        'hw.ramSize' = 3072; 'disk.dataPartition.size' = '6G'
        'showDeviceFrame' = 'no'; 'hw.initialOrientation' = 'portrait'
      }
      $lines = Get-Content $config | Where-Object { $settings.Keys -notcontains ($_ -split '=', 2)[0].Trim() }
      $lines += $settings.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }
      Set-Content -Path $config -Value $lines -Encoding ascii
      "Created $avd (${w}x$h, $dpi dpi)"
    }
  }
  'start' {
    if (-not $devices.Contains($Name)) { throw "Use: start phone | tablet-7 | tablet-10" }
    Start-Process $emulator -ArgumentList @('-avd', (AvdName $Name), '-no-snapshot-save', '-no-boot-anim')
    "Starting $(AvdName $Name). Wait for the home screen, then run: install"
  }
  'install' {
    & $adb wait-for-device
    $apk = Join-Path $root 'build\app\outputs\flutter-apk\app-debug.apk'
    & $adb install -r $apk
    & $adb shell monkey -p com.giltarcade.balance_arcade -c android.intent.category.LAUNCHER 1 | Out-Null
    'Installed and launched.'
  }
  'shot' {
    if (-not $Name) { throw 'Give the shot a name, e.g. shot 01-precision' }
    $size = (& $adb shell wm size) -join ' '
    $id = $null
    foreach ($key in $devices.Keys) {
      $w, $h, $dpi = $devices[$key]
      if ($size -match "${w}x$h") { $id = $key }
    }
    if (-not $id) { throw "Running emulator is not one of the store sizes ($size)" }
    $folder = Join-Path $root ("release\google-play\emulator-{0:yyyy-MM-dd}\$id" -f (Get-Date))
    New-Item -ItemType Directory -Force $folder | Out-Null
    $remote = '/sdcard/rollrise-shot.png'
    & $adb shell screencap -p $remote
    $file = Join-Path $folder "$Name.png"
    & $adb pull $remote $file | Out-Null
    & $adb shell rm $remote
    "Saved $file"
  }
  'stop' { & $adb emu kill }
}
