#!/system/bin/sh
MODDIR=${0%/*}
. "$MODDIR/config.sh"
: "${IMMICH_PKG=app.alextran.immich}"
LOG="$MODDIR/watcher.log"
TS=com.tailscale.ipn/.IPNReceiver
FLAG="$MODDIR/.we_connected"      # exists = we turned Tailscale on
DPID="$MODDIR/.disconnect_pid"
FRIGATE_TASK=""; IMMICH_TASK=""
CUR=""            # app in front that we care about: frigate | immich | ""
LAST=0; LAST_APP=""

log() { echo "$(date '+%m-%d %H:%M:%S') $*" >> "$LOG"; }
vpn_up() { ip -4 addr show 2>/dev/null | grep -q 'inet 100\.'; }
name_of() { case "$1" in frigate) echo Frigate ;; immich) echo Immich ;; esac; }
task_for() {
  dumpsys activity recents 2>/dev/null | grep -m1 "A=[0-9]*:$1}" | sed -n 's/.*Task{[0-9a-f]* #\([0-9]*\) .*/\1/p'
}
find_tasks() {
  [ -n "$FRIGATE_PKG" ] && FRIGATE_TASK=$(task_for "$FRIGATE_PKG")
  [ -n "$IMMICH_PKG" ] && IMMICH_TASK=$(task_for "$IMMICH_PKG")
}
task_app() {
  if [ -n "$FRIGATE_TASK" ] && [ "$1" = "$FRIGATE_TASK" ]; then echo frigate
  elif [ -n "$IMMICH_TASK" ] && [ "$1" = "$IMMICH_TASK" ]; then echo immich; fi
}
# Current Wi-Fi SSID, empty when not on Wi-Fi
wifi_ssid() { cmd wifi status 2>/dev/null | sed -n 's/^Wifi is connected to "\(.*\)"$/\1/p'; }
at_home() {
  [ -n "$HOME_SSIDS" ] || return 1
  s=$(wifi_ssid); [ -n "$s" ] || return 1
  old_ifs=$IFS; IFS='|'
  for h in $HOME_SSIDS; do [ "$s" = "$h" ] && { IFS=$old_ifs; return 0; }; done
  IFS=$old_ifs; return 1
}
cancel_disconnect() {
  [ -f "$DPID" ] && { kill "$(cat "$DPID")" 2>/dev/null && log "pending disconnect cancelled"; rm -f "$DPID"; }
}
enter() {   # $1 = frigate | immich
  prev=$CUR; CUR=$1; n=$(name_of "$1")
  now=$(date +%s); [ "$LAST_APP" = "$1" ] && [ $((now - LAST)) -lt 3 ] && return
  LAST=$now; LAST_APP=$1
  if [ "$1" = immich ] && at_home; then
    log "Immich opened on home Wi-Fi ($(wifi_ssid)) - not connecting"
    # Tailscale may still be up from Frigate; let the normal disconnect run
    [ "$prev" = frigate ] && schedule_disconnect "Frigate"
    return
  fi
  cancel_disconnect
  if vpn_up; then log "$n opened - Tailscale already up"; return; fi
  am broadcast -n $TS -a com.tailscale.ipn.CONNECT_VPN >/dev/null 2>&1
  touch "$FLAG"; log "$n opened - CONNECT_VPN sent"
}
schedule_disconnect() {   # $1 = app name for the log
  [ "$AUTO_DISCONNECT" = 1 ] && [ -f "$FLAG" ] || return
  cancel_disconnect
  ( sleep "$DISCONNECT_GRACE"
    am broadcast -n $TS -a com.tailscale.ipn.DISCONNECT_VPN >/dev/null 2>&1
    rm -f "$FLAG" "$DPID"; log "left $1 - DISCONNECT_VPN sent" ) &
  echo $! > "$DPID"; log "left $1 - disconnecting in ${DISCONNECT_GRACE}s"
}
leave() {
  [ -n "$CUR" ] || return
  n=$(name_of "$CUR"); CUR=""
  schedule_disconnect "$n"
}

[ -f "$LOG" ] && [ $(wc -l < "$LOG") -gt 500 ] && tail -n 200 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
if [ -z "$FRIGATE_PKG" ] && [ -z "$IMMICH_PKG" ]; then
  log "no app packages set in config.sh - idle"; while :; do sleep 3600; done
fi
find_tasks
log "watcher started (pid $$, frigate task ${FRIGATE_TASK:-none}, immich task ${IMMICH_TASK:-none}, home: ${HOME_SSIDS:-not set})"

logcat -b events -v brief -T 1 2>/dev/null | while read -r line; do
  app=""
  case "$line" in
    *wm_create_activity*|*wm_set_resumed_activity*)
      if [ -n "$FRIGATE_PKG" ] && case "$line" in *"$FRIGATE_PKG"*) true ;; *) false ;; esac; then app=frigate
      elif [ -n "$IMMICH_PKG" ] && case "$line" in *"$IMMICH_PKG/"*) true ;; *) false ;; esac; then app=immich
      fi ;;
  esac
  case "$line" in
    *wm_create_activity*)
      t=$(echo "$line" | sed -n 's/.*: \[[0-9]*,[0-9]*,\([0-9]*\),.*/\1/p')
      case "$app" in frigate) FRIGATE_TASK=$t ;; immich) IMMICH_TASK=$t ;; esac ;;
    *wm_set_resumed_activity*)
      [ -n "$app" ] && enter "$app" ;;
    *wm_task_to_front*)
      t=$(echo "$line" | sed -n 's/.*: \[[0-9]*,\([0-9]*\),.*/\1/p')
      app=$(task_app "$t")
      if [ -z "$app" ] && { { [ -n "$FRIGATE_PKG" ] && [ -z "$FRIGATE_TASK" ]; } || { [ -n "$IMMICH_PKG" ] && [ -z "$IMMICH_TASK" ]; }; }; then
        find_tasks; app=$(task_app "$t")
      fi
      if [ -n "$app" ]; then enter "$app"; else leave; fi ;;
    *wm_task_removed*)
      # app swiped away from Recents
      t=$(echo "$line" | sed -n 's/.*: \[\([0-9]*\),.*/\1/p')
      if [ -n "$FRIGATE_TASK" ] && [ "$t" = "$FRIGATE_TASK" ]; then
        FRIGATE_TASK=""; [ "$CUR" = frigate ] && leave
      elif [ -n "$IMMICH_TASK" ] && [ "$t" = "$IMMICH_TASK" ]; then
        IMMICH_TASK=""; [ "$CUR" = immich ] && leave
      fi ;;
  esac
done
log "logcat stream ended"
