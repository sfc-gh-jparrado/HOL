# Sub-Skill: Versioned Semantic Layer

## Metadata
- **Parent**: snowflake-hol-generator
- **Name**: modules/versioned-semantic-layer
- **Obligatorio**: No
- **Duración**: ~20 minutos
- **Dependencias**: Setup completado, Semantic View base creada

---

## Objetivo

Demostrar cómo construir un semantic layer versionado con:
- Control de cambios sobre definiciones de métricas
- Despliegue CI/CD automatizado con TASKs
- Promoción entre ambientes (dev → staging → prod)
- Eliminación de la ambigüedad en definiciones de métricas empresariales

---

## Compatibilidad Trial

| Característica | Trial | Notas |
|---------------|-------|-------|
| Semantic Views | ✅ | Funciona completamente |
| Multi-schema (DEV/STAGING/PROD) | ✅ | Simula multi-ambiente en misma DB |
| Multi-database | ✅ | Para separación real de ambientes |
| Git Integration (Workspaces) | ⚠️ | Requiere Enterprise+ para Snowflake Workspaces completas |
| TASKs (CI/CD) | ✅ | Funciona completamente |
| GET_DDL() | ✅ | Para extraer definiciones |

> **Nota Trial**: Para cuentas trial, se simula multi-ambiente usando 3 schemas (DEV, STAGING, PROD) dentro de la misma database. En Enterprise+, se recomienda usar databases separadas. Los ejemplos marcan claramente cuándo una feature requiere Enterprise+.

---

## Paso 1: Arquitectura Multi-Ambiente

```sql
-- ===========================================
-- ARQUITECTURA MULTI-AMBIENTE PARA SEMANTIC LAYER
-- ===========================================

USE DATABASE [CLIENTE_HOL];
USE WAREHOUSE [CLIENTE]_WH;

-- Crear schemas para simular ambientes (Trial)
-- En Enterprise+: usar databases separadas
CREATE SCHEMA IF NOT EXISTS DEV
    COMMENT = 'Ambiente de desarrollo - métricas en construcción';

CREATE SCHEMA IF NOT EXISTS STAGING
    COMMENT = 'Ambiente de validación - métricas pre-producción';

CREATE SCHEMA IF NOT EXISTS PROD
    COMMENT = 'Ambiente de producción - métricas oficiales';

-- Tabla de registro de promociones entre ambientes
CREATE OR REPLACE TABLE PROD.PROMOTION_LOG (
    PROMOTION_ID NUMBER AUTOINCREMENT,
    OBJECT_NAME VARCHAR(256),
    FROM_ENV VARCHAR(20),
    TO_ENV VARCHAR(20),
    PROMOTED_BY VARCHAR(128) DEFAULT CURRENT_USER(),
    PROMOTED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    APPROVAL_STATUS VARCHAR(20) DEFAULT 'PENDING',
    APPROVED_BY VARCHAR(128),
    APPROVED_AT TIMESTAMP_NTZ,
    ROLLBACK_DDL VARCHAR(16777216),
    NOTES VARCHAR(4096)
);

-- Verificar estructura
SHOW SCHEMAS IN DATABASE [CLIENTE_HOL];
```

---

## Paso 2: Definir Métricas en DEV

