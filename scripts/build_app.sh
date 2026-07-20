#!/bin/sh

set -eu

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
app_dir="$root_dir/output/Greekboard.app"
contents_dir="$app_dir/Contents"

export SWIFTPM_MODULECACHE_OVERRIDE="$root_dir/.build/ModuleCache"
export CLANG_MODULE_CACHE_PATH="$root_dir/.build/ModuleCache"

cd "$root_dir"
swift build --disable-sandbox -c release --product GreekKeyboardViewer
bin_dir=$(swift build --disable-sandbox -c release --show-bin-path)

rm -rf "$app_dir"
mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"
ditto "$bin_dir/GreekKeyboardViewer" "$contents_dir/MacOS/GreekKeyboardViewer"
ditto "$root_dir/Packaging/Info.plist" "$contents_dir/Info.plist"

resource_bundle="$bin_dir/GreekKeyboardViewer_GreekKeyboardCore.bundle"
if [ -d "$resource_bundle" ]; then
  ditto "$resource_bundle" "$contents_dir/Resources/GreekKeyboardViewer_GreekKeyboardCore.bundle"
fi

codesign --force --deep --sign - "$app_dir"
echo "$app_dir"
