#!/bin/sh
set -eu

PRODUCTS_DIR="${BUILT_PRODUCTS_DIR:-}"
APP_PATH="$PRODUCTS_DIR/AutoFocus.app"

if [ -z "$PRODUCTS_DIR" ] || [ ! -d "$APP_PATH" ]; then
    echo "The manager app was not found in BUILT_PRODUCTS_DIR." >&2
    exit 1
fi

mkdir -p "$APP_PATH/Contents/Resources"
cp "$PRODUCTS_DIR/eventkit-focusmode-agent" \
    "$APP_PATH/Contents/Resources/eventkit-focusmode-agent"
cp "$PRODUCTS_DIR/libdonotdisturbd-patch.dylib" \
    "$APP_PATH/Contents/Resources/libdonotdisturbd-patch.dylib"
chmod 755 "$APP_PATH/Contents/Resources/eventkit-focusmode-agent"

OUTPUT_APP="$PROJECT_DIR/Products/AutoFocus.app"
mkdir -p "$PROJECT_DIR/Products"
rm -rf "$OUTPUT_APP"
cp -R "$APP_PATH" "$OUTPUT_APP"

echo "Embedded agent and Squid tweak in $APP_PATH"
echo "Copied complete app to $OUTPUT_APP"
