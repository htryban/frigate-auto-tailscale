SKIPUNZIP=0
OLD=/data/adb/modules/frigate_tailscale/config.sh

if [ -f "$OLD" ]; then
  ui_print "- Keeping existing config.sh"
  cp -f "$OLD" "$MODPATH/config.sh"
else
  ui_print "- Looking for the Frigate web app..."
  PKG=""
  for p in $(pm list packages 2>/dev/null | sed -n 's/^package:\(org\.chromium\.webapk\..*\)/\1/p'); do
    apk=$(pm path "$p" 2>/dev/null | sed -n '1s/^package://p')
    [ -f "$apk" ] && tr -d '\000' < "$apk" | grep -qi frigate && { PKG=$p; break; }
  done
  if [ -n "$PKG" ]; then
    ui_print "  Found: $PKG"
    sed -i "s/^FRIGATE_PKG=.*/FRIGATE_PKG=\"$PKG\"/" "$MODPATH/config.sh"
  else
    ui_print "! Frigate web app not found. Install it from Chrome"
    ui_print "! (Add to Home screen > Install), then set FRIGATE_PKG"
    ui_print "! in $MODPATH/config.sh"
  fi
fi

pm list packages 2>/dev/null | grep -q '^package:com.tailscale.ipn$' || \
  ui_print "! Tailscale app (com.tailscale.ipn) is not installed"

set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/watcher.sh" 0 0 0755
set_perm "$MODPATH/action.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
