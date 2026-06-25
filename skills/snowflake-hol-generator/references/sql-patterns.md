# SQL Patterns Reutilizables

Patrones SQL comunes para usar en HOLs de Snowflake.

---

## Patrones de Datos Sintéticos

### Generar IDs Secuenciales

```sql
-- Usando SEQ4() en generator
SELECT 
    SEQ4() AS id,
    'ITEM_' || SEQ4() AS item_code
FROM TABLE(GENERATOR(ROWCOUNT => 1000));
```

### Generar Fechas en Rango

```sql
-- Fechas de los últimos 365 días
SELECT 
    DATEADD(day, -SEQ4(), CURRENT_DATE()) AS fecha
FROM TABLE(GENERATOR(ROWCOUNT => 365))
WHERE fecha >= '2024-01-01';
```

### Selección Aleatoria de Valores

```sql
-- Seleccionar de una lista
SELECT 
    CASE MOD(SEQ4(), 4)
        WHEN 0 THEN 'Norte'
        WHEN 1 THEN 'Sur'
        WHEN 2 THEN 'Este'
        WHEN 3 THEN 'Oeste'
    END AS region
FROM TABLE(GENERATOR(ROWCOUNT => 100));

-- Usando ARRAY
SELECT 
    ARRAY_CONSTRUCT('Activo', 'Inactivo', 'Pendiente')[
        UNIFORM(0, 2, RANDOM())::INT
    ] AS status
FROM TABLE(GENERATOR(ROWCOUNT => 100));
```

### Generar Montos Realistas

```sql
-- Montos con distribución normal-ish
SELECT 
    ROUND(ABS(NORMAL(500, 150, RANDOM())), 2) AS monto_venta
FROM TABLE(GENERATOR(ROWCOUNT => 1000));

-- Montos con rangos específicos
SELECT 
    ROUND(UNIFORM(10.00, 500.00, RANDOM())::NUMERIC(10,2), 2) AS precio
FROM TABLE(GENERATOR(ROWCOUNT => 100));
```

### Generar Nombres Aleatorios

```sql
-- Nombres de array
WITH nombres AS (
    SELECT ARRAY_CONSTRUCT(
        'María', 'Juan', 'Carlos', 'Ana', 'Luis', 'Laura', 
        'Pedro', 'Sofía', 'Diego', 'Carmen'
    ) AS arr
),
apellidos AS (
    SELECT ARRAY_CONSTRUCT(
        'García', 'Rodríguez', 'Martínez', 'López', 'González',
        'Hernández', 'Pérez', 'Sánchez', 'Ramírez', 'Torres'
    ) AS arr
)
SELECT 
    n.arr[UNIFORM(0, 9, RANDOM())::INT] || ' ' || 
    a.arr[UNIFORM(0, 9, RANDOM())::INT] AS nombre_completo
FROM TABLE(GENERATOR(ROWCOUNT => 100)), nombres n, apellidos a;
```

---

## Patrones de Análisis

### Agregación con Window Functions

```sql
-- Totales móviles y comparación período anterior
SELECT 
    fecha,
    ventas,
    SUM(ventas) OVER (
        ORDER BY fecha 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS ventas_7d,
    LAG(ventas, 7) OVER (ORDER BY fecha) AS ventas_hace_7d,
    ROUND((ventas - LAG(ventas, 7) OVER (ORDER BY fecha)) / 
          NULLIF(LAG(ventas, 7) OVER (ORDER BY fecha), 0) * 100, 2) AS var_pct
FROM ventas_diarias;
```

### RFM Segmentation

```sql
-- Cálculo RFM completo
WITH rfm_scores AS (
    SELECT 
        cliente_id,
        DATEDIFF(day, MAX(fecha_compra), CURRENT_DATE()) AS recency,
        COUNT(DISTINCT orden_id) AS frequency,
        SUM(monto) AS monetary,
        NTILE(5) OVER (ORDER BY DATEDIFF(day, MAX(fecha_compra), CURRENT_DATE()) DESC) AS r_score,
        NTILE(5) OVER (ORDER BY COUNT(DISTINCT orden_id)) AS f_score,
        NTILE(5) OVER (ORDER BY SUM(monto)) AS m_score
    FROM transacciones
    GROUP BY cliente_id
)
SELECT 
    *,
    r_score || f_score || m_score AS rfm_segment,
    CASE 
        WHEN r_score >= 4 AND f_score >= 4 THEN 'Champions'
        WHEN r_score >= 4 AND f_score >= 2 THEN 'Loyal'
        WHEN r_score >= 3 AND f_score >= 3 THEN 'Potential Loyalist'
        WHEN r_score >= 4 AND f_score = 1 THEN 'New Customer'
        WHEN r_score <= 2 AND f_score >= 4 THEN 'At Risk'
        WHEN r_score <= 2 AND f_score <= 2 THEN 'Lost'
        ELSE 'Others'
    END AS customer_segment
FROM rfm_scores;
```

