# Sub-Skill: Dynamic Tables

## Metadata
- **Parent**: snowflake-hol-generator
- **Name**: modules/dynamic-tables
- **Obligatorio**: ❌ No
- **Duración**: ~8 minutos
- **Dependencias**: Setup completado, datos cargados

---

## 🎯 Objetivo

Demostrar pipelines de datos declarativos con:
- Transformaciones automáticas
- Actualización incremental
- Sin programar jobs

---

## ✅ Compatibilidad Trial

| Característica | Trial | Notas |
|---------------|-------|-------|
| Dynamic Tables | ✅ | Funciona completamente |
| TARGET_LAG | ✅ | Mínimo 1 minute |
| Refresh History | ✅ | Via INFORMATION_SCHEMA |
| DOWNSTREAM mode | ✅ | Para cascadas |

---

## Paso 1: Dynamic Table Básica

```sql
-- ===========================================
-- DYNAMIC TABLE BÁSICA CON AGREGACIONES
-- ===========================================

USE DATABASE [CLIENTE_HOL];
USE WAREHOUSE [CLIENTE]_WH;

-- Crear Dynamic Table con resumen diario
CREATE OR REPLACE DYNAMIC TABLE ANALYTICS.DT_RESUMEN_DIARIO
    TARGET_LAG = '1 minute'
    WAREHOUSE = [CLIENTE]_WH
AS
SELECT 
    DATE_TRUNC('DAY', FECHA) AS DIA,
    COUNT(*) AS TOTAL_TRANSACCIONES,
    SUM(MONTO) AS INGRESOS_TOTALES,
    AVG(MONTO) AS TICKET_PROMEDIO,
    COUNT(DISTINCT ID_CLIENTE) AS CLIENTES_UNICOS
FROM RAW.[TABLA_TRANSACCIONES]
GROUP BY DATE_TRUNC('DAY', FECHA);

-- Verificar creación
SELECT * FROM ANALYTICS.DT_RESUMEN_DIARIO 
ORDER BY DIA DESC 
LIMIT 10;
```

---

## Paso 2: Cascada de Dynamic Tables

```sql
-- ===========================================
-- CASCADA: DIARIO → MENSUAL → TRIMESTRAL
-- ===========================================

-- Nivel 2: Agregación mensual (depende de diaria)
CREATE OR REPLACE DYNAMIC TABLE ANALYTICS.DT_RESUMEN_MENSUAL
    TARGET_LAG = DOWNSTREAM
    WAREHOUSE = [CLIENTE]_WH
AS
SELECT 
    DATE_TRUNC('MONTH', DIA) AS MES,
    SUM(TOTAL_TRANSACCIONES) AS TOTAL_TRANSACCIONES,
    SUM(INGRESOS_TOTALES) AS INGRESOS_TOTALES,
    ROUND(AVG(TICKET_PROMEDIO), 2) AS TICKET_PROMEDIO,
    SUM(CLIENTES_UNICOS) AS CLIENTES_UNICOS,
    
    -- Cálculos adicionales
    ROUND(SUM(INGRESOS_TOTALES) / NULLIF(SUM(TOTAL_TRANSACCIONES), 0), 2) AS INGRESO_POR_TXN
    
FROM ANALYTICS.DT_RESUMEN_DIARIO
GROUP BY DATE_TRUNC('MONTH', DIA);

-- Nivel 3: Agregación trimestral (depende de mensual)
CREATE OR REPLACE DYNAMIC TABLE ANALYTICS.DT_RESUMEN_TRIMESTRAL
    TARGET_LAG = DOWNSTREAM
    WAREHOUSE = [CLIENTE]_WH
AS
SELECT 
    DATE_TRUNC('QUARTER', MES) AS TRIMESTRE,
    SUM(TOTAL_TRANSACCIONES) AS TOTAL_TRANSACCIONES,
    SUM(INGRESOS_TOTALES) AS INGRESOS_TOTALES,
    ROUND(AVG(TICKET_PROMEDIO), 2) AS TICKET_PROMEDIO,
    
    -- YoY si hay datos históricos
    YEAR(MES) AS ANIO,
    QUARTER(MES) AS Q
    
FROM ANALYTICS.DT_RESUMEN_MENSUAL
GROUP BY DATE_TRUNC('QUARTER', MES), YEAR(MES), QUARTER(MES);

-- Ver la cascada
SELECT * FROM ANALYTICS.DT_RESUMEN_TRIMESTRAL ORDER BY TRIMESTRE DESC;
```

---

## Paso 3: Dynamic Table con Joins

```sql
-- ===========================================
-- DYNAMIC TABLE CON ENRIQUECIMIENTO
-- ===========================================

CREATE OR REPLACE DYNAMIC TABLE ANALYTICS.DT_VENTAS_ENRIQUECIDAS
    TARGET_LAG = '5 minutes'
    WAREHOUSE = [CLIENTE]_WH
AS
SELECT 
    -- Datos de venta
    v.ID_VENTA,
    v.FECHA,
    v.CANTIDAD,
    v.MONTO,
    
    -- Datos de producto
    p.NOMBRE_PRODUCTO,
    p.CATEGORIA,
    p.PRECIO_UNITARIO,
    
    -- Datos de cliente
    c.NOMBRE_CLIENTE,
    c.SEGMENTO,
    c.REGION,
    
    -- Cálculos
    v.CANTIDAD * p.PRECIO_UNITARIO AS VALOR_LISTA,
    v.MONTO AS VALOR_VENTA,
    ROUND((v.CANTIDAD * p.PRECIO_UNITARIO - v.MONTO) / NULLIF(v.CANTIDAD * p.PRECIO_UNITARIO, 0) * 100, 2) AS DESCUENTO_PCT
    
FROM RAW.VENTAS v
JOIN RAW.PRODUCTOS p ON v.ID_PRODUCTO = p.ID_PRODUCTO
JOIN RAW.CLIENTES c ON v.ID_CLIENTE = c.ID_CLIENTE;
```

