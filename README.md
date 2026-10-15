# AutoFocus

<p align="center">
  <img src="https://gitlab.athena.michelbarnich.com/uploads/-/system/project/avatar/20/AutoFocus-iOS-Default-128_1x.png?v=1792063674&width=180" width="128" alt="AutoFocus icon">
</p>

<p align="center">
  <strong>Calendar-aware Focus modes for macOS.</strong><br>
  Automatically keep Do Not Disturb aligned with the calendar events that matter.
</p>

<p align="center">
  <a href="#what-it-does">What it does</a> ·
  <a href="#build">Build</a> ·
  <a href="#install">Install</a> ·
  <a href="#how-it-works">How it works</a>
</p>

---

AutoFocus connects your macOS calendars to Focus modes. Choose a Focus mode, select the calendars that should activate it, and let the background agent keep the system state in sync as events start, end, or change.

> [!WARNING]
> AutoFocus integrates with private macOS Do Not Disturb data and relies on the separate [Squid](https://github.com/michelbarnich/squid) project for tweak loading. It is intended for experimentation and personal use. macOS updates may require changes.

## What it does

- Presents a lightweight menu-bar controller named **Calendar Focus**.
- Reads available Focus modes from macOS.
- Loads calendars through EventKit and groups them by account.
- Stores the selected Focus mode and calendar identifiers locally.
- Watches calendar-driven schedule state through a background C agent.
- Applies the desired Do Not Disturb end time based on active calendar events.
- Installs the agent, tweak, LaunchAgent, and Squid manifest from the app.

## Requirements

- macOS with Xcode
- Calendar access for AutoFocus
- Full Disk Access for FocusModeCalendarController so it can read macOS Focus configuration
- A checkout of the separate Squid project, expected at ../Squid
- Permission to load the resulting Squid tweak

The Squid location can be overridden with `SQUID_ROOT`. If `liblibsquid.dylib` already exists, provide its path with `LIBSQUID_PATH`.

## Build

Clone AutoFocus next to the Squid repository:

```text
Projects/
├── Squid/
└── eventkit-focusmode-agent/
```

Build the package from the repository root:

```sh
sh package/build-package.sh
```

The script builds:

1. Squid's `libsquid` target.
2. The EventKit background agent.
3. The Do Not Disturb patch.
4. The `AutoFocus.app` menu-bar controller.

The assembled app is written to `Products/AutoFocus.app`.

You can also build the individual Xcode schemes:

- `eventkit-focusmode-daemon`
- `donotdisturbd-patch`
- `FocusModeCalendarController`

## Install

After building, launch `Products/AutoFocus.app` and choose **Install Components**.

AutoFocus installs its runtime files under:

```text
~/Library/Application Support/EventKitFocusModeAgent/
├── AutoFocus.app
├── bin/eventkit-focusmode-agent
├── bin/libdonotdisturbd-patch.dylib
├── agent.stdout.log
└── agent.stderr.log
```

It also creates:

- `~/Library/LaunchAgents/com.michelbarnich.eventkit-focusmode-agent.plist`
- `~/.squid/com.michelbarnich.eventkit-focusmode-agent.plist`

For a packaged install, the equivalent shell entry point is:

```sh
sh package/install.sh
```

To remove the installed components:

```sh
sh package/uninstall.sh
```

## How it works

```text
EventKit calendars
        │
        ▼
AutoFocus menu-bar controller
        │  selected Focus mode + calendar IDs
        ▼
~/Library/Application Support/EventKitFocusModeAgent/config.json
        │
        ▼
Background EventKit agent
        │  desired active-event end time
        ▼
Do Not Disturb patch loaded by Squid
```

The agent evaluates active events and uses the latest ending event as the desired Do Not Disturb end time. Added, removed, and rescheduled events are detected so the system state can be updated on the next polling cycle.

## Project layout

| Path | Responsibility |
| --- | --- |
| `FocusModeCalendarController/` | SwiftUI menu-bar app and installer |
| `eventkit-focusmode-agent/` | EventKit polling agent and schedule policy |
| `donotdisturbd-patch/` | Squid-loaded Do Not Disturb patch |
| `package/` | Build, install, uninstall, and packaging scripts |
| `Products/` | Locally assembled build products |

## Permissions and troubleshooting

If no Focus modes appear:

1. Open **System Settings → Privacy & Security → Full Disk Access**.
2. Add `FocusModeCalendarController` or the built `AutoFocus.app`.
3. Relaunch AutoFocus and refresh.

If no calendars appear, grant Calendar access when prompted, then refresh from the menu-bar window.

If packaging cannot find Squid, set the project location explicitly:

```sh
SQUID_ROOT=/path/to/Squid sh package/build-package.sh
```

If you already built Squid separately:

```sh
LIBSQUID_PATH=/path/to/liblibsquid.dylib sh package/build-package.sh
```

## License

No license has been declared yet. Until one is added, all rights are reserved.