### Cohort Analysis

```sql
-- Retención por cohorte
WITH first_purchase AS (
    SELECT 
        cliente_id,
        DATE_TRUNC('month', MIN(fecha)) AS cohort_month
    FROM transacciones
    GROUP BY cliente_id
),
cohort_data AS (
    SELECT 
        f.cohort_month,
        DATEDIFF('month', f.cohort_month, DATE_TRUNC('month', t.fecha)) AS month_number,
        COUNT(DISTINCT t.cliente_id) AS users
    FROM transacciones t
    JOIN first_purchase f ON t.cliente_id = f.cliente_id
    GROUP BY 1, 2
)
SELECT 
    cohort_month,
    month_number,
    users,
    FIRST_VALUE(users) OVER (PARTITION BY cohort_month ORDER BY month_number) AS cohort_size,
    ROUND(users * 100.0 / FIRST_VALUE(users) OVER (PARTITION BY cohort_month ORDER BY month_number), 2) AS retention_pct
FROM cohort_data
ORDER BY cohort_month, month_number;
```

### Year-over-Year Comparison

```sql
-- Comparación YoY con varianza
SELECT 
    DATE_TRUNC('month', fecha) AS mes,
    SUM(ventas) AS ventas_actual,
    SUM(ventas) OVER (
        ORDER BY DATE_TRUNC('month', fecha)
        RANGE BETWEEN INTERVAL '1 YEAR' PRECEDING AND INTERVAL '1 YEAR' PRECEDING
    ) AS ventas_yoy,
    ROUND((SUM(ventas) - ventas_yoy) / NULLIF(ventas_yoy, 0) * 100, 2) AS varianza_pct
FROM ventas
GROUP BY 1
ORDER BY 1;
```

---

## Patrones Cortex AI

### Sentiment Analysis Batch

```sql
-- Análisis de sentimiento con categorización (2025+ syntax)
-- AI_SENTIMENT returns OBJECT, extract label with :categories[0]:sentiment
SELECT 
    id,
    comentario,
    AI_SENTIMENT(comentario):categories[0]:sentiment::VARCHAR AS sentiment_label,
    CASE AI_SENTIMENT(comentario):categories[0]:sentiment::VARCHAR
        WHEN 'positive' THEN 'Positivo'
        WHEN 'negative' THEN 'Negativo'
        ELSE 'Neutral'
    END AS clasificacion_sentimiento
FROM comentarios_clientes;
```

### Text Classification

```sql
-- Clasificar tickets de soporte
SELECT 
    ticket_id,
    descripcion,
    SNOWFLAKE.CORTEX.CLASSIFY_TEXT(
        descripcion,
        ['Facturación', 'Soporte Técnico', 'Ventas', 'Reclamo', 'Consulta General']
    ) AS categoria
FROM tickets_soporte;
```

### Summarization

```sql
-- Resumir textos largos
SELECT 
    documento_id,
    SNOWFLAKE.CORTEX.SUMMARIZE(contenido) AS resumen
FROM documentos
WHERE LENGTH(contenido) > 1000;
```

### LLM Completion

```sql
-- Generar respuestas con contexto
SELECT 
    pregunta,
    AI_COMPLETE(
        'mistral-large2',
        'Eres un asistente de servicio al cliente. Contexto: ' || contexto || 
        '. Pregunta: ' || pregunta || '. Responde de forma concisa.'
    )::VARCHAR AS respuesta
FROM preguntas_frecuentes;
```

### Extract Structured Data

```sql
-- Extraer entidades de texto
SELECT 
    texto,
    AI_COMPLETE(
        'mistral-large2',
        'Extrae las siguientes entidades del texto en formato JSON: 
         {nombre, email, telefono, empresa}. Texto: ' || texto
    )::VARCHAR AS entidades_json
FROM contactos_raw;
```

---

## Patrones Dynamic Tables

### Pipeline Básico

```sql
-- Dynamic Table con refresh automático
CREATE OR REPLACE DYNAMIC TABLE kpis_diarios
    TARGET_LAG = '1 hour'
    WAREHOUSE = compute_wh
AS
SELECT 
    DATE_TRUNC('day', fecha) AS dia,
    COUNT(*) AS total_transacciones,
    SUM(monto) AS total_ventas,
    AVG(monto) AS ticket_promedio,
    COUNT(DISTINCT cliente_id) AS clientes_unicos
FROM transacciones
GROUP BY 1;
```

### Cadena de Dynamic Tables

