# Auto-Tailscale

A small Magisk / KernelSU / KernelSU-Next module that turns Tailscale on when you open the [Frigate](https://frigate.video) web app, or the [Immich](https://immich.app) app while you're away from home Wi-Fi, and turns it off again shortly after you leave.

## Why

If Frigate is served over your tailnet (for example `https://<host>.<tailnet>.ts.net` via MagicDNS or `tailscale serve`), it is only reachable while Tailscale is connected. That holds even on your home Wi-Fi, because the `.ts.net` name only resolves through Tailscale. Leaving the VPN on all the time costs battery and routes DNS through Tailscale for everything. Turning it on by hand every time you want to check a camera gets old fast.

Immich is different: on home Wi-Fi the app can reach the server directly on the LAN, so Tailscale is only needed when you're out. The module checks the Wi-Fi network name when Immich opens and only connects when you're not on a home network.

## What it does

- **Watcher** (`watcher.sh`, started by `service.sh` after boot): reads the Android `events` log buffer with `logcat` (event-driven, no polling). It reacts to two events for each app:
  - `wm_set_resumed_activity` for the app's package (cold launch from the icon)
  - `wm_task_to_front` for the app's task ID (resume from Recents)

  For Frigate, and for Immich when the current Wi-Fi SSID isn't in `HOME_SSIDS`, it sends Tailscale's own `com.tailscale.ipn.CONNECT_VPN` broadcast to `com.tailscale.ipn/.IPNReceiver`. It does nothing if a `100.x` tailnet address is already up.
- **Auto-disconnect**: when another app comes to the front, or the app is swiped out of Recents, it sends `DISCONNECT_VPN` after a grace period (15 s by default). Returning to Frigate (or to Immich off home Wi-Fi) within that window cancels it. Opening Immich at home counts as leaving, so Tailscale that Frigate turned on still goes off. It only disconnects if this module was what connected Tailscale, so a VPN you turned on yourself is left alone.
- **Action button** (`action.sh`): shows the detected package, the current Tailscale state and recent log lines, and restarts the watcher.
- **Auto-detect**: at install, `customize.sh` scans installed Chrome WebAPKs (`org.chromium.webapk.*`) for one named Frigate and writes its package name into `config.sh`. It also stores the Wi-Fi network you're on as `HOME_SSIDS`, so install it at home. On updates your existing `config.sh` is kept and any new settings are appended to it.

The watcher runs in a supervisor loop, so it restarts if `logcat` ever exits. Activity is logged to `/data/adb/modules/auto-tailscale/watcher.log`, which is trimmed automatically.

## Requirements

- Root via Magisk, KernelSU or KernelSU-Next
- The [Tailscale](https://play.google.com/store/apps/details?id=com.tailscale.ipn) app, signed in, with VPN permission already granted (connect it once by hand)
- Frigate installed as a web app from Chrome (⋮ → Add to Home screen → Install)
- Optional: the [Immich](https://play.google.com/store/apps/details?id=app.alextran.immich) app

## Configuration

`/data/adb/modules/auto-tailscale/config.sh`:

| Setting | Default | Meaning |
| --- | --- | --- |
| `FRIGATE_PKG` | auto-detected | Frigate WebAPK package name (`pm list packages \| grep webapk`) |
| `IMMICH_PKG` | `app.alextran.immich` | Immich package; `""` turns the Immich trigger off |
| `HOME_SSIDS` | Wi-Fi at install | Home network names, `\|`-separated; Immich doesn't connect on these |
| `AUTO_DISCONNECT` | `1` | Disconnect after leaving the app |
| `DISCONNECT_GRACE` | `15` | Seconds to wait before disconnecting |

Apply changes with the Action button or `sh /data/adb/modules/auto-tailscale/service.sh restart`.

## Limitations

- Turning the screen off while Frigate is open doesn't count as leaving (no task change), so Tailscale stays up until you switch apps.
- The first page load can start a second or two before the tunnel is up. Frigate's UI reconnects on its own; if not, refresh once.
- Home detection is by Wi-Fi name only. Another network with the same SSID counts as home.
- The home check runs when Immich opens. Leaving home Wi-Fi while Immich stays open won't connect Tailscale until you switch away and back.
- The install-time auto-detect matches the first WebAPK whose APK mentions "Frigate". If you have more than one, check `FRIGATE_PKG`.

## Install

Download the zip from [Releases](../../releases) and install it from your root manager, then reboot once to start the watcher.

Upgrading from v1.0 (module ID `frigate_tailscale`): install this zip over it. The installer copies your old `config.sh` and marks the old module for removal on the next reboot.

## Build

```sh
./build.sh
```

## License

MIT
