# EventKit Focus Mode Controller

Use the shared Xcode scheme named `EventKitFocusModeAgent` and choose Build.

The scheme automatically:

1. Builds the separate Squid `libsquid` target only.
2. Builds the EventKit agent.
3. Builds the Squid tweak.
4. Builds the FocusModeCalendarController manager.
5. Embeds the agent and tweak into the manager app.

Squid's daemon and Squid Manager app are not part of this project or its
distribution. Only the separately built `liblibsquid.dylib` is used while
building the tweak.

The separate Squid project is expected at:

    ../Squid

Override it with `SQUID_ROOT`, or point directly to an existing library with
`LIBSQUID_PATH`.

The command-line equivalent is:

    sh package/build-package.sh

After copying the app to Applications, launch it and choose Install Components.
That creates the LaunchAgent and the `~/.squid` manifest with an absolute
tweak library path.
