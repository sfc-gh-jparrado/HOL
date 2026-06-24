#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Genera set_icap_hol.html con el CÓDIGO COMPLETO de cada paso (copy-paste a
Snowflake), tomando el SQL real de HOL_SET_ICAP.sql (partes 1-8 y 12). Los pasos
9 (Streamlit), 10 (Semantic View UI) y 11 (Intelligence UI) usan contenido
curado. Reusa el shell/CSS/JS del HTML existente: solo reemplaza el array STEPS.

Uso: ~/miniforge3/bin/python build_hol_html.py
"""
import json
import re
import os

HERE = os.path.dirname(os.path.abspath(__file__))
SQL = os.path.join(HERE, "HOL_SET_ICAP.sql")
HTML = os.path.join(HERE, "set_icap_hol.html")


def html_escape(s: str) -> str:
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def split_parts(sql_text: str) -> dict:
    """Divide el SQL por marcadores 'PARTE N', devuelve {n: texto_completo_parte}."""
    lines = sql_text.splitlines()
    marker = re.compile(r"PARTE\s+(\d+)\b")
    idxs = []  # (line_no, part_num)
    for i, ln in enumerate(lines):
        m = marker.search(ln)
        if m and ln.strip().startswith("/*"):
            idxs.append((i, int(m.group(1))))
    parts = {}
    for j, (start, num) in enumerate(idxs):
        end = idxs[j + 1][0] if j + 1 < len(idxs) else len(lines)
        parts[num] = "\n".join(lines[start:end]).strip("\n")
    return parts


# Intro corto (prosa) + tiempo + título por paso
META = {
    1:  ("2 min", "Configuración del ambiente",
         "<p>Creamos base de datos, warehouse y habilitamos Cortex cross-region.</p>"),
    2:  ("5 min", "Stage externo a S3 + File Format",
         "<p>Conectamos Snowflake al bucket S3 con los datos del HOL (CSV gzip ';').</p>"
         "<div class=\"note\"><strong>Credenciales:</strong> reemplaza <code>&lt;SOLICITAR_AL_INSTRUCTOR&gt;</code> por las llaves read-only del instructor.</div>"),
    3:  ("5 min", "DDL: creación de tablas",
         "<p>Creamos las 12 tablas del modelo SET-FX (catálogos, maestros y transaccionales).</p>"),
    4:  ("15 min", "Carga de datos + Warehouse Scaling",
         "<p>Cargamos 400M filas desde S3 e impresionamos con la velocidad. Demostramos el impacto del tamaño de warehouse cargando la misma tabla de 120M dos veces:</p>"
         "<ul><li><strong>SMALL</strong> (2 nodos) → 120M operaciones en ~50s</li>"
         "<li><strong>XLARGE</strong> (16 nodos) → la misma tabla en ~21s (~2.4x)</li></ul>"
         "<div class=\"note\"><strong>Lección:</strong> el paralelismo depende del <strong>número de archivos</strong> (30 archivos de 150 MB), no solo del warehouse. Luego se construye <code>OPERACIONES</code>, la tabla plana denormalizada (sin fan-out) que consume Cortex Analyst.</div>"),
    5:  ("15 min", "⭐ Snowpipe con auto-ingesta (event-driven)",
         "<div class=\"note new\"><strong>Lo nuevo.</strong> Cada archivo que llega a <code>stream/</code> dispara una notificación S3 → SQS y el pipe carga los datos en segundos, sin tareas. Para conectar S3→SQS usa el ARN del paso 5.2 con <code>aws s3api put-bucket-notification-configuration</code> (ver README).</div>"),
    6:  ("5 min", "Time Travel y Zero-Copy Cloning",
         "<p>Recupera datos y crea ambientes dev instantáneos sin duplicar almacenamiento.</p>"),
    7:  ("10 min", "Enmascaramiento dinámico de datos",
         "<p>Un analista no debe ver la identidad de las contrapartes. Aplicamos Dynamic Data Masking.</p>"),
    8:  ("12 min", "Cortex AI: análisis de mercado con IA",
         "<p>Clasificación, análisis diario, sentimiento y resumen con IA generativa.</p>"
         "<div class=\"note\"><strong>Nota:</strong> usamos <code>SNOWFLAKE.CORTEX.COMPLETE</code> y <code>SNOWFLAKE.CORTEX.SENTIMENT</code> (retorna FLOAT -1 a 1). Los prompts piden respuestas de una sola frase sin markdown.</div>"),
    9:  ("10 min", "Dynamic Tables: analítica que se refresca sola",
         "<p>VWAP diario y ranking de entidades, siempre actualizados (anti fan-out con DISTINCT).</p>"),
    13: ("3 min", "Limpieza",
         "<p>Detén el generador de streaming (Ctrl-C), pausa el pipe y elimina los objetos del HOL.</p>"),
}

# Pasos no-SQL (curados)
STREAMLIT_PY = """import streamlit as st, altair as alt
from snowflake.snowpark.context import get_active_session
session = get_active_session()
st.title("SET-FX \\u00b7 Tablero del Mercado de Divisas")

