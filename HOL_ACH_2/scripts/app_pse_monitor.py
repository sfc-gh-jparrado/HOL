# Dashboard de fraude PSE (batch) — Streamlit in Snowflake (SiS)
# Lee la tabla base PSE_TRANSACTIONS (cargada por COPY desde S3). Sin tiempo real.
# Desplegar en Snowsight: Projects > Streamlit > + Streamlit App (warehouse HOL_WH, schema HOL_SEC.INCIDENTE).
import streamlit as st
import altair as alt
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="ACH · Fraude PSE", layout="wide")
session = get_active_session()

st.title("ACH · Monitoreo de fraude PSE")
st.caption("Fuente: PSE_TRANSACTIONS (cargada desde S3). Análisis por lotes (batch).")
if st.button("Actualizar"):
    st.cache_data.clear()

@st.cache_data(ttl=600)
def q(sql: str):
    return session.sql(sql).to_pandas()

# ---- KPIs globales ----
k = q("""
  SELECT COUNT(*) AS txns,
         SUM(IFF(estado='APROBADA',1,0)) AS aprobadas,
         SUM(IFF(estado='RECHAZADA',1,0)) AS rechazadas,
         ROUND(SUM(monto)/1e9,1) AS mmm_cop
  FROM PSE_TRANSACTIONS
""").iloc[0]
c1, c2, c3, c4 = st.columns(4)
c1.metric("Transacciones", f"{int(k.TXNS or 0):,}")
c2.metric("Aprobadas", f"{int(k.APROBADAS or 0):,}")
c3.metric("Rechazadas", f"{int(k.RECHAZADAS or 0):,}")
c4.metric("Monto (mil MM COP)", f"{k.MMM_COP or 0}")

# ---- Volumen por hora del dia ----
st.subheader("Volumen por hora del día")
vol = q("""
  SELECT HOUR(ts) AS hora, COUNT(*) AS txns
  FROM PSE_TRANSACTIONS GROUP BY 1 ORDER BY 1
""")
if not vol.empty:
    st.altair_chart(
        alt.Chart(vol).mark_bar(color="#29b5e8").encode(
            x=alt.X("HORA:O", title="hora"), y=alt.Y("TXNS:Q", title="txns")),
        use_container_width=True)

# ---- Bancos con rechazo anomalo (por hora) ----
st.subheader("Bancos con tasa de rechazo anómala")
rech = q("""
  SELECT banco, DATE_TRUNC('hour', ts) AS hora, COUNT(*) AS total,
         SUM(IFF(estado='RECHAZADA',1,0)) AS rechazos,
         ROUND(100*SUM(IFF(estado='RECHAZADA',1,0))/COUNT(*),1) AS pct_rechazo
  FROM PSE_TRANSACTIONS
  GROUP BY 1,2
  HAVING rechazos > 500 AND pct_rechazo > 25
  ORDER BY rechazos DESC LIMIT 10
""")
if rech.empty:
    st.success("Sin bancos con rechazo anómalo.")
else:
    st.error(f"{len(rech)} banco(s)/hora con rechazo > 25%")
    st.dataframe(rech, use_container_width=True, hide_index=True)

# ---- Comercios bajo ataque (ventana 10 min) ----
st.subheader("Comercios bajo posible ataque")
ataque = q("""
  SELECT comercio_id, TIME_SLICE(ts,10,'MINUTE') AS ventana,
         COUNT(*) AS txns, COUNT(DISTINCT documento_hash) AS documentos,
         ROUND(SUM(monto)/1e6,1) AS mcop
  FROM PSE_TRANSACTIONS
  GROUP BY 1,2
  HAVING COUNT(*) > 300
  ORDER BY txns DESC LIMIT 10
""")
if ataque.empty:
    st.success("Sin comercios con concentración anómala.")
else:
    st.error(f"{len(ataque)} comercio(s) con pico de volumen")
    st.dataframe(ataque, use_container_width=True, hide_index=True)
