#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
================================================================================
 SET-ICAP HOL - Generador de STREAMING de operaciones FX (cada 5 minutos)
================================================================================
 Simula el flujo en tiempo real del sistema SET-FX: cada ciclo genera un lote
 de operaciones nuevas y lo deposita en S3 como CSV gzip. Snowflake lo captura
 con Snowpipe (ver Parte 4 del HOL).

 El esquema coincide EXACTAMENTE con la tabla operation_set_fx del histórico,
 para que el mismo PIPE / COPY INTO funcione sin cambios.

 Uso:
   export AWS_PROFILE=contributor-484577546576
   # Un solo lote (ideal para cron / AWS Lambda cada 5 min):
   ~/miniforge3/bin/python gen_set_icap_stream.py --once
   # Bucle continuo (genera cada 5 min hasta Ctrl-C):
   ~/miniforge3/bin/python gen_set_icap_stream.py --loop --interval 300
   # Local sin subir (debug):
   ~/miniforge3/bin/python gen_set_icap_stream.py --once --no-upload

 Datos 100% sintéticos para fines demostrativos.
================================================================================
"""
import argparse
import gzip
import io
import os
import time
import json
import datetime as dt
import numpy as np
import pandas as pd

S3_BUCKET = "demosjparrado"
S3_PREFIX = "set_icap_hol/stream"
OUT_DIR = os.path.join(os.path.dirname(__file__), "out_stream")
STATE_FILE = os.path.join(os.path.dirname(__file__), ".stream_state.json")

RNG = np.random.default_rng()  # sin semilla: cada lote es distinto

PLAZO_DIAS = {"T+0": 0, "T+1": 1, "T+2": 2, "1W": 7, "1M": 30,
              "3M": 90, "6M": 180, "1Y": 360}
NOTAS = [
    "Demanda corporativa eleva la TRM en la apertura.",
    "Exportadores venden dólares, presión a la baja.",
    "Spreads ajustados entre IMC, jornada estable.",
    "Volatilidad por dato de inflación en EE.UU.",
    "Banco de la República monitorea el mercado.",
    "Operaciones forward activas antes del cierre.",
    "Liquidez reducida, pocos participantes activos.",
    "Apetito de riesgo global favorece al peso.",
]

# Entidades más activas (entidad_id 1..25 = grandes/medianas del histórico)
ENT_ACTIVAS = list(range(1, 26))
PESO_ENT = np.array([8.0] * 11 + [3.0] * 14)
PESO_ENT = PESO_ENT / PESO_ENT.sum()


def load_state():
    """TRM de referencia: continúa donde quedó el último lote (o histórico)."""
    if os.path.exists(STATE_FILE):
        with open(STATE_FILE) as f:
            return json.load(f)
    return {"trm": 3445.0, "seq": 5000000}


def save_state(state):
    with open(STATE_FILE, "w") as f:
        json.dump(state, f)


def gen_batch(state, n=50):
    """Genera un lote de n operaciones con esquema idéntico a operation_set_fx."""
    now = dt.datetime.now()
    # random walk de la TRM intradía
    trm = state["trm"] + RNG.normal(0, 5)
    trm = float(np.clip(trm, 3300, 4600))
    state["trm"] = trm

    rows = []
    for _ in range(n):
        state["seq"] += 1
        oid = 22000000 + state["seq"]
        merc = int(RNG.choice([76, 77, 78, 79, 85, 80],
                              p=[0.62, 0.10, 0.12, 0.06, 0.05, 0.05]))
        ic, iv = RNG.choice(len(ENT_ACTIVAS), size=2, replace=False, p=PESO_ENT)
        eid_c, eid_v = ENT_ACTIVAS[ic], ENT_ACTIVAS[iv]
        monto = float(np.clip(round(np.exp(RNG.normal(13.0, 0.8)) / 50000) * 50000,
                              50000, 15000000))
        precio = round(trm + RNG.normal(0, trm * 0.0015), 2)

        if merc == 76:
            plazo, pf = "T+1", 0.0
        elif merc == 77:
            plazo, pf = "T+0", 0.0
        elif merc in (78, 85):
            plazo, pf = str(RNG.choice(["1M", "3M", "6M", "1Y"])), round(RNG.normal(15, 8), 2)
        elif merc == 79:
            plazo, pf = str(RNG.choice(["1W", "1M", "3M"])), round(RNG.normal(8, 5), 2)
        else:
            plazo, pf = "T+2", 0.0
        pdias = PLAZO_DIAS[plazo]

        hora_op = now - dt.timedelta(seconds=int(RNG.integers(0, 290)))
        hora_post = hora_op - dt.timedelta(seconds=int(RNG.integers(5, 300)))
        fecha_valor = (now.date() + dt.timedelta(days=pdias if pdias > 0 else 1))
        anulada = RNG.random() < 0.01
        monto_cop = round(monto * precio, 2)
        nota = str(RNG.choice(NOTAS)) if RNG.random() < 0.10 else ""

        rows.append((
            oid,
            now.date().isoformat(),
            hora_op.strftime("%H:%M:%S"),
            anulada,
            merc,
            int(RNG.choice([1, 2, 3, 4, 7, 10])),
            bool(RNG.random() < 0.4),
            f"FWST{state['seq']:X}",
            f"O{RNG.integers(100, 999)}",
            pdias,
            fecha_valor.isoformat(),
            hora_post.strftime("%H:%M:%S"),
            round(monto, 2),
            monto_cop,
            round(monto, 2),
            precio,
            pf,
            round(trm, 2),
            plazo,
            bool(RNG.random() < 0.05),
            bool(RNG.random() < 0.5),
            1, "USD/COP", 2, 1,
            int(eid_c), int(eid_v),
            pdias,
            bool(RNG.random() < 0.7),
            nota,
        ))

    df = pd.DataFrame(rows, columns=[
        "id", "fecha", "hora", "anulada", "mercado", "sub_mercado", "registro",
        "mcod_transaccion", "usuario_postura", "dias", "fecha_valor",
        "hora_postura", "monto_moneda_uno", "monto_moneda_dos", "monto_usd",
        "precio", "points_forward", "precio_spot", "plazo_curva",
        "entidad_publica_3c_1", "bandera_fisico_compensacion", "paridad_id",
        "paridad_nombre", "moneda_uno", "moneda_dos", "entidad_compradora",
        "entidad_vendedora", "plazo_dias", "enviada_camara", "texto_term"])
    return df


def to_gz(df):
    buf = io.BytesIO()
    with gzip.GzipFile(fileobj=buf, mode="wb") as gz:
        df.to_csv(gz, sep=";", index=False, header=True, na_rep="NULL")
    return buf.getvalue()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--once", action="store_true", help="un solo lote y termina")
    ap.add_argument("--loop", action="store_true", help="bucle continuo")
    ap.add_argument("--interval", type=int, default=300, help="segundos entre lotes (loop)")
    ap.add_argument("--rows", type=int, default=50, help="operaciones por lote")
    ap.add_argument("--no-upload", action="store_true", help="solo local, no S3")
    args = ap.parse_args()
    if not (args.once or args.loop):
        args.once = True

    s3 = None
    if not args.no_upload:
        import boto3
        s3 = boto3.Session(profile_name=os.environ.get(
            "AWS_PROFILE", "contributor-484577546576")).client("s3")

    def one_cycle():
        state = load_state()
        df = gen_batch(state, n=args.rows)
        save_state(state)
        data = to_gz(df)
        ts = dt.datetime.now().strftime("%Y%m%d_%H%M%S")
        fname = f"set_fx_{ts}.csv.gz"
        if s3 is not None:
            key = f"{S3_PREFIX}/{fname}"
            s3.put_object(Bucket=S3_BUCKET, Key=key, Body=data)
            print(f"[{ts}] {len(df)} ops -> s3://{S3_BUCKET}/{key}  (TRM~{state['trm']:.2f})")
        else:
            os.makedirs(OUT_DIR, exist_ok=True)
            path = os.path.join(OUT_DIR, fname)
            with open(path, "wb") as f:
                f.write(data)
            print(f"[{ts}] {len(df)} ops -> {path}  (TRM~{state['trm']:.2f})")

    if args.loop:
        print(f"Streaming cada {args.interval}s. Ctrl-C para detener.")
        try:
            while True:
                one_cycle()
                time.sleep(args.interval)
        except KeyboardInterrupt:
            print("\nDetenido.")
    else:
        one_cycle()


if __name__ == "__main__":
    main()
