#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGE_PATH="$ROOT_DIR/Release/com.apresley.DualScript.streamDeckPlugin"
MANIFEST_PATH="$ROOT_DIR/Sources/com.apresley.DualScript.sdPlugin/manifest.json"
BUILT_BINARY="$ROOT_DIR/.build/DerivedData/Build/Products/Release/DualScript"

"$ROOT_DIR/scripts/package.sh" --release

echo "Validating manifest..."
python3 -m json.tool "$MANIFEST_PATH" >/dev/null

echo "Checking packaged contents..."
unzip -l "$PACKAGE_PATH" | rg "com\\.apresley\\.DualScript\\.sdPlugin/(DualScript|manifest\\.json|index\\.html|inspector\\.js|css/dualscript\\.css|DualScriptIconIdle\\.png|DualScriptIconRunning\\.png|DualScriptIconError\\.png|DualScriptPluginIcon\\.png|DualScriptCategoryIcon\\.png)$"

echo "Built binary:"
file "$BUILT_BINARY"

echo "Package verification complete."
