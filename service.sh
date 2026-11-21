#!/system/bin/sh
MODDIR=${0%/*}
PIDF="$MODDIR/watcher.pid"
stop() {
  [ -f "$PIDF" ] && kill -9 "$(cat "$PIDF")" 2>/dev/null
  for w in $(pgrep -f "$MODDIR/watcher.sh"); do
    pkill -9 -P "$w" 2>/dev/null; kill -9 "$w" 2>/dev/null
  done
  rm -f "$PIDF"
}
case "$1" in
  stop) stop; exit 0 ;;
  restart) stop ;;
  *) until [ "$(getprop sys.boot_completed)" = 1 ]; do sleep 5; done ;;
esac
(
  while true; do
    sh "$MODDIR/watcher.sh"
    sleep 5
  done
) >/dev/null 2>&1 &
echo $! > "$PIDF"