```sql
-- ===========================================
-- SEMANTIC VIEW INICIAL EN AMBIENTE DEV
-- ===========================================

USE SCHEMA DEV;

-- Datos base para las métricas (tabla de hechos)
CREATE OR REPLACE TABLE DEV.ORDERS (
    ORDER_ID NUMBER,
    ORDER_DATE DATE,
    CUSTOMER_ID NUMBER,
    PRODUCT_ID NUMBER,
    AMOUNT NUMBER(12,2),
    COST NUMBER(12,2),
    STATUS VARCHAR(20),
    REGION VARCHAR(50),
    CHANNEL VARCHAR(30)
);

-- Insertar datos de ejemplo
INSERT INTO DEV.ORDERS 
SELECT 
    SEQ4() AS ORDER_ID,
    DATEADD('day', -UNIFORM(0, 365, RANDOM()), CURRENT_DATE()) AS ORDER_DATE,
    UNIFORM(1, 1000, RANDOM()) AS CUSTOMER_ID,
    UNIFORM(1, 50, RANDOM()) AS PRODUCT_ID,
    ROUND(UNIFORM(10, 5000, RANDOM())::NUMBER(12,2), 2) AS AMOUNT,
    ROUND(UNIFORM(5, 3000, RANDOM())::NUMBER(12,2), 2) AS COST,
    CASE UNIFORM(1, 5, RANDOM())
        WHEN 1 THEN 'completed'
        WHEN 2 THEN 'pending'
        WHEN 3 THEN 'cancelled'
        WHEN 4 THEN 'refunded'
        ELSE 'completed'
    END AS STATUS,
    CASE UNIFORM(1, 4, RANDOM())
        WHEN 1 THEN 'North America'
        WHEN 2 THEN 'Europe'
        WHEN 3 THEN 'LATAM'
        ELSE 'APAC'
    END AS REGION,
    CASE UNIFORM(1, 3, RANDOM())
        WHEN 1 THEN 'Online'
        WHEN 2 THEN 'In-Store'
        ELSE 'Partner'
    END AS CHANNEL
FROM TABLE(GENERATOR(ROWCOUNT => 10000));

-- Copiar datos a STAGING y PROD (mismos datos base)
CREATE OR REPLACE TABLE STAGING.ORDERS CLONE DEV.ORDERS;
CREATE OR REPLACE TABLE PROD.ORDERS CLONE DEV.ORDERS;

-- Semantic View v1 en DEV
-- Revenue v1: SUM de todos los montos (sin filtro de estado)
CREATE OR REPLACE SEMANTIC VIEW DEV.SV_FINANCIAL_METRICS
    COMMENT = 'Métricas financieras v1 - Definiciones iniciales'
AS
TABLES (
    ORDERS AS [CLIENTE_HOL].DEV.ORDERS
)
FACTS (
    ORDERS.AMOUNT AS ORDERS.AMOUNT
        WITH SYNONYMS = ('monto', 'valor venta', 'importe')
        COMMENT = 'Monto bruto de la orden sin filtro de estado',
    ORDERS.COST AS ORDERS.COST
        WITH SYNONYMS = ('costo', 'costo producto')
        COMMENT = 'Costo asociado a la orden'
)
DIMENSIONS (
    ORDERS.ORDER_DATE AS ORDERS.ORDER_DATE
        WITH SYNONYMS = ('fecha', 'fecha orden', 'fecha pedido')
        COMMENT = 'Fecha en que se realizó la orden',
    ORDERS.STATUS AS ORDERS.STATUS
        WITH SYNONYMS = ('estado', 'estado orden')
        COMMENT = 'Estado actual de la orden: completed, pending, cancelled, refunded',
    ORDERS.REGION AS ORDERS.REGION
        WITH SYNONYMS = ('región', 'zona geográfica')
        COMMENT = 'Región geográfica del pedido',
    ORDERS.CHANNEL AS ORDERS.CHANNEL
        WITH SYNONYMS = ('canal', 'canal de venta')
        COMMENT = 'Canal por el que se realizó la venta'
)
METRICS (
    REVENUE AS SUM(ORDERS.AMOUNT)
        WITH SYNONYMS = ('ingresos', 'ventas totales', 'facturación')
        COMMENT = 'v1: Ingresos totales = SUM(amount) de todas las órdenes sin filtro',
    TOTAL_COST AS SUM(ORDERS.COST)
        WITH SYNONYMS = ('costo total', 'gastos')
        COMMENT = 'v1: Costo total = SUM(cost)',
    GROSS_MARGIN AS SUM(ORDERS.AMOUNT) - SUM(ORDERS.COST)
        WITH SYNONYMS = ('margen bruto', 'ganancia bruta')
        COMMENT = 'v1: Margen bruto = Revenue - Costo Total'
);

-- Registro de métricas: tabla de versionamiento
CREATE OR REPLACE TABLE DEV.METRICS_REGISTRY (
    REGISTRY_ID NUMBER AUTOINCREMENT,
    METRIC_NAME VARCHAR(256),
    VERSION VARCHAR(10),
    DEFINITION VARCHAR(4096),
    BUSINESS_RULE VARCHAR(4096),
    SEMANTIC_VIEW_NAME VARCHAR(256),
    CREATED_BY VARCHAR(128) DEFAULT CURRENT_USER(),
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    STATUS VARCHAR(20) DEFAULT 'dev',
    PREVIOUS_VERSION VARCHAR(10),
    CHANGE_REASON VARCHAR(4096)
);

-- Registrar métricas v1
INSERT INTO DEV.METRICS_REGISTRY (METRIC_NAME, VERSION, DEFINITION, BUSINESS_RULE, SEMANTIC_VIEW_NAME, STATUS)
VALUES 
    ('REVENUE', 'v1', 'SUM(ORDERS.AMOUNT)', 'Suma de todos los montos sin filtro de estado', 'SV_FINANCIAL_METRICS', 'dev'),
    ('TOTAL_COST', 'v1', 'SUM(ORDERS.COST)', 'Suma de todos los costos', 'SV_FINANCIAL_METRICS', 'dev'),
    ('GROSS_MARGIN', 'v1', 'SUM(ORDERS.AMOUNT) - SUM(ORDERS.COST)', 'Revenue menos costo total', 'SV_FINANCIAL_METRICS', 'dev');

-- Verificar
DESCRIBE SEMANTIC VIEW DEV.SV_FINANCIAL_METRICS;
SELECT * FROM DEV.METRICS_REGISTRY ORDER BY CREATED_AT;
```

---

## Paso 3: Versionamiento de Métricas

