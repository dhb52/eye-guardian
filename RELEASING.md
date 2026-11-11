# Releasing

## One-time setup

1. Run `./scripts/generate-release-keys`. It creates a self-signed code-signing certificate and an Ed25519 key pair, writes `UpdatePublicKey` to `Info.plist`, and prints the values to add as GitHub Actions secrets. Commit the `Info.plist` change. Do not commit the private key or the p12.
2. Add these repository secrets:
   - `CODESIGN_CERT_P12`
   - `CODESIGN_CERT_PASSWORD`
   - `UPDATE_SIGNING_KEY`

## Release

Push a tag matching `vX.Y.Z`. The Release workflow validates the tag, stamps the version and build number, sets `UpdateEnabled` to true, imports the signing certificate, runs `make test`, builds and signs the universal DMG, signs it with the Ed25519 key, and uploads `EyeGuardian-X.Y.Z.dmg` and `EyeGuardian-X.Y.Z.dmg.sig` to a **draft** release whose body is GitHub's generated commit list.

The workflow fails if a secret is missing, if the app is not signed with `EyeGuardian Release Signing`, or if the uploaded signature does not verify. It does not fall back to an ad-hoc signature. Re-running it on a draft replaces the assets and leaves the body alone; on a published release it changes nothing.

Then run, from the repository root:

```sh
./scripts/publish-release-notes vX.Y.Z
```

That writes `build/release-notes-vX.Y.Z-prompt.md` containing the draft body and the rewrite instructions. Feed the prompt to an LLM, save its Chinese Markdown output, and publish:

```sh
./scripts/publish-release-notes vX.Y.Z build/release-notes-vX.Y.Z-summary.md
```

The script appends `.github/release-note-footer.md` and the `**Full Changelog**` compare link, then runs `gh release edit --draft=false --latest`. Drafts are invisible to `releases/latest`, so the app keeps offering the previous version until this step runs. If it fails, the release stays a draft; re-run the same command.

## Local update smoke

`./scripts/update-smoke.sh` builds the DMG, signs it with a temporary key, verifies the signature, and runs `testUpdateDmgSmoke`. That test mounts the disk image and validates the app bundle without installing anything.

## Keys

Keep the p12 and the Ed25519 private key outside the repository. The public key in `Info.plist` is the trust anchor for update downloads. Rotating it requires shipping a release signed with the old key before the new key takes effect.
