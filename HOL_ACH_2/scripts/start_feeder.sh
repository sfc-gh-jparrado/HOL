#!/usr/bin/env bash
# Arranca el feeder PSE en segundo plano. Uso: ./start_feeder.sh [intervalo_seg] [batch]
set -euo pipefail
cd "$(dirname "$0")"
INTERVAL="${1:-15}"
BATCH="${2:-800}"
PY="${PYTHON:-python}"
if [ -f feeder.pid ] && kill -0 "$(cat feeder.pid)" 2>/dev/null; then
  echo "Feeder ya corriendo (PID $(cat feeder.pid)). Usa ./stop_feeder.sh primero."; exit 1
fi
nohup "$PY" feeder_pse.py --interval "$INTERVAL" --batch "$BATCH" > feeder.log 2>&1 &
echo $! > feeder.pid
echo "Feeder PSE arrancado (PID $(cat feeder.pid)) cada ${INTERVAL}s, ${BATCH} txns/lote."
echo "Log: $(pwd)/feeder.log  |  Detener: ./stop_feeder.sh"
