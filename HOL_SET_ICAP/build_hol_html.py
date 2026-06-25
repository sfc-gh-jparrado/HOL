#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Genera set_icap_hol.html con el CÓDIGO COMPLETO de cada paso (copy-paste a
Snowflake), tomando el SQL real de HOL_SET_ICAP.sql (partes 1-8 y 12). Los pasos
9 (Streamlit), 10 (Cortex Analyst + Search) y 11 (CoWork UI) usan contenido
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
         "<p>Cargamos 400M filas desde S3 y demostramos el impacto del tamaño de warehouse cargando la misma tabla de 120M con SMALL y luego con XLARGE.</p>"
         "<div class=\"note\">La capa de consumo <code>OPERACIONES</code> (denormalizada, sin fan-out) nace en el paso 8 como <strong>Dynamic Table</strong>.</div>"),
    5:  ("5 min", "Time Travel & UNDROP",
         "<p>Recupérate de errores sin backups: <code>DROP</code>/<code>UNDROP</code> de una tabla y recuperación de un <code>UPDATE</code> sin <code>WHERE</code> con un <strong>BEFORE de ~3 minutos</strong> (o por query_id del statement dañino).</p>"),
    6:  ("10 min", "Enmascaramiento dinámico de datos",
         "<p>Un analista no debe ver la identidad de las contrapartes. Aplicamos Dynamic Data Masking.</p>"),
    7:  ("12 min", "Cortex AI: texto + imágenes + audio",
         "<p>Comentario de mercado <strong>automático en español</strong> sobre cifras reales (TRM promedio, volumen, número de operaciones) — listo para el reporte diario de la mesa. Además <strong>multimodal</strong>: lectura de un gráfico de la TRM (visión) y transcripción de una llamada de mesa de dinero (audio).</p>"
         "<div class=\"note\"><strong>Caso de negocio:</strong> en vez de un análisis interpretativo débil, el modelo redacta una lectura ejecutiva accionable fundamentada en los datos agregados del día. Imagen con <code>pixtral-large</code> + <code>TO_FILE</code>; audio con <code>AI_TRANSCRIBE</code>.</div>"),
    8:  ("10 min", "⭐ Dynamic Table: la vista plana del cliente, viva",
         "<p>Una <strong>sola</strong> Dynamic Table <code>OPERACIONES</code> replica el query del cliente (unión de todas las tablas) con grano <strong>1 fila por operación</strong>: la contraparte se aplana por lado (comprador/vendedor) para evitar fan-out. Se refresca sola (incremental cuando aplica) y es la única tabla del semantic view de Cortex Analyst → agregaciones correctas.</p>"
         "<div class=\"note new\"><strong>Verificación:</strong> <code>COUNT(*)</code> de OPERACIONES = <code>COUNT(*)</code> de OPERATION_SET_FX (sin fan-out).</div>"),
    12: ("3 min", "Limpieza",
         "<p>Elimina la base de datos, el warehouse y el rol del HOL.</p>"),
}

