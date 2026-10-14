#!/bin/sh
set -eu

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
SQUID_ROOT="${SQUID_ROOT:-$PROJECT_ROOT/../Squid}"
DERIVED_DATA="${SQUID_DERIVED_DATA:-$PROJECT_ROOT/.squid-derived-data}"
CONFIGURATION="${SQUID_CONFIGURATION:-Release}"
SQUID_PROJECT="$SQUID_ROOT/Squid.xcodeproj"
PRODUCTS_DIR="$DERIVED_DATA/Build/Products/$CONFIGURATION"
LIBSQUID_PATH="${LIBSQUID_PATH:-$PRODUCTS_DIR/liblibsquid.dylib}"

# Xcode can pass an iPhone deployment target into scheme actions. Prevent it
# from conflicting with Squid's macOS build settings.
unset IPHONEOS_DEPLOYMENT_TARGET
unset TVOS_DEPLOYMENT_TARGET
unset WATCHOS_DEPLOYMENT_TARGET
unset XROS_DEPLOYMENT_TARGET
unset DRIVERKIT_DEPLOYMENT_TARGET

if [ -f "$LIBSQUID_PATH" ]; then
    echo "Using existing Squid library: $LIBSQUID_PATH"
    exit 0
fi

if [ ! -d "$SQUID_PROJECT" ]; then
    echo "Unable to find Squid at $SQUID_PROJECT." >&2
    echo "Set SQUID_ROOT to the Squid project directory." >&2
    exit 1
fi

for scheme in libsquid; do
    xcodebuild \
        -project "$SQUID_PROJECT" \
        -scheme "$scheme" \
        -configuration "$CONFIGURATION" \
        -derivedDataPath "$DERIVED_DATA" \
        build
done

if [ ! -f "$LIBSQUID_PATH" ]; then
    echo "liblibsquid.dylib was not generated at $LIBSQUID_PATH." >&2
    exit 1
fi

echo "Using separate Squid library: $LIBSQUID_PATH"
