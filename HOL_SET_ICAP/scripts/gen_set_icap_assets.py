#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Genera y sube a S3 los assets NO estructurados del HOL SET-ICAP (Parte 7B):
  - grafico_trm.png  : gráfico sintético de la TRM USD/COP (análisis de imagen)
  - llamada_mesa.mp3 : llamada de mesa de dinero cerrando una operación (audio)

Destino: s3://demosjparrado/set_icap_hol/archivos/
Uso:  ~/miniforge3/bin/python gen_set_icap_assets.py
Requiere: matplotlib, numpy, boto3, /usr/bin/say, ffmpeg.
"""
import os
import subprocess
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
from datetime import date, timedelta
import boto3

BUCKET = "demosjparrado"
PREFIX = "set_icap_hol/archivos/"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out_assets")
os.makedirs(OUT, exist_ok=True)

# Credenciales WRITER (IAM estático). ROTAR tras el HOL.
AWS_KEY = os.environ.get("SETICAP_WRITER_KEY", "")
AWS_SECRET = os.environ.get("SETICAP_WRITER_SECRET", "")


def gen_chart(path):
    """Gráfico realista de la TRM: ~1 año, peso apreciándose 4340 -> 3900 con ruido."""
    n = 252
    start = date(2025, 6, 20)
    dias = [start + timedelta(days=int(i * 365 / n)) for i in range(n)]
    rng = np.random.default_rng(42)
    tendencia = np.linspace(4340, 3900, n)
    ruido = np.cumsum(rng.normal(0, 8, n))
    ruido -= np.linspace(0, ruido[-1], n)  # ancla extremos a la tendencia
    trm = tendencia + ruido

    plt.figure(figsize=(12, 6))
    plt.plot(dias, trm, color="#29B5E8", linewidth=1.8)
    plt.fill_between(dias, trm, trm.min() - 30, color="#29B5E8", alpha=0.08)
    plt.title("TRM USD/COP - Mercado SET-FX (datos sintéticos)", fontsize=15, fontweight="bold")
    plt.ylabel("COP por USD")
    plt.xlabel("Fecha")
    plt.grid(True, alpha=0.25)
    ax = plt.gca()
    ax.xaxis.set_major_formatter(mdates.DateFormatter("%b %Y"))
    # niveles de referencia
    plt.axhline(trm.max(), color="#d9534f", ls="--", lw=0.9, alpha=0.7)
    plt.axhline(trm.min(), color="#5cb85c", ls="--", lw=0.9, alpha=0.7)
    plt.text(dias[2], trm.max() - 8, f"Resistencia ~{trm.max():.0f}", color="#d9534f", fontsize=9)
    plt.text(dias[2], trm.min() + 4, f"Soporte ~{trm.min():.0f}", color="#5cb85c", fontsize=9)
    plt.tight_layout()
    plt.savefig(path, dpi=130)
    plt.close()
    print("OK chart:", path)


CALL_SCRIPT = (
    "Buenos días, habla la mesa de dinero de Bancolombia. "
    "Necesito cerrar una operación de compra de dólares. "
    "El monto es de dos millones de dólares, mercado de contado, para liquidar hoy. "
    "¿Qué precio me puedes ofrecer? "
    "Te puedo dar cuatro mil ciento veinte pesos por dólar. "
    "Perfecto, lo tomo. Cerramos entonces. "
    "Confirmo la operación: compra de dos millones de dólares, "
    "a un precio de cuatro mil ciento veinte pesos, plazo T más cero, "
    "la contraparte vendedora es Davivienda. Operación cerrada, muchas gracias."
)


def gen_audio(path):
    aiff = os.path.join(OUT, "_llamada.aiff")
    # Voz en español; si Paulina no existe, say usa la voz por defecto.
    voz = "Paulina"
    try:
        subprocess.run(["/usr/bin/say", "-v", voz, "-o", aiff, CALL_SCRIPT], check=True)
    except subprocess.CalledProcessError:
        subprocess.run(["/usr/bin/say", "-o", aiff, CALL_SCRIPT], check=True)
    subprocess.run(["ffmpeg", "-y", "-i", aiff, "-codec:a", "libmp3lame", "-qscale:a", "4", path],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    os.remove(aiff)
    print("OK audio:", path)


def upload(local, key):
    s3 = boto3.client("s3", aws_access_key_id=AWS_KEY, aws_secret_access_key=AWS_SECRET,
                      region_name="us-east-1")
    s3.upload_file(local, BUCKET, PREFIX + key)
    print(f"OK upload: s3://{BUCKET}/{PREFIX}{key}")


if __name__ == "__main__":
    chart = os.path.join(OUT, "grafico_trm.png")
    audio = os.path.join(OUT, "llamada_mesa.mp3")
    gen_chart(chart)
    gen_audio(audio)
    upload(chart, "grafico_trm.png")
    upload(audio, "llamada_mesa.mp3")
    print("Listo: assets generados y subidos a S3.")
