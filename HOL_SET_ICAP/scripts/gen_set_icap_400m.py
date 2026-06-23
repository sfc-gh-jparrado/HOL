#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
================================================================================
 SET-ICAP HOL - Generador de datos MASIVO (400M filas) del mercado FX SET-FX
================================================================================
 Genera 5 años de historia (2021-2026) del mercado cambiario colombiano:
   - operation_set_fx:                120,000,000 filas
   - operation_set_fx_contraparte:    240,000,000 filas (2 por operación)
   - operation_set_fx_contrap_comitente: 40,000,000 filas (~33% de ops)
   + catálogos (sin cambio) y maestros ampliados (1,000 usuarios, 5,000 comitentes)

 Genera en chunks (~5M filas/archivo ≈ ~200MB raw → ~30-50MB gzip) y sube a S3
 en paralelo con un ThreadPool.

 Uso:
   export AWS_PROFILE=contributor-484577546576
   ~/miniforge3/bin/python gen_set_icap_400m.py --upload --workers 4
   # Solo local (debug, 1 chunk):
   ~/miniforge3/bin/python gen_set_icap_400m.py --test-chunk

 Tiempo estimado: ~25-40 min generación + upload (depende de CPU y ancho de banda).
================================================================================
"""
import argparse
import gzip
import io
import os
import sys
import time
import datetime as dt
import numpy as np
import pandas as pd
from concurrent.futures import ThreadPoolExecutor, as_completed

RNG = np.random.default_rng(20210101)

S3_BUCKET = "demosjparrado"
S3_PREFIX = "set_icap_hol/hist"
OUT_DIR = os.path.join(os.path.dirname(__file__), "out_400m")

# --- Parámetros del mercado (5 años: 2021-01-04 a 2026-06-19) ---
FECHA_INI = dt.date(2021, 1, 4)
FECHA_FIN = dt.date(2026, 6, 19)

# TRM anclas mensuales realistas (COP/USD) — 5 años de historia real Colombia
ANCLAS_MENSUALES = {
    # 2021: recuperación post-covid, peso se aprecia de 3600→3800
    (2021,1):3600,(2021,2):3580,(2021,3):3650,(2021,4):3700,(2021,5):3720,
    (2021,6):3750,(2021,7):3800,(2021,8):3830,(2021,9):3850,(2021,10):3790,
    (2021,11):3900,(2021,12):3980,
    # 2022: depreciación fuerte (guerra Ucrania, Fed sube tasas)
    (2022,1):4000,(2022,2):3950,(2022,3):3780,(2022,4):3850,(2022,5):3950,
    (2022,6):4100,(2022,7):4300,(2022,8):4400,(2022,9):4500,(2022,10):4900,
    (2022,11):4850,(2022,12):4800,
    # 2023: estabilización/apreciación parcial
    (2023,1):4700,(2023,2):4800,(2023,3):4750,(2023,4):4600,(2023,5):4400,
    (2023,6):4300,(2023,7):4150,(2023,8):4100,(2023,9):4050,(2023,10):4200,
    (2023,11):4100,(2023,12):3900,
    # 2024: rango 3800-4200
    (2024,1):3900,(2024,2):3950,(2024,3):3850,(2024,4):3900,(2024,5):3850,
    (2024,6):4000,(2024,7):4100,(2024,8):4050,(2024,9):4150,(2024,10):4200,
    (2024,11):4180,(2024,12):4250,
    # 2025: apreciación gradual
    (2025,1):4250,(2025,2):4200,(2025,3):4100,(2025,4):4050,(2025,5):4000,
    (2025,6):4150,(2025,7):4080,(2025,8):4020,(2025,9):3980,(2025,10):4050,
    (2025,11):4180,(2025,12):4320,
    # 2026: apreciación fuerte del peso
    (2026,1):4250,(2026,2):4100,(2026,3):3950,(2026,4):3820,(2026,5):3650,
    (2026,6):3445,
}

# Crecimiento del mercado: eventos/día (ops + cotizaciones + modificaciones)
# 120M ops / ~1,380 días hábiles ≈ 87,000/día promedio
# Justificación negocio: SET-FX captura calces + posturas + modificaciones + anulaciones
def ops_por_dia(year):
    # Crece de ~70K (2021) a ~100K (2026)
    return int(70000 + (year - 2021) * 6000)


# --- Entidades (IMCs) --- reutilizamos las 50 del generador original
ENTIDADES_NOMBRES = [
    "Banco de la República","Bancolombia S.A.","Banco de Bogotá S.A.",
    "Banco Davivienda S.A.","BBVA Colombia S.A.","Banco de Occidente S.A.",
    "Itaú Colombia S.A.","Scotiabank Colpatria S.A.","Banco Popular S.A.",
    "Banco GNB Sudameris S.A.","Citibank Colombia S.A.","JPMorgan Chase Bank Colombia",
    "Banco Santander Colombia S.A.","Banco Agrario de Colombia S.A.",
    "Banco Caja Social S.A.","Banco AV Villas S.A.","Banco Falabella S.A.",
    "Banco Pichincha S.A.","Bancoomeva S.A.","Banco Serfinanza S.A.",
    "Banco W S.A.","Bancamía S.A.","Banco Finandina S.A.","Banco Mundo Mujer S.A.",
    "Coltefinanciera S.A.","Credicorp Capital Colombia S.A.",
    "Corredores Davivienda S.A.","Acciones y Valores S.A.","Alianza Valores S.A.",
    "BTG Pactual Colombia S.A.","Casa de Bolsa S.A.","Global Securities S.A.",
    "Servivalores GNB Sudameris S.A.","Valores Bancolombia S.A.",
    "Ultraserfinco S.A.","Corficolombiana S.A.","Banco Cooperativo Coopcentral",
    "Mibanco S.A.","Financiera de Desarrollo Nacional","Bancóldex S.A.",
    "Goldman Sachs Colombia","Banco BTG Pactual","Larrainvial Colombia S.A.",
    "Banco Tequendama","Fiduciaria Bancolombia S.A.","Fiduciaria Bogotá S.A.",
    "Skandia Valores S.A.","Profesionales de Bolsa S.A.","Banco Multibank Colombia",
    "Davivienda Corredores Internacional",
]
N_ENTIDADES = len(ENTIDADES_NOMBRES)
PESO_ENT = np.ones(N_ENTIDADES, dtype=float)
PESO_ENT[:11] = 8.0   # banrep + grandes
PESO_ENT[11:25] = 3.0
PESO_ENT = PESO_ENT / PESO_ENT.sum()

PLAZOS = {76:"T+1",77:"T+0",78:"3M",79:"1M",80:"T+2",85:"6M"}
NOTAS = [
    "Demanda corporativa sostenida durante la sesión.",
    "Exportadores venden dólares, presión a la baja.",
    "Spreads ajustados entre IMC, jornada estable.",
    "Volatilidad por dato de inflación en EE.UU.",
    "Banco de la República monitorea la TRM.",
    "Apetito por riesgo global favorece al peso.",
    "Cierre con tendencia alcista por incertidumbre fiscal.",
    "Liquidez reducida en la última hora de negociación.",
    "Operaciones forward activas antes del cierre.",
    "Intervención del Banco de la República estabiliza la TRM.",
]


def business_days(d0, d1):
    days = []
    d = d0
    while d <= d1:
        if d.weekday() < 5:
            days.append(d)
        d += dt.timedelta(days=1)
    return days


def trm_serie(days):
    serie = {}
    prev = ANCLAS_MENSUALES[(2021, 1)]
    for d in days:
        ancla = ANCLAS_MENSUALES.get((d.year, d.month), prev)
        prev = prev + 0.12 * (ancla - prev) + RNG.normal(0, 10)
        serie[d] = round(max(3200, min(5200, prev)), 2)
    return serie


# --- Generación por chunks ---
CHUNK_SIZE_OPS = 5_000_000  # 5M operaciones por archivo


def gen_ops_chunk(chunk_id, days_subset, trm, start_oid):
    """Genera un chunk de operaciones + contraparte + comitente."""
    rng = np.random.default_rng(chunk_id * 1000 + 42)
    op_rows = []
    cp_rows = []
    cm_rows = []
    oid = start_oid

    for d in days_subset:
        n = max(100, int(rng.normal(ops_por_dia(d.year), ops_por_dia(d.year) * 0.15)))
        spot = trm[d]
        mercados = rng.choice([76,77,78,79,85,80], size=n, p=[0.60,0.10,0.12,0.07,0.06,0.05])
        idx_c = rng.choice(N_ENTIDADES, size=n, p=PESO_ENT)
        idx_v = rng.choice(N_ENTIDADES, size=n, p=PESO_ENT)
        same = idx_c == idx_v
        idx_v[same] = (idx_v[same] + 1) % N_ENTIDADES

        montos = np.round(np.exp(rng.normal(13.0, 0.8, size=n)) / 50000) * 50000
        montos = np.clip(montos, 50000, 15000000)
        precios = np.round(spot + rng.normal(0, spot * 0.0012, size=n), 2)
        segs = rng.integers(0, 18000, size=n)  # 5 horas
        anuladas = rng.random(size=n) < 0.012
        tiene_nota = rng.random(size=n) < 0.07
        tiene_comitente = rng.random(size=n) < 0.33

        for k in range(n):
            oid += 1
            merc = int(mercados[k])
            ec = int(idx_c[k]) + 1
            ev = int(idx_v[k]) + 1
            monto = float(montos[k])
            precio = float(precios[k])
            plazo = PLAZOS.get(merc, "T+1")
            pf = round(rng.normal(12, 6), 2) if merc in (78, 85) else 0.0
            hora = (dt.datetime.combine(d, dt.time(8,0)) + dt.timedelta(seconds=int(segs[k])))
            nota = NOTAS[rng.integers(0, len(NOTAS))] if tiene_nota[k] else ""
            monto_cop = round(monto * precio, 2)

            op_rows.append((
                oid, d.isoformat(), hora.strftime("%H:%M:%S"), bool(anuladas[k]),
                merc, int(rng.choice([1,2,3,4,7,10])), bool(rng.random() < 0.4),
                f"FW{oid:X}", f"O{rng.integers(100,999)}",
                {"T+0":0,"T+1":1,"T+2":2,"1M":30,"3M":90,"6M":180,"1Y":360}.get(plazo,1),
                (d + dt.timedelta(days={"T+0":0,"T+1":1,"T+2":2,"1M":30,"3M":90,"6M":180}.get(plazo,1))).isoformat(),
                (hora - dt.timedelta(seconds=int(rng.integers(5,300)))).strftime("%H:%M:%S"),
                round(monto, 2), monto_cop, round(monto, 2),
                precio, pf, round(spot, 2), plazo,
                bool(rng.random() < 0.05), bool(rng.random() < 0.5),
                1, "USD/COP", 2, 1, ec, ev,
                {"T+0":0,"T+1":1,"T+2":2,"1M":30,"3M":90,"6M":180}.get(plazo,1),
                bool(rng.random() < 0.7), nota
            ))

            # Contraparte (siempre 2)
            suc_c = (ec - 1) * 3 + rng.integers(1, 4)
            suc_v = (ev - 1) * 3 + rng.integers(1, 4)
            tr_c = suc_c * 3 + rng.integers(0, 3)
            tr_v = suc_v * 3 + rng.integers(0, 3)
            cp_rows.append((oid, "C", ec, int(suc_c), int(tr_c), None, None))
            cp_rows.append((oid, "V", ev, int(suc_v), int(tr_v), None, None))

            # Comitente (~33%)
            if tiene_comitente[k]:
                cm_rows.append((oid, ec, int(suc_c), int(tr_c), int(rng.integers(1, 5001))))

    cols_op = ["id","fecha","hora","anulada","mercado","sub_mercado","registro",
               "mcod_transaccion","usuario_postura","dias","fecha_valor","hora_postura",
               "monto_moneda_uno","monto_moneda_dos","monto_usd","precio","points_forward",
               "precio_spot","plazo_curva","entidad_publica_3c_1","bandera_fisico_compensacion",
               "paridad_id","paridad_nombre","moneda_uno","moneda_dos","entidad_compradora",
               "entidad_vendedora","plazo_dias","enviada_camara","texto_term"]
    cols_cp = ["oper_id","oper_lado","entidad_id","sucursal_id","trader_id","broker_id","comitente_id"]
    cols_cm = ["oper_id","entidad_id","sucursal_id","trader_id","comitente_id"]

    return (pd.DataFrame(op_rows, columns=cols_op),
            pd.DataFrame(cp_rows, columns=cols_cp),
            pd.DataFrame(cm_rows, columns=cols_cm))


def to_gz(df):
    buf = io.BytesIO()
    with gzip.GzipFile(fileobj=buf, mode="wb") as gz:
        df.to_csv(gz, sep=";", index=False, header=True, na_rep="NULL")
    return buf.getvalue()


def upload(s3, key, data):
    s3.put_object(Bucket=S3_BUCKET, Key=key, Body=data)
    return f"s3://{S3_BUCKET}/{key}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--upload", action="store_true")
    ap.add_argument("--workers", type=int, default=4)
    ap.add_argument("--test-chunk", action="store_true", help="solo 1 chunk (~5M)")
    args = ap.parse_args()

    print("=" * 70)
    print(" SET-ICAP HOL — Generador 400M filas (5 años mercado FX)")
    print("=" * 70)

    # 1. Serie TRM
    days = business_days(FECHA_INI, FECHA_FIN)
    print(f"Días hábiles: {len(days)} ({FECHA_INI} → {FECHA_FIN})")
    trm = trm_serie(days)
    print(f"TRM rango: {min(trm.values()):.0f} – {max(trm.values()):.0f} COP/USD")

    # 2. Partir días en chunks de ~5M ops
    total_ops_est = sum(ops_por_dia(d.year) for d in days)
    print(f"Ops estimadas totales: {total_ops_est:,.0f}")
    chunks = []
    chunk_days = []
    chunk_ops = 0
    for d in days:
        chunk_days.append(d)
        chunk_ops += ops_por_dia(d.year)
        if chunk_ops >= CHUNK_SIZE_OPS:
            chunks.append(chunk_days)
            chunk_days = []
            chunk_ops = 0
    if chunk_days:
        chunks.append(chunk_days)
    print(f"Chunks: {len(chunks)} (cada uno ~{CHUNK_SIZE_OPS/1e6:.0f}M ops)")

    if args.test_chunk:
        chunks = chunks[:1]
        print("** TEST MODE: solo 1 chunk **")

    # 3. S3 client
    s3 = None
    if args.upload:
        import boto3
        s3 = boto3.Session(profile_name=os.environ.get(
            "AWS_PROFILE", "contributor-484577546576")).client("s3")

    # 4. Generar catálogos y maestros (pequeños, una vez)
    from gen_set_icap_datos import (gen_currency, gen_mercado, gen_paridad,
                                    gen_sub_mercado, gen_ciiu, gen_entidad,
                                    gen_sucursal, gen_comitente)
    # Ampliar maestros
    ent = gen_entidad()
    suc = gen_sucursal(ent)
    # Usuarios: ampliar a ~1000
    from gen_set_icap_datos import gen_usuario
    usr = gen_usuario(suc)
    # Comitentes: ampliar a 5000
    com = gen_comitente(ent, n=5000)

    catalogs = {
        "currency": gen_currency(), "mercado": gen_mercado(),
        "paridad_moneda": gen_paridad(), "sub_mercado": gen_sub_mercado(),
        "ciiu": gen_ciiu(), "entidad": ent, "sucursal": suc,
        "usuario": usr, "comitente": com,
    }
    print("\nSubiendo catálogos y maestros...")
    for name, df in catalogs.items():
        data = to_gz(df)
        key = f"{S3_PREFIX}/{name}/{name}.csv.gz"
        if s3:
            upload(s3, key, data)
        else:
            os.makedirs(os.path.join(OUT_DIR, name), exist_ok=True)
            open(os.path.join(OUT_DIR, name, f"{name}.csv.gz"), "wb").write(data)
        print(f"  {name:32s} {len(df):>6,} filas")

    # 5. Generar y subir chunks de operaciones
    print(f"\nGenerando {len(chunks)} chunks de operaciones...")
    t0 = time.time()
    total_ops = 0
    total_cp = 0
    total_cm = 0
    start_oid = 20_000_000

    def process_chunk(i, ch_days):
        nonlocal start_oid
        oid_start = start_oid + i * CHUNK_SIZE_OPS
        df_op, df_cp, df_cm = gen_ops_chunk(i, ch_days, trm, oid_start)
        results = []
        for tbl, df, prefix in [
            ("operation_set_fx", df_op, "operation_set_fx"),
            ("operation_set_fx_contraparte", df_cp, "operation_set_fx_contraparte"),
            ("operation_set_fx_contrap_comitente", df_cm, "operation_set_fx_contrap_comitente"),
        ]:
            if len(df) == 0:
                continue
            data = to_gz(df)
            fname = f"{prefix}_{i:03d}.csv.gz"
            key = f"{S3_PREFIX}/{prefix}/{fname}"
            if s3:
                upload(s3, key, data)
            else:
                os.makedirs(os.path.join(OUT_DIR, prefix), exist_ok=True)
                open(os.path.join(OUT_DIR, prefix, fname), "wb").write(data)
            results.append((tbl, len(df), len(data)))
        return results

    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        futs = {pool.submit(process_chunk, i, ch): i for i, ch in enumerate(chunks)}
        for fut in as_completed(futs):
            i = futs[fut]
            try:
                results = fut.result()
                for tbl, rows, sz in results:
                    if tbl == "operation_set_fx":
                        total_ops += rows
                    elif tbl == "operation_set_fx_contraparte":
                        total_cp += rows
                    else:
                        total_cm += rows
                elapsed = time.time() - t0
                print(f"  chunk {i+1:3d}/{len(chunks)} done | ops={total_ops:>12,} cp={total_cp:>12,} cm={total_cm:>10,} | {elapsed:.0f}s")
            except Exception as e:
                print(f"  ERROR chunk {i}: {e}", file=sys.stderr)

    elapsed = time.time() - t0
    grand_total = total_ops + total_cp + total_cm + sum(len(df) for df in catalogs.values())
    print(f"\n{'='*70}")
    print(f" COMPLETO en {elapsed:.0f}s ({elapsed/60:.1f} min)")
    print(f" operation_set_fx:                {total_ops:>14,}")
    print(f" operation_set_fx_contraparte:    {total_cp:>14,}")
    print(f" operation_set_fx_contrap_comitente: {total_cm:>11,}")
    print(f" TOTAL FILAS:                     {grand_total:>14,}")
    print(f"{'='*70}")


if __name__ == "__main__":
    main()
