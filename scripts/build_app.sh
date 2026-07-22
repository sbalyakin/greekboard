#!/bin/sh

set -eu

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
app_dir="$root_dir/output/Greekboard.app"
contents_dir="$app_dir/Contents"
xcode_developer_dir=${GREEKBOARD_XCODE_DEVELOPER_DIR:-/Applications/Xcode-26.5.0.app/Contents/Developer}

if [ ! -d "$xcode_developer_dir" ]; then
  echo "error: Xcode 26.5 not found at $xcode_developer_dir" >&2
  exit 1
fi

export DEVELOPER_DIR="$xcode_developer_dir"
export SWIFTPM_MODULECACHE_OVERRIDE="$root_dir/.build/ModuleCache"
export CLANG_MODULE_CACHE_PATH="$root_dir/.build/ModuleCache"
swift_executable=$(xcrun --find swift)

cd "$root_dir"
"$swift_executable" build \
  --disable-sandbox \
  -c release \
  --product GreekboardViewer \
  -Xswiftc -Xlinker \
  -Xswiftc -platform_version \
  -Xswiftc -Xlinker \
  -Xswiftc macos \
  -Xswiftc -Xlinker \
  -Xswiftc 14.0 \
  -Xswiftc -Xlinker \
  -Xswiftc 26.5
bin_dir=$("$swift_executable" build --disable-sandbox -c release --show-bin-path)

rm -rf "$app_dir"
mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"
ditto "$bin_dir/GreekboardViewer" "$contents_dir/MacOS/GreekboardViewer"
ditto "$root_dir/Packaging/Info.plist" "$contents_dir/Info.plist"

resource_bundle="$bin_dir/GreekboardViewer_GreekboardCore.bundle"
if [ -d "$resource_bundle" ]; then
  ditto "$resource_bundle" "$contents_dir/Resources/GreekboardViewer_GreekboardCore.bundle"
fi

# Stable identity keeps Accessibility / Input Monitoring across rebuilds.
# Ad-hoc ("-") changes CDHash every build → TCC treats the app as new.
if [ -n "${CODESIGN_IDENTITY:-}" ]; then
  identity=$CODESIGN_IDENTITY
else
  identity=$(
    security find-identity -v -p codesigning 2>/dev/null \
      | awk -F\" '/Apple Development|Developer ID Application/ { print $2; exit }'
  )
fi

if [ -z "${identity:-}" ]; then
  identity="-"
  echo "warning: no stable codesign identity; using ad-hoc. Accessibility/Input Monitoring will reset on each rebuild. Set CODESIGN_IDENTITY or install an Apple Development certificate." >&2
fi

codesign --force --deep --sign "$identity" "$app_dir"
echo "signed with: $identity"
echo "$app_dir"
