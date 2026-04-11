# Dank UPS Monitor

A [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) DankBar plugin that shows **real-time UPS status** using [Network UPS Tools (NUT)](https://networkupstools.org/). It polls `upsc`, highlights **on-battery** operation in the bar, optionally sends **desktop notifications** (via `notify-send`), and includes a **simple charge history** graph in the popout.


## Features

- **Tight NUT integration**: runs `upsc <device>` on a configurable interval; optional **faster polling while on battery** so power-loss is noticed quickly without spamming `upsd` on mains.
- **Bar states**: utility power vs **battery** (warning styling, larger/bolder text), with a stronger **critical** look when the UPS reports **LB**, charge is at or below **critical**, or you have crossed the **low charge** threshold for notifications.
- **Notifications**: optional alerts for mains loss, low battery (including configurable % threshold), and mains restore.
- **Popout**: status (common NUT `ups.status` tokens turned into short labels; unknown tokens stay as-is), charge, runtime, load, **real power** (`ups.realpower`, watts when the UPS exposes it), voltages, and a **charge %** graph. **UPS poll** is separate from **chart sampling** (you can poll often but add graph points less often).
- **Click**: opens the popout; **Refresh** inside runs `upsc` immediately.
- **Bar on mains**: choose the primary statistic (battery %, load, power, voltages, or status) in plugin settings.

This plugin **does not replace [upsmon](https://networkupstools.org/docs/man/upsmon.html)**. Keep **upsmon** for shutdown and system-level handling; use this plugin for the shell UI and optional user-session notifications.

## Debugging (“NUT?” or errors in the bar)

The bar only showed **NUT?** in older builds; current versions show **`upsc`’s real message** (truncated) and the **popout** lists **Command**, **Exit code**, and **Message**.

1. **Run the same command in a terminal** (use your configured UPS name and optional path):

   ```bash
   upsc ups@localhost
   # or
   /usr/bin/upsc ups@localhost
   ```

2. **List UPS names NUT knows**:

   ```bash
   upsc -l
   ```

   If your device is not `ups@localhost`, set **UPS device** in plugin settings to match (e.g. `myups@127.0.0.1`).

3. **“upsc not found”** — DankMaterialShell often runs with a **minimal PATH**. Set **upsc path** in settings to the full binary (e.g. `/usr/bin/upsc`). Find it with `command -v upsc` or `pacman -Ql nut | grep upsc` (Arch).

4. **Connection / driver errors** — Ensure **`upsd`** is running and your user may talk to it (`upsd.users`, group `nut` / `nutups`, etc.). Check `systemctl status nut-server` (names vary by distro).

5. **Logs** — Failed runs log to the **DankMaterialShell / Quickshell console** with exit code, command, and full output (`console.warn` lines mentioning `DankUpsMonitor`).

## Requirements

- **NUT** client tools (`upsc` on `PATH`, or configure **upsc path** in the plugin).
- A running **`upsd`** that exposes your UPS, and correct **`ups.conf` / `nut.conf`** device naming.
- **`notify-send`** (e.g. `libnotify`) if you enable desktop notifications.

## Installation

1. Create a folder in your DankMaterialShell plugins directory (name it however you like, e.g. `DankUpsMonitor`).
2. Copy **`plugin.json`**, **`DankUpsMonitor.qml`**, and **`DankUpsMonitorSettings.qml`** from this repo into that folder (three files in **one** directory, no nested `DankUpsMonitor/` subfolder).
3. Enable **Dank UPS Monitor** in DankMaterialShell and add the widget to the DankBar.

Same layout as other plugins: one folder per plugin, all QML and `plugin.json` at the same level ([dms-plugins](https://github.com/AvengeMedia/dms-plugins) uses one folder per plugin inside their monorepo; here the repo **is** that single plugin folder).

If the bar shows **`NUT?`**, `upsc` failed (wrong device name, `upsd` not running, or missing permissions).

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

## upsmon and NOTIFYCMD

**upsmon** watches the same UPS state for **shutdown** and **notify** events. This plugin **polls independently** for the UI; you can still route **upsmon** events to scripts.

Example: in `upsmon.conf`, set a notification command (paths and options depend on your distro):

```conf
NOTIFYCMD /usr/local/bin/nut-notify
```

Example script `/usr/local/bin/nut-notify`:

```bash
#!/bin/sh
# upsmon passes NOTIFYTYPE etc. in the environment — see upsmon(8).
/usr/bin/notify-send -a NUT "UPS $NOTIFYTYPE" "UPS event — check power"
```

Use this for **email**, **logging**, or **extra** alerts. The DankBar plugin’s own notifications are separate and only need `notify-send` in your **user** session.

## Permissions

- **Session user** only needs to run `upsc` (and `notify-send` for alerts). If `upsd` restricts clients, add your user to the right group or adjust `upsd.users` / ACLs so `upsc` works **non-root**.
- **upsmon** often runs as root or a dedicated user — that is independent of this plugin.

### Latency vs chart

- **UPS poll interval** (and, when enabled, **battery poll interval**) sets how soon the **bar** and **notifications** can see a change. Worst case ≈ **one poll** after the UPS changes (plus process time).
- **Chart sample interval**, **history retention**, and **max chart points** only affect the **popout graph** (how often a point is stored and how many are kept). They do **not** slow down bar updates or alerts.

### Does NUT support subscriptions?

Not for this plugin. The usual client is **`upsc`**, which is **request/response** — there is no supported push stream for “notify me when `ups.status` changes” from a random user session. **upsmon** gets events because it is the designated monitor and talks to `upsd` in that role. For extra responsiveness you can lower poll intervals, use **adaptive battery polling** (built into this plugin), or run **NOTIFYCMD** / scripts from **upsmon** in parallel.

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

**Notifications:** Power, low-battery, and mains state live in **plugin state** (`pluginService.savePluginState`) so every widget instance shares one logical state. Identical title and body within **15 seconds** is deduped. Low-battery is skipped in the same poll as power-loss. If you still get pairs of similar alerts, check **upsmon** `NOTIFYCMD` scripts that also call `notify-send`.

## License

MIT — see [LICENSE](./LICENSE).