@st.cache_data(ttl=300)
def q(sql): return session.sql(sql).to_pandas()

vwap = q("SELECT * FROM DT_VWAP_DIARIO ORDER BY FECHA")
rank = q("SELECT * FROM DT_RANKING_ENTIDADES LIMIT 10")
c1,c2,c3 = st.columns(3)
c1.metric("TRM m\\u00e1s reciente (VWAP)", f"{vwap['VWAP'].iloc[-1]:,.2f}")
c2.metric("Volumen \\u00faltimo d\\u00eda (M USD)", f"{vwap['VOLUMEN_MUSD'].iloc[-1]:,.1f}")
c3.metric("Operaciones (stream)", q("SELECT COUNT(*) N FROM OPERATION_FX_STREAM")['N'].iloc[0])

st.altair_chart(alt.Chart(vwap).mark_line(point=True).encode(
  x="FECHA:T", y=alt.Y("VWAP:Q", scale=alt.Scale(zero=False))
).properties(height=320), use_container_width=True)
st.altair_chart(alt.Chart(rank).mark_bar().encode(
  x="VOLUMEN_COMPRA_MUSD:Q", y=alt.Y("ENTIDAD_SIGLA:N", sort="-x")
).properties(height=320), use_container_width=True)"""

COCO_PROMPT = """Crea una app de Streamlit-in-Snowflake visualmente potente para el mercado
de divisas SET-FX de SET-ICAP (Colombia). Usala con get_active_session() y
SIN dependencias de red externas (solo altair/plotly nativos).

Base de datos: DB_HOL_SETICAP, schema PUBLIC. Objetos disponibles:
- DT_VWAP_DIARIO (FECHA, VWAP, VOLUMEN_MUSD, NUM_OPERACIONES, PRECIO_MIN, PRECIO_MAX, RANGO)
- DT_RANKING_ENTIDADES (ENTIDAD_SIGLA, ENTIDAD_NOMBRE, ENTIDAD_CLASE, NUM_OPERACIONES, VOLUMEN_COMPRA_MUSD)
- OPERATION_SET_FX (ID, FECHA, HORA, ANULADA, MERCADO, MONTO_USD, MONTO_MONEDA_DOS, PRECIO, PLAZO_CURVA, ENTIDAD_COMPRADORA, ENTIDAD_VENDEDORA, TEXTO_TERM)
- OPERATION_FX_STREAM (mismas columnas, operaciones en vivo via Snowpipe)
- ENTIDAD (ENTIDAD_ID, ENTIDAD_SIGLA, ENTIDAD_NOMBRE, ENTIDAD_CLASE)
- MERCADO (MERCADO_ID, MERCADO_NOMBRE)

