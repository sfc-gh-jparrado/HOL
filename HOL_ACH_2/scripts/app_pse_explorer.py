# =============================================================================
# HOL ACH - Explorador visual de fraude PSE (Streamlit-in-Snowflake, Plotly)
# -----------------------------------------------------------------------------
# CODIGO DE MUESTRA / SAMPLE CODE - Entregado "TAL CUAL" (AS-IS), sin garantia.
# Uso educativo dentro del HOL. Datos 100% sinteticos, sin PII real.
# -----------------------------------------------------------------------------
# Despliegue (Modulo B, solo navegador): Snowsight -> Projects -> Streamlit ->
#   + Streamlit App, base de datos HOL_SEC, esquema INCIDENTE, warehouse HOL_WH.
#   Agrega el paquete "plotly" en Packages. Pega este archivo y ejecuta.
# Tambien sirve en Modulo A desplegado como servicio SPCS.
# =============================================================================
import streamlit as st
import plotly.express as px
import plotly.graph_objects as go
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="PSE · Explorador de fraude", layout="wide")
session = get_active_session()


@st.cache_data(ttl=600)
def q(sql: str):
    return session.sql(sql).to_pandas()


# ---------------------------------------------------------------------------
# Deteccion automatica del incidente (bucket banco+hora con mas rechazos)
# ---------------------------------------------------------------------------
inc = q("""
    WITH hourly AS (
        SELECT banco, DATE_TRUNC('hour', ts) AS hb,
               SUM(IFF(estado = 'RECHAZADA', 1, 0)) AS rech
        FROM PSE_TRANSACTIONS GROUP BY 1, 2)
    SELECT banco, TO_DATE(hb) AS dia, HOUR(hb) AS hora, rech
    FROM hourly ORDER BY rech DESC LIMIT 1
""").iloc[0]
inc_banco, inc_dia, inc_hora = inc["BANCO"], inc["DIA"], int(inc["HORA"])

rango = q("SELECT MIN(TO_DATE(ts)) lo, MAX(TO_DATE(ts)) hi FROM PSE_TRANSACTIONS").iloc[0]
bancos = q("SELECT DISTINCT banco FROM BANCOS ORDER BY banco")["BANCO"].tolist()

st.title("PSE · Explorador de fraude")
st.caption(
    f"~30M transacciones cargadas desde S3 (batch). Incidente detectado: "
    f"**{inc_banco}** el **{inc_dia}** hacia las **{inc_hora:02d}:00**."
)

dia = st.date_input("Día a inspeccionar", value=inc_dia,
                    min_value=rango["LO"], max_value=rango["HI"])
d = dia.strftime("%Y-%m-%d")

# ---------------------------------------------------------------------------
# KPIs
# ---------------------------------------------------------------------------
kpi = q("""
    SELECT COUNT(*)                     AS txns,
           ROUND(SUM(monto) / 1e6, 0)   AS mcop,
           ROUND(100.0 * SUM(IFF(estado = 'RECHAZADA', 1, 0)) / COUNT(*), 1) AS pct
    FROM PSE_TRANSACTIONS
""").iloc[0]
peak = q(f"""
    WITH bh AS (
        SELECT banco, HOUR(ts) AS h,
               100.0 * SUM(IFF(estado = 'RECHAZADA', 1, 0)) / COUNT(*) AS pct
        FROM PSE_TRANSACTIONS WHERE TO_DATE(ts) = '{d}' GROUP BY 1, 2)
    SELECT banco, ROUND(MAX(pct), 1) AS mx FROM bh GROUP BY 1 ORDER BY mx DESC LIMIT 1
""").iloc[0]
c1, c2, c3, c4 = st.columns(4)
c1.metric("Transacciones (total)", f"{int(kpi['TXNS']):,}")
c2.metric("Monto total", f"{int(kpi['MCOP']):,} MCOP")
c3.metric("% rechazo global", f"{kpi['PCT']}%")
c4.metric(f"Pico de rechazo {d}", f"{peak['MX']}%", peak['BANCO'])

st.divider()

