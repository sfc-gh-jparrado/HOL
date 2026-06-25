# Referencia: Datasets del Marketplace

## Metadata
- **Parent**: snowflake-hol-generator
- **Name**: references/marketplace-datasets
- **Última actualización**: 2024

---

## 📋 Datasets Gratuitos por Categoría

Esta referencia lista los datasets FREE más útiles del Snowflake Marketplace para enriquecer HOLs por industria.

---

## 🌐 Datos Universales (Todas las Industrias)

### Weather Source LLC: Frostbyte
- **Proveedor**: Weather Source
- **Costo**: FREE
- **Uso**: Correlacionar datos de negocio con clima
- **Tablas principales**:
  - `HISTORY_DAY`: Datos diarios por código postal
  - `FORECAST`: Pronóstico a 15 días
  - `POSTAL_CODES`: Catálogo de códigos postales
- **SQL de ejemplo**:
```sql
SELECT 
    DATE_VALID_STD,
    POSTAL_CODE,
    AVG_TEMPERATURE_AIR_2M_F,
    TOT_PRECIPITATION_IN
FROM WEATHER_SOURCE_LLC__FROSTBYTE.ONPOINT_ID.HISTORY_DAY
WHERE COUNTRY = 'MX'
LIMIT 100;
```

### IPinfo: IP Geolocation
- **Proveedor**: IPinfo
- **Costo**: FREE (versión limitada)
- **Uso**: Geolocalización de IPs de visitantes/usuarios
- **Tablas principales**:
  - `IPINFO_GEOLOC`: Mapeo IP a ubicación

### Cybersyn: Financial & Economic Essentials
- **Proveedor**: Cybersyn
- **Costo**: FREE
- **Uso**: Indicadores económicos, tasas, inflación
- **Tablas principales**:
  - `ECONOMIC_INDICATORS`: PIB, inflación, empleo
  - `INTEREST_RATES`: Tasas de interés
  - `EXCHANGE_RATES`: Tipos de cambio

---

## 🛒 Retail / E-commerce

### Knoema: Demographics
- **Proveedor**: Knoema
- **Costo**: FREE
- **Uso**: Datos demográficos para análisis de mercado
- **Campos útiles**: Población, edad, ingreso por región

### SafeGraph: Places
- **Proveedor**: SafeGraph
- **Costo**: FREE (sample)
- **Uso**: Datos de puntos de interés y foot traffic
- **Nota**: Versión sample, datos completos son de pago

### Recomendaciones de uso:
```sql
-- Correlacionar ventas con indicadores económicos
SELECT 
    v.MES,
    SUM(v.MONTO) AS VENTAS,
    e.CONSUMER_CONFIDENCE_INDEX
FROM TU_DB.ANALYTICS.VENTAS_MENSUALES v
LEFT JOIN CYBERSYN.PUBLIC.ECONOMIC_INDICATORS e
    ON v.MES = e.DATE
GROUP BY v.MES, e.CONSUMER_CONFIDENCE_INDEX;
```

---

## 🏭 Manufactura

### Cybersyn: Global Commodities
- **Proveedor**: Cybersyn
- **Costo**: FREE
- **Uso**: Precios de materias primas
- **Campos útiles**: Petróleo, metales, agrícolas

### Supply Chain Insights
- **Varios proveedores**: FREE samples disponibles
- **Uso**: Índices de cadena de suministro

### Recomendaciones de uso:
```sql
-- Correlacionar costos de producción con commodities
SELECT 
    DATE_TRUNC('MONTH', p.FECHA) AS MES,
    AVG(p.COSTO_PRODUCCION) AS COSTO_PROMEDIO,
    c.STEEL_PRICE_INDEX
FROM TU_DB.RAW.PRODUCCION p
LEFT JOIN CYBERSYN.PUBLIC.COMMODITY_PRICES c
    ON DATE_TRUNC('MONTH', p.FECHA) = c.DATE
GROUP BY DATE_TRUNC('MONTH', p.FECHA), c.STEEL_PRICE_INDEX;
```

---

## 💊 Healthcare / Pharma

### Starschema: COVID-19 Epidemiological Data
- **Proveedor**: Starschema
- **Costo**: FREE
- **Uso**: Datos epidemiológicos, casos, vacunación
- **Tablas principales**:
  - `JHU_COVID_19`: Casos por país/región

