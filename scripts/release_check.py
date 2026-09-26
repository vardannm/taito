"""Read-only release preflight. Reports blockers without altering testing settings."""
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[1]
blockers = []
profile = (root / "lib/profile.dart").read_text(encoding="utf-8")
if re.search(r"wallet\s*=\s*99999", profile):
    blockers.append("Remove the temporary 99,999-coin override from the normal economy before store release.")
if not (root / "android/key.properties").is_file():
    blockers.append("Android upload signing is not configured; local APKs use development signing.")
ios = (root / "ios/Runner.xcodeproj/project.pbxproj").read_text(encoding="utf-8")
if not re.search(r"DEVELOPMENT_TEAM\s*=\s*[A-Z0-9]+;", ios):
    blockers.append("Set the iOS signing team on the release Mac and verify the registered bundle ID.")
for message in blockers:
    print("BLOCKED: " + message)
print("MANUAL: Check release/DEVICE_QA.md, store identity/support details, privacy disclosures, and real-player results.")
print("Online rankings/cloud deployment remain pending backend configuration; do not advertise them as live.")
sys.exit(1 if blockers else 0)