```sql
-- Bronze → Silver → Gold
CREATE OR REPLACE DYNAMIC TABLE bronze_ventas
    TARGET_LAG = '5 minutes'
    WAREHOUSE = compute_wh
AS
SELECT * FROM raw_ventas WHERE fecha >= DATEADD(day, -30, CURRENT_DATE());

CREATE OR REPLACE DYNAMIC TABLE silver_ventas
    TARGET_LAG = '10 minutes'
    WAREHOUSE = compute_wh
AS
SELECT 
    v.*,
    p.nombre AS producto_nombre,
    c.segmento AS cliente_segmento
FROM bronze_ventas v
JOIN productos p ON v.producto_id = p.id
JOIN clientes c ON v.cliente_id = c.id;

CREATE OR REPLACE DYNAMIC TABLE gold_kpis
    TARGET_LAG = '1 hour'
    WAREHOUSE = compute_wh
AS
SELECT 
    DATE_TRUNC('day', fecha) AS dia,
    cliente_segmento,
    SUM(monto) AS ventas,
    COUNT(*) AS transacciones
FROM silver_ventas
GROUP BY 1, 2;
```

---

## Patrones Time Travel

### Recuperar Datos Eliminados

```sql
-- Ver datos de hace 1 hora
SELECT * FROM mi_tabla AT(OFFSET => -3600);

-- Ver datos en timestamp específico
SELECT * FROM mi_tabla AT(TIMESTAMP => '2024-01-15 10:30:00'::TIMESTAMP);

-- Recuperar tabla eliminada
UNDROP TABLE mi_tabla_eliminada;
```

### Clonar con Time Travel

```sql
-- Clonar estado anterior
CREATE TABLE mi_tabla_backup CLONE mi_tabla AT(OFFSET => -86400);

-- Clonar estado en timestamp
CREATE TABLE mi_tabla_snapshot CLONE mi_tabla AT(TIMESTAMP => '2024-01-15 00:00:00');
```

### Comparar Cambios

```sql
-- Ver qué cambió entre dos puntos en el tiempo
SELECT 
    'Añadido' AS cambio,
    actual.*
FROM mi_tabla actual
LEFT JOIN mi_tabla AT(OFFSET => -3600) anterior 
    ON actual.id = anterior.id
WHERE anterior.id IS NULL

UNION ALL

SELECT 
    'Eliminado' AS cambio,
    anterior.*
FROM mi_tabla AT(OFFSET => -3600) anterior
LEFT JOIN mi_tabla actual 
    ON anterior.id = actual.id
WHERE actual.id IS NULL;
```

---

## Patrones de Performance

### Clustering

```sql
-- Definir clustering key
ALTER TABLE ventas CLUSTER BY (region, fecha);

-- Verificar clustering
SELECT SYSTEM$CLUSTERING_INFORMATION('ventas', '(region, fecha)');
```

### Search Optimization

```sql
-- Habilitar para búsquedas puntuales
ALTER TABLE clientes ADD SEARCH OPTIMIZATION ON EQUALITY(email, telefono);
```

### Query Tagging

```sql
-- Etiquetar queries para análisis
ALTER SESSION SET QUERY_TAG = 'HOL_DEMO_VENTAS';

-- Luego analizar
SELECT query_tag, COUNT(*) 
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE query_tag LIKE 'HOL_%'
GROUP BY 1;
```

---

## Patrones de Seguridad

### Row Access Policy

```sql
-- Crear política de acceso por región
CREATE OR REPLACE ROW ACCESS POLICY region_policy AS (region VARCHAR)
RETURNS BOOLEAN ->
    CURRENT_ROLE() = 'ADMIN' OR 
    region = CURRENT_USER();

-- Aplicar a tabla
ALTER TABLE ventas ADD ROW ACCESS POLICY region_policy ON (region);
```

### Masking Policy

```sql
-- Enmascarar datos sensibles
CREATE OR REPLACE MASKING POLICY email_mask AS (val STRING)
RETURNS STRING ->
    CASE 
        WHEN CURRENT_ROLE() IN ('ADMIN') THEN val
        ELSE REGEXP_REPLACE(val, '.+@', '***@')
    END;

-- Aplicar
ALTER TABLE clientes MODIFY COLUMN email SET MASKING POLICY email_mask;
```

---

## Snippets Útiles

### Verificar Cuenta Trial

```sql
-- Verificar tipo de cuenta
SELECT SYSTEM$GET_SNOWFLAKE_PLATFORM_INFO();
```

### Limpiar Objetos de Demo

```sql
-- Cleanup completo
DROP DATABASE IF EXISTS HOL_DEMO CASCADE;
DROP WAREHOUSE IF EXISTS HOL_WH;
```

### Verificar Costos de Query

```sql
-- Ver créditos consumidos
SELECT 
    query_id,
    query_text,
    total_elapsed_time/1000 AS seconds,
    credits_used_cloud_services
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD(hour, -1, CURRENT_TIMESTAMP())
ORDER BY credits_used_cloud_services DESC
LIMIT 10;
```
