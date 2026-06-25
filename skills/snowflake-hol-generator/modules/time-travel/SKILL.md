# Sub-Skill: Time Travel & Cloning

## Metadata
- **Parent**: snowflake-hol-generator
- **Name**: modules/time-travel
- **Obligatorio**: ❌ No
- **Duración**: ~8 minutos
- **Dependencias**: Setup completado, datos cargados

---

## 🎯 Objetivo

Demostrar capacidades únicas de Snowflake:
- Acceso a datos históricos (Time Travel)
- Clonación instantánea sin costo de storage
- Recuperación de datos eliminados

---

## ✅ Compatibilidad Trial

| Característica | Trial | Notas |
|---------------|-------|-------|
| Time Travel | ✅ | Hasta 1 día en trial (24h) |
| Clone Tables | ✅ | Zero-copy cloning |
| Clone Schemas | ✅ | Zero-copy cloning |
| Clone Databases | ✅ | Zero-copy cloning |
| UNDROP | ✅ | Recuperar objetos eliminados |

> **Nota**: Cuentas Enterprise tienen hasta 90 días de Time Travel.

---

## Paso 1: Consultar Datos Históricos

```sql
-- ===========================================
-- TIME TRAVEL: CONSULTAR DATOS DEL PASADO
-- ===========================================

USE DATABASE [CLIENTE_HOL];
USE WAREHOUSE [CLIENTE]_WH;

-- Ver datos actuales
SELECT COUNT(*) AS REGISTROS_ACTUALES FROM RAW.VENTAS;

-- Ver datos de hace 10 minutos
SELECT COUNT(*) AS REGISTROS_HACE_10MIN 
FROM RAW.VENTAS AT(OFFSET => -60*10);

-- Ver datos en un timestamp específico
SELECT COUNT(*) AS REGISTROS_TIMESTAMP
FROM RAW.VENTAS AT(TIMESTAMP => '2024-01-15 10:00:00'::TIMESTAMP);

-- Ver datos antes de un statement específico
SELECT COUNT(*) AS REGISTROS_ANTES_STATEMENT
FROM RAW.VENTAS BEFORE(STATEMENT => '<query_id>');
```

---

## Paso 2: Comparar Cambios en el Tiempo

```sql
-- ===========================================
-- COMPARAR DATOS: ANTES VS AHORA
-- ===========================================

-- Primero, hagamos un cambio para demostrar
-- (Guardemos el query_id para usarlo después)
UPDATE RAW.VENTAS 
SET MONTO = MONTO * 1.1 
WHERE FECHA >= '2024-01-01';

-- Comparar totales antes y después
WITH ANTES AS (
    SELECT SUM(MONTO) AS TOTAL_ANTES
    FROM RAW.VENTAS AT(OFFSET => -60*5)  -- Hace 5 minutos
),
AHORA AS (
    SELECT SUM(MONTO) AS TOTAL_AHORA
    FROM RAW.VENTAS
)
SELECT 
    a.TOTAL_ANTES,
    n.TOTAL_AHORA,
    n.TOTAL_AHORA - a.TOTAL_ANTES AS DIFERENCIA,
    ROUND((n.TOTAL_AHORA - a.TOTAL_ANTES) / a.TOTAL_ANTES * 100, 2) AS PCT_CAMBIO
FROM ANTES a, AHORA n;

-- Ver registros que cambiaron
SELECT 
    actual.ID_VENTA,
    historico.MONTO AS MONTO_ANTERIOR,
    actual.MONTO AS MONTO_ACTUAL,
    actual.MONTO - historico.MONTO AS DIFERENCIA
FROM RAW.VENTAS actual
JOIN RAW.VENTAS AT(OFFSET => -60*5) historico 
    ON actual.ID_VENTA = historico.ID_VENTA
WHERE actual.MONTO != historico.MONTO
LIMIT 10;
```

---

## Paso 3: Restaurar Datos Modificados

```sql
-- ===========================================
-- RESTAURAR DATOS A UN PUNTO ANTERIOR
-- ===========================================

-- Opción 1: Crear tabla con datos históricos
CREATE OR REPLACE TABLE RAW.VENTAS_BACKUP AS
SELECT * FROM RAW.VENTAS AT(OFFSET => -60*10);

-- Opción 2: Restaurar in-place (reemplazar datos actuales)
CREATE OR REPLACE TABLE RAW.VENTAS AS
SELECT * FROM RAW.VENTAS AT(OFFSET => -60*10);

-- Opción 3: Restaurar solo ciertos registros
MERGE INTO RAW.VENTAS actual
USING (SELECT * FROM RAW.VENTAS AT(OFFSET => -60*10)) historico
ON actual.ID_VENTA = historico.ID_VENTA
WHEN MATCHED AND actual.FECHA >= '2024-01-01' THEN
    UPDATE SET actual.MONTO = historico.MONTO;
```

---

## Paso 4: Clonación Zero-Copy

