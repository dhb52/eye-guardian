# Release rules

- The app version lives in `Info.plist`.
- Before pushing a `vX.Y.Z` tag, set `CFBundleShortVersionString` to `X.Y.Z` and commit it.
- The Release workflow rejects a tag that does not match `Info.plist`.
- Do not add a separate `VERSION` file; local `make dmg` uses the committed `Info.plist`.
