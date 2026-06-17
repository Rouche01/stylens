#!/bin/sh
# Strips geolocator_apple's requestAlwaysAuthorization code path from SPM builds.
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
IOS_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
PACKAGES_DIR="$IOS_DIR/Flutter/ephemeral/Packages/.packages"

if [ ! -d "$PACKAGES_DIR" ]; then
  echo "patch_geolocator_location_hardening: ephemeral packages not found (run flutter pub get / flutter build ios --config-only first)"
  exit 0
fi

GEOLocator_PACKAGE="$(find "$PACKAGES_DIR" -maxdepth 1 -name 'geolocator_apple-*' -print -quit)"

if [ -z "$GEOLocator_PACKAGE" ] || [ ! -e "$GEOLocator_PACKAGE/Package.swift" ]; then
  echo "patch_geolocator_location_hardening: geolocator Package.swift not found"
  exit 0
fi

if [ -L "$GEOLocator_PACKAGE" ]; then
  MATERIALIZED="${GEOLocator_PACKAGE}.materialized"
  rm -rf "$MATERIALIZED"
  mkdir -p "$MATERIALIZED"
  cp -R "$GEOLocator_PACKAGE/." "$MATERIALIZED/"
  rm "$GEOLocator_PACKAGE"
  mv "$MATERIALIZED" "$GEOLocator_PACKAGE"
fi

PACKAGE_SWIFT="$GEOLocator_PACKAGE/Package.swift"

if grep -q 'BYPASS_PERMISSION_LOCATION_ALWAYS' "$PACKAGE_SWIFT"; then
  exit 0
fi

/usr/bin/python3 - "$PACKAGE_SWIFT" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
content = path.read_text()
needle = '.headerSearchPath("include/geolocator_apple")\n            ]'
replacement = '.headerSearchPath("include/geolocator_apple"),\n                .define("BYPASS_PERMISSION_LOCATION_ALWAYS", to: "1"),\n            ]'

if needle not in content:
    raise SystemExit(f"patch_geolocator_location_hardening: unexpected Package.swift format in {path}")

path.write_text(content.replace(needle, replacement, 1))
print(f"patch_geolocator_location_hardening: applied BYPASS_PERMISSION_LOCATION_ALWAYS to {path}")
PY
