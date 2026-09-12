#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/module-cache
xcrun swiftc -swift-version 5 -module-cache-path "$PWD/.build/module-cache" Sources/Geometry.swift Sources/UCGeometry.swift Sources/Preferences.swift Tests/GeometryTests.swift -o .build/geometry-tests
.build/geometry-tests
