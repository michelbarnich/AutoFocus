#!/bin/sh
set -eu

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
PACKAGE_ROOT="$PROJECT_ROOT/package"
DERIVED_DATA="${DERIVED_DATA:-$PROJECT_ROOT/.package-derived-data}"
OUTPUT_DIR="${OUTPUT_DIR:-$PROJECT_ROOT/Products}"
VERSION="${VERSION:-1.0.0}"
CONFIGURATION="${CONFIGURATION:-Release}"
PROJECT_FILE="${PROJECT_FILE:-}"

if [ -z "$PROJECT_FILE" ]; then
    PROJECT_FILE="$(find "$PROJECT_ROOT" -maxdepth 1 -name '*.xcodeproj' -print -quit)"
fi

if [ -z "$PROJECT_FILE" ] || [ ! -d "$PROJECT_FILE" ]; then
    echo "Unable to locate the Xcode project. Set PROJECT_FILE explicitly." >&2
    exit 1
fi

CONFIGURATION="$CONFIGURATION" sh "$PACKAGE_ROOT/build-squid-products.sh"

xcodebuild -project "$PROJECT_FILE" -scheme eventkit-focusmode-daemon -configuration "$CONFIGURATION" -derivedDataPath "$DERIVED_DATA" build
xcodebuild -project "$PROJECT_FILE" -scheme donotdisturbd-patch -configuration "$CONFIGURATION" -derivedDataPath "$DERIVED_DATA" build
xcodebuild -project "$PROJECT_FILE" -scheme FocusModeCalendarController -configuration "$CONFIGURATION" -derivedDataPath "$DERIVED_DATA" build

PRODUCTS="$DERIVED_DATA/Build/Products/$CONFIGURATION"
APP_OUTPUT="$OUTPUT_DIR/AutoFocus.app"

mkdir -p "$OUTPUT_DIR"
rm -rf "$APP_OUTPUT"
cp -R "$PRODUCTS/AutoFocus.app" "$APP_OUTPUT"
mkdir -p "$APP_OUTPUT/Contents/Resources"
cp "$PRODUCTS/eventkit-focusmode-agent" \
    "$APP_OUTPUT/Contents/Resources/eventkit-focusmode-agent"
cp "$PRODUCTS/libdonotdisturbd-patch.dylib" \
    "$APP_OUTPUT/Contents/Resources/libdonotdisturbd-patch.dylib"
chmod 755 "$APP_OUTPUT/Contents/Resources/eventkit-focusmode-agent"

echo "Created $APP_OUTPUT"