```sql
-- ===========================================
-- VERSIONAMIENTO: CAMBIO DE REGLA DE NEGOCIO
-- ===========================================

-- ANTES: Revenue v1 = SUM(amount) -- todos los estados
-- DESPUÉS: Revenue v2 = SUM(amount) WHERE status = 'completed'
--
-- Motivo: El negocio decidió que solo las órdenes completadas
-- cuentan como ingreso real (excluir pending, cancelled, refunded)

-- Ver métrica ANTES del cambio
SELECT 
    'v1 - Sin filtro' AS VERSION,
    SUM(AMOUNT) AS REVENUE
FROM DEV.ORDERS;

-- Ver métrica DESPUÉS del cambio (preview)
SELECT 
    'v2 - Solo completed' AS VERSION,
    SUM(AMOUNT) AS REVENUE
FROM DEV.ORDERS
WHERE STATUS = 'completed';

-- Registrar el cambio en el registry ANTES de aplicarlo
INSERT INTO DEV.METRICS_REGISTRY 
    (METRIC_NAME, VERSION, DEFINITION, BUSINESS_RULE, SEMANTIC_VIEW_NAME, STATUS, PREVIOUS_VERSION, CHANGE_REASON)
VALUES 
    ('REVENUE', 'v2', 
     'SUM(ORDERS.AMOUNT) WHERE ORDERS.STATUS = ''completed''', 
     'Solo órdenes con estado completed cuentan como ingreso real',
     'SV_FINANCIAL_METRICS', 'dev', 'v1',
     'Decisión del CFO: excluir pending/cancelled/refunded del revenue reportado');

INSERT INTO DEV.METRICS_REGISTRY 
    (METRIC_NAME, VERSION, DEFINITION, BUSINESS_RULE, SEMANTIC_VIEW_NAME, STATUS, PREVIOUS_VERSION, CHANGE_REASON)
VALUES 
    ('GROSS_MARGIN', 'v2', 
     'SUM(ORDERS.AMOUNT) - SUM(ORDERS.COST) WHERE ORDERS.STATUS = ''completed''', 
     'Margen basado solo en órdenes completadas',
     'SV_FINANCIAL_METRICS', 'dev', 'v1',
     'Alineado con cambio de Revenue v2');

-- Aplicar cambio: CREATE OR REPLACE Semantic View v2
CREATE OR REPLACE SEMANTIC VIEW DEV.SV_FINANCIAL_METRICS
    COMMENT = 'Métricas financieras v2 - Revenue filtrado por status=completed'
AS
TABLES (
    ORDERS AS [CLIENTE_HOL].DEV.ORDERS
)
FACTS (
    ORDERS.AMOUNT AS ORDERS.AMOUNT
        WITH SYNONYMS = ('monto', 'valor venta', 'importe')
        COMMENT = 'Monto bruto de la orden',
    ORDERS.COST AS ORDERS.COST
        WITH SYNONYMS = ('costo', 'costo producto')
        COMMENT = 'Costo asociado a la orden'
)
DIMENSIONS (
    ORDERS.ORDER_DATE AS ORDERS.ORDER_DATE
        WITH SYNONYMS = ('fecha', 'fecha orden', 'fecha pedido')
        COMMENT = 'Fecha en que se realizó la orden',
    ORDERS.STATUS AS ORDERS.STATUS
        WITH SYNONYMS = ('estado', 'estado orden')
        COMMENT = 'Estado actual de la orden: completed, pending, cancelled, refunded',
    ORDERS.REGION AS ORDERS.REGION
        WITH SYNONYMS = ('región', 'zona geográfica')
        COMMENT = 'Región geográfica del pedido',
    ORDERS.CHANNEL AS ORDERS.CHANNEL
        WITH SYNONYMS = ('canal', 'canal de venta')
        COMMENT = 'Canal por el que se realizó la venta'
)
METRICS (
    REVENUE AS SUM(ORDERS.AMOUNT) WHERE ORDERS.STATUS = 'completed'
        WITH SYNONYMS = ('ingresos', 'ventas totales', 'facturación')
        COMMENT = 'v2: Ingresos = SUM(amount) solo de órdenes completadas',
    TOTAL_COST AS SUM(ORDERS.COST) WHERE ORDERS.STATUS = 'completed'
        WITH SYNONYMS = ('costo total', 'gastos')
        COMMENT = 'v2: Costo total solo de órdenes completadas',
    GROSS_MARGIN AS SUM(ORDERS.AMOUNT) - SUM(ORDERS.COST) WHERE ORDERS.STATUS = 'completed'
        WITH SYNONYMS = ('margen bruto', 'ganancia bruta')
        COMMENT = 'v2: Margen bruto = Revenue - Costo (solo completed)'
);

-- Verificar el cambio
DESCRIBE SEMANTIC VIEW DEV.SV_FINANCIAL_METRICS;

-- Historial de versiones
SELECT 
    METRIC_NAME, 
    VERSION, 
    DEFINITION,
    CHANGE_REASON,
    STATUS,
    CREATED_AT
FROM DEV.METRICS_REGISTRY
WHERE METRIC_NAME = 'REVENUE'
ORDER BY CREATED_AT;
```

---

## Paso 4: Promoción DEV → STAGING

