#!/system/bin/sh
MODDIR=${0%/*}
. "$MODDIR/config.sh"
LOG="$MODDIR/watcher.log"
TS=com.tailscale.ipn/.IPNReceiver
FLAG="$MODDIR/.we_connected"      # exists = we turned Tailscale on
DPID="$MODDIR/.disconnect_pid"
FRIGATE_TASK=""; IN_FRIGATE=0; LAST=0

log() { echo "$(date '+%m-%d %H:%M:%S') $*" >> "$LOG"; }
vpn_up() { ip -4 addr show 2>/dev/null | grep -q 'inet 100\.'; }
find_task() {
  FRIGATE_TASK=$(dumpsys activity recents 2>/dev/null | grep -m1 "A=[0-9]*:$FRIGATE_PKG}" | sed -n 's/.*Task{[0-9a-f]* #\([0-9]*\) .*/\1/p')
}
cancel_disconnect() {
  [ -f "$DPID" ] && { kill "$(cat "$DPID")" 2>/dev/null && log "pending disconnect cancelled"; rm -f "$DPID"; }
}
enter() {
  IN_FRIGATE=1; cancel_disconnect
  now=$(date +%s); [ $((now - LAST)) -lt 3 ] && return; LAST=$now
  if vpn_up; then log "Frigate opened - Tailscale already up"; return; fi
  am broadcast -n $TS -a com.tailscale.ipn.CONNECT_VPN >/dev/null 2>&1
  touch "$FLAG"; log "Frigate opened - CONNECT_VPN sent"
}
leave() {
  IN_FRIGATE=0
  [ "$AUTO_DISCONNECT" = 1 ] && [ -f "$FLAG" ] || return
  cancel_disconnect
  ( sleep "$DISCONNECT_GRACE"
    am broadcast -n $TS -a com.tailscale.ipn.DISCONNECT_VPN >/dev/null 2>&1
    rm -f "$FLAG" "$DPID"; log "left Frigate - DISCONNECT_VPN sent" ) &
  echo $! > "$DPID"; log "left Frigate - disconnecting in ${DISCONNECT_GRACE}s"
}

[ -f "$LOG" ] && [ $(wc -l < "$LOG") -gt 500 ] && tail -n 200 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
if [ -z "$FRIGATE_PKG" ]; then
  log "FRIGATE_PKG not set in config.sh - idle"; while :; do sleep 3600; done
fi
find_task
log "watcher started (pid $$, frigate task ${FRIGATE_TASK:-none})"

logcat -b events -v brief -T 1 2>/dev/null | while read -r line; do
  case "$line" in
    *wm_create_activity*"$FRIGATE_PKG"*)
      FRIGATE_TASK=$(echo "$line" | sed -n 's/.*: \[[0-9]*,[0-9]*,\([0-9]*\),.*/\1/p') ;;
    *wm_set_resumed_activity*"$FRIGATE_PKG"*)
      enter ;;
    *wm_task_to_front*)
      t=$(echo "$line" | sed -n 's/.*: \[[0-9]*,\([0-9]*\),.*/\1/p')
      [ -z "$FRIGATE_TASK" ] && find_task
      if [ "$t" = "$FRIGATE_TASK" ]; then enter
      elif [ "$IN_FRIGATE" = 1 ]; then leave; fi ;;
    *wm_task_removed*)
      # Frigate swiped away from Recents
      t=$(echo "$line" | sed -n 's/.*: \[\([0-9]*\),.*/\1/p')
      if [ -n "$FRIGATE_TASK" ] && [ "$t" = "$FRIGATE_TASK" ]; then FRIGATE_TASK=""; [ "$IN_FRIGATE" = 1 ] && leave; fi ;;
  esac
done
log "logcat stream ended"
