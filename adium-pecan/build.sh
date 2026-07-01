#!/bin/bash -eu
#
# Build the WLM (Pecan) Adium plugin bundle.
#
# Needs:
#   - libmsn-pecan.a   built in the repo root with: make STATIC=y (x86_64)
#   - Adium source tree (for headers, since the installed app ships none)
#   - pidgin 2.12.0 libpurple headers
#   - glib headers (Homebrew)
#
# Override these with env vars if your paths differ.

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"

: "${ADIUM_SRC:?Set ADIUM_SRC to a checkout of github.com/adium/adium}"
: "${PURPLE_INC:?Set PURPLE_INC to pidgin-2.12.0/libpurple}"

STATIC_LIB="$REPO/libmsn-pecan.a"
[ -f "$STATIC_LIB" ] || { echo "Missing $STATIC_LIB — run 'make STATIC=y' in repo root"; exit 1; }

GLIB_CFLAGS="$(pkg-config --cflags glib-2.0 gobject-2.0 gmodule-2.0)"

BUILD="$HERE/build"
rm -rf "$BUILD"
mkdir -p "$BUILD/obj"

# Framework-style header umbrella so <Adium/..>, <AdiumLibpurple/..>,
# <AIUtilities/..> resolve against the source tree. The real frameworks
# flatten headers from nested source subdirs into one directory, so we do
# the same by symlinking every .h into a flat umbrella subdir.
UMB="$BUILD/umbrella"
flatten() {  # <dest-subdir> <source-root>
	local dest="$UMB/$1" root="$2"
	mkdir -p "$dest"
	find "$root" -name '*.h' -print0 | while IFS= read -r -d '' h; do
		ln -sfn "$h" "$dest/$(basename "$h")"
	done
}
# The <Adium/..> namespace aggregates headers from both the framework source
# and the top-level application Source directory.
flatten Adium          "$ADIUM_SRC/Frameworks/Adium/Source"
flatten Adium          "$ADIUM_SRC/Source"
flatten AIUtilities    "$ADIUM_SRC/Frameworks/AIUtilities/Source"
flatten AdiumLibpurple "$ADIUM_SRC/Plugins/Purple Service"

# Adium references libpurple as a framework: <libpurple/...>. pidgin's source
# lays the headers out flat with the umbrella named purple.h, so mirror them
# under umbrella/libpurple and add a libpurple.h shim.
flatten libpurple      "$PURPLE_INC"
echo '#include <purple.h>' > "$UMB/libpurple/libpurple.h"

CC=(clang -arch x86_64)
CFLAGS=(-fobjc-exceptions -Wall -Wno-deprecated-declarations
  -I"$UMB"
  -I"$ADIUM_SRC/Plugins/Purple Service"
  -I"$ADIUM_SRC/Frameworks/Adium/Source"
  -I"$ADIUM_SRC/Frameworks/AIUtilities/Source"
  -I"$PURPLE_INC"
  $GLIB_CFLAGS)

for src in PecanAccount PecanService PecanPlugin; do
	echo "   CC   $src.m"
	"${CC[@]}" "${CFLAGS[@]}" -c "$HERE/$src.m" -o "$BUILD/obj/$src.o"
done

echo "   LINK Pecan"
"${CC[@]}" -bundle -undefined dynamic_lookup \
	-o "$BUILD/Pecan" \
	"$BUILD/obj/"*.o \
	"$STATIC_LIB" \
	-framework Cocoa

# Optional release strip: drop local/debug symbols but KEEP the ~371 undefined
# symbols the host (Adium/purple/glib) resolves at load. `strip -x` is safe here.
if [ "${STRIP:-}" = "1" ]; then
	strip -x "$BUILD/Pecan"
fi

# Assemble the .AdiumLibpurplePlugin bundle.
BUNDLE="$BUILD/WLM (Pecan).AdiumLibpurplePlugin"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$HERE/Info.plist" "$BUNDLE/Contents/Info.plist"
cp "$BUILD/Pecan" "$BUNDLE/Contents/MacOS/Pecan"

# GPLv2 requires the license travel with the binary. Bundle it (plus a source
# pointer) into Resources so it ships inside the .AdiumLibpurplePlugin.
cp "$REPO/COPYING" "$BUNDLE/Contents/Resources/COPYING"
cat > "$BUNDLE/Contents/Resources/README.txt" <<'TXT'
WLM (Pecan) — MSN/WLM (Escargot) protocol plugin for Adium
==========================================================

Embeds the msn-pecan libpurple protocol plugin (a derivative work of libpurple's
MSN support) as a static library, wrapped for Adium.

License: GNU General Public License, version 2 (see COPYING).
Source code (required by the GPL): https://github.com/s0rs/msn-pecan

Requirements: Adium 1.5.10.x (x86_64, libpurple 2.12.0).

Install: quit Adium, copy this .AdiumLibpurplePlugin into
  ~/Library/Application Support/Adium 2.0/PlugIns/
then relaunch Adium and add a new account of type "WLM (Escargot)".
TXT

echo "Built: $BUNDLE"
file "$BUNDLE/Contents/MacOS/Pecan"
