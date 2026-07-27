#!/usr/bin/env bash
# Detiene el feeder PSE.
set -euo pipefail
cd "$(dirname "$0")"
if [ -f feeder.pid ] && kill -0 "$(cat feeder.pid)" 2>/dev/null; then
  kill "$(cat feeder.pid)" && echo "Feeder detenido (PID $(cat feeder.pid))."
  rm -f feeder.pid
else
  pkill -f feeder_pse.py 2>/dev/null && echo "Feeder detenido (pkill)." || echo "No hay feeder corriendo."
  rm -f feeder.pid
fi
