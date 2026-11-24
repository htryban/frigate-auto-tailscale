#!/bin/sh
# Package the module zip: ./build.sh  ->  auto-tailscale-<version>.zip
set -e
cd "$(dirname "$0")"
VER=$(sed -n 's/^version=//p' module.prop)
OUT="auto-tailscale-$VER.zip"
rm -f "$OUT"
zip -r -X "$OUT" module.prop config.sh customize.sh service.sh watcher.sh action.sh uninstall.sh META-INF >/dev/null
echo "$OUT"
