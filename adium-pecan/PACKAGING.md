# Packaging WLM (Pecan) for distribution (AdiumXtras)

The plugin is a `.AdiumLibpurplePlugin` bundle that embeds the msn-pecan
libpurple protocol plugin (built as a static lib) and wraps it for Adium.

## Compatibility

- **Adium 1.5.10.x**, **x86_64**, **libpurple 2.12.0**.
- The bundle links no third-party dylibs; ~371 symbols (purple/glib/Adium) are
  resolved from the host process at load (`-undefined dynamic_lookup`). It is
  therefore tied to that libpurple ABI — build against the headers matching the
  Adium release you target.
- x86_64-only is intentional: Adium ships no arm64 build. (For an arm64 host you
  would build a second slice and `lipo` them together.)

## Build inputs

- `ADIUM_SRC` — a checkout of https://github.com/adium/adium at the release tag
  you target (used only for headers; the installed app ships none).
- `PURPLE_INC` — `pidgin-2.12.0/libpurple` headers (from pidgin-2.12.0.tar.bz2).
- glib headers via `pkg-config` (Homebrew `glib`).

## Dev build (unsigned, for local testing)

```sh
# static prpl
make all STATIC=y CC='clang -arch x86_64' AR=ar GIO= \
  PURPLE_CFLAGS="-I$PURPLE_INC $(pkg-config --cflags glib-2.0 gobject-2.0 gmodule-2.0)" \
  PURPLE_LIBS= GIO_CFLAGS= GIO_LIBS=
# bundle
ADIUM_SRC=... PURPLE_INC=... adium-pecan/build.sh
# install
cp -R "adium-pecan/build/WLM (Pecan).AdiumLibpurplePlugin" \
   ~/Library/Application\ Support/Adium\ 2.0/PlugIns/
```

## Release build (signed + notarized, for shipping)

One-time notary credential setup:

```sh
xcrun notarytool store-credentials pecan-notary \
  --apple-id you@example.com --team-id TEAMID \
  --password <app-specific-password>   # appleid.apple.com → App-Specific Passwords
```

Then:

```sh
ADIUM_SRC=... PURPLE_INC=... \
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE=pecan-notary \
adium-pecan/package.sh
```

Produces `adium-pecan/dist/WLM-Pecan-Adium.zip` — stripped, Developer-ID signed,
notarized, and stapled. That is the file to upload.

Notes:
- Hardened runtime (`--options runtime`) is set only to satisfy notarization; it
  does not stop the bundle loading into Adium (the non-hardened host performs no
  library validation).
- Stapling lets it pass Gatekeeper offline after download (quarantine).

## Licensing (GPLv2 — required)

- msn-pecan is GPLv2. `build.sh` copies `COPYING` and a source pointer into the
  bundle's `Contents/Resources/`.
- `Info.plist` carries `NSHumanReadableCopyright` with the license + source URL.
- The AdiumXtras listing must link the corresponding source
  (https://github.com/s0rs/msn-pecan) to satisfy the "offer source"
  obligation for a binary distribution.

## AdiumXtras submission checklist

1. Bump `CFBundleShortVersionString` / `CFBundleVersion` in `Info.plist`.
2. Run `package.sh`; verify `xcrun stapler validate` passed.
3. Test the **downloaded** zip (with quarantine) on a clean Adium + fresh
   account — not just the dev drop-in.
4. Submit at adiumxtras.com → category **Plugin**: name, description, version,
   screenshot, GPL note + source link, upload the zip.
