# Sub-Skill: Streamlit Dashboard

## Metadata
- **Parent**: snowflake-hol-generator
- **Name**: modules/streamlit
- **Obligatorio**: ❌ No
- **Duración**: ~15 minutos
- **Dependencias**: Setup completado, datos cargados, vistas creadas

---

## 🎯 Objetivo

Crear un dashboard interactivo que visualice los datos:
- Desplegado dentro de Snowflake (Streamlit in Snowflake)
- Sin infraestructura externa
- Conectado directamente a las tablas

---

## ✅ Compatibilidad Trial

| Característica | Trial | Notas |
|---------------|-------|-------|
| Streamlit in Snowflake | ✅ | Funciona completamente |
| snowflake-ml-python | ✅ | Disponible |
| Gráficos Altair | ✅ | Incluido |
| st.connection | ❌ | Solo para Streamlit externo |
| get_active_session() | ✅ | Para Streamlit in Snowflake |

---

## Paso 1: Crear App de Streamlit via UI

### Instrucciones para el Usuario
```html
<h3>Crear Dashboard en Snowflake</h3>

<ol>
    <li><strong>Navegar a Streamlit:</strong>
        <ul>
            <li>En Snowsight, ve a <code>Projects → Streamlit</code></li>
            <li>O usa el menú: <code>Data Products → Apps → Streamlit</code></li>
        </ul>
    </li>
    <li><strong>Crear nueva app:</strong>
        <ul>
            <li>Click en <code>+ Streamlit App</code></li>
            <li><strong>Nombre:</strong> <code>[CLIENTE]_DASHBOARD</code></li>
            <li><strong>Warehouse:</strong> <code>[CLIENTE]_WH</code></li>
            <li><strong>Database:</strong> <code>[CLIENTE_HOL]</code></li>
            <li><strong>Schema:</strong> <code>APPS</code></li>
        </ul>
    </li>
    <li><strong>Pegar el código</strong> (se proporciona abajo)</li>
    <li><strong>Click en Run</strong></li>
</ol>
```

---

## Paso 2: Código del Dashboard

