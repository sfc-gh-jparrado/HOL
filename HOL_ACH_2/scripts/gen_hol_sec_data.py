#!/usr/bin/env python
"""Genera datos sinteticos de seguridad (~50M filas) y los sube a S3.
Tablas: AUTH_LOGINS (~20M), EXPORT_EVENTS (~25M en varios archivos), CUSTOMERS (~5M).
Formato: CSV gzip, delimitador ';', con header. Sin PII real.

Modelo pensado para que las detecciones tengan senal limpia:
- Cada usuario tiene un PAIS DE ORIGEN FIJO (usr_NNN -> CITIES[NNN % 7]),
  asi que un usuario normal nunca dispara "viaje imposible".
- svc_etl tiene actividad base (logins CO + exports pequenos) MAS las anomalias,
  para que el pico de exfiltracion quede por encima de 3 sigma de su propia media.
"""
import gzip, io, datetime as dt
import numpy as np
import pandas as pd
import boto3

PROFILE = "contributor-484577546576"
BUCKET = "demosjparrado"
PREFIX = "hol_ach_2"
session = boto3.Session(profile_name=PROFILE)
s3 = session.client("s3")

rng = np.random.default_rng(42)

CITIES  = np.array(["Bogota","Medellin","Lima","Madrid","Miami","Frankfurt","Singapore"])
COUNTRY = np.array(["CO","CO","PE","ES","US","DE","SG"])

today0 = dt.datetime.combine(dt.date.today(), dt.time())
yday0  = today0 - dt.timedelta(days=1)
WINDOW_MIN = 60 * 24 * 60  # 60 dias en minutos


def upload_gz(df: pd.DataFrame, key: str):
    buf = io.BytesIO()
    with gzip.GzipFile(fileobj=buf, mode="wb") as gz:
        gz.write(df.to_csv(index=False, sep=";", header=True).encode("utf-8"))
    buf.seek(0)
    s3.upload_fileobj(buf, BUCKET, key)
    print(f"  uploaded s3://{BUCKET}/{key}  ({len(df):,} rows)", flush=True)


def ips(n):
    parts = [rng.integers(1, 256, n).astype(str) for _ in range(4)]
    out = parts[0]
    for p in parts[1:]:
        out = np.char.add(np.char.add(out, "."), p)
    return out


def ts_random(n):
    mins = rng.integers(0, WINDOW_MIN, n)
    return (np.datetime64(today0) - mins.astype("timedelta64[m]")).astype("datetime64[s]")


# ---------- AUTH_LOGINS ~20M en 20 archivos de 1M ----------
print("AUTH_LOGINS", flush=True)
seq = 0
for i in range(20):
    n = 1_000_000
    uidx = rng.integers(1, 301, n)                     # 1..300
    users = np.char.add("usr_", np.char.zfill(uidx.astype(str), 3))
    gidx = uidx % 7                                     # pais de origen FIJO por usuario
    status = np.where(rng.integers(1, 101, n) <= 12, "FAIL", "SUCCESS")
    df = pd.DataFrame({
        "EVENT_ID": np.arange(seq, seq + n),
        "EVENT_TS": ts_random(n),
        "USER_NAME": users,
        "CITY": CITIES[gidx],
        "COUNTRY": COUNTRY[gidx],
        "CLIENT_IP": ips(n),
        "STATUS": status,
    })
    seq += n
    upload_gz(df, f"{PREFIX}/auth_logins/part_{i:03d}.csv.gz")

# svc_etl: actividad base (logins CO), rafaga de fallos + viaje imposible (CO -> DE en 2h)
rows = []
eid = 900000
# base: ~200 logins normales desde Bogota, dias -60..-2
for j in range(200):
    d = int(rng.integers(2, 60))
    rows.append([eid, today0 - dt.timedelta(days=d, minutes=int(rng.integers(0, 1440))),
                 "svc_etl", "Bogota", "CO", "10.0.0.5", "SUCCESS"]); eid += 1
