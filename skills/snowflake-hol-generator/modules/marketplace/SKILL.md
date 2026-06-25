# Sub-Skill: Snowflake Marketplace Integration

## Metadata
- **Parent**: snowflake-hol-generator
- **Name**: modules/marketplace
- **Obligatorio**: ❌ No
- **Duración**: ~10 minutos
- **Dependencias**: Setup completado

---

## 🎯 Objetivo

Demostrar cómo enriquecer datos propios con:
- Datasets gratuitos del Marketplace
- Datos de terceros sin mover data
- Combinación datos internos + externos

---

## ✅ Compatibilidad Trial

| Característica | Trial | Notas |
|---------------|-------|-------|
| Browse Marketplace | ✅ | Sin restricciones |
| Get Free Data | ✅ | Disponible inmediatamente |
| Get Paid Data | ⚠️ | Requiere billing configurado |
| Use Shared Data | ✅ | Funciona completamente |

---

## Datasets Gratuitos Recomendados por Industria

### 🛒 Retail / E-commerce
| Dataset | Proveedor | Uso |
|---------|-----------|-----|
| Weather Source LLC | Weather Source | Correlacionar ventas con clima |
| Cybersyn Economy | Cybersyn | Indicadores económicos |
| Knoema Demographics | Knoema | Datos demográficos |

### 🏭 Manufactura
| Dataset | Proveedor | Uso |
|---------|-----------|-----|
| Global Commodity Prices | Cybersyn | Precios de materias primas |
| Supply Chain Indices | Multiple | Indicadores de cadena de suministro |

### 💊 Healthcare / Pharma
| Dataset | Proveedor | Uso |
|---------|-----------|-----|
| COVID-19 Data | Starschema | Datos epidemiológicos |
| Healthcare Provider Data | CMS | Información de proveedores |

### 🏦 Servicios Financieros
| Dataset | Proveedor | Uso |
|---------|-----------|-----|
| Financial & Economic Essentials | Cybersyn | Tasas de interés, inflación |
| Stock Market Data | Multiple | Precios de acciones |

### 🌐 General / Cross-Industry
| Dataset | Proveedor | Uso |
|---------|-----------|-----|
| IP Geolocation | IPinfo | Localización por IP |
| Public Holidays | Multiple | Calendario de festivos |
| Exchange Rates | Multiple | Tipos de cambio |

---

## Paso 1: Acceder al Marketplace

```html
<h3>Acceder al Snowflake Marketplace</h3>

<ol>
    <li>En Snowsight, haz clic en <strong>Data Products</strong> en el menú lateral</li>
    <li>Selecciona <strong>Marketplace</strong></li>
    <li>Usa la barra de búsqueda o navega por categorías</li>
</ol>

<div class="info-box tip">
    <span class="info-icon">💡</span>
    <div class="info-content">
        <h4>Filtrar por Precio</h4>
        <p>Usa el filtro "Free" para ver solo datasets gratuitos disponibles.</p>
    </div>
</div>
```

---

## Paso 2: Obtener Dataset de Weather Source

### Instrucciones UI
```html
<h3>Obtener Datos de Clima (Gratuito)</h3>

<ol>
    <li>Busca "Weather Source" en el Marketplace</li>
    <li>Selecciona <strong>Weather Source LLC: frostbyte</strong> (gratuito)</li>
    <li>Click en <strong>Get</strong></li>
    <li>Acepta los términos</li>
    <li>Selecciona los roles que tendrán acceso</li>
    <li>Click en <strong>Get</strong></li>
</ol>

<p>El dataset aparecerá como una nueva base de datos compartida en tu cuenta.</p>
```

### SQL de Verificación
```sql
-- ===========================================
-- VERIFICAR DATASET DEL MARKETPLACE
-- ===========================================

-- Ver bases de datos compartidas
SHOW DATABASES LIKE '%WEATHER%';

-- Explorar esquemas y tablas
SHOW SCHEMAS IN DATABASE WEATHER_SOURCE_LLC__FROSTBYTE;

-- Ver datos de ejemplo
SELECT * 
FROM WEATHER_SOURCE_LLC__FROSTBYTE.ONPOINT_ID.POSTAL_CODES
LIMIT 10;
```

---

## Paso 3: Combinar con Datos Propios

```sql
-- ===========================================
-- ENRIQUECER DATOS CON INFORMACIÓN DEL MARKETPLACE
-- ===========================================

USE DATABASE [CLIENTE_HOL];
USE WAREHOUSE [CLIENTE]_WH;

-- Ejemplo: Correlacionar ventas con clima
CREATE OR REPLACE VIEW ANALYTICS.V_VENTAS_CON_CLIMA AS
SELECT 
    v.FECHA,
    v.REGION,
    v.MONTO AS VENTAS,
    v.CANTIDAD,
    
    -- Datos del marketplace (clima)
    w.AVG_TEMPERATURE_AIR_2M_F AS TEMPERATURA_F,
    w.TOT_PRECIPITATION_IN AS PRECIPITACION,
    w.AVG_CLOUD_COVER_TOT_PCT AS NUBOSIDAD_PCT,
    
    -- Clasificación del día
    CASE 
        WHEN w.TOT_PRECIPITATION_IN > 0.1 THEN 'Lluvia'
        WHEN w.AVG_TEMPERATURE_AIR_2M_F > 85 THEN 'Caluroso'
        WHEN w.AVG_TEMPERATURE_AIR_2M_F < 50 THEN 'Frío'
        ELSE 'Normal'
    END AS TIPO_CLIMA

FROM RAW.VENTAS v
LEFT JOIN WEATHER_SOURCE_LLC__FROSTBYTE.ONPOINT_ID.HISTORY_DAY w
    ON v.FECHA = w.DATE_VALID_STD
    AND v.CODIGO_POSTAL = w.POSTAL_CODE
;

-- Análisis: ¿El clima afecta las ventas?
SELECT 
    TIPO_CLIMA,
    COUNT(*) AS NUM_DIAS,
    SUM(VENTAS) AS TOTAL_VENTAS,
    ROUND(AVG(VENTAS), 2) AS PROMEDIO_DIARIO,
    ROUND(AVG(CANTIDAD), 2) AS CANTIDAD_PROMEDIO
FROM ANALYTICS.V_VENTAS_CON_CLIMA
GROUP BY TIPO_CLIMA
ORDER BY PROMEDIO_DIARIO DESC;
```

