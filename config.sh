# Auto-Tailscale settings.
# After editing: sh /data/adb/modules/auto-tailscale/service.sh restart

# Package name of the Frigate web app (a Chrome WebAPK). Filled in at install
# time; find it manually with: pm list packages | grep webapk
FRIGATE_PKG=""

# Package name of the Immich app. Set to "" to turn the Immich trigger off.
IMMICH_PKG="app.alextran.immich"

# Home Wi-Fi network name(s), separated by |  (e.g. "Home|Home-5G").
# Opening Immich on one of these does NOT connect Tailscale. Frigate always
# connects. Filled in at install time from the Wi-Fi you are on.
HOME_SSIDS=""

# 1 = disconnect Tailscale after leaving the app (only if this module turned it on)
AUTO_DISCONNECT=1

# Seconds to wait after leaving before disconnecting (cancelled if you return)
DISCONNECT_GRACE=15
