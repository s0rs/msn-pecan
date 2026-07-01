#!/bin/bash -eu
#
# Release-package the WLM (Pecan) Adium plugin: build → strip → codesign →
# notarize → staple → zip, producing a distributable .zip for AdiumXtras.
#
# Prerequisites (one-time):
#   - Xcode command line tools (codesign, notarytool, stapler).
#   - A "Developer ID Application" certificate in your login keychain.
#   - A stored notarytool credential profile, created once with:
#       xcrun notarytool store-credentials pecan-notary \
#         --apple-id you@example.com --team-id TEAMID \
#         --password <app-specific-password>
#
# Required env:
#   ADIUM_SRC       checkout of github.com/adium/adium (matching the target release)
#   PURPLE_INC      pidgin-2.12.0/libpurple headers
#   SIGN_IDENTITY   e.g. "Developer ID Application: Your Name (TEAMID)"
#   NOTARY_PROFILE  the notarytool keychain profile name (e.g. pecan-notary)
#
# Usage:  ADIUM_SRC=... PURPLE_INC=... SIGN_IDENTITY="..." NOTARY_PROFILE=pecan-notary ./package.sh

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"

: "${ADIUM_SRC:?Set ADIUM_SRC}"
: "${PURPLE_INC:?Set PURPLE_INC}"
: "${SIGN_IDENTITY:?Set SIGN_IDENTITY to your Developer ID Application identity}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to your stored notarytool credential profile}"

BUNDLE_NAME="WLM (Pecan).AdiumLibpurplePlugin"
BUNDLE="$HERE/build/$BUNDLE_NAME"
DIST="$HERE/dist"
GLIB_CFLAGS="$(pkg-config --cflags glib-2.0 gobject-2.0 gmodule-2.0)"

echo "==> Building static prpl (x86_64, release)"
make -C "$REPO" clean >/dev/null 2>&1 || true
make -C "$REPO" all STATIC=y CC='clang -arch x86_64' AR=ar GIO= \
	PURPLE_CFLAGS="-I$PURPLE_INC $GLIB_CFLAGS" \
	PURPLE_LIBS= GIO_CFLAGS= GIO_LIBS=

echo "==> Building + stripping the Adium bundle"
STRIP=1 ADIUM_SRC="$ADIUM_SRC" PURPLE_INC="$PURPLE_INC" "$HERE/build.sh"

echo "==> Code signing (Developer ID, hardened runtime, secure timestamp)"
# Sign the nested Mach-O, then the bundle. --options runtime is required for
# notarization; it does not prevent loading into Adium (the non-hardened host
# process performs no library validation).
codesign --force --timestamp --options runtime \
	--sign "$SIGN_IDENTITY" "$BUNDLE/Contents/MacOS/Pecan"
codesign --force --timestamp --options runtime \
	--sign "$SIGN_IDENTITY" "$BUNDLE"
codesign --verify --strict --verbose=2 "$BUNDLE"

echo "==> Zipping for notarization"
mkdir -p "$DIST"
ZIP="$DIST/WLM-Pecan-Adium.zip"
rm -f "$ZIP"
/usr/bin/ditto -c -k --keepParent "$BUNDLE" "$ZIP"

echo "==> Submitting to the notary service (waits for result)"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Stapling the ticket to the bundle"
xcrun stapler staple "$BUNDLE"
xcrun stapler validate "$BUNDLE"

echo "==> Re-zipping the stapled bundle for distribution"
rm -f "$ZIP"
/usr/bin/ditto -c -k --keepParent "$BUNDLE" "$ZIP"

echo
echo "Done. Distributable (signed + notarized + stapled):"
echo "  $ZIP"
echo "Upload that zip to AdiumXtras (category: Plugin)."
