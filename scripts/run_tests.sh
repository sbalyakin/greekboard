#!/bin/sh

set -eu

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
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
"$swift_executable" test \
  --disable-sandbox \
  -Xswiftc -Xlinker \
  -Xswiftc -platform_version \
  -Xswiftc -Xlinker \
  -Xswiftc macos \
  -Xswiftc -Xlinker \
  -Xswiftc 14.0 \
  -Xswiftc -Xlinker \
  -Xswiftc 26.5
