#!/bin/bash
# Use standard SwiftPM with project-local build caches.
set -euo pipefail
cd "$(dirname "$0")/.."
task="${1:-build}"
if [ "$#" -gt 0 ]; then shift; fi
cache="$PWD/.build/local-cache"
mkdir -p "$cache"
export CLANG_MODULE_CACHE_PATH="$cache/clang"
export SWIFTPM_MODULECACHE_OVERRIDE="$CLANG_MODULE_CACHE_PATH"
exec swift "$task" --disable-sandbox --cache-path "$cache/swiftpm" \
    --config-path "$cache/config" --security-path "$cache/security" "$@"