# Paso no-SQL (curado): prompt para generar el dashboard con CoCo
COCO_PROMPT = """Crea una app de Streamlit-in-Snowflake VISUALMENTE POTENTE para el mercado de divisas
SET-FX de SET-ICAP (Colombia). Usala con get_active_session() y SIN dependencias de red externas
(solo Streamlit nativo + altair/plotly disponibles en SiS).

Base de datos: DB_HOL_SETICAP, schema PUBLIC. Fuente principal: la Dynamic Table OPERACIONES
(1 fila por operacion, ya denormalizada). Columnas relevantes:
- FECHA, HORA, ANULADA, MERCADO, MERCADO_NOMBRE, SUBMERCADO_NOMBRE, PARIDAD_NOMBRE, PLAZO_CURVA
- MONTO_USD, MONTO_COP, PRECIO (TRM), PRECIO_SPOT, POINTS_FORWARD
- COMPRADOR_SIGLA / COMPRADOR_NOMBRE / COMPRADOR_CLASE / COMPRADOR_CIUDAD
- VENDEDOR_SIGLA / VENDEDOR_NOMBRE / VENDEDOR_CLASE / VENDEDOR_CIUDAD
- COMPRADOR_TRADER, VENDEDOR_TRADER, COMPRADOR_COMITENTE, VENDEDOR_COMITENTE
No hay tablas pre-agregadas: calcula todo con agregaciones SQL sobre OPERACIONES. Ejemplo:
VWAP diario = SUM(PRECIO*MONTO_USD)/NULLIF(SUM(MONTO_USD),0) por FECHA, con ANULADA=FALSE y MERCADO=76.

Diseno (estilo fintech profesional, TEMA OSCURO, branding Snowflake #29B5E8 / #11567F):
1. Hero con titulo "SET-FX - Mercado de Divisas", subtitulo y selector de rango de fechas.
2. KPI cards grandes con delta/flechas y color: TRM (VWAP) mas reciente, variacion % vs dia anterior,
   volumen del dia (M USD), numero de operaciones, % anuladas.
3. Grafico principal: evolucion de la TRM (VWAP diario) tipo linea con banda min-max sombreada y tooltip rico.
4. Barras horizontales: Top 10 entidades compradoras por volumen, coloreadas por COMPRADOR_CLASE.
5. Profundidad de mercado: compra vs venta por clase de entidad (barras divergentes).
6. Mapa de calor de actividad por HORA del dia vs dia de la semana (numero de operaciones).
7. Donut: distribucion de volumen por PLAZO_CURVA (T+0, T+1, 3M...).
8. Tabla de las 50 operaciones mas recientes (ORDER BY FECHA, HORA desc) con formato de moneda.
9. Layout responsive con st.columns y st.container(border=True), tema oscuro elegante con acentos en
   #29B5E8. Usa @st.cache_data(ttl=300) y maneja DataFrame vacio.

Hazlo realmente atractivo: paleta coherente, espaciado generoso y que parezca un terminal de trading
profesional. Genera el app.py COMPLETO, listo para pegar en Snowsight -> Streamlit."""

STEP9 = ("15 min", "Streamlit: tablero del mercado SET-FX (con CoCo)",
         "<p>En Snowsight → Projects → Streamlit → <em>+ Streamlit App</em> (warehouse WH_HOL_SETICAP, database DB_HOL_SETICAP, schema PUBLIC).</p>"
         "<div class=\"note new\"><strong>Genéralo con Cortex Code (CoCo).</strong> No escribes código a mano: abre Cortex Code, pega este prompt y CoCo arma el <code>app.py</code> completo — un dashboard fintech de tema oscuro con KPIs, serie de la TRM, profundidad de mercado, mapa de calor y tabla de operaciones — conectado a tus objetos del HOL:</div>"
         "<div class=\"codebox\"><span class=\"lang\">prompt · cortex code</span><button class=\"btn-copy\" onclick=\"copyCode(this)\">Copiar</button><pre>"
         + html_escape(COCO_PROMPT) + "</pre></div>")

