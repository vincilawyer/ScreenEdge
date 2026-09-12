#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/build.sh
APP="build/跨屏边缘.app"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")
ARCH=$(lipo -archs "$APP/Contents/MacOS/ScreenEdge")
case "$ARCH" in arm64|x86_64) ;; *) printf 'Unsupported archive architecture: %s\n' "$ARCH" >&2; exit 1 ;; esac
NAME="ScreenEdge-${VERSION}-macOS-${ARCH}.zip"
mkdir -p dist
# Set the ZIP UTF-8 filename flag so Chinese app names survive different unzip tools.
# ZipFile preserves executable permission bits, without Finder metadata or extended attributes.
python3 - "$APP" "dist/$NAME" <<'PY'
from pathlib import Path
import sys
import zipfile

app, archive = map(Path, sys.argv[1:])
with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as output:
    for path in [app, *sorted(app.rglob("*"))]:
        if path.is_symlink():
            raise SystemExit("Unexpected symlink in app bundle")
        output.write(path, path.relative_to(app.parent).as_posix())
PY
(cd dist && shasum -a 256 "$NAME" > "$NAME.sha256")
printf 'Packaged: %s/dist/%s\n' "$PWD" "$NAME"
