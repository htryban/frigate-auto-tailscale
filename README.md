# Frigate Auto-Tailscale

A small Magisk / KernelSU / KernelSU-Next module that turns Tailscale on when you open the [Frigate](https://frigate.video) web app, and turns it off again shortly after you leave.

## Why

If Frigate is served over your tailnet (for example `https://<host>.<tailnet>.ts.net` via MagicDNS or `tailscale serve`), it is only reachable while Tailscale is connected. That holds even on your home Wi-Fi, because the `.ts.net` name only resolves through Tailscale. Leaving the VPN on all the time costs battery and routes DNS through Tailscale for everything. Turning it on by hand every time you want to check a camera gets old fast.

## What it does

- **Watcher** (`watcher.sh`, started by `service.sh` after boot): reads the Android `events` log buffer with `logcat` (event-driven, no polling). It reacts to two events:
  - `wm_set_resumed_activity` for the Frigate WebAPK (cold launch from the icon)
  - `wm_task_to_front` for Frigate's task ID (resume from Recents)

  On either event it sends Tailscale's own `com.tailscale.ipn.CONNECT_VPN` broadcast to `com.tailscale.ipn/.IPNReceiver`. It does nothing if a `100.x` tailnet address is already up.
- **Auto-disconnect**: when another app comes to the front, or Frigate is swiped out of Recents, it sends `DISCONNECT_VPN` after a grace period (15 s by default). Returning to Frigate within that window cancels it. It only disconnects if this module was what connected Tailscale, so a VPN you turned on yourself is left alone.
- **Action button** (`action.sh`): shows the detected package, the current Tailscale state and recent log lines, and restarts the watcher.
- **Auto-detect**: at install, `customize.sh` scans installed Chrome WebAPKs (`org.chromium.webapk.*`) for one named Frigate and writes its package name into `config.sh`. On updates your existing `config.sh` is kept.

The watcher runs in a supervisor loop, so it restarts if `logcat` ever exits. Activity is logged to `/data/adb/modules/frigate_tailscale/watcher.log`, which is trimmed automatically.

## Requirements

- Root via Magisk, KernelSU or KernelSU-Next
- The [Tailscale](https://play.google.com/store/apps/details?id=com.tailscale.ipn) app, signed in, with VPN permission already granted (connect it once by hand)
- Frigate installed as a web app from Chrome (⋮ → Add to Home screen → Install)

## Configuration

`/data/adb/modules/frigate_tailscale/config.sh`:

| Setting | Default | Meaning |
| --- | --- | --- |
| `FRIGATE_PKG` | auto-detected | Frigate WebAPK package name (`pm list packages \| grep webapk`) |
| `AUTO_DISCONNECT` | `1` | Disconnect after leaving Frigate |
| `DISCONNECT_GRACE` | `15` | Seconds to wait before disconnecting |

Apply changes with the Action button or `sh /data/adb/modules/frigate_tailscale/service.sh restart`.

## Limitations

- Turning the screen off while Frigate is open doesn't count as leaving (no task change), so Tailscale stays up until you switch apps.
- The first page load can start a second or two before the tunnel is up. Frigate's UI reconnects on its own; if not, refresh once.
- The install-time auto-detect matches the first WebAPK whose APK mentions "Frigate". If you have more than one, check `FRIGATE_PKG`.

## Install

Download the zip from [Releases](../../releases) and install it from your root manager, then reboot once to start the watcher.

## Build

```sh
./build.sh
```

## License

MIT