```sql
-- ===========================================
-- PROMOCIÓN DE DEV A STAGING
-- ===========================================

-- Paso 4.1: Extraer DDL de la Semantic View en DEV
-- GET_DDL devuelve la definición completa
SELECT GET_DDL('SEMANTIC_VIEW', 'DEV.SV_FINANCIAL_METRICS');

-- Paso 4.2: Crear la Semantic View en STAGING
-- (Reemplazar referencias de schema DEV → STAGING)
CREATE OR REPLACE SEMANTIC VIEW STAGING.SV_FINANCIAL_METRICS
    COMMENT = 'Métricas financieras v2 - Promovida de DEV para validación'
AS
TABLES (
    ORDERS AS [CLIENTE_HOL].STAGING.ORDERS
)
FACTS (
    ORDERS.AMOUNT AS ORDERS.AMOUNT
        WITH SYNONYMS = ('monto', 'valor venta', 'importe')
        COMMENT = 'Monto bruto de la orden',
    ORDERS.COST AS ORDERS.COST
        WITH SYNONYMS = ('costo', 'costo producto')
        COMMENT = 'Costo asociado a la orden'
)
DIMENSIONS (
    ORDERS.ORDER_DATE AS ORDERS.ORDER_DATE
        WITH SYNONYMS = ('fecha', 'fecha orden', 'fecha pedido')
        COMMENT = 'Fecha en que se realizó la orden',
    ORDERS.STATUS AS ORDERS.STATUS
        WITH SYNONYMS = ('estado', 'estado orden')
        COMMENT = 'Estado actual de la orden: completed, pending, cancelled, refunded',
    ORDERS.REGION AS ORDERS.REGION
        WITH SYNONYMS = ('región', 'zona geográfica')
        COMMENT = 'Región geográfica del pedido',
    ORDERS.CHANNEL AS ORDERS.CHANNEL
        WITH SYNONYMS = ('canal', 'canal de venta')
        COMMENT = 'Canal por el que se realizó la venta'
)
METRICS (
    REVENUE AS SUM(ORDERS.AMOUNT) WHERE ORDERS.STATUS = 'completed'
        WITH SYNONYMS = ('ingresos', 'ventas totales', 'facturación')
        COMMENT = 'v2: Ingresos = SUM(amount) solo de órdenes completadas',
    TOTAL_COST AS SUM(ORDERS.COST) WHERE ORDERS.STATUS = 'completed'
        WITH SYNONYMS = ('costo total', 'gastos')
        COMMENT = 'v2: Costo total solo de órdenes completadas',
    GROSS_MARGIN AS SUM(ORDERS.AMOUNT) - SUM(ORDERS.COST) WHERE ORDERS.STATUS = 'completed'
        WITH SYNONYMS = ('margen bruto', 'ganancia bruta')
        COMMENT = 'v2: Margen bruto = Revenue - Costo (solo completed)'
);

-- Paso 4.3: Validación cruzada DEV vs STAGING
-- Los resultados deben coincidir si los datos base son iguales
WITH DEV_METRICS AS (
    SELECT 
        SUM(AMOUNT) AS REVENUE
    FROM DEV.ORDERS
    WHERE STATUS = 'completed'
),
STAGING_METRICS AS (
    SELECT 
        SUM(AMOUNT) AS REVENUE
    FROM STAGING.ORDERS
    WHERE STATUS = 'completed'
)
SELECT 
    d.REVENUE AS DEV_REVENUE,
    s.REVENUE AS STAGING_REVENUE,
    CASE WHEN d.REVENUE = s.REVENUE THEN '✅ MATCH' ELSE '❌ MISMATCH' END AS VALIDATION
FROM DEV_METRICS d, STAGING_METRICS s;

-- Paso 4.4: Actualizar registry
-- Copiar registry a STAGING
CREATE OR REPLACE TABLE STAGING.METRICS_REGISTRY CLONE DEV.METRICS_REGISTRY;

UPDATE STAGING.METRICS_REGISTRY 
SET STATUS = 'staging' 
WHERE STATUS = 'dev' AND VERSION = 'v2';

-- Registrar la promoción
INSERT INTO PROD.PROMOTION_LOG (OBJECT_NAME, FROM_ENV, TO_ENV, NOTES)
VALUES ('SV_FINANCIAL_METRICS', 'DEV', 'STAGING', 'Promoción v2 - Revenue filtrado por completed');

-- Verificar
SELECT * FROM PROD.PROMOTION_LOG ORDER BY PROMOTED_AT DESC;
DESCRIBE SEMANTIC VIEW STAGING.SV_FINANCIAL_METRICS;
```

---

## Paso 5: Promoción STAGING → PROD

