#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
================================================================================
 SET-ICAP HOL - Generador VECTORIZADO 400M filas (archivos 100-250 MB gzip)
================================================================================
 Genera 120M ops + 240M contraparte + 40M comitente en archivos óptimos para
 COPY INTO con warehouse XLARGE (16 nodos). Cada archivo pesa 100-250 MB gzip.

 Vectorizado: genera columnas enteras con numpy (sin loops Python por fila).
 Tiempo estimado: ~15-20 min total (generación + upload).

 Uso:
   export AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=... AWS_DEFAULT_REGION=us-east-1
   ~/miniforge3/bin/python gen_set_icap_400m.py --upload
================================================================================
"""
import argparse, gzip, io, os, sys, time
import datetime as dt
import numpy as np
import pandas as pd
from concurrent.futures import ThreadPoolExecutor, as_completed

S3_BUCKET = "demosjparrado"
S3_PREFIX = "set_icap_hol/hist"

# --- Targets ---
TARGET_OPS = 120_000_000
TARGET_CP  = TARGET_OPS * 2    # 240M (siempre 2 por op)
TARGET_CM  = 40_000_000        # comitentes

# File sizing: target 100-250 MB gzip each (measured from test run)
# operation_set_fx: 2M rows = 79 MB → 4M rows ≈ 158 MB ✓  (30 files for 120M)
# contraparte: 4M rows = 18 MB → 30M rows ≈ 135 MB ✓  (8 files for 240M)
# comitente: 2.5M rows = 17 MB → 20M rows ≈ 136 MB ✓  (2 files for 40M)
ROWS_PER_FILE_OPS = 4_000_000   # ~30 files × 158 MB = 120M
ROWS_PER_FILE_CP  = 30_000_000  # ~8 files × 135 MB = 240M
ROWS_PER_FILE_CM  = 20_000_000  # ~2 files × 136 MB = 40M

N_ENTIDADES = 50
PESO_ENT = np.ones(N_ENTIDADES, dtype=float)
PESO_ENT[:11] = 8.0
PESO_ENT[11:25] = 3.0
PESO_ENT /= PESO_ENT.sum()

# TRM anchors (monthly, 2021-2026)
ANCLAS = {
    (2021,1):3600,(2021,2):3580,(2021,3):3650,(2021,4):3700,(2021,5):3720,
    (2021,6):3750,(2021,7):3800,(2021,8):3830,(2021,9):3850,(2021,10):3790,
    (2021,11):3900,(2021,12):3980,
    (2022,1):4000,(2022,2):3950,(2022,3):3780,(2022,4):3850,(2022,5):3950,
    (2022,6):4100,(2022,7):4300,(2022,8):4400,(2022,9):4500,(2022,10):4900,
    (2022,11):4850,(2022,12):4800,
    (2023,1):4700,(2023,2):4800,(2023,3):4750,(2023,4):4600,(2023,5):4400,
    (2023,6):4300,(2023,7):4150,(2023,8):4100,(2023,9):4050,(2023,10):4200,
    (2023,11):4100,(2023,12):3900,
    (2024,1):3900,(2024,2):3950,(2024,3):3850,(2024,4):3900,(2024,5):3850,
    (2024,6):4000,(2024,7):4100,(2024,8):4050,(2024,9):4150,(2024,10):4200,
    (2024,11):4180,(2024,12):4250,
    (2025,1):4250,(2025,2):4200,(2025,3):4100,(2025,4):4050,(2025,5):4000,
    (2025,6):4150,(2025,7):4080,(2025,8):4020,(2025,9):3980,(2025,10):4050,
    (2025,11):4180,(2025,12):4320,
    (2026,1):4250,(2026,2):4100,(2026,3):3950,(2026,4):3820,(2026,5):3650,
    (2026,6):3445,
}

NOTAS = [
    "Demanda corporativa sostenida durante la sesion.",
    "Exportadores venden dolares, presion a la baja.",
    "Spreads ajustados entre IMC, jornada estable.",
    "Volatilidad por dato de inflacion en EE.UU.",
    "Banco de la Republica monitorea la TRM.",
    "Apetito por riesgo global favorece al peso.",
    "Cierre con tendencia alcista por incertidumbre fiscal.",
    "Liquidez reducida en la ultima hora de negociacion.",
    "Operaciones forward activas antes del cierre.",
    "Intervencion del Banco de la Republica estabiliza la TRM.",
]
PLAZOS = np.array(["T+1","T+1","T+1","T+0","1M","3M","6M","T+2"])
MERCADOS = np.array([76,76,76,77,78,79,85,80])
PLAZO_DIAS_MAP = {"T+0":0,"T+1":1,"T+2":2,"1W":7,"1M":30,"3M":90,"6M":180,"1Y":360}


def gen_trm_array(n, rng):
    """Generate n TRM values with realistic random walk anchored to monthly means."""
    # Distribute across 5.5 years proportionally
    total_months = 66  # Jan 2021 - Jun 2026
    trm = np.empty(n, dtype=np.float64)
    prev = 3600.0
    for i in range(n):
        month_idx = int(i / n * total_months)
        year = 2021 + month_idx // 12
        month = 1 + month_idx % 12
        ancla = ANCLAS.get((year, month), prev)
        prev = prev + 0.12 * (ancla - prev) + rng.normal(0, 8)
        prev = max(3200, min(5200, prev))
        trm[i] = round(prev, 2)
    return trm


def gen_dates_array(n, rng):
    """Generate n business dates spanning 2021-01-04 to 2026-06-19."""
    d0 = dt.date(2021, 1, 4).toordinal()
    d1 = dt.date(2026, 6, 19).toordinal()
    ords = rng.integers(d0, d1 + 1, size=n)
    # filter to weekdays (vectorized)
    days_of_week = ords % 7  # 0=Mon in Python's ordinal? No - need adjustment
    # dt.date.fromordinal(1).weekday() = 0 (Monday) for Jan 1, 0001
    # Better: just map and retry non-weekdays
    dow = (ords + 5) % 7  # shift so 0=Mon, 5=Sat, 6=Sun
    sat = dow == 5
    sun = dow == 6
    ords[sat] -= rng.integers(1, 2, size=sat.sum())  # Sat → Fri
    ords[sun] += rng.integers(1, 2, size=sun.sum())  # Sun → Mon
    # Sort for sequential ID ordering
    ords.sort()
    return ords


def gen_ops_file(file_id, n_rows, start_id, rng):
    """Generate one file of operation_set_fx (fully vectorized)."""
    ids = np.arange(start_id, start_id + n_rows, dtype=np.int64)
    
    # Dates
    date_ords = gen_dates_array(n_rows, rng)
    fechas = [dt.date.fromordinal(int(o)).isoformat() for o in date_ords]
    
    # TRM per row (anchored walk)
    trm = gen_trm_array(n_rows, rng)
    
    # Hours (8:00-13:00 = 18000 seconds)
    secs = rng.integers(0, 18000, size=n_rows)
    horas = [f"{8+s//3600:02d}:{(s%3600)//60:02d}:{s%60:02d}" for s in secs]
    hora_post_secs = secs - rng.integers(5, 300, size=n_rows)
    horas_post = [f"{max(8,(8+s//3600)):02d}:{abs(s%3600)//60:02d}:{abs(s)%60:02d}" for s in hora_post_secs]
    
    # Market and plazo
    merc_idx = rng.integers(0, len(MERCADOS), size=n_rows)
    mercados = MERCADOS[merc_idx]
    plazos = PLAZOS[merc_idx]
    plazo_dias = np.array([PLAZO_DIAS_MAP.get(p, 1) for p in plazos], dtype=np.int32)
    
    # Entities
    idx_c = rng.choice(N_ENTIDADES, size=n_rows, p=PESO_ENT) + 1
    idx_v = rng.choice(N_ENTIDADES, size=n_rows, p=PESO_ENT) + 1
    same = idx_c == idx_v
    idx_v[same] = (idx_v[same] % N_ENTIDADES) + 1
    
    # Amounts
    montos = np.round(np.exp(rng.normal(13.0, 0.8, size=n_rows)) / 50000) * 50000
    montos = np.clip(montos, 50000, 15000000)
    
    # Prices
    precios = np.round(trm + rng.normal(0, trm * 0.0012), 2)
    monto_cop = np.round(montos * precios, 2)
    
    # Forward points
    pf = np.where(np.isin(mercados, [78, 85]), np.round(rng.normal(12, 6, size=n_rows), 2), 0.0)
    
    # Booleans
    anuladas = rng.random(size=n_rows) < 0.012
    registros = rng.random(size=n_rows) < 0.4
    pub = rng.random(size=n_rows) < 0.05
    fisico = rng.random(size=n_rows) < 0.5
    camara = rng.random(size=n_rows) < 0.7
    
    # Sub-mercado
    sub_mercados = rng.choice([1,2,3,4,7,10], size=n_rows)
    
    # Transaction codes
    mcods = [f"FW{x:X}" for x in ids]
    
    # User codes
    user_codes = [f"O{rng.integers(100,999)}" for _ in range(n_rows)]
    
    # Notas (~7%)
    tiene_nota = rng.random(size=n_rows) < 0.07
    notas_idx = rng.integers(0, len(NOTAS), size=n_rows)
    notas = [NOTAS[notas_idx[i]] if tiene_nota[i] else "" for i in range(n_rows)]
    
    # Fecha valor
    fvalor = [dt.date.fromordinal(int(date_ords[i]) + int(plazo_dias[i]) if plazo_dias[i] > 0 else int(date_ords[i]) + 1).isoformat() for i in range(n_rows)]
    
    df = pd.DataFrame({
        "id": ids, "fecha": fechas, "hora": horas,
        "anulada": anuladas, "mercado": mercados, "sub_mercado": sub_mercados,
        "registro": registros, "mcod_transaccion": mcods, "usuario_postura": user_codes,
        "dias": plazo_dias, "fecha_valor": fvalor, "hora_postura": horas_post,
        "monto_moneda_uno": montos, "monto_moneda_dos": monto_cop, "monto_usd": montos,
        "precio": precios, "points_forward": pf, "precio_spot": trm,
        "plazo_curva": plazos, "entidad_publica_3c_1": pub,
        "bandera_fisico_compensacion": fisico, "paridad_id": 1,
        "paridad_nombre": "USD/COP", "moneda_uno": 2, "moneda_dos": 1,
        "entidad_compradora": idx_c, "entidad_vendedora": idx_v,
        "plazo_dias": plazo_dias, "enviada_camara": camara, "texto_term": notas,
    })
    return df


def gen_cp_file(file_id, n_rows, start_id, rng):
    """Generate contraparte file (2 rows per op, fully vectorized)."""
    n_ops = n_rows // 2
    op_ids = np.repeat(np.arange(start_id, start_id + n_ops, dtype=np.int64), 2)
    lados = np.tile(["C", "V"], n_ops)
    ent_ids = rng.choice(N_ENTIDADES, size=n_rows, p=PESO_ENT) + 1
    suc_ids = (ent_ids - 1) * 3 + rng.integers(1, 4, size=n_rows)
    trader_ids = suc_ids * 3 + rng.integers(0, 3, size=n_rows)
    
    df = pd.DataFrame({
        "oper_id": op_ids, "oper_lado": lados, "entidad_id": ent_ids,
        "sucursal_id": suc_ids, "trader_id": trader_ids,
        "broker_id": np.full(n_rows, None), "comitente_id": np.full(n_rows, None),
    })
    return df


def gen_cm_file(file_id, n_rows, start_id, rng):
    """Generate comitente file (vectorized)."""
    op_ids = np.arange(start_id, start_id + n_rows, dtype=np.int64)
    ent_ids = rng.choice(N_ENTIDADES, size=n_rows, p=PESO_ENT) + 1
    suc_ids = (ent_ids - 1) * 3 + rng.integers(1, 4, size=n_rows)
    trader_ids = suc_ids * 3 + rng.integers(0, 3, size=n_rows)
    com_ids = rng.integers(1, 5001, size=n_rows)
    
    df = pd.DataFrame({
        "oper_id": op_ids, "entidad_id": ent_ids,
        "sucursal_id": suc_ids, "trader_id": trader_ids, "comitente_id": com_ids,
    })
    return df


def to_gz(df):
    buf = io.BytesIO()
    with gzip.GzipFile(fileobj=buf, mode="wb") as gz:
        df.to_csv(gz, sep=";", index=False, header=True, na_rep="NULL")
    return buf.getvalue()


def upload(s3, key, data):
    s3.put_object(Bucket=S3_BUCKET, Key=key, Body=data)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--upload", action="store_true")
    ap.add_argument("--workers", type=int, default=6)
    ap.add_argument("--test", action="store_true", help="1 file per table only")
    args = ap.parse_args()

    print("=" * 70)
    print(" SET-ICAP HOL — Generador vectorizado 400M filas")
    print(" Archivos: 100-250 MB gzip (óptimo para COPY INTO con XLARGE)")
    print("=" * 70)

    s3 = None
    if args.upload:
        import boto3
        s3 = boto3.client("s3")

    # Upload catalogs (reuse from original generator)
    sys.path.insert(0, os.path.dirname(__file__))
    from gen_set_icap_datos import (gen_currency, gen_mercado, gen_paridad,
                                    gen_sub_mercado, gen_ciiu, gen_entidad,
                                    gen_sucursal, gen_usuario, gen_comitente)
    ent = gen_entidad()
    suc = gen_sucursal(ent)
    usr = gen_usuario(suc)
    com = gen_comitente(ent, n=5000)
    catalogs = {"currency": gen_currency(), "mercado": gen_mercado(),
                "paridad_moneda": gen_paridad(), "sub_mercado": gen_sub_mercado(),
                "ciiu": gen_ciiu(), "entidad": ent, "sucursal": suc,
                "usuario": usr, "comitente": com}
    
    print("\nCatálogos y maestros:")
    for name, df in catalogs.items():
        data = to_gz(df)
        key = f"{S3_PREFIX}/{name}/{name}.csv.gz"
        if s3: upload(s3, key, data)
        print(f"  {name:32s} {len(df):>6,} filas  {len(data)/1e6:.2f} MB")

    # Generate large tables
    t0 = time.time()
    tables = [
        ("operation_set_fx", TARGET_OPS, ROWS_PER_FILE_OPS, gen_ops_file),
        ("operation_set_fx_contraparte", TARGET_CP, ROWS_PER_FILE_CP, gen_cp_file),
        ("operation_set_fx_contrap_comitente", TARGET_CM, ROWS_PER_FILE_CM, gen_cm_file),
    ]

    for tbl_name, total, per_file, gen_fn in tables:
        n_files = (total + per_file - 1) // per_file
        if args.test:
            n_files = 1
        print(f"\n{tbl_name}: {total:,} filas → {n_files} archivos (~{per_file/1e6:.1f}M filas c/u)")

        def process_file(fid):
            rng = np.random.default_rng(fid * 7919 + 31)
            rows_this = min(per_file, total - fid * per_file)
            start = 20_000_000 + fid * per_file
            df = gen_fn(fid, rows_this, start, rng)
            data = to_gz(df)
            key = f"{S3_PREFIX}/{tbl_name}/{tbl_name}_{fid:03d}.csv.gz"
            if s3: upload(s3, key, data)
            return fid, len(df), len(data)

        done = 0
        with ThreadPoolExecutor(max_workers=args.workers) as pool:
            futs = {pool.submit(process_file, i): i for i in range(n_files)}
            for fut in as_completed(futs):
                fid, rows, sz = fut.result()
                done += rows
                elapsed = time.time() - t0
                pct = done / total * 100
                print(f"  [{elapsed:5.0f}s] file {fid:3d} | {rows:>9,} rows | {sz/1e6:6.1f} MB gz | total {done:>12,} ({pct:.1f}%)")

    elapsed = time.time() - t0
    print(f"\n{'='*70}")
    print(f" COMPLETO en {elapsed:.0f}s ({elapsed/60:.1f} min)")
    print(f" {TARGET_OPS/1e6:.0f}M ops + {TARGET_CP/1e6:.0f}M cp + {TARGET_CM/1e6:.0f}M cm = {(TARGET_OPS+TARGET_CP+TARGET_CM)/1e6:.0f}M filas")
    print(f"{'='*70}")


if __name__ == "__main__":
    main()