STEP10 = ("12 min", "Cortex Analyst + Cortex Search",
          "<p>Capa de IA conversacional sobre dos frentes: <strong>Cortex Analyst</strong> (cifras/SQL) y <strong>Cortex Search</strong> (texto). Los <code>CREATE CORTEX SEARCH SERVICE</code> van en el código SQL de este paso; el Analyst se arma en la UI o importando el YAML.</p>"
          "<ul><li><strong>Cortex Analyst — Semantic View SV_SET_FX</strong> sobre la tabla ÚNICA <code>OPERACIONES</code> (sin relaciones → sin fan-out). Métricas: volumen_usd, num_operaciones, vwap, trm_promedio. O importa <code>HOL_SET_ICAP_semantic_model.yaml</code>.</li>"
          "<li><strong>CS_NOTAS_MERCADO</strong> — Cortex Search sobre <code>TEXTO_TERM</code> (notas de los traders) para buscar/citar comentarios de mercado.</li>"
          "<li><strong>CS_ENTIDADES</strong> — Cortex Search sobre el catálogo de entidades para descubrir/desambiguar contrapartes por nombre, sigla, clase o ciudad.</li></ul>"
          "<div class=\"note\">El código de abajo crea ambos servicios de búsqueda y los prueba con <code>SEARCH_PREVIEW</code>.</div>"
          + "<div class=\"codebox\"><span class=\"lang\">sql</span><button class=\"btn-copy\" onclick=\"copyCode(this)\">Copiar</button><pre>"
          + html_escape("""-- Cortex Search sobre las NOTAS de mercado\nCREATE OR REPLACE CORTEX SEARCH SERVICE CS_NOTAS_MERCADO\n  ON TEXTO_TERM\n  ATTRIBUTES FECHA, MERCADO_NOMBRE, COMPRADOR_SIGLA, VENDEDOR_SIGLA, PLAZO_CURVA\n  WAREHOUSE = WH_HOL_SETICAP TARGET_LAG = '1 hour'\n  AS SELECT TEXTO_TERM, FECHA, MERCADO_NOMBRE, COMPRADOR_SIGLA, VENDEDOR_SIGLA, PLAZO_CURVA\n     FROM OPERACIONES WHERE TEXTO_TERM IS NOT NULL AND TEXTO_TERM <> '';\n\n-- Cortex Search sobre el catálogo de ENTIDADES\nCREATE OR REPLACE CORTEX SEARCH SERVICE CS_ENTIDADES\n  ON ENTIDAD_NOMBRE\n  ATTRIBUTES ENTIDAD_SIGLA, ENTIDAD_CLASE, ENTIDAD_TIPO, ENTIDAD_CIUDAD\n  WAREHOUSE = WH_HOL_SETICAP TARGET_LAG = '1 hour'\n  AS SELECT ENTIDAD_NOMBRE, ENTIDAD_SIGLA, ENTIDAD_CLASE, ENTIDAD_TIPO, ENTIDAD_CIUDAD FROM ENTIDAD;\n\nSHOW CORTEX SEARCH SERVICES;""") + "</pre></div>")

STEP11 = ("15 min", "Snowflake CoWork: agente conversacional",
          "<p>En Snowsight → AI &amp; ML → <strong>Snowflake CoWork</strong> → + Crear agente. Conecta las <strong>tres herramientas</strong> de la Parte 10 y define las instrucciones (todo el razonamiento en español).</p>"
          "<ul><li><strong>Nombre:</strong> AGT_SETICAP · DB/Schema: DB_HOL_SETICAP.PUBLIC</li>"
          "<li><strong>Tools:</strong> Cortex Analyst → <code>SV_SET_FX</code> · Cortex Search → <code>CS_NOTAS_MERCADO</code> · Cortex Search → <code>CS_ENTIDADES</code></li></ul>"
          "<p><strong>Instrucciones de orquestación:</strong> cifras/métricas/rankings → Cortex Analyst; buscar/citar notas → CS_NOTAS_MERCADO; identificar/listar entidades por nombre o atributo → CS_ENTIDADES (y encadenar con Analyst para sus cifras). Cita las dimensiones usadas y razona SIEMPRE en español.</p>"
          "<p><strong>Instrucciones de respuesta:</strong> responde en español con cifras claras (TRM COP/USD, volumen en M USD); propón 2-3 preguntas de seguimiento; TODO el contenido y el razonamiento paso a paso debe estar en español.</p>"
          "<p><strong>Preguntas demo (cubren las 3 herramientas):</strong></p><ul>"
          "<li>(Analyst) ¿Cuál fue el VWAP del USD/COP la última semana?</li>"
          "<li>(Analyst) Compara el volumen entre bancos y comisionistas el último mes.</li>"
          "<li>(Notas) Busca notas que mencionen intervención del Banco de la República.</li>"
          "<li>(Entidades) ¿Qué comisionistas de bolsa hay en Medellín?</li></ul>")


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