---

## Paso 4: Enriquecer con Datos Económicos

```sql
-- ===========================================
-- AGREGAR INDICADORES ECONÓMICOS
-- ===========================================

-- Si tienes Cybersyn Financial & Economic Essentials
CREATE OR REPLACE VIEW ANALYTICS.V_VENTAS_CON_ECONOMIA AS
SELECT 
    v.*,
    
    -- Tasa de inflación del mes
    inf.VALUE AS INFLACION_MENSUAL,
    
    -- Índice de confianza del consumidor
    conf.VALUE AS CONFIANZA_CONSUMIDOR

FROM RAW.VENTAS v
LEFT JOIN CYBERSYN.PUBLIC.ECONOMIC_INDICATORS inf
    ON DATE_TRUNC('MONTH', v.FECHA) = inf.DATE
    AND inf.INDICATOR_NAME = 'CPI'
LEFT JOIN CYBERSYN.PUBLIC.ECONOMIC_INDICATORS conf
    ON DATE_TRUNC('MONTH', v.FECHA) = conf.DATE
    AND conf.INDICATOR_NAME = 'CONSUMER_CONFIDENCE'
;
```

---

## Paso 5: Dashboard con Datos Enriquecidos

```sql
-- ===========================================
-- VISTA FINAL PARA DASHBOARD
-- ===========================================

CREATE OR REPLACE VIEW ANALYTICS.V_DASHBOARD_ENRIQUECIDO AS
SELECT 
    -- Dimensiones de tiempo
    DATE_TRUNC('WEEK', v.FECHA) AS SEMANA,
    DATE_TRUNC('MONTH', v.FECHA) AS MES,
    
    -- Dimensiones de negocio
    v.REGION,
    v.CATEGORIA_PRODUCTO,
    
    -- Métricas de ventas
    SUM(v.MONTO) AS VENTAS,
    COUNT(*) AS TRANSACCIONES,
    
    -- Contexto externo (marketplace)
    AVG(w.AVG_TEMPERATURE_AIR_2M_F) AS TEMP_PROMEDIO,
    MAX(CASE WHEN w.TOT_PRECIPITATION_IN > 0 THEN 1 ELSE 0 END) AS TUVO_LLUVIA,
    
    -- Indicador compuesto
    SUM(v.MONTO) / NULLIF(AVG(w.AVG_TEMPERATURE_AIR_2M_F - 60), 0) AS VENTAS_AJUSTADAS_CLIMA

FROM RAW.VENTAS v
LEFT JOIN WEATHER_SOURCE_LLC__FROSTBYTE.ONPOINT_ID.HISTORY_DAY w
    ON v.FECHA = w.DATE_VALID_STD
GROUP BY 
    DATE_TRUNC('WEEK', v.FECHA),
    DATE_TRUNC('MONTH', v.FECHA),
    v.REGION,
    v.CATEGORIA_PRODUCTO
;
```

---

## Contenido HTML para el HOL

```html
<h2>🛒 Snowflake Marketplace</h2>

<p>Enriquece tus datos con información de terceros sin mover datos:</p>

<div class="card-grid">
    <div class="card">
        <div class="card-icon">🌤️</div>
        <h4>Datos de Clima</h4>
        <p>Correlaciona ventas con condiciones meteorológicas</p>
    </div>
    <div class="card">
        <div class="card-icon">📊</div>
        <h4>Indicadores Económicos</h4>
        <p>Inflación, PIB, confianza del consumidor</p>
    </div>
    <div class="card">
        <div class="card-icon">🗺️</div>
        <h4>Datos Geográficos</h4>
        <p>Demografía, códigos postales, geolocalización</p>
    </div>
    <div class="card">
        <div class="card-icon">📈</div>
        <h4>Datos Financieros</h4>
        <p>Tasas de cambio, precios de commodities</p>
    </div>
</div>

<div class="info-box tip">
    <span class="info-icon">✨</span>
    <div class="info-content">
        <h4>Zero-Copy Data Sharing</h4>
        <p>Los datos del Marketplace no se copian a tu cuenta - 
        accedes directamente a la fuente. Siempre actualizados, sin costo de storage.</p>
    </div>
</div>
```

---

## Siguiente Módulo

- **Streamlit**: [../streamlit/SKILL.md](../streamlit/SKILL.md)
