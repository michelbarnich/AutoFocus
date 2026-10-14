#!/bin/sh
set -eu

PACKAGE_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
INSTALL_ROOT="$HOME/Library/Application Support/EventKitFocusModeAgent"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
LAUNCH_AGENT_ID="com.michelbarnich.eventkit-focusmode-agent"
LAUNCH_AGENT_PLIST="$LAUNCH_AGENTS_DIR/$LAUNCH_AGENT_ID.plist"
SQUID_DIR="$HOME/.squid"
SQUID_MANIFEST="$SQUID_DIR/$LAUNCH_AGENT_ID.plist"
AGENT_PATH="$INSTALL_ROOT/bin/eventkit-focusmode-agent"
TWEAK_PATH="$INSTALL_ROOT/bin/libdonotdisturbd-patch.dylib"
MANAGER_PATH="$INSTALL_ROOT/AutoFocus.app"
TARGET_BUNDLE_ID="${SQUID_TARGET_BUNDLE_ID:-com.apple.donotdisturbd}"

if [ ! -x "$PACKAGE_ROOT/bin/eventkit-focusmode-agent" ]; then
    echo "Missing agent binary in package." >&2
    exit 1
fi
if [ ! -f "$PACKAGE_ROOT/bin/libdonotdisturbd-patch.dylib" ]; then
    echo "Missing Squid tweak in package." >&2
    exit 1
fi
if [ ! -d "$PACKAGE_ROOT/apps/AutoFocus.app" ]; then
    echo "Missing manager app in package." >&2
    exit 1
fi

mkdir -p "$INSTALL_ROOT/bin" "$LAUNCH_AGENTS_DIR" "$SQUID_DIR"
cp "$PACKAGE_ROOT/bin/eventkit-focusmode-agent" "$AGENT_PATH"
cp "$PACKAGE_ROOT/bin/libdonotdisturbd-patch.dylib" "$TWEAK_PATH"
rm -rf "$MANAGER_PATH"
cp -R "$PACKAGE_ROOT/apps/AutoFocus.app" "$MANAGER_PATH"
chmod 755 "$AGENT_PATH"

cat > "$LAUNCH_AGENT_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LAUNCH_AGENT_ID</string>
    <key>ProgramArguments</key>
    <array>
        <string>$AGENT_PATH</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ProcessType</key>
    <string>Interactive</string>
    <key>StandardOutPath</key>
    <string>$INSTALL_ROOT/agent.stdout.log</string>
    <key>StandardErrorPath</key>
    <string>$INSTALL_ROOT/agent.stderr.log</string>
</dict>
</plist>
EOF

cat > "$SQUID_MANIFEST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Identifier</key>
    <string>com.michelbarnich.eventkit-focusmode-agent.dnd-patch</string>

    <key>TargetBundleID</key>
    <string>$TARGET_BUNDLE_ID</string>

    <key>LibraryPath</key>
    <string>$TWEAK_PATH</string>

    <key>OSVersion</key>
    <string>*</string>

    <key>Enabled</key>
    <true/>
</dict>
</plist>
EOF

launchctl bootout "gui/$(id -u)" "$LAUNCH_AGENT_PLIST" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$LAUNCH_AGENT_PLIST"

echo "Installed manager: $MANAGER_PATH"
echo "Installed LaunchAgent: $LAUNCH_AGENT_PLIST"
echo "Installed Squid manifest: $SQUID_MANIFEST"
echo "Squid target bundle: $TARGET_BUNDLE_ID"
