"""Read-only release preflight. Reports blockers without altering testing settings."""
from pathlib import Path
import re
import sys
from privacy_policy import release_blockers
from coin_release_check import testing_coin_blockers

root = Path(__file__).resolve().parents[1]
blockers = []
blockers.extend(release_blockers())
profile = (root / "lib/profile.dart").read_text(encoding="utf-8")
main = (root / "lib/main.dart").read_text(encoding="utf-8")
blockers.extend(testing_coin_blockers(profile, main))
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
