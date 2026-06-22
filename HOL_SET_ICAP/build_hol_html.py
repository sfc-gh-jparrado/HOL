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
    3:  ("10 min", "DDL + carga del histórico (COPY INTO)",
         "<p>Creamos las 11 tablas del modelo SET-FX y cargamos un año de operaciones desde S3.</p>"),
    4:  ("15 min", "⭐ Snowpipe con auto-ingesta (event-driven)",
         "<div class=\"note new\"><strong>Lo nuevo.</strong> Cada archivo que llega a <code>stream/</code> dispara una notificación S3 → SQS y el pipe carga los datos en segundos, sin tareas. Para conectar S3→SQS usa el ARN del paso 4.2 con <code>aws s3api put-bucket-notification-configuration</code> (ver README).</div>"),
    5:  ("5 min", "Time Travel y Zero-Copy Cloning",
         "<p>Recupera datos y crea ambientes dev instantáneos sin duplicar almacenamiento.</p>"),
    6:  ("10 min", "Enmascaramiento dinámico de datos",
         "<p>Un analista no debe ver la identidad de las contrapartes. Aplicamos Dynamic Data Masking.</p>"),
    7:  ("12 min", "Cortex AI: análisis de mercado con IA",
         "<p>Clasificación, análisis diario, sentimiento y resumen con IA generativa.</p>"
         "<div class=\"note\"><strong>Nota:</strong> <code>AI_SENTIMENT</code> retorna OBJECT; se accede con <code>:categories[0]:sentiment::VARCHAR</code>.</div>"),
    8:  ("10 min", "Dynamic Tables: analítica que se refresca sola",
         "<p>VWAP diario y ranking de entidades, siempre actualizados (anti fan-out con DISTINCT).</p>"),
    12: ("3 min", "Limpieza",
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

STEP9 = ("15 min", "Streamlit: tablero del mercado SET-FX",
         "<p>En Snowsight → Projects → Streamlit → <em>+ Streamlit App</em> (warehouse WH_HOL_SETICAP, database DB_HOL_SETICAP, schema PUBLIC). Pega el código:</p>"
         "<div class=\"codebox\"><span class=\"lang\">python</span><button class=\"btn-copy\" onclick=\"copyCode(this)\">Copiar</button><pre>"
         + html_escape(STREAMLIT_PY) + "</pre></div>")

STEP10 = ("8 min", "Semantic View para Cortex Analyst",
          "<p>En Snowsight → AI &amp; ML → Cortex Analyst → Create → Semantic View. Selecciona las tablas y métricas (o importa <code>HOL_SET_ICAP_semantic_model.yaml</code>).</p>"
          "<ul><li><strong>Tablas:</strong> OPERATION_SET_FX, ENTIDAD, MERCADO, PARIDAD_MONEDA</li>"
          "<li><strong>Relaciones:</strong> MERCADO→MERCADO_ID, ENTIDAD_COMPRADORA→ENTIDAD_ID, PARIDAD_ID→PARIDAD_ID</li>"
          "<li><strong>Métricas:</strong> volumen_usd=SUM(MONTO_USD), num_operaciones=COUNT(ID), vwap=SUM(PRECIO*MONTO_USD)/SUM(MONTO_USD), trm_promedio=AVG(PRECIO)</li>"
          "<li><strong>Dimensiones:</strong> FECHA, PLAZO_CURVA, MERCADO_NOMBRE, ENTIDAD_SIGLA</li></ul>")

STEP11 = ("15 min", "Snowflake Intelligence: agente conversacional",
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
    for n in range(1, 13):
        if n in (1, 2, 3, 4, 5, 6, 7, 8, 12):
            t, title, intro = META[n]
            body = intro + code_block(parts[n], "sql")
        elif n == 9:
            t, title, body = STEP9
        elif n == 10:
            t, title, body = STEP10
        elif n == 11:
            t, title, body = STEP11
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
    assert all(n in parts for n in range(1, 13)), f"faltan partes: {sorted(set(range(1,13))-set(parts))}"
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
