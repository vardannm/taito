from pathlib import Path
import json
p = Path('ios/Runner/Info.plist')
s = p.read_text().replace('<string>Balance Arcade</string>', '<string>GILT</string>')
s = s.replace('<string>balance_arcade</string>', '<string>GILT</string>')
p.write_text(s)
p = Path('web/manifest.json')
m = json.loads(p.read_text()); m.update(name='GILT — Precision Arcade', short_name='GILT', background_color='#F2ECDD', theme_color='#F2ECDD', description='Ten holes. Two thumbs. Steady nerves.')
p.write_text(json.dumps(m, indent=2))

