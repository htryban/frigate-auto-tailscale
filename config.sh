# Frigate Auto-Tailscale settings.
# After editing: sh /data/adb/modules/frigate_tailscale/service.sh restart

# Package name of the Frigate web app (a Chrome WebAPK). Filled in at install
# time; find it manually with: pm list packages | grep webapk
FRIGATE_PKG=""

# 1 = disconnect Tailscale after leaving Frigate (only if this module turned it on)
AUTO_DISCONNECT=1

# Seconds to wait after leaving Frigate before disconnecting (cancelled if you return)
DISCONNECT_GRACE=15
