# Releasing

## One-time setup

1. Run `./scripts/generate-release-keys`. It creates a self-signed code-signing certificate and an Ed25519 key pair, writes `UpdatePublicKey` to `Info.plist`, and prints the values to add as GitHub Actions secrets. Commit the `Info.plist` change. Do not commit the private key or the p12.
2. Add these repository secrets:
   - `CODESIGN_CERT_P12`
   - `CODESIGN_CERT_PASSWORD`
   - `UPDATE_SIGNING_KEY`

## Release

Push a tag matching `vX.Y.Z`. The Release workflow validates the tag, stamps the version and build number, sets `UpdateEnabled` to true, imports the signing certificate, runs `make test`, builds and signs the universal DMG, signs it with the Ed25519 key, and uploads `EyeGuardian-X.Y.Z.dmg` and `EyeGuardian-X.Y.Z.dmg.sig`.

The workflow fails if a secret is missing, if the app is not signed with `EyeGuardian Release Signing`, or if the uploaded signature does not verify. It does not fall back to an ad-hoc signature.

## Local update smoke

`./scripts/update-smoke.sh` builds the DMG, signs it with a temporary key, verifies the signature, and runs `testUpdateDmgSmoke`. That test mounts the disk image and validates the app bundle without installing anything.

## Keys

Keep the p12 and the Ed25519 private key outside the repository. The public key in `Info.plist` is the trust anchor for update downloads. Rotating it requires shipping a release signed with the old key before the new key takes effect.
