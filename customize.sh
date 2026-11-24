SKIPUNZIP=0
OLD=/data/adb/modules/auto-tailscale/config.sh
LEGACY=/data/adb/modules/frigate_tailscale   # module ID before v1.1
[ -f "$OLD" ] || OLD=$LEGACY/config.sh

if [ -f "$OLD" ]; then
  ui_print "- Keeping existing config.sh"
  NEW="$MODPATH/config.sh.new"
  mv -f "$MODPATH/config.sh" "$NEW"
  cp -f "$OLD" "$MODPATH/config.sh"
  # Add settings introduced since that config was written
  for key in $(sed -n 's/^\([A-Z_]*\)=.*/\1/p' "$NEW"); do
    grep -q "^$key=" "$MODPATH/config.sh" && continue
    ui_print "  Adding new setting $key"
    { echo; awk -v k="$key" '/^#/{c=c $0 "\n"; next} index($0, k "=")==1{printf "%s%s\n", c, $0} {c=""}' "$NEW"; } >> "$MODPATH/config.sh"
  done
  rm -f "$NEW"
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

if grep -q '^HOME_SSIDS=""' "$MODPATH/config.sh"; then
  SSID=$(cmd wifi status 2>/dev/null | sed -n 's/^Wifi is connected to "\(.*\)"$/\1/p')
  if [ -n "$SSID" ]; then
    ui_print "- Home Wi-Fi set to: $SSID"
    ui_print "  (Immich won't connect Tailscale on this network;"
    ui_print "   edit HOME_SSIDS in config.sh if that's wrong)"
    ESC=$(printf '%s' "$SSID" | sed 's/[&/\\]/\\&/g')
    sed -i "s/^HOME_SSIDS=.*/HOME_SSIDS=\"$ESC\"/" "$MODPATH/config.sh"
  else
    ui_print "! Not on Wi-Fi, so HOME_SSIDS is empty: Immich will"
    ui_print "! always connect Tailscale until you set it in config.sh"
  fi
fi

if [ -d "$LEGACY" ] || [ -d /data/adb/modules_update/frigate_tailscale ]; then
  ui_print "- Replacing old module frigate_tailscale (removed on reboot)"
  [ -d "$LEGACY" ] && touch "$LEGACY/remove"
  rm -rf /data/adb/modules_update/frigate_tailscale
fi

pm list packages 2>/dev/null | grep -q '^package:com.tailscale.ipn$' || \
  ui_print "! Tailscale app (com.tailscale.ipn) is not installed"
pm list packages 2>/dev/null | grep -q '^package:app.alextran.immich$' || \
  ui_print "- Immich app not installed (Immich trigger will be idle)"

set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/watcher.sh" 0 0 0755
set_perm "$MODPATH/action.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