```sql
-- ===========================================
-- PROMOCIÓN DE STAGING A PROD (CON GATES)
-- ===========================================

-- Paso 5.1: Gate de aprobación
-- En un flujo real, esto vendría de un sistema externo (Jira, Slack, etc.)
-- Aquí simulamos con la tabla PROMOTION_LOG

INSERT INTO PROD.PROMOTION_LOG 
    (OBJECT_NAME, FROM_ENV, TO_ENV, APPROVAL_STATUS, NOTES)
VALUES 
    ('SV_FINANCIAL_METRICS', 'STAGING', 'PROD', 'PENDING', 
     'Solicitud de promoción v2 a PROD - requiere aprobación del Data Owner');

-- Simular aprobación
UPDATE PROD.PROMOTION_LOG 
SET 
    APPROVAL_STATUS = 'APPROVED',
    APPROVED_BY = CURRENT_USER(),
    APPROVED_AT = CURRENT_TIMESTAMP()
WHERE OBJECT_NAME = 'SV_FINANCIAL_METRICS' 
  AND TO_ENV = 'PROD' 
  AND APPROVAL_STATUS = 'PENDING';

-- Paso 5.2: Guardar DDL actual de PROD para rollback
-- (Si existe una versión previa en PROD)
UPDATE PROD.PROMOTION_LOG 
SET ROLLBACK_DDL = (SELECT GET_DDL('SEMANTIC_VIEW', 'PROD.SV_FINANCIAL_METRICS'))
WHERE OBJECT_NAME = 'SV_FINANCIAL_METRICS' 
  AND TO_ENV = 'PROD'
  AND APPROVED_AT IS NOT NULL
  AND ROLLBACK_DDL IS NULL;

-- Paso 5.3: Desplegar a PROD
CREATE OR REPLACE SEMANTIC VIEW PROD.SV_FINANCIAL_METRICS
    COMMENT = 'Métricas financieras v2 - PRODUCCIÓN - Aprobado para uso oficial'
AS
TABLES (
    ORDERS AS [CLIENTE_HOL].PROD.ORDERS
)
FACTS (
    ORDERS.AMOUNT AS ORDERS.AMOUNT
        WITH SYNONYMS = ('monto', 'valor venta', 'importe')
        COMMENT = 'Monto bruto de la orden',
    ORDERS.COST AS ORDERS.COST
        WITH SYNONYMS = ('costo', 'costo producto')
        COMMENT = 'Costo asociado a la orden'
)
DIMENSIONS (
    ORDERS.ORDER_DATE AS ORDERS.ORDER_DATE
        WITH SYNONYMS = ('fecha', 'fecha orden', 'fecha pedido')
        COMMENT = 'Fecha en que se realizó la orden',
    ORDERS.STATUS AS ORDERS.STATUS
        WITH SYNONYMS = ('estado', 'estado orden')
        COMMENT = 'Estado actual de la orden: completed, pending, cancelled, refunded',
    ORDERS.REGION AS ORDERS.REGION
        WITH SYNONYMS = ('región', 'zona geográfica')
        COMMENT = 'Región geográfica del pedido',
    ORDERS.CHANNEL AS ORDERS.CHANNEL
        WITH SYNONYMS = ('canal', 'canal de venta')
        COMMENT = 'Canal por el que se realizó la venta'
)
METRICS (
    REVENUE AS SUM(ORDERS.AMOUNT) WHERE ORDERS.STATUS = 'completed'
        WITH SYNONYMS = ('ingresos', 'ventas totales', 'facturación')
        COMMENT = 'v2: Ingresos = SUM(amount) solo de órdenes completadas',
    TOTAL_COST AS SUM(ORDERS.COST) WHERE ORDERS.STATUS = 'completed'
        WITH SYNONYMS = ('costo total', 'gastos')
        COMMENT = 'v2: Costo total solo de órdenes completadas',
    GROSS_MARGIN AS SUM(ORDERS.AMOUNT) - SUM(ORDERS.COST) WHERE ORDERS.STATUS = 'completed'
        WITH SYNONYMS = ('margen bruto', 'ganancia bruta')
        COMMENT = 'v2: Margen bruto = Revenue - Costo (solo completed)'
);

-- Paso 5.4: Smoke test - comparar STAGING vs PROD
WITH STAGING_RESULTS AS (
    SELECT 
        SUM(CASE WHEN STATUS = 'completed' THEN AMOUNT ELSE 0 END) AS REVENUE,
        SUM(CASE WHEN STATUS = 'completed' THEN COST ELSE 0 END) AS TOTAL_COST
    FROM STAGING.ORDERS
),
PROD_RESULTS AS (
    SELECT 
        SUM(CASE WHEN STATUS = 'completed' THEN AMOUNT ELSE 0 END) AS REVENUE,
        SUM(CASE WHEN STATUS = 'completed' THEN COST ELSE 0 END) AS TOTAL_COST
    FROM PROD.ORDERS
)
SELECT 
    s.REVENUE AS STAGING_REVENUE,
    p.REVENUE AS PROD_REVENUE,
    CASE WHEN s.REVENUE = p.REVENUE THEN '✅ PASS' ELSE '❌ FAIL' END AS REVENUE_CHECK,
    s.TOTAL_COST AS STAGING_COST,
    p.TOTAL_COST AS PROD_COST,
    CASE WHEN s.TOTAL_COST = p.TOTAL_COST THEN '✅ PASS' ELSE '❌ FAIL' END AS COST_CHECK
FROM STAGING_RESULTS s, PROD_RESULTS p;

-- Paso 5.5: Actualizar registry en PROD
CREATE OR REPLACE TABLE PROD.METRICS_REGISTRY CLONE STAGING.METRICS_REGISTRY;

UPDATE PROD.METRICS_REGISTRY 
SET STATUS = 'prod' 
WHERE STATUS = 'staging' AND VERSION = 'v2';

-- Paso 5.6: Patrón de Rollback (si algo falla)
-- Para ejecutar un rollback, usar el DDL guardado en PROMOTION_LOG:
-- 
-- SELECT ROLLBACK_DDL FROM PROD.PROMOTION_LOG 
-- WHERE OBJECT_NAME = 'SV_FINANCIAL_METRICS' AND TO_ENV = 'PROD'
-- ORDER BY PROMOTED_AT DESC LIMIT 1;
--
-- Luego ejecutar ese DDL para restaurar la versión anterior.
-- También actualizar METRICS_REGISTRY:
--
-- UPDATE PROD.METRICS_REGISTRY SET STATUS = 'rolled_back' 
-- WHERE VERSION = 'v2' AND STATUS = 'prod';
--
-- UPDATE PROD.METRICS_REGISTRY SET STATUS = 'prod' 
-- WHERE VERSION = 'v1' AND STATUS != 'rolled_back';

-- Verificación final
SELECT * FROM PROD.PROMOTION_LOG ORDER BY PROMOTED_AT DESC;
DESCRIBE SEMANTIC VIEW PROD.SV_FINANCIAL_METRICS;
```

