# Monitor PSE en vivo — Streamlit in Snowflake (SiS)
# Lee las Dynamic Tables (DT_PSE_*) que se refrescan cada minuto desde el feed en S3.
# Desplegar en Snowsight: Projects > Streamlit > + Streamlit App (warehouse HOL_WH, schema HOL_SEC.INCIDENTE).
import streamlit as st
import altair as alt
from datetime import datetime
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="ACH · Monitor PSE en vivo", layout="wide")
session = get_active_session()

REFRESH_SEG = 15
st.title("ACH · Monitor PSE en tiempo real")
st.caption(f"Fuente: Dynamic Tables (lag 1 min) alimentadas por Snowpipe desde S3 · refresco {REFRESH_SEG}s")

# auto-refresh (si la version de Streamlit lo soporta)
try:
    st.autorefresh(interval=REFRESH_SEG * 1000, key="pse_auto")
except Exception:
    pass

@st.cache_data(ttl=REFRESH_SEG)
def q(sql: str):
    return session.sql(sql).to_pandas()

# ---- KPIs de la ultima hora ----
kpi = q("""
  SELECT SUM(txns) AS txns,
         SUM(IFF(estado='APROBADA',txns,0)) AS aprobadas,
         SUM(IFF(estado='RECHAZADA',txns,0)) AS rechazadas,
         ROUND(SUM(monto_total)/1e9,1) AS mmm_cop
  FROM DT_PSE_POR_MINUTO
  WHERE minuto >= DATEADD('hour',-1,CURRENT_TIMESTAMP())
""").iloc[0]
c1, c2, c3, c4 = st.columns(4)
c1.metric("Transacciones (1h)", f"{int(kpi.TXNS or 0):,}")
c2.metric("Aprobadas", f"{int(kpi.APROBADAS or 0):,}")
c3.metric("Rechazadas", f"{int(kpi.RECHAZADAS or 0):,}")
c4.metric("Monto (mil MM COP)", f"{kpi.MMM_COP or 0}")

# ---- Volumen por minuto (ultimos 30 min) ----
st.subheader("Volumen por minuto")
vol = q("""
  SELECT minuto, SUM(txns) AS txns
  FROM DT_PSE_POR_MINUTO
  WHERE minuto >= DATEADD('minute',-30,CURRENT_TIMESTAMP())
  GROUP BY 1 ORDER BY 1
""")
if not vol.empty:
    st.altair_chart(
        alt.Chart(vol).mark_area(opacity=0.5, color="#29b5e8").encode(
            x=alt.X("MINUTO:T", title="minuto"), y=alt.Y("TXNS:Q", title="txns")),
        use_container_width=True)

# ---- Alertas: bancos con rechazo anomalo ----
st.subheader("Bancos con tasa de rechazo anomala")
rech = q("""
  SELECT banco, hora, rechazos, pct_rechazo
  FROM DT_PSE_RECHAZOS
  WHERE pct_rechazo > 25 AND total > 100
  ORDER BY rechazos DESC LIMIT 10
""")
if rech.empty:
    st.success("Sin bancos con rechazo anomalo en la ventana.")
else:
    st.error(f"{len(rech)} banco(s) con rechazo > 25%")
    st.dataframe(rech, use_container_width=True, hide_index=True)

# ---- Alertas: comercios bajo ataque ----
st.subheader("Comercios bajo posible ataque (pico de volumen)")
ataque = q("""
  SELECT comercio_id, ventana, txns, ROUND(monto_total/1e6,1) AS mcop
  FROM DT_PSE_COMERCIO_ATAQUE
  WHERE txns > 300
  ORDER BY txns DESC LIMIT 10
""")
if ataque.empty:
    st.success("Sin comercios con concentracion anomala.")
else:
    st.error(f"{len(ataque)} comercio(s) con pico de volumen")
    st.dataframe(ataque, use_container_width=True, hide_index=True)

st.caption(f"Actualizado: {datetime.now():%H:%M:%S}")
