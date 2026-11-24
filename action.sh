#!/system/bin/sh
# Action button: restart the watcher and show its status.
MODDIR=${0%/*}
. "$MODDIR/config.sh"
SSID=$(cmd wifi status 2>/dev/null | sed -n 's/^Wifi is connected to "\(.*\)"$/\1/p')
echo "- Frigate package: ${FRIGATE_PKG:-NOT SET}"
echo "- Immich package: ${IMMICH_PKG:-off}"
echo "- Home Wi-Fi: ${HOME_SSIDS:-NOT SET} (now on: ${SSID:-no Wi-Fi})"
echo "- Auto-disconnect: $AUTO_DISCONNECT (grace ${DISCONNECT_GRACE}s)"
if ip -4 addr show 2>/dev/null | grep -q 'inet 100\.'; then
  echo "- Tailscale: connected"
else
  echo "- Tailscale: disconnected"
fi
echo "- Restarting watcher..."
sh "$MODDIR/service.sh" restart
sleep 1
echo "- Recent log:"
tail -n 8 "$MODDIR/watcher.log" 2>/dev/null