```python
# ===========================================
# DASHBOARD [CLIENTE] - STREAMLIT IN SNOWFLAKE
# ===========================================

import streamlit as st
from snowflake.snowpark.context import get_active_session
import pandas as pd
import altair as alt

# Configuración de página
st.set_page_config(
    page_title="Dashboard [CLIENTE]",
    page_icon="📊",
    layout="wide"
)

# Obtener sesión de Snowflake
session = get_active_session()

# ===========================================
# FUNCIONES DE DATOS
# ===========================================

@st.cache_data(ttl=300)
def cargar_resumen():
    """Carga métricas principales"""
    query = """
    SELECT 
        SUM(MONTO) AS VENTAS_TOTALES,
        COUNT(*) AS TOTAL_TRANSACCIONES,
        COUNT(DISTINCT ID_CLIENTE) AS CLIENTES_UNICOS,
        AVG(MONTO) AS TICKET_PROMEDIO
    FROM [CLIENTE_HOL].ANALYTICS.V_[ENTIDAD]_ANALISIS
    """
    return session.sql(query).to_pandas()

@st.cache_data(ttl=300)
def cargar_tendencia():
    """Carga tendencia temporal"""
    query = """
    SELECT 
        DATE_TRUNC('MONTH', FECHA) AS MES,
        SUM(MONTO) AS VENTAS,
        COUNT(*) AS TRANSACCIONES
    FROM [CLIENTE_HOL].ANALYTICS.V_[ENTIDAD]_ANALISIS
    GROUP BY DATE_TRUNC('MONTH', FECHA)
    ORDER BY MES
    """
    return session.sql(query).to_pandas()

@st.cache_data(ttl=300)
def cargar_por_dimension(dimension):
    """Carga datos agrupados por dimensión"""
    query = f"""
    SELECT 
        {dimension},
        SUM(MONTO) AS VENTAS,
        COUNT(*) AS TRANSACCIONES
    FROM [CLIENTE_HOL].ANALYTICS.V_[ENTIDAD]_ANALISIS
    GROUP BY {dimension}
    ORDER BY VENTAS DESC
    LIMIT 10
    """
    return session.sql(query).to_pandas()

# ===========================================
# INTERFAZ
# ===========================================

# Header
col1, col2 = st.columns([3, 1])
with col1:
    st.title("📊 Dashboard [CLIENTE]")
    st.caption("Análisis de datos en tiempo real")

# Métricas principales
st.subheader("📈 Métricas Principales")
df_resumen = cargar_resumen()

col1, col2, col3, col4 = st.columns(4)
with col1:
    st.metric(
        "Ventas Totales",
        f"${df_resumen['VENTAS_TOTALES'].iloc[0]:,.0f}"
    )
with col2:
    st.metric(
        "Transacciones",
        f"{df_resumen['TOTAL_TRANSACCIONES'].iloc[0]:,.0f}"
    )
with col3:
    st.metric(
        "Clientes Únicos",
        f"{df_resumen['CLIENTES_UNICOS'].iloc[0]:,.0f}"
    )
with col4:
    st.metric(
        "Ticket Promedio",
        f"${df_resumen['TICKET_PROMEDIO'].iloc[0]:,.2f}"
    )

st.divider()

# Gráficos
col1, col2 = st.columns(2)

with col1:
    st.subheader("📅 Tendencia Mensual")
    df_tendencia = cargar_tendencia()
    
    chart = alt.Chart(df_tendencia).mark_line(
        point=True,
        strokeWidth=3
    ).encode(
        x=alt.X('MES:T', title='Mes'),
        y=alt.Y('VENTAS:Q', title='Ventas ($)'),
        tooltip=['MES', 'VENTAS', 'TRANSACCIONES']
    ).properties(height=300)
    
    st.altair_chart(chart, use_container_width=True)

with col2:
    st.subheader("🏆 Top por Categoría")
    df_categoria = cargar_por_dimension('CATEGORIA')
    
    chart = alt.Chart(df_categoria).mark_bar(
        color='#29B5E8'
    ).encode(
        x=alt.X('VENTAS:Q', title='Ventas ($)'),
        y=alt.Y('CATEGORIA:N', sort='-x', title=''),
        tooltip=['CATEGORIA', 'VENTAS', 'TRANSACCIONES']
    ).properties(height=300)
    
    st.altair_chart(chart, use_container_width=True)

st.divider()

# Tabla detallada
st.subheader("📋 Datos Detallados")
dimension = st.selectbox(
    "Agrupar por:",
    ["REGION", "CATEGORIA", "SEGMENTO"]
)
df_detalle = cargar_por_dimension(dimension)
st.dataframe(df_detalle, use_container_width=True)

# Footer
st.caption("Dashboard generado con Streamlit in Snowflake")
```

---

## Paso 3: Estructura de 5 Vistas (Template Completo)

