#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/Sources/DualScript.xcodeproj"
PLUGIN_SOURCE_DIR="$ROOT_DIR/Sources/com.apresley.DualScript.sdPlugin"
BUILD_ROOT="$ROOT_DIR/.build"
DERIVED_DATA_PATH="$BUILD_ROOT/DerivedData"
STAGING_ROOT="$BUILD_ROOT/package"
STAGING_PLUGIN_DIR="$STAGING_ROOT/com.apresley.DualScript.sdPlugin"
OUTPUT_DIR="$ROOT_DIR/Release"
OUTPUT_PACKAGE="$OUTPUT_DIR/com.apresley.DualScript.streamDeckPlugin"
BUILD_LOG_PATH="$BUILD_ROOT/xcodebuild.log"
KEY_ART_TOOL="$BUILD_ROOT/generate_key_art"

CONFIGURATION="Release"
INSTALL_AFTER_BUILD=0

usage() {
    cat <<'EOF'
Usage: ./scripts/package.sh [--debug|--release] [--install]

  --debug    Build the Debug configuration
  --release  Build the Release configuration (default)
  --install  Open the generated .streamDeckPlugin installer after packaging
EOF
}

while (($# > 0)); do
    case "$1" in
        --debug)
            CONFIGURATION="Debug"
            ;;
        --release)
            CONFIGURATION="Release"
            ;;
        --install)
            INSTALL_AFTER_BUILD=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
    shift
done

mkdir -p "$BUILD_ROOT" "$OUTPUT_DIR"
rm -rf "$DERIVED_DATA_PATH" "$STAGING_ROOT"

echo "Generating Stream Deck key art..."
swiftc -framework AppKit "$ROOT_DIR/scripts/generate_key_art.swift" -o "$KEY_ART_TOOL"
"$KEY_ART_TOOL" "$PLUGIN_SOURCE_DIR"

echo "Building $CONFIGURATION plugin binary..."
if ! xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme RunDualScript \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    build >"$BUILD_LOG_PATH" 2>&1; then
    cat "$BUILD_LOG_PATH" >&2
    exit 1
fi

BUILT_BINARY="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/DualScript"
if [[ ! -x "$BUILT_BINARY" ]]; then
    echo "Built executable not found at: $BUILT_BINARY" >&2
    exit 1
fi

echo "Staging Stream Deck bundle..."
mkdir -p "$STAGING_ROOT"
ditto "$PLUGIN_SOURCE_DIR" "$STAGING_PLUGIN_DIR"
cp "$BUILT_BINARY" "$STAGING_PLUGIN_DIR/DualScript"
chmod +x "$STAGING_PLUGIN_DIR/DualScript"

echo "Creating installer..."
rm -f "$OUTPUT_PACKAGE"
ditto -c -k --sequesterRsrc --keepParent "$STAGING_PLUGIN_DIR" "$OUTPUT_PACKAGE"

echo "Created: $OUTPUT_PACKAGE"

if (( INSTALL_AFTER_BUILD )); then
    echo "Opening installer..."
    open "$OUTPUT_PACKAGE"
fi