### CMS: Healthcare Provider Data
- **Proveedor**: CMS (Centers for Medicare & Medicaid Services)
- **Costo**: FREE
- **Uso**: Datos de proveedores de salud en USA

### Recomendaciones de uso:
```sql
-- Contextualizar datos de pharma con epidemiología
SELECT 
    v.FECHA,
    v.LINEA_TERAPEUTICA,
    SUM(v.MONTO) AS VENTAS,
    c.CASES_NEW
FROM TU_DB.ANALYTICS.VENTAS_PHARMA v
LEFT JOIN STARSCHEMA.COVID_19.JHU_COVID_19 c
    ON v.FECHA = c.DATE AND c.COUNTRY_REGION = 'Mexico'
GROUP BY v.FECHA, v.LINEA_TERAPEUTICA, c.CASES_NEW;
```

---

## 🏦 Servicios Financieros

### Cybersyn: SEC Filings
- **Proveedor**: Cybersyn
- **Costo**: FREE
- **Uso**: Reportes financieros de empresas públicas

### Knoema: World Bank Data
- **Proveedor**: Knoema
- **Costo**: FREE
- **Uso**: Indicadores macroeconómicos globales

### Exchange Rates
- **Varios proveedores**: FREE
- **Uso**: Tipos de cambio históricos

### Recomendaciones de uso:
```sql
-- Análisis de exposición cambiaria
SELECT 
    v.MONEDA,
    SUM(v.MONTO_USD) AS EXPOSICION,
    e.EXCHANGE_RATE
FROM TU_DB.RAW.TRANSACCIONES v
LEFT JOIN CYBERSYN.PUBLIC.EXCHANGE_RATES e
    ON v.FECHA = e.DATE AND v.MONEDA = e.CURRENCY
GROUP BY v.MONEDA, e.EXCHANGE_RATE;
```

---

## 📅 Calendarios y Fechas

### Public Holidays
- **Varios proveedores**: FREE
- **Uso**: Días festivos por país
- **Campos útiles**: Fecha, país, tipo de festivo

### Recomendaciones de uso:
```sql
-- Identificar impacto de festivos en ventas
SELECT 
    v.FECHA,
    CASE WHEN h.HOLIDAY IS NOT NULL THEN 'Festivo' ELSE 'Normal' END AS TIPO_DIA,
    SUM(v.MONTO) AS VENTAS
FROM TU_DB.RAW.VENTAS v
LEFT JOIN HOLIDAYS.PUBLIC.HOLIDAYS h
    ON v.FECHA = h.DATE AND h.COUNTRY = 'MX'
GROUP BY v.FECHA, TIPO_DIA;
```

---

## 🔍 Cómo Encontrar Datasets

### Paso 1: Acceder al Marketplace
```
Snowsight → Data Products → Marketplace
```

### Paso 2: Filtrar por precio
```
Filters → Price → Free
```

### Paso 3: Buscar por categoría
```
Categories → [Seleccionar industria]
```

### Paso 4: Obtener el dataset
```
Click en "Get" → Aceptar términos → Seleccionar roles
```

---

## ⚠️ Notas Importantes

1. **Disponibilidad**: Los datasets FREE pueden cambiar o dejar de estar disponibles
2. **Términos de uso**: Leer siempre los términos antes de usar en producción
3. **Regiones**: Algunos datasets solo están disponibles en ciertas regiones
4. **Actualizaciones**: La frecuencia de actualización varía por proveedor
5. **Trial**: Todos los datasets FREE funcionan en cuentas trial

---

## 📚 Plantilla de SQL para Integración

```sql
-- Template para integrar datos del Marketplace
CREATE OR REPLACE VIEW ANALYTICS.V_DATOS_ENRIQUECIDOS AS
SELECT 
    -- Tus datos
    t.*,
    
    -- Datos del marketplace
    m.CAMPO_MARKETPLACE_1,
    m.CAMPO_MARKETPLACE_2,
    
    -- Clasificación o cálculo
    CASE 
        WHEN m.CAMPO > X THEN 'Alto'
        ELSE 'Normal'
    END AS CLASIFICACION

FROM TU_DB.SCHEMA.TU_TABLA t
LEFT JOIN MARKETPLACE_DB.SCHEMA.MARKETPLACE_TABLE m
    ON t.CAMPO_JOIN = m.CAMPO_JOIN
    -- AND otras condiciones de join (fecha, región, etc.)
;
```