Requisitos visuales (estilo fintech profesional, branding Snowflake #29B5E8 / #11567F):
1. Encabezado con titulo "SET-FX - Mercado de Divisas" y selector de rango de fechas.
2. Fila de KPI cards: TRM mas reciente (VWAP), variacion % vs dia anterior,
   volumen del dia (M USD), num operaciones, % anuladas. Con flechas de tendencia y color.
3. Grafico principal: evolucion de la TRM (VWAP diario) tipo linea con banda min-max
   (area sombreada PRECIO_MIN-PRECIO_MAX) y tooltip rico.
4. Barras horizontales: Top 10 entidades por volumen comprado, coloreadas por ENTIDAD_CLASE.
5. Profundidad de mercado: comparativo compra vs venta por entidad (barras divergentes).
6. Mapa de calor de actividad por hora del dia vs dia de la semana (num operaciones).
7. Donut: distribucion de volumen por PLAZO_CURVA (T+1, 3M, etc.).
8. Panel "En vivo" que lee OPERATION_FX_STREAM: ultimas operaciones en una tabla con
   auto-refresh (st.fragment o autorefresh cada 30s) y un contador del total.
9. Layout responsive con st.columns, st.container(border=True), metricas grandes,
   tema oscuro elegante y tipografia clara. Usa @st.cache_data(ttl=300) en las consultas.

Genera el app.py completo, listo para pegar en Snowsight -> Streamlit. No uses
librerias que requieran instalacion externa mas alla de las disponibles en SiS."""

STEP10 = ("15 min", "Streamlit: tablero del mercado SET-FX",
         "<p>En Snowsight → Projects → Streamlit → <em>+ Streamlit App</em> (warehouse WH_HOL_SETICAP, database DB_HOL_SETICAP, schema PUBLIC). Elige una de las dos opciones:</p>"
         "<div class=\"note\"><strong>Opción A — Rápida.</strong> Pega este código base para un tablero funcional:</div>"
         "<div class=\"codebox\"><span class=\"lang\">python</span><button class=\"btn-copy\" onclick=\"copyCode(this)\">Copiar</button><pre>"
         + html_escape(STREAMLIT_PY) + "</pre></div>"
         "<div class=\"note new\"><strong>Opción B — Genéralo con Cortex Code (CoCo).</strong> Para un dashboard visualmente potente, abre Cortex Code en tu cuenta y pega este prompt. CoCo arma el <code>app.py</code> completo conectado a tus objetos del HOL (KPIs, series TRM, profundidad de mercado, mapa de calor, panel en vivo de Snowpipe):</div>"
         "<div class=\"codebox\"><span class=\"lang\">prompt · cortex code</span><button class=\"btn-copy\" onclick=\"copyCode(this)\">Copiar</button><pre>"
         + html_escape(COCO_PROMPT) + "</pre></div>")

STEP11 = ("8 min", "Semantic View para Cortex Analyst",
          "<p>En Snowsight → AI &amp; ML → Cortex Analyst → Create → Semantic View. Selecciona las tablas y métricas (o importa <code>HOL_SET_ICAP_semantic_model.yaml</code>).</p>"
          "<ul><li><strong>Tablas:</strong> OPERATION_SET_FX, ENTIDAD, MERCADO, PARIDAD_MONEDA</li>"
          "<li><strong>Relaciones:</strong> MERCADO→MERCADO_ID, ENTIDAD_COMPRADORA→ENTIDAD_ID, PARIDAD_ID→PARIDAD_ID</li>"
          "<li><strong>Métricas:</strong> volumen_usd=SUM(MONTO_USD), num_operaciones=COUNT(ID), vwap=SUM(PRECIO*MONTO_USD)/SUM(MONTO_USD), trm_promedio=AVG(PRECIO)</li>"
          "<li><strong>Dimensiones:</strong> FECHA, PLAZO_CURVA, MERCADO_NOMBRE, ENTIDAD_SIGLA</li></ul>")

STEP12 = ("15 min", "Snowflake Intelligence: agente conversacional",
          "<p>En Snowsight → AI &amp; ML → Agents → Create agent. Conecta la Semantic View y configura el agente experto del mercado FX.</p>"
          "<ul><li><strong>Nombre:</strong> AGT_SETICAP</li>"
          "<li><strong>Herramienta:</strong> Cortex Analyst → Semantic View <code>SV_SET_FX</code></li>"
          "<li><strong>Instrucciones:</strong> \"Eres un analista experto del mercado cambiario colombiano SET-FX de SET-ICAP. Respondes en español con cifras claras (TRM, volumen en millones de USD).\"</li></ul>"
          "<p><strong>Preguntas demo:</strong></p><ul>"
          "<li>¿Cuál fue el VWAP del USD/COP la última semana?</li>"
          "<li>¿Qué entidad negoció el mayor volumen el último mes?</li>"
          "<li>¿Cuántas operaciones forward se hicieron a plazo 3M?</li>"
          "<li>Compara el volumen de bancos vs comisionistas.</li></ul>")


def code_block(sql_text: str, lang="sql") -> str:
    return (f'<div class="codebox"><span class="lang">{lang}</span>'
            f'<button class="btn-copy" onclick="copyCode(this)">Copiar</button>'
            f'<pre>{html_escape(sql_text)}</pre></div>')


def build_steps(parts: dict) -> str:
    steps = []
    for n in range(1, 14):
        if n in (1, 2, 3, 4, 5, 6, 7, 8, 9, 13):
            t, title, intro = META[n]
            body = intro + code_block(parts[n], "sql")
        elif n == 10:
            t, title, body = STEP10
        elif n == 11:
            t, title, body = STEP11
        elif n == 12:
            t, title, body = STEP12
        steps.append({"n": n, "t": t, "title": title, "body": body})
    # array JS con strings via JSON (escape seguro)
    items = []
    for s in steps:
        items.append("  {n:%d,t:%s,title:%s,body:%s}" % (
            s["n"], json.dumps(s["t"], ensure_ascii=False),
            json.dumps(s["title"], ensure_ascii=False),
            json.dumps(s["body"], ensure_ascii=False)))
    return "const STEPS = [\n" + ",\n".join(items) + "\n];"


def main():
    sql_text = open(SQL, encoding="utf-8").read()
    parts = split_parts(sql_text)
    assert all(n in parts for n in range(1, 14)), f"faltan partes: {sorted(set(range(1,14))-set(parts))}"
    new_steps = build_steps(parts)

    html = open(HTML, encoding="utf-8").read()
    # Reemplaza el bloque 'const STEPS = [ ... ];' (hasta el primer '];' seguido de salto)
    # Reemplazo con función para que re.sub NO interprete los \n del JSON como saltos reales
    new_html = re.sub(r"const STEPS = \[.*?\n\];", lambda m: new_steps, html, count=1, flags=re.S)
    assert new_html != html and "const STEPS" in new_html, "no se reemplazó STEPS"
    open(HTML, "w", encoding="utf-8").write(new_html)
    print(f"OK: set_icap_hol.html regenerado con código completo. STEPS bytes={len(new_steps)}")


if __name__ == "__main__":
    main()
