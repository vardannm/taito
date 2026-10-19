# Privacy policy deployment

Public URL: https://gilt-ead46.web.app/privacy-policy.html

Source: assets/privacy/policy.json. After edits, run scripts/privacy_policy.py,
copy release/privacy-policy.html to this directory as privacy-policy.html and
index.html, then deploy using scripts/firebase.ps1 with:

    deploy --only hosting --config firebase.privacy.json --project gilt-ead46

Verified public HTTP 200 on 19 October 2026. Current policy describes the current
sample-ad and analytics implementation; review it when those behaviors change.
