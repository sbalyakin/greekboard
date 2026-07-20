#!/bin/sh

set -eu

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
export SWIFTPM_MODULECACHE_OVERRIDE="$root_dir/.build/ModuleCache"
export CLANG_MODULE_CACHE_PATH="$root_dir/.build/ModuleCache"

cd "$root_dir"
swift test --disable-sandbox