```sql
-- ===========================================
-- CLONACIÓN INSTANTÁNEA (ZERO-COPY)
-- ===========================================

-- Clonar una tabla (instantáneo, sin costo de storage)
CREATE TABLE RAW.VENTAS_CLONE CLONE RAW.VENTAS;

-- Clonar un schema completo
CREATE SCHEMA DEV CLONE RAW;

-- Clonar una base de datos completa
CREATE DATABASE [CLIENTE_HOL]_DEV CLONE [CLIENTE_HOL];

-- Clonar con time travel (snapshot histórico)
CREATE TABLE RAW.VENTAS_AYER CLONE RAW.VENTAS AT(OFFSET => -60*60*24);

-- Verificar que son idénticas
SELECT 
    'ORIGINAL' AS FUENTE, COUNT(*) AS REGISTROS FROM RAW.VENTAS
UNION ALL
SELECT 
    'CLONE' AS FUENTE, COUNT(*) AS REGISTROS FROM RAW.VENTAS_CLONE;
```

---

## Paso 5: Recuperar Objetos Eliminados (UNDROP)

```sql
-- ===========================================
-- RECUPERAR OBJETOS ELIMINADOS
-- ===========================================

-- Eliminar una tabla (para demostrar)
DROP TABLE RAW.VENTAS_CLONE;

-- Verificar que no existe
SHOW TABLES LIKE 'VENTAS_CLONE' IN SCHEMA RAW;

-- ¡Recuperarla!
UNDROP TABLE RAW.VENTAS_CLONE;

-- Verificar que volvió
SELECT COUNT(*) FROM RAW.VENTAS_CLONE;

-- También funciona con schemas y databases
-- DROP SCHEMA DEV;
-- UNDROP SCHEMA DEV;
-- DROP DATABASE [CLIENTE_HOL]_DEV;
-- UNDROP DATABASE [CLIENTE_HOL]_DEV;
```

---

## Paso 6: Auditoría con Time Travel

```sql
-- ===========================================
-- AUDITORÍA: QUIÉN MODIFICÓ QUÉ Y CUÁNDO
-- ===========================================

-- Ver historial de queries en la tabla
SELECT 
    QUERY_ID,
    QUERY_TEXT,
    USER_NAME,
    START_TIME,
    ROWS_PRODUCED,
    ROWS_UPDATED,
    ROWS_DELETED
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY())
WHERE QUERY_TEXT ILIKE '%VENTAS%'
    AND QUERY_TYPE IN ('UPDATE', 'DELETE', 'INSERT', 'MERGE')
ORDER BY START_TIME DESC
LIMIT 20;

-- Crear vista de cambios diarios
CREATE OR REPLACE VIEW ANALYTICS.V_CAMBIOS_DIARIOS AS
SELECT 
    DATE_TRUNC('DAY', START_TIME) AS DIA,
    COUNT(*) AS TOTAL_OPERACIONES,
    SUM(ROWS_UPDATED) AS FILAS_ACTUALIZADAS,
    SUM(ROWS_DELETED) AS FILAS_ELIMINADAS,
    SUM(ROWS_INSERTED) AS FILAS_INSERTADAS
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY())
WHERE QUERY_TYPE IN ('UPDATE', 'DELETE', 'INSERT', 'MERGE')
GROUP BY DATE_TRUNC('DAY', START_TIME)
ORDER BY DIA DESC;
```

---

## Diagrama: Time Travel & Clone

```
           TIEMPO
             │
    ─────────┼─────────────────────────────►
             │
   T-24h     │    T-1h      T-10m      AHORA
     │       │      │          │         │
     ▼       ▼      ▼          ▼         ▼
  ┌─────┐ ┌─────┐ ┌─────┐  ┌─────┐  ┌─────┐
  │ v1  │ │ v2  │ │ v3  │  │ v4  │  │ v5  │
  └─────┘ └─────┘ └─────┘  └─────┘  └─────┘
     │                         │
     │  AT(OFFSET => -86400)   │  CLONE
     │                         │
     ▼                         ▼
  ┌─────────────┐       ┌─────────────┐
  │ VENTAS_AYER │       │ VENTAS_DEV  │
  │ (snapshot)  │       │ (zero-copy) │
  └─────────────┘       └─────────────┘
```

---

## Contenido HTML para el HOL

```html
<h2>⏰ Time Travel y Clonación</h2>

<p>Snowflake guarda automáticamente el historial de tus datos:</p>

<div class="card-grid">
    <div class="card">
        <div class="card-icon">⏪</div>
        <h4>Time Travel</h4>
        <p>Consulta datos como estaban en cualquier momento del pasado (hasta 90 días)</p>
        <code>SELECT * FROM tabla AT(OFFSET => -3600)</code>
    </div>
    <div class="card">
        <div class="card-icon">📋</div>
        <h4>Zero-Copy Clone</h4>
        <p>Crea copias instantáneas sin duplicar storage - ideal para desarrollo/testing</p>
        <code>CREATE TABLE copia CLONE original</code>
    </div>
    <div class="card">
        <div class="card-icon">🔄</div>
        <h4>UNDROP</h4>
        <p>Recupera tablas, schemas o databases eliminados accidentalmente</p>
        <code>UNDROP TABLE mi_tabla</code>
    </div>
</div>

<div class="info-box warning">
    <span class="info-icon">⚠️</span>
    <div class="info-content">
        <h4>Límite en Cuentas Trial</h4>
        <p>Las cuentas trial tienen Time Travel limitado a 24 horas. 
        Para retención extendida (hasta 90 días), se requiere edición Enterprise.</p>
    </div>
</div>
```

---

## Siguiente Módulo

- **Marketplace**: [../marketplace/SKILL.md](../marketplace/SKILL.md)
- **Streamlit**: [../streamlit/SKILL.md](../streamlit/SKILL.md)