# rafaga de fallos ~02:00 de ayer
burst0 = yday0 + dt.timedelta(hours=2)
for j in range(40):
    rows.append([eid, burst0 + dt.timedelta(seconds=3 * j), "svc_etl",
                 "Bogota", "CO", "10.0.0.5", "FAIL"]); eid += 1
# viaje imposible: SUCCESS Bogota 00:30 -> SUCCESS Frankfurt 02:30 (mismo dia, ayer)
rows.append([eid, yday0 + dt.timedelta(minutes=30), "svc_etl", "Bogota", "CO", "10.0.0.5", "SUCCESS"]); eid += 1
rows.append([eid, yday0 + dt.timedelta(hours=2, minutes=30), "svc_etl", "Frankfurt", "DE", "185.22.14.9", "SUCCESS"]); eid += 1
df_anom = pd.DataFrame(rows, columns=["EVENT_ID","EVENT_TS","USER_NAME","CITY","COUNTRY","CLIENT_IP","STATUS"])
upload_gz(df_anom, f"{PREFIX}/auth_logins/part_999_anomaly.csv.gz")

# ---------- EXPORT_EVENTS ~25M en 25 archivos de 1M (tabla de escalado) ----------
print("EXPORT_EVENTS", flush=True)
seq = 0
for i in range(25):
    n = 1_000_000
    uidx = rng.integers(1, 301, n)
    users = np.char.add("usr_", np.char.zfill(uidx.astype(str), 3))
    df = pd.DataFrame({
        "EXPORT_ID": np.arange(seq, seq + n),
        "EXPORT_TS": ts_random(n),
        "USER_NAME": users,
        "BYTES_OUT": rng.integers(50_000, 5_000_000, n),
    })
    seq += n
    upload_gz(df, f"{PREFIX}/export_events/part_{i:03d}.csv.gz")

# svc_etl: actividad base pequena + pico de exfiltracion a las 3:00 AM de ayer
rows = []
xid = 800000
for j in range(1000):                                   # base pequena, 60 dias
    d = int(rng.integers(2, 60))
    rows.append([xid, today0 - dt.timedelta(days=d, minutes=int(rng.integers(0, 1440))),
                 "svc_etl", int(rng.integers(50_000, 2_000_000))]); xid += 1
spike0 = yday0 + dt.timedelta(hours=3)                  # pico
for j in range(30):
    rows.append([xid, spike0 + dt.timedelta(minutes=2 * j), "svc_etl",
                 int(rng.integers(180_000_000, 400_000_000))]); xid += 1
df_spike = pd.DataFrame(rows, columns=["EXPORT_ID","EXPORT_TS","USER_NAME","BYTES_OUT"])
upload_gz(df_spike, f"{PREFIX}/export_events/part_999_spike.csv.gz")

# ---------- CUSTOMERS ~5M en 5 archivos de 1M ----------
print("CUSTOMERS", flush=True)
BR = np.array(["Bogota","Medellin","Cali","Barranquilla"])
seq = 0
for i in range(5):
    n = 1_000_000
    ids = np.arange(seq, seq + n)
    df = pd.DataFrame({
        "CUSTOMER_ID": ids,
        "FULL_NAME": np.char.add("Cliente ", ids.astype(str)),
        "EMAIL": np.char.add(np.char.add("user", ids.astype(str)), "@correo.com"),
        "NATIONAL_ID": np.char.zfill(rng.integers(1_000_000_000, 9_999_999_999, n).astype(str), 10),
        "CARD_LAST4": np.char.add("****-****-****-", np.char.zfill(rng.integers(0, 10000, n).astype(str), 4)),
        "BRANCH_CITY": BR[rng.integers(0, 4, n)],
    })
    seq += n
    upload_gz(df, f"{PREFIX}/customers/part_{i:03d}.csv.gz")

print("DONE", flush=True)