---

## Paso 4: Monitoreo de Dynamic Tables

```sql
-- ===========================================
-- MONITOREO Y ESTADO DE DYNAMIC TABLES
-- ===========================================

-- Ver todas las Dynamic Tables
SHOW DYNAMIC TABLES IN SCHEMA ANALYTICS;

-- Ver historial de refresh
SELECT 
    NAME,
    STATE,
    REFRESH_START_TIME,
    REFRESH_END_TIME,
    TIMEDIFF('second', REFRESH_START_TIME, REFRESH_END_TIME) AS DURACION_SEGUNDOS,
    STATISTICS:numInsertedRows::INT AS FILAS_INSERTADAS
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(
    NAME => 'ANALYTICS.DT_RESUMEN_DIARIO'
))
ORDER BY REFRESH_START_TIME DESC
LIMIT 10;

-- Dashboard de estado
SELECT 
    NAME,
    SCHEDULING_STATE,
    LAST_COMPLETED_REFRESH_STATE,
    DATA_TIMESTAMP,
    TIMEDIFF('minute', DATA_TIMESTAMP, CURRENT_TIMESTAMP()) AS MINUTOS_DESDE_REFRESH
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_GRAPH_HISTORY())
WHERE SCHEMA_NAME = 'ANALYTICS'
ORDER BY NAME;
```

---

## Paso 5: Refresh Manual (Opcional)

```sql
-- ===========================================
-- FORZAR REFRESH MANUAL
-- ===========================================

-- Refresh inmediato de una Dynamic Table
ALTER DYNAMIC TABLE ANALYTICS.DT_RESUMEN_DIARIO REFRESH;

-- Verificar que se actualizó
SELECT 
    MAX(DIA) AS ULTIMO_DIA,
    COUNT(*) AS TOTAL_FILAS
FROM ANALYTICS.DT_RESUMEN_DIARIO;

-- Suspender/Reanudar (útil para mantenimiento)
ALTER DYNAMIC TABLE ANALYTICS.DT_RESUMEN_DIARIO SUSPEND;
-- ... hacer cambios ...
ALTER DYNAMIC TABLE ANALYTICS.DT_RESUMEN_DIARIO RESUME;
```

---

## Diagrama de Flujo

```
┌──────────────────┐
│   RAW.VENTAS     │
│   RAW.PRODUCTOS  │
│   RAW.CLIENTES   │
└────────┬─────────┘
         │
         ▼ (cada 1 min)
┌──────────────────────────┐
│  DT_VENTAS_ENRIQUECIDAS  │
└────────────┬─────────────┘
             │
             ▼ (cada 1 min)
    ┌────────────────────┐
    │  DT_RESUMEN_DIARIO │
    └─────────┬──────────┘
              │
              ▼ (DOWNSTREAM)
     ┌────────────────────┐
     │ DT_RESUMEN_MENSUAL │
     └─────────┬──────────┘
               │
               ▼ (DOWNSTREAM)
   ┌───────────────────────┐
   │ DT_RESUMEN_TRIMESTRAL │
   └───────────────────────┘
```

---

## Contenido HTML para el HOL

```html
<h2>⚡ Pipelines Declarativos con Dynamic Tables</h2>

<p>Las Dynamic Tables transforman tus datos automáticamente sin programar jobs:</p>

<div class="info-box tip">
    <span class="info-icon">🔄</span>
    <div class="info-content">
        <h4>¿Qué son las Dynamic Tables?</h4>
        <p>Son tablas que se actualizan automáticamente cuando cambian los datos fuente. 
        Tú defines QUÉ quieres (el SELECT), Snowflake se encarga del CUÁNDO y CÓMO.</p>
    </div>
</div>

<h3>Beneficios</h3>
<ul>
    <li>✅ <strong>Declarativo</strong>: Define la transformación, no el proceso</li>
    <li>✅ <strong>Incremental</strong>: Solo procesa datos nuevos/modificados</li>
    <li>✅ <strong>Automático</strong>: Sin orquestar jobs ni manejar dependencias</li>
    <li>✅ <strong>Eficiente</strong>: Optimizado por Snowflake</li>
</ul>

<h3>TARGET_LAG</h3>
<table>
    <tr><th>Valor</th><th>Significado</th></tr>
    <tr><td><code>'1 minute'</code></td><td>Actualizar máximo cada minuto</td></tr>
    <tr><td><code>'1 hour'</code></td><td>Actualizar máximo cada hora</td></tr>
    <tr><td><code>DOWNSTREAM</code></td><td>Actualizar cuando cambien las tablas padre</td></tr>
</table>
```

---

## Siguiente Módulo

- **Time Travel**: [../time-travel/SKILL.md](../time-travel/SKILL.md)
- **Streamlit**: [../streamlit/SKILL.md](../streamlit/SKILL.md)
