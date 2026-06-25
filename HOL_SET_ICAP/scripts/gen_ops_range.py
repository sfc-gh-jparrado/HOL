#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Genera y sube un RANGO de archivos de operation_set_fx (re-particionado).
Pensado para correr varios procesos en paralelo, cada uno con un rango disjunto
de file-ids, de modo que un warehouse XLARGE (128 hilos) tenga suficientes
archivos para saturar todos sus hilos en COPY INTO.

Reutiliza la lógica de generación de gen_set_icap_400m.py (mismo esquema/datos).
Las credenciales del bucket se leen de variables de entorno (no se hardcodean):
  SETICAP_WRITER_KEY / SETICAP_WRITER_SECRET   (o AWS_ACCESS_KEY_ID/SECRET)

Uso:
  python gen_ops_range.py --start-fid 0 --end-fid 32 [--per-file 940000] [--workers 8]
"""
import argparse, os, sys
from concurrent.futures import ThreadPoolExecutor, as_completed
import numpy as np
import boto3

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_set_icap_400m import (gen_ops_file, to_gz, TARGET_OPS,
                               ROWS_PER_FILE_OPS, S3_BUCKET, S3_PREFIX)


def s3_client():
    key = os.environ.get("SETICAP_WRITER_KEY") or os.environ.get("AWS_ACCESS_KEY_ID")
    sec = os.environ.get("SETICAP_WRITER_SECRET") or os.environ.get("AWS_SECRET_ACCESS_KEY")
    if not key or not sec:
        sys.exit("ERROR: faltan credenciales (SETICAP_WRITER_KEY/SECRET).")
    return boto3.client("s3", aws_access_key_id=key, aws_secret_access_key=sec,
                        region_name=os.environ.get("AWS_DEFAULT_REGION", "us-east-1"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--start-fid", type=int, required=True)
    ap.add_argument("--end-fid", type=int, required=True, help="exclusivo")
    ap.add_argument("--per-file", type=int, default=ROWS_PER_FILE_OPS)
    ap.add_argument("--workers", type=int, default=8)
    args = ap.parse_args()

    s3 = s3_client()
    per_file = args.per_file

    def process_file(fid):
        rng = np.random.default_rng(fid * 7919 + 31)
        rows_this = min(per_file, TARGET_OPS - fid * per_file)
        if rows_this <= 0:
            return fid, 0, 0
        start = 20_000_000 + fid * per_file
        df = gen_ops_file(fid, rows_this, start, rng)
        data = to_gz(df)
        key = f"{S3_PREFIX}/operation_set_fx/operation_set_fx_{fid:03d}.csv.gz"
        s3.put_object(Bucket=S3_BUCKET, Key=key, Body=data)
        return fid, len(df), len(data)

    fids = list(range(args.start_fid, args.end_fid))
    total_rows = 0
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        futs = {pool.submit(process_file, i): i for i in fids}
        for fut in as_completed(futs):
            fid, rows, sz = fut.result()
            total_rows += rows
            print(f"  file {fid:3d} | {rows:>9,} rows | {sz/1e6:5.1f} MB gz", flush=True)

    print(f"RANGO [{args.start_fid},{args.end_fid}) listo: {len(fids)} archivos, {total_rows:,} filas", flush=True)


if __name__ == "__main__":
    main()
