"""Render the bundled policy for hosting, or check privacy release prerequisites."""
import argparse
import html
import json
import plistlib
import re
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
POLICY_PATH = ROOT / "assets/privacy/policy.json"


def release_blockers():
    policy = json.loads(POLICY_PATH.read_text(encoding="utf-8"))
    errors = []
    if not policy["publisher"].strip():
        errors.append("Set the privacy-policy publisher in assets/privacy/policy.json.")
    if not re.fullmatch(r"[^\s@]+@[^\s@]+\.[^\s@]+", policy["contactEmail"]):
        errors.append("Set a real public privacy-contact email in assets/privacy/policy.json.")
    url = urlsplit(policy["publicUrl"])
    if url.scheme != "https" or not url.netloc or url.username or url.password:
        errors.append("Set the published HTTPS privacy-policy URL in assets/privacy/policy.json.")
    manifest = ROOT / "ios/Runner/PrivacyInfo.xcprivacy"
    try:
        data = plistlib.loads(manifest.read_bytes())
        user_defaults = next(item for item in data["NSPrivacyAccessedAPITypes"]
                             if item["NSPrivacyAccessedAPIType"] == "NSPrivacyAccessedAPICategoryUserDefaults")
        if "CA92.1" not in user_defaults["NSPrivacyAccessedAPITypeReasons"]:
            errors.append("The app privacy manifest must declare its app-owned UserDefaults reason.")
    except (OSError, ValueError, KeyError, TypeError, StopIteration):
        errors.append("The app privacy manifest is missing or invalid.")
    project = (ROOT / "ios/Runner.xcodeproj/project.pbxproj").read_text(encoding="utf-8")
    resources = re.search(r"97C146EC1CF9000F007C117D /\* Resources \*/ = \{(.*?)\n\s*\};", project, re.S)
    if not resources or "PrivacyInfo.xcprivacy in Resources" not in resources[1]:
        errors.append("Include the app privacy manifest in Runner's Resources build phase.")
    return errors


def render():
    policy = json.loads(POLICY_PATH.read_text(encoding="utf-8"))
    escape = html.escape
    blocks = []
    draft = not policy["publisher"] or not policy["contactEmail"] or not policy["publicUrl"]
    if draft:
        blocks.append('<aside>Draft for review. Publisher, privacy contact, and public URL are pending. Do not publish this draft as the final policy.</aside>')
    blocks.append(f'<h1>{escape(policy["title"])}</h1><p class="date">Updated {escape(policy["updated"])}</p>')
    if policy["publisher"]:
        blocks.append(f'<p>Publisher: {escape(policy["publisher"])}</p>')
    for section in policy["sections"]:
        blocks.append(f'<section><h2>{escape(section["title"])}</h2><p>{escape(section["body"])}</p></section>')
    if policy["contactEmail"]:
        email = escape(policy["contactEmail"], quote=True)
        blocks.append(f'<section><h2>Privacy contact</h2><p><a href="mailto:{email}">{email}</a></p></section>')
    links = "".join(f'<li><a href="{escape(item["url"], quote=True)}">{escape(item["title"])}</a></li>' for item in policy["references"])
    blocks.append(f'<section><h2>Learn more</h2><ul>{links}</ul></section>')
    document = """<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>GILT Privacy Policy</title><style>
body{margin:0;background:#102b2b;color:#f1eedf;font:17px/1.65 system-ui,sans-serif}
main{max-width:760px;margin:auto;padding:48px 24px}h1{font-size:36px;line-height:1.2}
h2{font-size:23px;color:#d5ad63;margin-top:32px}a{color:#9edbc6;overflow-wrap:anywhere}
.date{color:#a9b9b5}aside{padding:16px;border:1px solid #d5ad63;border-radius:12px}
@media(max-width:480px){main{padding:24px 20px}h1{font-size:29px}}
</style></head><body><main>""" + "\n".join(blocks) + "</main></body></html>\n"
    target = ROOT / "release/privacy-policy.html"
    target.write_text(document, encoding="utf-8")
    print(f"Rendered {target.relative_to(ROOT)}" + (" (draft)" if draft else ""))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Read-only release prerequisites check")
    args = parser.parse_args()
    if args.check:
        errors = release_blockers()
        for error in errors:
            print("BLOCKED: " + error)
        print("MANUAL: Verify the hosted policy, final SDK Privacy Report, and App Store answers; see release/APP_PRIVACY.md.")
        raise SystemExit(1 if errors else 0)
    render()
