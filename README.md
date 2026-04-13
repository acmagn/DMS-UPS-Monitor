# Dank UPS Monitor

A [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) DankBar plugin that shows **real-time UPS status** using [Network UPS Tools (NUT)](https://networkupstools.org/). It polls `upsc`, highlights **on-battery** operation in the bar, optionally sends **desktop notifications** (via `notify-send`), and includes a **simple charge history** graph in the popout.


<img width="528" height="553" alt="image" src="https://github.com/user-attachments/assets/06f0f507-67b4-452a-b4f8-ad37ac80a795" />

![status-change](https://github.com/user-attachments/assets/769ebf81-615f-4127-bf58-7634304bb959)


## Features

- **Tight NUT integration**: runs `upsc <device>` on a configurable interval; optional **faster polling while on battery** so power-loss is noticed quickly without spamming `upsd` on mains.
- **Bar states**: utility power vs **battery** (warning styling, larger/bolder text), with a stronger **critical** look when the UPS reports **LB**, charge is at or below **critical**, or you have crossed the **low charge** threshold for notifications.
- **Notifications**: optional alerts for mains loss, low battery (including configurable % threshold), and mains restore.
- **Popout**: status (common NUT `ups.status` tokens turned into short labels; unknown tokens stay as-is), charge, runtime, load, **real power** (`ups.realpower`, watts when the UPS exposes it), voltages, and a **charge %** graph. **UPS poll** is separate from **chart sampling** (you can poll often but add graph points less often).
- **Click**: opens the popout; **Refresh** inside runs `upsc` immediately.
- **Bar on mains**: choose the primary statistic (battery %, load, power, voltages, or status) in plugin settings.

This plugin **does not replace [upsmon](https://networkupstools.org/docs/man/upsmon.html)**. Keep **upsmon** for shutdown and system-level handling; use this plugin for the shell UI and optional user-session notifications.

## Debugging

**“upsc not found”** — DankMaterialShell often runs with a **minimal PATH**. Set **upsc path** in settings to the full binary (e.g. `/usr/bin/upsc`). Find it with `command -v upsc` or `pacman -Ql nut | grep upsc` (Arch).

**Connection / driver errors** — Ensure **`upsd`** is running and your user may talk to it (`upsd.users`, group `nut` / `nutups`, etc.). Check `systemctl status nut-server` (names vary by distro).

**Logs** — Failed runs log to the **DankMaterialShell / Quickshell console** with exit code, command, and full output (`console.warn` lines mentioning `DankUpsMonitor`).

## Requirements

- **NUT** client tools (`upsc` on `PATH`, or configure **upsc path** in the plugin).
- A running **`upsd`** that exposes your UPS, and correct **`ups.conf` / `nut.conf`** device naming.
- **`notify-send`** (e.g. `libnotify`) if you enable desktop notifications.

## Installation

Ideally, install from DMS Plugin Management. Otherwise:

1. Create a folder in your DankMaterialShell plugins directory (name it however you like, e.g. `DankUpsMonitor`).
2. Copy **`plugin.json`**, **`DankUpsMonitor.qml`**, and **`DankUpsMonitorSettings.qml`** from this repo into that folder.
3. Enable **Dank UPS Monitor** in DankMaterialShell and add the widget to the DankBar.

### UPS device name

The setting **UPS device** must match what NUT expects, for example:

- `ups@localhost` — local `upsd`, UPS section `[ups]` in `ups.conf`
- `myups@192.168.1.10` — remote `upsd`

List devices:

```bash
upsc -l
```

Inspect one:

```bash
upsc ups@localhost
```

### Latency vs chart

- **UPS poll interval** (and, when enabled, **battery poll interval**) sets how soon the **bar** and **notifications** can see a change.
- **Chart sample interval**, **history retention**, and **max chart points** only affect the **popout graph** (how often a point is stored and how many are kept). They do **not** slow down bar updates or alerts.

## Configuration reference

| Setting | Meaning |
|--------|---------|
| UPS device | Argument to `upsc` (e.g. `ups@localhost`) |
| UPS poll interval (mains) | Seconds between `upsc` on utility power (default **10**, max **120**). **Worst-case delay** for bar + notifications to see OL↔OB (unless faster battery polling applies). |
| Faster poll on battery | On battery, poll every `min(mains poll, battery poll)`. |
| Battery poll interval | Compared to mains poll while on OB (default **5** s). |
| Chart sample interval | Minimum seconds between **graph** points; UPS still polls at the poll interval. |
| History retention | Hours of chart points kept (in-memory only). |
| Max chart points | Hard cap after time pruning. |
| Low charge warning | Low-battery **notification** when on battery and charge ≤ this % (or UPS **LB**). Slider 0 to 100%. |
| Critical charge | Stronger **bar** styling on battery at or below this. Slider 0 to 100%. |
| Notifications | Toggles for power loss, low battery, mains restore |
| Show runtime in bar | On **battery** only, shows `battery.runtime` next to charge |
| Bar on mains | Dropdown: battery %, load, real power, input/output V, or status (utility power only) |

## License

MIT — see [LICENSE](./LICENSE).
