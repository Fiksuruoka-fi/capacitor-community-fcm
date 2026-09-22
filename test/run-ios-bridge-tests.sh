#!/usr/bin/env bash
set -euo pipefail

test_root="$(cd "$(dirname "$0")/.." && pwd)"
test_build="$(mktemp -d)"
trap 'rm -rf "$test_build"' EXIT

# Compile the actual bridge against local SDK doubles. No Firebase app is initialized.
for module in Capacitor FirebaseCore FirebaseMessaging FirebaseInstallations; do
  swiftc -module-cache-path "$test_build/cache" -emit-library -emit-module \
    -module-name "$module" "$test_root/test/ios/$module.swift" \
    -emit-module-path "$test_build/$module.swiftmodule" -o "$test_build/lib$module.dylib"
done
swiftc -module-cache-path "$test_build/cache" -I "$test_build" -L "$test_build" \
  -lCapacitor -lFirebaseCore -lFirebaseMessaging -lFirebaseInstallations \
  -Xlinker -rpath -Xlinker "$test_build" \
  "$test_root/ios/Plugin/Plugin.swift" "$test_root/test/ios/main.swift" -o "$test_build/bridge-tests"
"$test_build/bridge-tests"