---

## Paso 6: CI/CD con Snowflake TASKs

```sql
-- ===========================================
-- AUTOMATIZACIÓN CI/CD CON TASKS
-- ===========================================

-- Tabla de resultados de validación automática
CREATE OR REPLACE TABLE PROD.VALIDATION_RESULTS (
    VALIDATION_ID NUMBER AUTOINCREMENT,
    RUN_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    ENVIRONMENT VARCHAR(20),
    CHECK_NAME VARCHAR(256),
    CHECK_RESULT VARCHAR(20),
    DETAILS VARCHAR(4096)
);

-- Stored Procedure para validar consistencia entre ambientes
CREATE OR REPLACE PROCEDURE PROD.SP_VALIDATE_SEMANTIC_LAYER()
RETURNS VARCHAR
LANGUAGE SQL
AS
BEGIN
    -- Check 1: Verificar que Semantic Views existen en todos los ambientes
    LET dev_exists BOOLEAN := (SELECT COUNT(*) > 0 FROM INFORMATION_SCHEMA.VIEWS 
                               WHERE TABLE_SCHEMA = 'DEV' AND TABLE_NAME = 'SV_FINANCIAL_METRICS');
    LET staging_exists BOOLEAN := (SELECT COUNT(*) > 0 FROM INFORMATION_SCHEMA.VIEWS 
                                   WHERE TABLE_SCHEMA = 'STAGING' AND TABLE_NAME = 'SV_FINANCIAL_METRICS');
    LET prod_exists BOOLEAN := (SELECT COUNT(*) > 0 FROM INFORMATION_SCHEMA.VIEWS 
                                WHERE TABLE_SCHEMA = 'PROD' AND TABLE_NAME = 'SV_FINANCIAL_METRICS');

    INSERT INTO PROD.VALIDATION_RESULTS (ENVIRONMENT, CHECK_NAME, CHECK_RESULT, DETAILS)
    VALUES ('ALL', 'SEMANTIC_VIEW_EXISTS', 
            CASE WHEN :dev_exists AND :staging_exists AND :prod_exists THEN 'PASS' ELSE 'FAIL' END,
            'DEV=' || :dev_exists || ', STAGING=' || :staging_exists || ', PROD=' || :prod_exists);

    -- Check 2: Verificar que las métricas en DEV más recientes están en registry
    LET unregistered NUMBER := (
        SELECT COUNT(*) FROM DEV.METRICS_REGISTRY 
        WHERE STATUS = 'dev' 
        AND CREATED_AT > DATEADD('day', -7, CURRENT_TIMESTAMP())
        AND METRIC_NAME NOT IN (
            SELECT METRIC_NAME FROM STAGING.METRICS_REGISTRY WHERE STATUS = 'staging'
        )
    );
    
    INSERT INTO PROD.VALIDATION_RESULTS (ENVIRONMENT, CHECK_NAME, CHECK_RESULT, DETAILS)
    VALUES ('DEV', 'PENDING_PROMOTIONS', 
            CASE WHEN :unregistered > 0 THEN 'WARNING' ELSE 'PASS' END,
            :unregistered || ' métricas en DEV sin promover a STAGING');

    -- Check 3: Verificar que PROD no tiene versiones más antiguas que STAGING
    LET version_drift NUMBER := (
        SELECT COUNT(*) 
        FROM PROD.METRICS_REGISTRY p
        JOIN STAGING.METRICS_REGISTRY s 
            ON p.METRIC_NAME = s.METRIC_NAME
        WHERE p.STATUS = 'prod' AND s.STATUS = 'staging'
        AND s.CREATED_AT > p.CREATED_AT
    );

    INSERT INTO PROD.VALIDATION_RESULTS (ENVIRONMENT, CHECK_NAME, CHECK_RESULT, DETAILS)
    VALUES ('PROD', 'VERSION_DRIFT', 
            CASE WHEN :version_drift > 0 THEN 'WARNING' ELSE 'PASS' END,
            :version_drift || ' métricas en STAGING más nuevas que PROD');

    RETURN 'Validación completada: ' || CURRENT_TIMESTAMP()::VARCHAR;
END;

-- TASK de validación automática (cada 6 horas)
CREATE OR REPLACE TASK PROD.TASK_VALIDATE_SEMANTIC_LAYER
    WAREHOUSE = [CLIENTE]_WH
    SCHEDULE = 'USING CRON 0 */6 * * * America/Mexico_City'
    COMMENT = 'Valida consistencia del semantic layer entre ambientes'
AS
    CALL PROD.SP_VALIDATE_SEMANTIC_LAYER();

-- TASK de alerta: notificar si hay métricas pendientes de promoción > 3 días
CREATE OR REPLACE TASK PROD.TASK_STALE_METRICS_ALERT
    WAREHOUSE = [CLIENTE]_WH
    SCHEDULE = 'USING CRON 0 9 * * MON America/Mexico_City'
    COMMENT = 'Alerta semanal de métricas estancadas en DEV sin promover'
    WHEN SYSTEM$STREAM_HAS_DATA('DEV.METRICS_REGISTRY') OR 
         (SELECT COUNT(*) FROM DEV.METRICS_REGISTRY 
          WHERE STATUS = 'dev' 
          AND CREATED_AT < DATEADD('day', -3, CURRENT_TIMESTAMP())) > 0
AS
    INSERT INTO PROD.VALIDATION_RESULTS (ENVIRONMENT, CHECK_NAME, CHECK_RESULT, DETAILS)
    SELECT 'DEV', 'STALE_METRIC', 'ALERT',
           METRIC_NAME || ' v' || VERSION || ' lleva ' || 
           DATEDIFF('day', CREATED_AT, CURRENT_TIMESTAMP()) || ' días sin promover'
    FROM DEV.METRICS_REGISTRY
    WHERE STATUS = 'dev' 
    AND CREATED_AT < DATEADD('day', -3, CURRENT_TIMESTAMP());

-- Activar tasks
ALTER TASK PROD.TASK_VALIDATE_SEMANTIC_LAYER RESUME;
ALTER TASK PROD.TASK_STALE_METRICS_ALERT RESUME;

-- Ejecutar manualmente para probar
EXECUTE TASK PROD.TASK_VALIDATE_SEMANTIC_LAYER;

-- Ver resultados
SELECT * FROM PROD.VALIDATION_RESULTS ORDER BY RUN_AT DESC LIMIT 10;

-- Ver estado de tasks
SHOW TASKS IN SCHEMA PROD;
```

