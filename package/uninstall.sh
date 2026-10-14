#!/bin/sh
set -eu

INSTALL_ROOT="$HOME/Library/Application Support/EventKitFocusModeAgent"
LAUNCH_AGENT_PLIST="$HOME/Library/LaunchAgents/com.michelbarnich.eventkit-focusmode-agent.plist"
SQUID_MANIFEST="$HOME/.squid/com.michelbarnich.eventkit-focusmode-agent.plist"

launchctl bootout "gui/$(id -u)" "$LAUNCH_AGENT_PLIST" 2>/dev/null || true
rm -f "$LAUNCH_AGENT_PLIST" "$SQUID_MANIFEST"
rm -rf "$INSTALL_ROOT"

echo "Removed EventKit Focus Mode Agent, its LaunchAgent, and its Squid manifest."