```python
# ===========================================
# DASHBOARD COMPLETO CON NAVEGACIÓN
# ===========================================

import streamlit as st
from snowflake.snowpark.context import get_active_session
import pandas as pd
import altair as alt

st.set_page_config(
    page_title="[CLIENTE] Analytics",
    page_icon="📊",
    layout="wide"
)

session = get_active_session()

# ===========================================
# SIDEBAR - NAVEGACIÓN
# ===========================================

st.sidebar.image("https://www.logo.wine/a/logo/Snowflake_Inc./Snowflake_Inc.-Logo.wine.svg", width=150)
st.sidebar.title("Navegación")

vista = st.sidebar.radio(
    "Selecciona una vista:",
    ["🏠 Resumen", "📍 Por Región", "📦 Productos", "👥 Clientes", "📈 Tendencias"]
)

# Filtros globales
st.sidebar.divider()
st.sidebar.subheader("Filtros")

# ===========================================
# FUNCIONES DE CARGA
# ===========================================

@st.cache_data(ttl=300)
def ejecutar_query(query):
    return session.sql(query).to_pandas()

# ===========================================
# VISTAS
# ===========================================

if vista == "🏠 Resumen":
    st.title("🏠 Resumen Ejecutivo")
    
    # KPIs
    df_kpis = ejecutar_query("""
        SELECT 
            SUM(MONTO) AS VENTAS,
            COUNT(*) AS TXN,
            COUNT(DISTINCT ID_CLIENTE) AS CLIENTES,
            AVG(MONTO) AS TICKET
        FROM [CLIENTE_HOL].ANALYTICS.V_[ENTIDAD]_ANALISIS
    """)
    
    c1, c2, c3, c4 = st.columns(4)
    c1.metric("Ventas", f"${df_kpis['VENTAS'].iloc[0]:,.0f}")
    c2.metric("Transacciones", f"{df_kpis['TXN'].iloc[0]:,}")
    c3.metric("Clientes", f"{df_kpis['CLIENTES'].iloc[0]:,}")
    c4.metric("Ticket Promedio", f"${df_kpis['TICKET'].iloc[0]:,.2f}")

elif vista == "📍 Por Región":
    st.title("📍 Análisis por Región")
    
    df_region = ejecutar_query("""
        SELECT REGION, SUM(MONTO) AS VENTAS, COUNT(*) AS TXN
        FROM [CLIENTE_HOL].ANALYTICS.V_[ENTIDAD]_ANALISIS
        GROUP BY REGION
        ORDER BY VENTAS DESC
    """)
    
    col1, col2 = st.columns(2)
    with col1:
        st.dataframe(df_region, use_container_width=True)
    with col2:
        chart = alt.Chart(df_region).mark_bar().encode(
            x='VENTAS:Q', y=alt.Y('REGION:N', sort='-x')
        )
        st.altair_chart(chart, use_container_width=True)

elif vista == "📦 Productos":
    st.title("📦 Análisis de Productos")
    
    df_prod = ejecutar_query("""
        SELECT CATEGORIA, PRODUCTO, SUM(MONTO) AS VENTAS
        FROM [CLIENTE_HOL].ANALYTICS.V_[ENTIDAD]_ANALISIS
        GROUP BY CATEGORIA, PRODUCTO
        ORDER BY VENTAS DESC
        LIMIT 20
    """)
    
    st.dataframe(df_prod, use_container_width=True)

elif vista == "👥 Clientes":
    st.title("👥 Análisis de Clientes")
    
    df_clientes = ejecutar_query("""
        SELECT SEGMENTO, COUNT(DISTINCT ID_CLIENTE) AS CLIENTES, SUM(MONTO) AS VENTAS
        FROM [CLIENTE_HOL].ANALYTICS.V_[ENTIDAD]_ANALISIS
        GROUP BY SEGMENTO
    """)
    
    st.dataframe(df_clientes, use_container_width=True)

elif vista == "📈 Tendencias":
    st.title("📈 Tendencias")
    
    df_trend = ejecutar_query("""
        SELECT DATE_TRUNC('MONTH', FECHA) AS MES, SUM(MONTO) AS VENTAS
        FROM [CLIENTE_HOL].ANALYTICS.V_[ENTIDAD]_ANALISIS
        GROUP BY MES
        ORDER BY MES
    """)
    
    chart = alt.Chart(df_trend).mark_line(point=True).encode(
        x='MES:T', y='VENTAS:Q'
    )
    st.altair_chart(chart, use_container_width=True)

# Footer
st.sidebar.divider()
st.sidebar.caption("Powered by Snowflake")
```

---

## Estilos CSS Personalizados

```python
# Agregar al inicio del código para estilos personalizados
st.markdown("""
<style>
    /* Colores Snowflake */
    :root {
        --snowflake-blue: #29B5E8;
        --snowflake-dark: #1565C0;
    }
    
    /* Headers */
    h1, h2, h3 {
        color: var(--snowflake-dark);
    }
    
    /* Métricas */
    [data-testid="stMetricValue"] {
        font-size: 2rem;
        color: var(--snowflake-blue);
    }
    
    /* Sidebar */
    [data-testid="stSidebar"] {
        background-color: #f8f9fa;
    }
</style>
""", unsafe_allow_html=True)
```

---

## Contenido HTML para el HOL

```html
<h2>📊 Dashboard con Streamlit</h2>

<p>Crea visualizaciones interactivas que corren dentro de Snowflake:</p>

<div class="info-box tip">
    <span class="info-icon">✨</span>
    <div class="info-content">
        <h4>Streamlit in Snowflake</h4>
        <p>Tu código Python corre en la infraestructura de Snowflake. 
        Sin servidores que manejar, sin costos de hosting, seguridad heredada.</p>
    </div>
</div>

<h3>Características</h3>
<ul>
    <li>✅ Conexión directa a tus datos (sin extraer)</li>
    <li>✅ Autenticación integrada con Snowflake</li>
    <li>✅ Gráficos interactivos con Altair</li>
    <li>✅ Caching automático para performance</li>
    <li>✅ Compartir apps con otros usuarios</li>
</ul>
```

---

## Siguiente Módulo

Este es el último módulo técnico base. Continuar con:
- **Industrias específicas**: [../../industries/](../../industries/)
- **Casos transversales**: [../../cross-functional/](../../cross-functional/)
