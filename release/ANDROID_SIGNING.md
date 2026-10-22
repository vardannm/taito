# Android upload signing and release bundle

Configured 23 October 2026 for `com.giltarcade.balance_arcade`.

## Signing files

- Upload keystore: `android/keystore/rollrise-upload.jks`
- Alias: `upload`
- Local credentials: `android/key.properties`
- Public certificate: `artifacts/rollrise-upload-certificate.pem`

The keystore is a 3,072-bit RSA upload key with a SHA256withRSA certificate,
valid until 10 March 2054. Both the keystore and credential file are ignored
by Git. Passwords were generated securely and are stored only in the local
ignored properties file; they were not printed in the conversation.

**Back up both private signing files securely outside this checkout** before
reinstalling Windows, moving computers or deleting the project. Keep the
passwords in a password manager or encrypted backup. The Git repository and
the public certificate do not contain enough information to restore this key.
On another computer, restore the keystore to the same relative location and
restore `android/key.properties`, or update its `storeFile` path accordingly.

The upload certificate's SHA-256 fingerprint is:

```text
F3:A3:6E:4F:DC:DC:BD:61:A5:E6:02:55:16:49:47:8E:33:D3:E6:DA:30:2B:9B:1C:15:50:88:65:6E:02:15:64
```

Use Play App Signing when the app is created in Play Console. The local
upload key signs submissions; Google's app-signing key is a separate key
used to sign the APKs delivered to players.

`scripts/setup_android_signing.ps1` creates signing files only when neither
exists. It refuses to overwrite an existing key or credentials. Do not rerun
it to replace this key for routine updates.

## Built artifact

```powershell
.\scripts\flutter.ps1 build appbundle --release --no-pub
```

The new bundle is at:

```text
build/app/outputs/bundle/release/app-release.aab
```

- Version: `0.13.6+24`
- Size: 61,645,982 bytes (58.8 MiB)
- Application ID: `com.giltarcade.balance_arcade`
- Minimum API: 24; target/compile API: 36
- Architectures: ARM64, ARMv7 and x86-64
- SHA-256: `d602cbfbad4ca79076080792eefdf223b1df3923dc98c7cc347ebb8912b27b61`

Validation completed:

- Gradle release bundle build succeeded using the configured upload key.
- `jarsigner -verify` returned `jar verified`.
- The signer certificate in the bundle matches the upload certificate above.
- ZIP integrity passed, and the bundled manifest has the intended package,
  version and API target.
- Every ARM64/x86-64 ELF load segment has at least 16 KB alignment. This checks
  the native libraries, not final device performance or every generated split.

Local evidence:

- `artifacts/android-release-bundle-2026-10-23.log`
- `artifacts/android-release-signature-2026-10-23.log`
- `artifacts/android-release-bundle-validation-2026-10-23.json`
- `artifacts/android-release-bundle-2026-10-23.sha256`

This is a signed **testing candidate**, not a production sign-off. It retains
the existing Google sample ad IDs and lacks the planned in-app UMP consent
integration. The nine regression failures from the launch audit were resolved
later on 23 October through test-fixture updates; the full suite now passes
all 743 tests. Gameplay code did not change, so this bundle was not rebuilt.
Native device testing and Play account/listing setup remain necessary.

The build emitted future Kotlin-plugin migration and SDK XML-tooling warnings,
but completed successfully. The upload certificate is self-signed; Java's
generic certificate-chain/timestamp warnings do not mean the bundle is unsigned.

See the [Flutter Android release guide](https://docs.flutter.dev/deployment/android).
