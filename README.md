# Dank UPS Monitor

A [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) DankBar plugin that shows **real-time UPS status** using [Network UPS Tools (NUT)](https://networkupstools.org/). It polls `upsc`, highlights **on-battery** operation in the bar, optionally sends **desktop notifications** (via `notify-send`), and includes a **simple charge history** graph in the popout.

The official plugin layout this project follows matches the [dms-plugins](https://github.com/AvengeMedia/dms-plugins) collection.

## Features

- **Tight NUT integration**: runs `upsc <device>` on a configurable interval (default **2s**).
- **Bar states**: utility power vs **battery** (warning styling, larger/bolder text), with a stronger **critical** look when the UPS reports **LB**, charge is at or below **critical**, or you have crossed the **low charge** threshold for notifications.
- **Notifications**: optional alerts for mains loss, low battery (including configurable % threshold), and mains restore.
- **Popout**: key variables (status, charge, runtime, load, voltages) and a **battery charge** line graph over recent samples.
- **Click**: refreshes the UPS read immediately (same as waiting for the next poll).

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

1. Copy the `DankUpsMonitor` folder into your DankMaterialShell plugins directory (same idea as cloning plugins from [dms-plugins](https://github.com/AvengeMedia/dms-plugins)).
2. Enable **Dank UPS Monitor** in DankMaterialShell plugin settings and add its widget to the DankBar.

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

## Configuration reference

| Setting | Meaning |
|--------|---------|
| UPS device | Argument to `upsc` (e.g. `ups@localhost`) |
| Poll interval | Seconds between `upsc` runs (default **60**; longer = fewer samples and less CPU) |
| History retention | **Hours** of charge samples kept (older points dropped; in-memory only) |
| Max history samples | Hard cap after time pruning (default **1440**; e.g. ~24h at 60s polling) |
| Low charge warning | Triggers low-battery **notification** when on battery and charge ≤ this % (and when UPS sends **LB**) |
| Critical charge | Stronger **bar** styling when on battery and charge ≤ this % |
| Notifications | Toggles for power loss, low battery, mains restore |
| Show runtime in bar | On **battery** only, shows `battery.runtime` next to charge |

**Notifications:** Power / low-battery / mains state is stored in **plugin state** (`pluginService.savePluginState`) so **all** widget instances (e.g. horizontal and vertical DankBar) share one logical state — otherwise each instance would fire its own notifications. Duplicate toasts are also suppressed if the **same title + body** repeats within **15 seconds**. A **low-battery** toast is not sent in the **same poll** as a **power-loss** toast. If you still see **pairs** of similar alerts, check **upsmon** `NOTIFYCMD` / scripts — they may also call `notify-send` for the same event.

## License

MIT — see [LICENSE](./LICENSE).