# ---------------------------------------------------------------------------
# Gauges: maximo % de rechazo por banco en el dia seleccionado
# ---------------------------------------------------------------------------
st.subheader(f"Máximo % de rechazo por banco · {d}")
gaug = q(f"""
    WITH bh AS (
        SELECT banco, HOUR(ts) AS h,
               100.0 * SUM(IFF(estado = 'RECHAZADA', 1, 0)) / COUNT(*) AS pct
        FROM PSE_TRANSACTIONS WHERE TO_DATE(ts) = '{d}' GROUP BY 1, 2)
    SELECT banco, ROUND(MAX(pct), 1) AS max_pct
    FROM bh GROUP BY 1 ORDER BY max_pct DESC LIMIT 6
""")
cols = st.columns(3)
for i, row in gaug.iterrows():
    val = float(row["MAX_PCT"])
    fig = go.Figure(go.Indicator(
        mode="gauge+number", value=val, number={"suffix": "%"},
        title={"text": row["BANCO"], "font": {"size": 14}},
        gauge={
            "axis": {"range": [0, 60]},
            "bar": {"color": "#ef4444" if val > 25 else "#29b5e8"},
            "threshold": {"line": {"color": "#b91c1c", "width": 3},
                          "thickness": 0.8, "value": 25},
        },
    ))
    fig.update_layout(height=200, margin=dict(l=10, r=10, t=40, b=10))
    cols[i % 3].plotly_chart(fig, use_container_width=True)

st.divider()

# ---------------------------------------------------------------------------
# Bar-race: volumen por comercio, hora a hora del dia seleccionado
# ---------------------------------------------------------------------------
st.subheader(f"Volumen por comercio, hora a hora · {d} ▶")
st.caption("Presiona ▶ para animar. El comercio bajo ataque se dispara en la madrugada.")
race = q(f"""
    WITH top AS (
        SELECT comercio_id FROM PSE_TRANSACTIONS
        WHERE TO_DATE(ts) = '{d}' GROUP BY 1 ORDER BY COUNT(*) DESC LIMIT 7)
    SELECT HOUR(t.ts)                                       AS hora,
           COALESCE(c.nombre, 'Comercio ' || t.comercio_id) AS comercio,
           COUNT(*)                                         AS txns
    FROM PSE_TRANSACTIONS t
    LEFT JOIN COMERCIOS c ON c.comercio_id = t.comercio_id
    WHERE TO_DATE(t.ts) = '{d}'
      AND (t.comercio_id IN (SELECT comercio_id FROM top) OR t.comercio_id = 9001)
    GROUP BY 1, 2 ORDER BY 1
""")
if race.empty:
    st.info("Sin datos para ese día.")
else:
    race["HORA"] = race["HORA"].astype(int)
    xmax = float(race["TXNS"].max()) * 1.1
    fig_race = px.bar(
        race.sort_values("HORA"), x="TXNS", y="COMERCIO", color="COMERCIO",
        orientation="h", animation_frame="HORA", range_x=[0, xmax],
        labels={"TXNS": "Transacciones", "COMERCIO": "", "HORA": "Hora"},
    )
    fig_race.update_layout(height=430, showlegend=False,
                           margin=dict(l=10, r=10, t=10, b=10))
    st.plotly_chart(fig_race, use_container_width=True)

st.divider()

# ---------------------------------------------------------------------------
# Heatmap: % rechazo por dia x hora para un banco (el incidente = 1 sola noche)
# ---------------------------------------------------------------------------
st.subheader("Mapa de calor · % rechazo por día y hora")
banco_sel = st.selectbox("Banco", bancos,
                         index=bancos.index(inc_banco) if inc_banco in bancos else 0)
hm = q(f"""
    SELECT TO_DATE(ts) AS fecha, HOUR(ts) AS hora,
           ROUND(100.0 * SUM(IFF(estado = 'RECHAZADA', 1, 0)) / COUNT(*), 1) AS pct
    FROM PSE_TRANSACTIONS WHERE banco = '{banco_sel}' GROUP BY 1, 2
""")
if hm.empty:
    st.info("Sin datos para ese banco.")
else:
    hm["HORA"] = hm["HORA"].astype(int)
    piv = hm.pivot(index="FECHA", columns="HORA", values="PCT").sort_index()
    fig_hm = go.Figure(go.Heatmap(
        z=piv.values, x=[f"{h:02d}" for h in piv.columns],
        y=[str(f) for f in piv.index],
        colorscale="Blues", colorbar={"title": "% rechazo"},
        hovertemplate="Día %{y}<br>Hora %{x}:00<br>%{z}%<extra></extra>",
    ))
    fig_hm.update_layout(height=520, margin=dict(l=10, r=10, t=10, b=10),
                         xaxis_title="Hora del día", yaxis_title="")
    st.plotly_chart(fig_hm, use_container_width=True)
    st.caption("Una sola celda se enciende: el incidente es una única madrugada, no un patrón diario.")
