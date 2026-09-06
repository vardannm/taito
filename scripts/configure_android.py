from pathlib import Path
p=Path('scripts/flutter.ps1');s=p.read_text(encoding='utf-8-sig')
s=s.replace("$env:PUB_CACHE = Join-Path $projectDirectory '.pub-cache'", """$env:PUB_CACHE = Join-Path $projectDirectory '.pub-cache'
$androidSdkDirectory = Join-Path $projectDirectory '.tools/android-sdk'
if (Test-Path -LiteralPath $androidSdkDirectory) { $env:ANDROID_HOME = $androidSdkDirectory }
$env:GRADLE_USER_HOME = Join-Path $projectDirectory '.tools/gradle-cache'""")
p.write_text(s,encoding='utf-8')
p=Path('android/app/src/main/AndroidManifest.xml');s=p.read_text().replace('android:label="balance_arcade"','android:label="GILT"').replace('@mipmap/ic_launcher','@drawable/gilt_icon').replace('android:launchMode="singleTop"','android:launchMode="singleTop"\n            android:screenOrientation="portrait"');p.write_text(s)
for name in ['values','values-night']:
    p=Path(f'android/app/src/main/res/{name}/styles.xml');s=p.read_text().replace('?android:colorBackground','#F2ECDD');p.write_text(s)
for name in ['drawable','drawable-v21']:
    p=Path(f'android/app/src/main/res/{name}/launch_background.xml');p.write_text('''<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
  <item><shape android:shape="rectangle"><solid android:color="#F2ECDD"/></shape></item>
</layer-list>
''')