---

## Verificación

```sql
-- ===========================================
-- VERIFICACIÓN COMPLETA DEL SEMANTIC LAYER VERSIONADO
-- ===========================================

-- 1. Comparar métricas entre los 3 ambientes
SELECT 'DEV' AS ENV, SUM(AMOUNT) AS REVENUE_ALL, 
       SUM(CASE WHEN STATUS='completed' THEN AMOUNT ELSE 0 END) AS REVENUE_COMPLETED
FROM DEV.ORDERS
UNION ALL
SELECT 'STAGING', SUM(AMOUNT), 
       SUM(CASE WHEN STATUS='completed' THEN AMOUNT ELSE 0 END)
FROM STAGING.ORDERS
UNION ALL
SELECT 'PROD', SUM(AMOUNT), 
       SUM(CASE WHEN STATUS='completed' THEN AMOUNT ELSE 0 END)
FROM PROD.ORDERS;

-- 2. Verificar historial de versiones completo
SELECT 
    METRIC_NAME,
    VERSION,
    STATUS,
    DEFINITION,
    CHANGE_REASON,
    CREATED_AT
FROM PROD.METRICS_REGISTRY
ORDER BY METRIC_NAME, CREATED_AT;

-- 3. Verificar que todas las Semantic Views existen
SHOW SEMANTIC VIEWS IN SCHEMA DEV;
SHOW SEMANTIC VIEWS IN SCHEMA STAGING;
SHOW SEMANTIC VIEWS IN SCHEMA PROD;

-- 4. Verificar log de promociones
SELECT 
    OBJECT_NAME,
    FROM_ENV || ' → ' || TO_ENV AS PROMOTION_PATH,
    APPROVAL_STATUS,
    PROMOTED_AT,
    APPROVED_BY
FROM PROD.PROMOTION_LOG
ORDER BY PROMOTED_AT;

-- 5. Test de rollback: verificar que existe DDL guardado
SELECT 
    OBJECT_NAME,
    TO_ENV,
    CASE WHEN ROLLBACK_DDL IS NOT NULL THEN '✅ Rollback disponible' 
         ELSE '⚠️ Sin rollback' END AS ROLLBACK_STATUS,
    LEFT(ROLLBACK_DDL, 100) AS DDL_PREVIEW
FROM PROD.PROMOTION_LOG
WHERE TO_ENV = 'PROD';

-- 6. Resultados de validación automática
SELECT * FROM PROD.VALIDATION_RESULTS ORDER BY RUN_AT DESC;
```

---

## Troubleshooting

