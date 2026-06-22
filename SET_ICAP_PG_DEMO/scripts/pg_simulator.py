#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
================================================================================
 Demo SET-ICAP - Simulador OLTP: actualiza Postgres constantemente
================================================================================
 Simula el sistema SET-FX escribiendo en la instancia Snowflake Postgres:
 cada ciclo INSERTA operaciones nuevas y, periódicamente, ACTUALIZA (anula
 operaciones, ajusta precios). Así el cliente ve los cambios fluir a Snowflake
 (vía catalog integration / CLD) en segundos, SIN ETL.

 Usa psql con la conexión guardada 'setfx' (~/.pg_service.conf + ~/.pgpass).

 Uso:
   # un solo lote:
   ~/miniforge3/bin/python scripts/pg_simulator.py --once
   # bucle continuo cada 10s (Ctrl-C para detener):
   ~/miniforge3/bin/python scripts/pg_simulator.py --loop --interval 10
================================================================================
"""
import argparse
import os
import random
import subprocess
import sys
import time

PGSERVICE = os.environ.get("PGSERVICE", "setfx")
STATE = os.path.join(os.path.dirname(__file__), ".sim_trm")


def psql(sql: str) -> str:
    """Ejecuta SQL en la instancia Postgres vía psql (service=setfx)."""
    r = subprocess.run(
        ["psql", f"service={PGSERVICE} connect_timeout=10", "-v", "ON_ERROR_STOP=1",
         "-t", "-A", "-c", sql],
        capture_output=True, text=True)
    if r.returncode != 0:
        sys.stderr.write(r.stderr)
        raise RuntimeError(f"psql falló: {r.stderr.strip()[:200]}")
    return r.stdout.strip()


def load_trm() -> float:
    try:
        with open(STATE) as f:
            return float(f.read().strip())
    except Exception:
        return 3445.0


def save_trm(v: float):
    with open(STATE, "w") as f:
        f.write(f"{v:.2f}")


def next_id() -> int:
    out = psql("SELECT COALESCE(MAX(id), 22500000) FROM operation_set_fx;")
    return int(out) + 1


def insert_batch(start_id: int, n: int, trm: float) -> int:
    """Inserta n operaciones nuevas con timestamp actual."""
    sql = f"""
INSERT INTO operation_set_fx
  (id, fecha, hora, anulada, mercado, mcod_transaccion, monto_usd, monto_cop,
   precio, precio_spot, plazo_curva, entidad_compradora, entidad_vendedora, texto_term)
SELECT
  {start_id} + g,
  CURRENT_DATE,
  CURRENT_TIME::time,
  (random() < 0.01),
  (ARRAY[76,76,76,77,78,79])[1+floor(random()*6)::int],
  'FWLIVE' || to_hex({start_id} + g),
  mm.monto_usd,
  round(mm.monto_usd * pp.precio, 2),
  pp.precio,
  {trm:.2f},
  (ARRAY['T+1','T+1','T+1','T+0','1M','3M'])[1+floor(random()*6)::int],
  1 + floor(random()*15)::int,
  1 + ((floor(random()*15)::int + 3) % 15),
  CASE WHEN random() < 0.1 THEN
    (ARRAY['Demanda corporativa sostenida.','Exportadores venden dólares.',
           'Spreads ajustados entre IMC.','Volatilidad por dato externo.',
           'Banco de la República monitorea la TRM.'])[1+floor(random()*5)::int]
  ELSE NULL END
FROM generate_series(1, {n}) AS g
CROSS JOIN LATERAL (SELECT (round((50000 + random()*1950000)/50000)*50000)::numeric(18,2) AS monto_usd) mm
CROSS JOIN LATERAL (SELECT round(({trm:.2f} + (random()-0.5)*6)::numeric, 2) AS precio) pp;
"""
    psql(sql)
    return n


def random_update():
    """Periódicamente anula una operación reciente (muestra UPDATE fluyendo)."""
    psql("""
UPDATE operation_set_fx SET anulada = TRUE, ts_carga = now()
WHERE id IN (SELECT id FROM operation_set_fx WHERE NOT anulada
             ORDER BY id DESC LIMIT 1 OFFSET floor(random()*20)::int);
""")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--once", action="store_true")
    ap.add_argument("--loop", action="store_true")
    ap.add_argument("--interval", type=int, default=10)
    ap.add_argument("--rows", type=int, default=20)
    args = ap.parse_args()
    if not (args.once or args.loop):
        args.once = True

    def cycle():
        trm = load_trm()
        trm = round(min(4600, max(3300, trm + random.gauss(0, 3))), 2)  # random walk
        save_trm(trm)
        sid = next_id()
        n = insert_batch(sid, args.rows, trm)
        if random.random() < 0.5:
            random_update()
        total = psql("SELECT count(*) FROM operation_set_fx;")
        ts = time.strftime("%H:%M:%S")
        print(f"[{ts}] +{n} ops (TRM~{trm:.2f}) -> total operation_set_fx = {total}")

    if args.loop:
        print(f"Simulador SET-FX activo cada {args.interval}s. Ctrl-C para detener.")
        try:
            while True:
                cycle()
                time.sleep(args.interval)
        except KeyboardInterrupt:
            print("\nDetenido.")
    else:
        cycle()


if __name__ == "__main__":
    main()
