#!/usr/bin/env python
"""Feeder de tiempo real PSE -> S3 (pse_stream/).
Cada INTERVALO segundos genera un lote de transacciones PSE con ts actual
y sube un CSV.gz a s3://demosjparrado/hol_ach_2/pse_stream/.
Sube vía AWS SSO (profile contributor); NO usa credenciales de Snowflake.

Uso:
  python feeder_pse.py --interval 15 --batch 800            # corre hasta Ctrl-C
  python feeder_pse.py --interval 15 --batch 800 --minutes 90
  python feeder_pse.py --once                               # un solo lote (para probar)

Columnas (orden = tabla PSE_TRANSACTIONS):
  txn_id; ts; banco; comercio_id; monto; canal; estado; tipo_persona; documento_hash; ciudad
"""
import argparse, gzip, io, time, sys, datetime as dt
import numpy as np
import boto3

PROFILE = "contributor-484577546576"
BUCKET  = "demosjparrado"
PREFIX  = "hol_ach_2/pse_stream"
s3 = boto3.Session(profile_name=PROFILE).client("s3")
rng = np.random.default_rng()

BANCOS = np.array([
  "Bancolombia","Davivienda","BBVA Colombia","Banco de Bogota","Nequi","Daviplata",
  "Banco de Occidente","Scotiabank Colpatria","Itau","Banco Popular","Banco Caja Social",
  "Banco AV Villas","Banco Agrario","Bancoomeva","Banco Falabella","Banco Pichincha",
  "GNB Sudameris","Banco Serfinanza","Lulo Bank","Nu Colombia"])
CIUDADES = np.array(["Bogota","Medellin","Cali","Barranquilla","Bucaramanga","Cartagena","Pereira"])
ESTADOS  = np.array(["APROBADA","RECHAZADA","PENDIENTE","TIMEOUT","REVERSADA"])
EST_P    = np.array([0.85, 0.08, 0.03, 0.02, 0.02])

# base de txn_id alto para no chocar con el historico
_counter = {"n": 60_000_000}


def make_batch(n: int) -> bytes:
    now = dt.datetime.now()
    base = _counter["n"]; _counter["n"] += n
    txn_id = np.arange(base, base + n)
    # ts: repartido en el intervalo hacia atras (segundos)
    offs = rng.integers(0, 60, n)
    ts = [(now - dt.timedelta(seconds=int(o))).strftime("%Y-%m-%d %H:%M:%S") for o in offs]
    banco = BANCOS[rng.integers(0, len(BANCOS), n)]
    comercio = rng.integers(1, 501, n)
    tier = rng.random(n)
    monto = np.where(tier < 0.70, rng.integers(10_000, 500_000, n),
             np.where(tier < 0.95, rng.integers(500_000, 3_000_000, n),
                                    rng.integers(3_000_000, 20_000_000, n)))
    canal = np.where(rng.integers(0, 2, n) == 0, "WEB", "APP")
    estado = rng.choice(ESTADOS, size=n, p=EST_P)
    tipo = np.where(rng.integers(1, 101, n) <= 80, "NATURAL", "JURIDICA")
    doc = np.char.add("DOC", np.char.zfill(rng.integers(1, 2_000_000, n).astype(str), 8))
    ciudad = CIUDADES[rng.integers(0, len(CIUDADES), n)]

    buf = io.StringIO()
    buf.write("txn_id;ts;banco;comercio_id;monto;canal;estado;tipo_persona;documento_hash;ciudad\n")
    for i in range(n):
        buf.write(f"{txn_id[i]};{ts[i]};{banco[i]};{comercio[i]};{monto[i]};"
                  f"{canal[i]};{estado[i]};{tipo[i]};{doc[i]};{ciudad[i]}\n")
    out = io.BytesIO()
    with gzip.GzipFile(fileobj=out, mode="wb") as gz:
        gz.write(buf.getvalue().encode("utf-8"))
    return out.getvalue()


def upload(n: int):
    data = make_batch(n)
    key = f"{PREFIX}/pse_{dt.datetime.now().strftime('%Y%m%d_%H%M%S_%f')}.csv.gz"
    s3.put_object(Bucket=BUCKET, Key=key, Body=data)
    print(f"{dt.datetime.now():%H:%M:%S}  ->  s3://{BUCKET}/{key}  ({n} txns, {len(data)} B)", flush=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--interval", type=int, default=15, help="segundos entre lotes")
    ap.add_argument("--batch", type=int, default=800, help="transacciones por lote")
    ap.add_argument("--minutes", type=int, default=0, help="detener tras N minutos (0 = infinito)")
    ap.add_argument("--once", action="store_true", help="un solo lote y salir")
    a = ap.parse_args()

    if a.once:
        upload(a.batch); return

    end = time.time() + a.minutes * 60 if a.minutes else None
    print(f"Feeder PSE iniciado: cada {a.interval}s, {a.batch} txns/lote. Ctrl-C para detener.", flush=True)
    try:
        while True:
            upload(a.batch)
            if end and time.time() >= end:
                print("Duracion alcanzada, deteniendo.", flush=True); break
            time.sleep(a.interval)
    except KeyboardInterrupt:
        print("\nFeeder detenido por el usuario.", flush=True)


if __name__ == "__main__":
    main()