| Problema | Causa | Solución |
|----------|-------|----------|
| `Schema 'DEV' does not exist` | No se ejecutó Paso 1 | Ejecutar `CREATE SCHEMA IF NOT EXISTS DEV` |
| Semantic View no se crea | Error de sintaxis DDL | Verificar: TABLES antes de FACTS, FACTS antes de DIMENSIONS, usar alias correctos |
| Métricas no coinciden entre ambientes | Datos base diferentes | Verificar que ORDERS tiene mismos datos con `SELECT COUNT(*), SUM(AMOUNT) FROM <schema>.ORDERS` |
| `GET_DDL` devuelve NULL | Objeto no existe en schema | Verificar con `SHOW SEMANTIC VIEWS IN SCHEMA <env>` |
| TASK no se ejecuta | Task suspendida | `ALTER TASK <nombre> RESUME;` y verificar con `SHOW TASKS` |
| TASK falla con WHEN clause | Stream vacío o condición no cumplida | Verificar que la condición evalúa a TRUE: ejecutar el SELECT del WHEN manualmente |
| Promoción falla: schema mismatch | Referencias hardcodeadas al schema incorrecto | Revisar que las rutas en TABLES apuntan al schema destino, no al origen |
| Rollback no disponible | No se guardó DDL previo antes de CREATE OR REPLACE | Siempre guardar `GET_DDL` antes de desplegar nueva versión |
| `APPROVAL_STATUS` siempre PENDING | No se ejecutó el UPDATE de aprobación | Ejecutar el UPDATE de aprobación en Paso 5.1 |
| Conflicto de versiones: 2 personas modifican misma métrica | Sin locking en METRICS_REGISTRY | Agregar constraint UNIQUE en (METRIC_NAME, VERSION) o usar merge pattern |

---

## Contenido HTML para el HOL

```html
<h2>📐 Semantic Layer Versionado</h2>

<p>Un semantic layer versionado elimina la ambigüedad en las métricas empresariales 
y establece un flujo controlado de cambios entre ambientes.</p>

<div class="info-box tip">
    <span class="info-icon">🎯</span>
    <div class="info-content">
        <h4>¿Por qué versionar métricas?</h4>
        <p>Cuando "Revenue" significa cosas diferentes para Finance, Sales y Marketing, 
        los reportes contradicen. Un semantic layer versionado establece <strong>una única fuente de verdad</strong> 
        con trazabilidad completa de cada cambio.</p>
    </div>
</div>

<h3>Arquitectura de Promoción</h3>
<div style="text-align: center; margin: 20px 0;">
    <div style="display: inline-flex; align-items: center; gap: 10px; font-family: monospace;">
        <div style="background: #e3f2fd; border: 2px solid #1976d2; border-radius: 8px; padding: 12px 20px;">
            <strong>🧪 DEV</strong><br>
            <small>Experimentación</small><br>
            <small>Nuevas métricas</small>
        </div>
        <div style="font-size: 24px;">→</div>
        <div style="background: #fff3e0; border: 2px solid #f57c00; border-radius: 8px; padding: 12px 20px;">
            <strong>🔬 STAGING</strong><br>
            <small>Validación</small><br>
            <small>Tests cruzados</small>
        </div>
        <div style="font-size: 24px;">→</div>
        <div style="background: #e8f5e9; border: 2px solid #388e3c; border-radius: 8px; padding: 12px 20px;">
            <strong>🏭 PROD</strong><br>
            <small>Oficial</small><br>
            <small>Aprobado</small>
        </div>
    </div>
</div>

<h3>Flujo de Versionamiento</h3>
<table>
    <tr>
        <th>Etapa</th>
        <th>Acción</th>
        <th>Quién</th>
    </tr>
    <tr>
        <td>1. Definir</td>
        <td>Crear/modificar métrica en DEV + registrar en METRICS_REGISTRY</td>
        <td>Data Engineer / Analyst</td>
    </tr>
    <tr>
        <td>2. Promover a STAGING</td>
        <td>Replicar Semantic View + validar resultados</td>
        <td>Data Engineer</td>
    </tr>
    <tr>
        <td>3. Aprobar</td>
        <td>Revisar definición + confirmar con negocio</td>
        <td>Data Owner / CFO</td>
    </tr>
    <tr>
        <td>4. Desplegar a PROD</td>
        <td>Smoke test + deploy + guardar rollback DDL</td>
        <td>Data Engineer</td>
    </tr>
    <tr>
        <td>5. Monitorear</td>
        <td>TASKs verifican consistencia automáticamente</td>
        <td>Automático</td>
    </tr>
</table>

<div class="info-box warning">
    <span class="info-icon">⚠️</span>
    <div class="info-content">
        <h4>Nota sobre Trial</h4>
        <p>En cuentas trial, los 3 ambientes se simulan con schemas en la misma database. 
        En Enterprise+, se recomienda usar databases separadas y Git Integration para 
        versionamiento completo con Snowflake Workspaces.</p>
    </div>
</div>

<div class="info-box tip">
    <span class="info-icon">🔄</span>
    <div class="info-content">
        <h4>Rollback Instantáneo</h4>
        <p>Cada promoción guarda el DDL anterior en <code>PROMOTION_LOG</code>. 
        Si una métrica en producción genera reportes incorrectos, 
        se puede restaurar la versión anterior en segundos ejecutando el DDL guardado.</p>
    </div>
</div>
```

---

## Siguiente Módulo

- **Cortex AI**: [../cortex-ai/SKILL.md](../cortex-ai/SKILL.md)
- **Dynamic Tables**: [../dynamic-tables/SKILL.md](../dynamic-tables/SKILL.md)
