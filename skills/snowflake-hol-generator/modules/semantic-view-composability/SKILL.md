# Sub-Skill: Semantic View Composability

## Metadata
- **Parent**: snowflake-hol-generator
- **Name**: modules/semantic-view-composability
- **Obligatorio**: ❌ No
- **Duración**: ~15 minutos
- **Dependencias**: Setup completado, al menos una Semantic View creada

---

## 🎯 Objetivo

Demostrar la composabilidad de Semantic Views:
- Cómo métricas definidas en una capa **Silver** se heredan automáticamente por productos **Gold**
- Cómo `ALTER SEMANTIC VIEW` propaga cambios a todos los consumidores downstream
- Patrón multi-consumidor con Cortex Agents consumiendo diferentes capas Gold

---

## ✅ Compatibilidad Trial

| Característica | Trial | Notas |
|---------------|-------|-------|
| CREATE SEMANTIC VIEW | ✅ | Funciona via Snowsight UI y SQL |
| ALTER SEMANTIC VIEW | ✅ | Solo via SQL worksheet |
| DESCRIBE SEMANTIC VIEW | ✅ | Verifica estructura |
| Cortex Analyst queries | ✅ | Requiere warehouse activo |
| Cortex Agent con SV | ✅ | Via API o Snowsight |

> **Nota**: Semantic Views funcionan completamente en cuentas trial. La creación via UI es la ruta más sencilla; ALTER requiere SQL.

---

## Paso 1: Crear Capa Silver (Semantic View Base)

```sql
-- ===========================================
-- CAPA SILVER: SEMANTIC VIEW BASE (SOURCE OF TRUTH)
-- ===========================================

USE DATABASE [CLIENTE_HOL];
USE WAREHOUSE [CLIENTE]_WH;

-- Primero, crear la vista base que alimenta la Semantic View
CREATE OR REPLACE VIEW ANALYTICS.V_SILVER_VENTAS AS
SELECT
    v.ID_VENTA,
    v.FECHA,
    v.CANTIDAD AS UNITS_SOLD,
    v.MONTO AS REVENUE,
    v.COSTO AS COST,
    v.MONTO - v.COSTO AS MARGIN,
    p.NOMBRE_PRODUCTO AS PRODUCT_NAME,
    p.CATEGORIA AS CATEGORY,
    c.NOMBRE_CLIENTE AS CUSTOMER_NAME,
    c.SEGMENTO AS SEGMENT,
    c.REGION AS REGION,
    v.ID_PRODUCTO,
    v.ID_CLIENTE
FROM RAW.VENTAS v
JOIN RAW.PRODUCTOS p ON v.ID_PRODUCTO = p.ID_PRODUCTO
JOIN RAW.CLIENTES c ON v.ID_CLIENTE = c.ID_CLIENTE;

-- Crear la Semantic View Silver (source of truth)
-- IMPORTANTE: El orden correcto es TABLES → FACTS → DIMENSIONS → METRICS → COMMENT
CREATE OR REPLACE SEMANTIC VIEW ANALYTICS.SV_SILVER_VENTAS

  TABLES (
    VENTAS AS [CLIENTE_HOL].ANALYTICS.V_SILVER_VENTAS
  )

  FACTS (
    VENTAS.REVENUE AS VENTAS.REVENUE
      WITH SYNONYMS = ('ingresos', 'ventas', 'monto')
      COMMENT = 'Ingreso total por transacción',

    VENTAS.COST AS VENTAS.COST
      WITH SYNONYMS = ('costo', 'gasto')
      COMMENT = 'Costo asociado a la transacción',

    VENTAS.MARGIN AS VENTAS.MARGIN
      WITH SYNONYMS = ('margen', 'ganancia', 'utilidad')
      COMMENT = 'Margen = Revenue - Cost',

    VENTAS.UNITS_SOLD AS VENTAS.UNITS_SOLD
      WITH SYNONYMS = ('unidades', 'cantidad', 'volumen')
      COMMENT = 'Unidades vendidas por transacción'
  )

  DIMENSIONS (
    VENTAS.FECHA AS VENTAS.FECHA
      WITH SYNONYMS = ('fecha', 'date', 'día')
      COMMENT = 'Fecha de la transacción',

    VENTAS.PRODUCT_NAME AS VENTAS.PRODUCT_NAME
      WITH SYNONYMS = ('producto', 'nombre producto')
      COMMENT = 'Nombre del producto',

    VENTAS.CATEGORY AS VENTAS.CATEGORY
      WITH SYNONYMS = ('categoría', 'tipo producto')
      COMMENT = 'Categoría del producto',

    VENTAS.CUSTOMER_NAME AS VENTAS.CUSTOMER_NAME
      WITH SYNONYMS = ('cliente', 'nombre cliente')
      COMMENT = 'Nombre del cliente',

    VENTAS.SEGMENT AS VENTAS.SEGMENT
      WITH SYNONYMS = ('segmento', 'tipo cliente')
      COMMENT = 'Segmento del cliente',

    VENTAS.REGION AS VENTAS.REGION
      WITH SYNONYMS = ('región', 'zona', 'área')
      COMMENT = 'Región geográfica del cliente'
  )

  METRICS (
    TOTAL_REVENUE AS SUM(VENTAS.REVENUE)
      WITH SYNONYMS = ('ingresos totales', 'revenue total')
      COMMENT = 'Suma total de ingresos',

    TOTAL_COST AS SUM(VENTAS.COST)
      WITH SYNONYMS = ('costo total', 'gastos totales')
      COMMENT = 'Suma total de costos',

    TOTAL_MARGIN AS SUM(VENTAS.MARGIN)
      WITH SYNONYMS = ('margen total', 'utilidad total')
      COMMENT = 'Margen total = Total Revenue - Total Cost',

    TOTAL_UNITS AS SUM(VENTAS.UNITS_SOLD)
      WITH SYNONYMS = ('unidades totales', 'volumen total')
      COMMENT = 'Total de unidades vendidas',

    AVG_ORDER_VALUE AS AVG(VENTAS.REVENUE)
      WITH SYNONYMS = ('ticket promedio', 'valor promedio pedido', 'AOV')
      COMMENT = 'Valor promedio por transacción',

    MARGIN_PCT AS SUM(VENTAS.MARGIN) / NULLIF(SUM(VENTAS.REVENUE), 0) * 100
      WITH SYNONYMS = ('porcentaje margen', '% margen', 'margin rate')
      COMMENT = 'Porcentaje de margen sobre ingresos'
  )

  COMMENT = 'Capa Silver: métricas core de ventas. Source of truth para capas Gold.';

-- Verificar creación
DESCRIBE SEMANTIC VIEW ANALYTICS.SV_SILVER_VENTAS;
```

### Notas de Sintaxis (IMPORTANTE)

> **TABLES**: Usa `ALIAS AS fully.qualified.table` — NO incluir la palabra `TABLE` antes del alias.
>
> **FACTS antes de DIMENSIONS**: El orden es obligatorio. Si pones DIMENSIONS antes de FACTS, obtendrás error de parsing.
>
> **Orden correcto**: `TABLES → FACTS → DIMENSIONS → METRICS → COMMENT`

---

## Paso 2: Crear Capa Gold (Semantic Views Derivadas)

Las capas Gold se construyen sobre vistas que consumen las mismas tablas base, pero cada una enfoca un dominio diferente. Heredan la estructura base y agregan métricas especializadas.

### Gold 1: SV_EXECUTIVE (Métricas C-Level)

```sql
-- ===========================================
-- GOLD: VISTA EJECUTIVA PARA C-LEVEL
-- ===========================================

-- Vista base para ejecutivos (agregación mensual)
CREATE OR REPLACE VIEW ANALYTICS.V_GOLD_EXECUTIVE AS
SELECT
    DATE_TRUNC('MONTH', FECHA) AS MES,
    SEGMENT,
    REGION,
    SUM(REVENUE) AS REVENUE,
    SUM(COST) AS COST,
    SUM(MARGIN) AS MARGIN,
    SUM(UNITS_SOLD) AS UNITS_SOLD,
    COUNT(DISTINCT ID_CLIENTE) AS UNIQUE_CUSTOMERS,
    COUNT(*) AS TOTAL_TRANSACTIONS
FROM ANALYTICS.V_SILVER_VENTAS
GROUP BY DATE_TRUNC('MONTH', FECHA), SEGMENT, REGION;

-- Semantic View Gold Executive
CREATE OR REPLACE SEMANTIC VIEW ANALYTICS.SV_EXECUTIVE

  TABLES (
    EXEC AS [CLIENTE_HOL].ANALYTICS.V_GOLD_EXECUTIVE
  )

  FACTS (
    EXEC.REVENUE AS EXEC.REVENUE
      WITH SYNONYMS = ('ingresos', 'ventas')
      COMMENT = 'Ingresos mensuales por segmento y región',

    EXEC.COST AS EXEC.COST
      WITH SYNONYMS = ('costos')
      COMMENT = 'Costos mensuales',

    EXEC.MARGIN AS EXEC.MARGIN
      WITH SYNONYMS = ('margen', 'utilidad')
      COMMENT = 'Margen mensual',

    EXEC.UNITS_SOLD AS EXEC.UNITS_SOLD
      WITH SYNONYMS = ('unidades')
      COMMENT = 'Unidades vendidas en el mes',

    EXEC.UNIQUE_CUSTOMERS AS EXEC.UNIQUE_CUSTOMERS
      WITH SYNONYMS = ('clientes únicos', 'base clientes')
      COMMENT = 'Clientes únicos en el periodo',

    EXEC.TOTAL_TRANSACTIONS AS EXEC.TOTAL_TRANSACTIONS
      WITH SYNONYMS = ('transacciones', 'operaciones')
      COMMENT = 'Número total de transacciones'
  )

  DIMENSIONS (
    EXEC.MES AS EXEC.MES
      WITH SYNONYMS = ('mes', 'periodo', 'month')
      COMMENT = 'Mes del periodo',

    EXEC.SEGMENT AS EXEC.SEGMENT
      WITH SYNONYMS = ('segmento')
      COMMENT = 'Segmento de cliente',

    EXEC.REGION AS EXEC.REGION
      WITH SYNONYMS = ('región', 'zona')
      COMMENT = 'Región geográfica'
  )

  METRICS (
    MONTHLY_REVENUE AS SUM(EXEC.REVENUE)
      WITH SYNONYMS = ('ingresos mensuales', 'revenue mensual')
      COMMENT = 'Ingresos totales del mes',

    MONTHLY_MARGIN AS SUM(EXEC.MARGIN)
      WITH SYNONYMS = ('margen mensual')
      COMMENT = 'Margen total del mes',

    MARGIN_RATE AS SUM(EXEC.MARGIN) / NULLIF(SUM(EXEC.REVENUE), 0) * 100
      WITH SYNONYMS = ('tasa margen', '% margen')
      COMMENT = 'Porcentaje de margen',

    REVENUE_PER_CUSTOMER AS SUM(EXEC.REVENUE) / NULLIF(SUM(EXEC.UNIQUE_CUSTOMERS), 0)
      WITH SYNONYMS = ('ingreso por cliente', 'LTV proxy', 'revenue per customer')
      COMMENT = 'Ingreso promedio por cliente único',

    CUSTOMER_BASE AS SUM(EXEC.UNIQUE_CUSTOMERS)
      WITH SYNONYMS = ('base de clientes', 'total clientes')
      COMMENT = 'Total clientes únicos'
  )

  COMMENT = 'Capa Gold Executive: KPIs de alto nivel para C-suite. Hereda métricas Silver.';
```

### Gold 2: SV_OPERATIONS (KPIs Operativos)

```sql
-- ===========================================
-- GOLD: VISTA OPERATIVA
-- ===========================================

-- Vista base operativa (agregación diaria por categoría)
CREATE OR REPLACE VIEW ANALYTICS.V_GOLD_OPERATIONS AS
SELECT
    FECHA,
    CATEGORY,
    PRODUCT_NAME,
    SUM(REVENUE) AS REVENUE,
    SUM(COST) AS COST,
    SUM(UNITS_SOLD) AS UNITS_SOLD,
    COUNT(*) AS ORDER_COUNT,
    AVG(REVENUE) AS AVG_ORDER_SIZE
FROM ANALYTICS.V_SILVER_VENTAS
GROUP BY FECHA, CATEGORY, PRODUCT_NAME;

-- Semantic View Gold Operations
CREATE OR REPLACE SEMANTIC VIEW ANALYTICS.SV_OPERATIONS

  TABLES (
    OPS AS [CLIENTE_HOL].ANALYTICS.V_GOLD_OPERATIONS
  )

  FACTS (
    OPS.REVENUE AS OPS.REVENUE
      WITH SYNONYMS = ('ingresos', 'ventas')
      COMMENT = 'Ingresos diarios por producto',

    OPS.COST AS OPS.COST
      WITH SYNONYMS = ('costo')
      COMMENT = 'Costo diario por producto',

    OPS.UNITS_SOLD AS OPS.UNITS_SOLD
      WITH SYNONYMS = ('unidades', 'volumen')
      COMMENT = 'Unidades vendidas por día',

    OPS.ORDER_COUNT AS OPS.ORDER_COUNT
      WITH SYNONYMS = ('pedidos', 'órdenes', 'transacciones')
      COMMENT = 'Número de pedidos',

    OPS.AVG_ORDER_SIZE AS OPS.AVG_ORDER_SIZE
      WITH SYNONYMS = ('tamaño promedio pedido', 'average order')
      COMMENT = 'Tamaño promedio del pedido'
  )

  DIMENSIONS (
    OPS.FECHA AS OPS.FECHA
      WITH SYNONYMS = ('fecha', 'día')
      COMMENT = 'Fecha de operación',

    OPS.CATEGORY AS OPS.CATEGORY
      WITH SYNONYMS = ('categoría', 'línea producto')
      COMMENT = 'Categoría de producto',

    OPS.PRODUCT_NAME AS OPS.PRODUCT_NAME
      WITH SYNONYMS = ('producto', 'nombre producto', 'SKU')
      COMMENT = 'Nombre del producto'
  )

  METRICS (
    DAILY_VOLUME AS SUM(OPS.UNITS_SOLD)
      WITH SYNONYMS = ('volumen diario', 'unidades del día')
      COMMENT = 'Total unidades vendidas en el día',

    DAILY_ORDERS AS SUM(OPS.ORDER_COUNT)
      WITH SYNONYMS = ('pedidos del día', 'órdenes diarias')
      COMMENT = 'Total de pedidos del día',

    UNITS_PER_ORDER AS SUM(OPS.UNITS_SOLD) / NULLIF(SUM(OPS.ORDER_COUNT), 0)
      WITH SYNONYMS = ('unidades por pedido', 'items per order')
      COMMENT = 'Promedio de unidades por pedido',

    COST_PER_UNIT AS SUM(OPS.COST) / NULLIF(SUM(OPS.UNITS_SOLD), 0)
      WITH SYNONYMS = ('costo unitario', 'cost per unit')
      COMMENT = 'Costo promedio por unidad vendida',

    REVENUE_PER_UNIT AS SUM(OPS.REVENUE) / NULLIF(SUM(OPS.UNITS_SOLD), 0)
      WITH SYNONYMS = ('ingreso por unidad', 'revenue per unit')
      COMMENT = 'Ingreso promedio por unidad vendida'
  )

  COMMENT = 'Capa Gold Operations: KPIs operativos diarios por producto/categoría.';
```

### Gold 3: SV_FINANCE (Análisis Financiero)

```sql
-- ===========================================
-- GOLD: VISTA FINANCIERA
-- ===========================================

-- Vista base financiera (con cálculos de margen detallados)
CREATE OR REPLACE VIEW ANALYTICS.V_GOLD_FINANCE AS
SELECT
    DATE_TRUNC('MONTH', FECHA) AS MES,
    CATEGORY,
    SEGMENT,
    SUM(REVENUE) AS REVENUE,
    SUM(COST) AS COST,
    SUM(MARGIN) AS MARGIN,
    SUM(UNITS_SOLD) AS UNITS_SOLD,
    COUNT(*) AS TRANSACTION_COUNT,
    SUM(REVENUE) - LAG(SUM(REVENUE)) OVER (
        PARTITION BY CATEGORY, SEGMENT ORDER BY DATE_TRUNC('MONTH', FECHA)
    ) AS REVENUE_MOM_CHANGE
FROM ANALYTICS.V_SILVER_VENTAS
GROUP BY DATE_TRUNC('MONTH', FECHA), CATEGORY, SEGMENT;

-- Semantic View Gold Finance
CREATE OR REPLACE SEMANTIC VIEW ANALYTICS.SV_FINANCE

  TABLES (
    FIN AS [CLIENTE_HOL].ANALYTICS.V_GOLD_FINANCE
  )

  FACTS (
    FIN.REVENUE AS FIN.REVENUE
      WITH SYNONYMS = ('ingresos', 'facturación')
      COMMENT = 'Ingresos mensuales por categoría y segmento',

    FIN.COST AS FIN.COST
      WITH SYNONYMS = ('costos', 'COGS')
      COMMENT = 'Costos de productos vendidos',

    FIN.MARGIN AS FIN.MARGIN
      WITH SYNONYMS = ('margen bruto', 'gross margin')
      COMMENT = 'Margen bruto mensual',

    FIN.UNITS_SOLD AS FIN.UNITS_SOLD
      WITH SYNONYMS = ('unidades')
      COMMENT = 'Unidades vendidas en el mes',

    FIN.TRANSACTION_COUNT AS FIN.TRANSACTION_COUNT
      WITH SYNONYMS = ('transacciones', 'operaciones')
      COMMENT = 'Número de transacciones',

    FIN.REVENUE_MOM_CHANGE AS FIN.REVENUE_MOM_CHANGE
      WITH SYNONYMS = ('cambio MoM', 'variación mensual', 'delta revenue')
      COMMENT = 'Cambio en revenue vs mes anterior'
  )

  DIMENSIONS (
    FIN.MES AS FIN.MES
      WITH SYNONYMS = ('mes', 'periodo')
      COMMENT = 'Mes del periodo financiero',

    FIN.CATEGORY AS FIN.CATEGORY
      WITH SYNONYMS = ('categoría', 'línea')
      COMMENT = 'Categoría de producto',

    FIN.SEGMENT AS FIN.SEGMENT
      WITH SYNONYMS = ('segmento', 'tipo cliente')
      COMMENT = 'Segmento de cliente'
  )

  METRICS (
    GROSS_MARGIN_PCT AS SUM(FIN.MARGIN) / NULLIF(SUM(FIN.REVENUE), 0) * 100
      WITH SYNONYMS = ('% margen bruto', 'gross margin percentage', 'GM%')
      COMMENT = 'Porcentaje de margen bruto',

    COST_RATIO AS SUM(FIN.COST) / NULLIF(SUM(FIN.REVENUE), 0) * 100
      WITH SYNONYMS = ('ratio costo', '% costo sobre ventas', 'cost ratio')
      COMMENT = 'Costo como porcentaje de revenue',

    REVENUE_GROWTH AS SUM(FIN.REVENUE_MOM_CHANGE) / NULLIF(
        SUM(FIN.REVENUE) - SUM(FIN.REVENUE_MOM_CHANGE), 0
    ) * 100
      WITH SYNONYMS = ('crecimiento', 'growth rate', '% crecimiento')
      COMMENT = 'Tasa de crecimiento mensual de revenue',

    AVG_MARGIN_PER_TXN AS SUM(FIN.MARGIN) / NULLIF(SUM(FIN.TRANSACTION_COUNT), 0)
      WITH SYNONYMS = ('margen por transacción', 'profit per order')
      COMMENT = 'Margen promedio por transacción'
  )

  COMMENT = 'Capa Gold Finance: análisis financiero con márgenes, ratios y crecimiento MoM.';
```

---

## Paso 3: Demostrar Propagación con ALTER

Este paso demuestra el poder de la composabilidad: un cambio en la capa Silver se propaga automáticamente a las capas Gold que consumen la misma base.

### 3.1: Estado ANTES del cambio

```sql
-- ===========================================
-- ANTES: Verificar métricas actuales en Silver
-- ===========================================

DESCRIBE SEMANTIC VIEW ANALYTICS.SV_SILVER_VENTAS;

-- Output esperado (resumen):
-- METRICS:
--   TOTAL_REVENUE, TOTAL_COST, TOTAL_MARGIN,
--   TOTAL_UNITS, AVG_ORDER_VALUE, MARGIN_PCT
-- (6 métricas)
```

### 3.2: Agregar nueva métrica a la vista base y al Silver

```sql
-- ===========================================
-- AGREGAR NUEVA MÉTRICA AL SILVER
-- ===========================================

-- Primero, actualizar la vista base para incluir nuevo campo
CREATE OR REPLACE VIEW ANALYTICS.V_SILVER_VENTAS AS
SELECT
    v.ID_VENTA,
    v.FECHA,
    v.CANTIDAD AS UNITS_SOLD,
    v.MONTO AS REVENUE,
    v.COSTO AS COST,
    v.MONTO - v.COSTO AS MARGIN,
    -- NUEVA COLUMNA: descuento aplicado
    COALESCE(v.DESCUENTO, 0) AS DISCOUNT_AMOUNT,
    p.NOMBRE_PRODUCTO AS PRODUCT_NAME,
    p.CATEGORIA AS CATEGORY,
    c.NOMBRE_CLIENTE AS CUSTOMER_NAME,
    c.SEGMENTO AS SEGMENT,
    c.REGION AS REGION,
    v.ID_PRODUCTO,
    v.ID_CLIENTE
FROM RAW.VENTAS v
JOIN RAW.PRODUCTOS p ON v.ID_PRODUCTO = p.ID_PRODUCTO
JOIN RAW.CLIENTES c ON v.ID_CLIENTE = c.ID_CLIENTE;

-- Usar ALTER para agregar la nueva métrica al Silver SIN recrear
ALTER SEMANTIC VIEW ANALYTICS.SV_SILVER_VENTAS
  ADD FACT VENTAS.DISCOUNT_AMOUNT AS VENTAS.DISCOUNT_AMOUNT
    WITH SYNONYMS = ('descuento', 'rebaja', 'discount')
    COMMENT = 'Monto de descuento aplicado a la transacción';

ALTER SEMANTIC VIEW ANALYTICS.SV_SILVER_VENTAS
  ADD METRIC TOTAL_DISCOUNTS AS SUM(VENTAS.DISCOUNT_AMOUNT)
    WITH SYNONYMS = ('descuentos totales', 'total rebajas')
    COMMENT = 'Suma total de descuentos aplicados';

ALTER SEMANTIC VIEW ANALYTICS.SV_SILVER_VENTAS
  ADD METRIC DISCOUNT_RATE AS SUM(VENTAS.DISCOUNT_AMOUNT) / NULLIF(SUM(VENTAS.REVENUE), 0) * 100
    WITH SYNONYMS = ('tasa descuento', '% descuento', 'discount rate')
    COMMENT = 'Porcentaje de descuento sobre revenue total';
```

### 3.3: Estado DESPUÉS del cambio

```sql
-- ===========================================
-- DESPUÉS: Verificar propagación
-- ===========================================

-- Silver ahora tiene 8 métricas (antes tenía 6)
DESCRIBE SEMANTIC VIEW ANALYTICS.SV_SILVER_VENTAS;

-- Output esperado (resumen):
-- METRICS:
--   TOTAL_REVENUE, TOTAL_COST, TOTAL_MARGIN,
--   TOTAL_UNITS, AVG_ORDER_VALUE, MARGIN_PCT,
--   TOTAL_DISCOUNTS ← NUEVA
--   DISCOUNT_RATE   ← NUEVA
-- (8 métricas)
```

### 3.4: Propagar a Gold — Actualizar vistas base y SVs

```sql
-- ===========================================
-- PROPAGAR: Actualizar Gold para consumir nueva métrica
-- ===========================================

-- Actualizar vista base Gold Finance para incluir descuentos
CREATE OR REPLACE VIEW ANALYTICS.V_GOLD_FINANCE AS
SELECT
    DATE_TRUNC('MONTH', FECHA) AS MES,
    CATEGORY,
    SEGMENT,
    SUM(REVENUE) AS REVENUE,
    SUM(COST) AS COST,
    SUM(MARGIN) AS MARGIN,
    SUM(UNITS_SOLD) AS UNITS_SOLD,
    SUM(DISCOUNT_AMOUNT) AS DISCOUNT_AMOUNT,  -- NUEVO
    COUNT(*) AS TRANSACTION_COUNT,
    SUM(REVENUE) - LAG(SUM(REVENUE)) OVER (
        PARTITION BY CATEGORY, SEGMENT ORDER BY DATE_TRUNC('MONTH', FECHA)
    ) AS REVENUE_MOM_CHANGE
FROM ANALYTICS.V_SILVER_VENTAS
GROUP BY DATE_TRUNC('MONTH', FECHA), CATEGORY, SEGMENT;

-- ALTER la SV Gold Finance para incluir la nueva métrica
ALTER SEMANTIC VIEW ANALYTICS.SV_FINANCE
  ADD FACT FIN.DISCOUNT_AMOUNT AS FIN.DISCOUNT_AMOUNT
    WITH SYNONYMS = ('descuentos', 'rebajas')
    COMMENT = 'Monto total de descuentos mensuales';

ALTER SEMANTIC VIEW ANALYTICS.SV_FINANCE
  ADD METRIC DISCOUNT_IMPACT AS SUM(FIN.DISCOUNT_AMOUNT) / NULLIF(SUM(FIN.REVENUE), 0) * 100
    WITH SYNONYMS = ('impacto descuento', '% descuento sobre revenue')
    COMMENT = 'Impacto del descuento como % del revenue';

-- Verificar que SV_FINANCE ahora incluye la métrica
DESCRIBE SEMANTIC VIEW ANALYTICS.SV_FINANCE;
```

### 3.5: Validar con Cortex Analyst

```sql
-- ===========================================
-- VALIDAR: Cortex Analyst reconoce nuevas métricas
-- ===========================================

-- Preguntar a Cortex Analyst usando la SV Silver
-- (En Snowsight: Cortex Analyst → seleccionar SV_SILVER_VENTAS)
-- Pregunta: "¿Cuál es la tasa de descuento total por región?"
-- → Cortex Analyst ahora puede responder usando DISCOUNT_RATE

-- Preguntar a Cortex Analyst usando la SV Finance
-- Pregunta: "¿Cuál es el impacto de descuentos por categoría este mes?"
-- → Cortex Analyst usa DISCOUNT_IMPACT automáticamente
```

---

## Paso 4: Multi-Consumer Pattern

### Diagrama de Arquitectura

```
┌─────────────────────────────────────────────────────────────────────┐
│                        TABLAS BASE (RAW)                            │
│         RAW.VENTAS  ·  RAW.PRODUCTOS  ·  RAW.CLIENTES              │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    CAPA SILVER (Source of Truth)                     │
│                                                                     │
│   V_SILVER_VENTAS ──→ SV_SILVER_VENTAS                             │
│   (vista SQL)          (6→8 métricas core)                          │
│                                                                     │
│   Un cambio aquí (ALTER) propaga a TODAS las capas Gold             │
└──────┬────────────────────────┬────────────────────────┬────────────┘
       │                        │                        │
       ▼                        ▼                        ▼
┌──────────────┐    ┌──────────────────┐    ┌──────────────────┐
│  GOLD: EXEC  │    │  GOLD: OPS       │    │  GOLD: FINANCE   │
│              │    │                  │    │                  │
│ SV_EXECUTIVE │    │ SV_OPERATIONS    │    │ SV_FINANCE       │
│ (C-Level)    │    │ (Operaciones)    │    │ (Finanzas)       │
└──────┬───────┘    └────────┬─────────┘    └────────┬─────────┘
       │                     │                       │
       ▼                     ▼                       ▼
┌──────────────┐    ┌──────────────────┐    ┌──────────────────┐
│ AGENT:       │    │ AGENT:           │    │ AGENT:           │
│ CEO Bot      │    │ Ops Manager Bot  │    │ CFO Bot          │
│              │    │                  │    │                  │
│ "¿Cómo van  │    │ "¿Cuál producto  │    │ "¿Cuál es el     │
│  los ingresos│    │  tiene mayor     │    │  margen bruto    │
│  este Q?"    │    │  volumen hoy?"   │    │  por categoría?" │
└──────────────┘    └──────────────────┘    └──────────────────┘
```

### Crear Agents Consumidores (Ejemplo Conceptual)

```sql
-- ===========================================
-- MULTI-CONSUMER: CORTEX AGENTS POR CAPA GOLD
-- ===========================================

-- Agent 1: Executive Agent (consume SV_EXECUTIVE)
CREATE OR REPLACE CORTEX AGENT ANALYTICS.AGENT_EXECUTIVE
  COMMENT = 'Agente para consultas ejecutivas C-level'
  SEMANTIC_VIEWS = ('ANALYTICS.SV_EXECUTIVE')
  INSTRUCTIONS = 'Responde preguntas sobre KPIs de alto nivel: 
    revenue mensual, base de clientes, margen por región y segmento.
    Siempre incluye contexto temporal (MoM, QoQ).';

-- Agent 2: Operations Agent (consume SV_OPERATIONS)
CREATE OR REPLACE CORTEX AGENT ANALYTICS.AGENT_OPERATIONS
  COMMENT = 'Agente para consultas operativas diarias'
  SEMANTIC_VIEWS = ('ANALYTICS.SV_OPERATIONS')
  INSTRUCTIONS = 'Responde preguntas operativas: volumen diario,
    productos más vendidos, eficiencia por categoría.
    Enfócate en métricas accionables del día a día.';

-- Agent 3: Finance Agent (consume SV_FINANCE)
CREATE OR REPLACE CORTEX AGENT ANALYTICS.AGENT_FINANCE
  COMMENT = 'Agente para análisis financiero'
  SEMANTIC_VIEWS = ('ANALYTICS.SV_FINANCE')
  INSTRUCTIONS = 'Responde preguntas financieras: márgenes,
    ratios de costo, crecimiento MoM, impacto de descuentos.
    Siempre incluye porcentajes y comparativas.';

-- DEMOSTRACIÓN DE PROPAGACIÓN:
-- Al agregar DISCOUNT_RATE al Silver (Paso 3), y propagar a Gold Finance,
-- el AGENT_FINANCE automáticamente puede responder:
-- "¿Cuál es el impacto de los descuentos este mes?"
-- SIN necesidad de modificar el Agent.
```

---

## Contenido HTML para el HOL

```html
<h2>🔗 Composabilidad de Semantic Views</h2>

<p>Las Semantic Views se componen en capas: una capa <strong>Silver</strong> define 
métricas base que se heredan y especializan en capas <strong>Gold</strong>.</p>

<div class="info-box tip">
    <span class="info-icon">🏗️</span>
    <div class="info-content">
        <h4>Patrón Silver → Gold</h4>
        <p>Define tus métricas core UNA vez en Silver. Las capas Gold heredan 
        esas métricas a través de las vistas SQL subyacentes y agregan 
        especializaciones para cada audiencia (ejecutivos, operaciones, finanzas).</p>
    </div>
</div>

<h3>Beneficios de la Composabilidad</h3>
<ul>
    <li>✅ <strong>Single Source of Truth</strong>: Métricas definidas una sola vez</li>
    <li>✅ <strong>Propagación automática</strong>: ALTER en Silver propaga a Gold</li>
    <li>✅ <strong>Especialización</strong>: Cada Gold agrega métricas para su audiencia</li>
    <li>✅ <strong>Multi-Consumer</strong>: Distintos Agents consumen distintas capas</li>
</ul>

<div class="info-box warning">
    <span class="info-icon">⚠️</span>
    <div class="info-content">
        <h4>Orden de declaración en CREATE SEMANTIC VIEW</h4>
        <p>El orden es estricto: <code>TABLES → FACTS → DIMENSIONS → METRICS → COMMENT</code>.<br>
        FACTS debe ir ANTES de DIMENSIONS. Si inviertes el orden, obtendrás un error de parsing.</p>
    </div>
</div>

<h3>Arquitectura</h3>
<pre>
Base Tables → Silver SV (source of truth)
                ├── Gold SV Executive → Agent CEO
                ├── Gold SV Operations → Agent Ops
                └── Gold SV Finance   → Agent CFO
</pre>

<div class="info-box tip">
    <span class="info-icon">🔄</span>
    <div class="info-content">
        <h4>ALTER propaga cambios</h4>
        <p>Cuando agregas una métrica al Silver con <code>ALTER SEMANTIC VIEW ... ADD METRIC</code>,
        solo necesitas actualizar la vista SQL subyacente de cada Gold que la necesite.
        El Agent no necesita modificación — la nueva métrica estará disponible automáticamente.</p>
    </div>
</div>
```

---

## Verificación

```sql
-- ===========================================
-- VERIFICACIÓN COMPLETA
-- ===========================================

-- 1. Verificar estructura Silver
DESCRIBE SEMANTIC VIEW ANALYTICS.SV_SILVER_VENTAS;
-- Confirmar: 4 FACTS, 6 DIMENSIONS, 8 METRICS (después de ALTER)

-- 2. Verificar estructura Gold Executive
DESCRIBE SEMANTIC VIEW ANALYTICS.SV_EXECUTIVE;
-- Confirmar: 6 FACTS, 3 DIMENSIONS, 5 METRICS

-- 3. Verificar estructura Gold Operations
DESCRIBE SEMANTIC VIEW ANALYTICS.SV_OPERATIONS;
-- Confirmar: 5 FACTS, 3 DIMENSIONS, 5 METRICS

-- 4. Verificar estructura Gold Finance (con propagación)
DESCRIBE SEMANTIC VIEW ANALYTICS.SV_FINANCE;
-- Confirmar: 7 FACTS (incluyendo DISCOUNT_AMOUNT), 3 DIMENSIONS, 5 METRICS

-- 5. Listar todas las Semantic Views creadas
SHOW SEMANTIC VIEWS IN SCHEMA ANALYTICS;

-- 6. Test funcional: consultar usando Cortex Analyst
-- En Snowsight → Cortex Analyst → SV_SILVER_VENTAS:
-- Pregunta: "¿Cuáles son los ingresos totales por región?"
-- Pregunta: "¿Cuál es la tasa de descuento?" (métrica nueva)

-- En Snowsight → Cortex Analyst → SV_FINANCE:
-- Pregunta: "¿Cuál es el margen bruto por categoría?"
-- Pregunta: "¿Cuál es el impacto del descuento?" (propagada desde Silver)
```

---

## Troubleshooting

| Error | Causa | Solución |
|-------|-------|----------|
| `SQL compilation error: ... unexpected 'DIMENSIONS'` | DIMENSIONS declarado antes de FACTS | Mover FACTS antes de DIMENSIONS en el DDL |
| `Object does not exist: ...` en CREATE SEMANTIC VIEW | La tabla/vista referenciada no existe | Crear la vista SQL base ANTES de la Semantic View |
| `Invalid identifier` en ALTER ... ADD FACT | La columna no existe en la tabla subyacente | Actualizar primero la vista SQL con CREATE OR REPLACE VIEW |
| `Circular reference detected` | SV_A referencia SV_B que referencia SV_A | Las Semantic Views no se referencian entre sí directamente; usan vistas SQL intermedias |
| `METRIC already exists` en ALTER ... ADD METRIC | Métrica con ese nombre ya fue definida | Usar ALTER ... DROP METRIC primero, luego ADD |
| `TABLE keyword not expected` | Usar `TABLE alias AS ...` en TABLES | Sintaxis correcta: `ALIAS AS fully.qualified.table` (sin TABLE) |
| `Synonym conflict` | Mismo sinónimo en FACT y DIMENSION | Usar sinónimos distintos; evitar conflicto entre niveles |
| ALTER no refleja nueva métrica en Agent | La vista SQL subyacente no tiene la columna | Paso 1: UPDATE vista SQL. Paso 2: ALTER SV ADD FACT. Paso 3: ALTER SV ADD METRIC |

### Errores Frecuentes con ALTER

```sql
-- ❌ ERROR: Intentar agregar métrica que referencia columna inexistente
ALTER SEMANTIC VIEW ANALYTICS.SV_SILVER_VENTAS
  ADD METRIC BAD_METRIC AS SUM(VENTAS.COLUMNA_QUE_NO_EXISTE);
-- Fix: Primero agregar la columna a la vista SQL base

-- ❌ ERROR: Orden incorrecto en CREATE
CREATE SEMANTIC VIEW ANALYTICS.SV_BAD
  TABLES (T AS DB.SCHEMA.TABLE)
  DIMENSIONS (...)   -- ← ERROR: FACTS debe ir primero
  FACTS (...)
  METRICS (...);
-- Fix: Poner FACTS antes de DIMENSIONS

-- ❌ ERROR: Usar TABLE keyword en TABLES
CREATE SEMANTIC VIEW ANALYTICS.SV_BAD
  TABLES (
    TABLE VENTAS AS DB.ANALYTICS.V_SILVER_VENTAS  -- ← ERROR
  );
-- Fix: Quitar TABLE → solo 'VENTAS AS DB.ANALYTICS.V_SILVER_VENTAS'
```

---

## Siguiente Módulo

- **Cortex AI Functions**: [../cortex-ai/SKILL.md](../cortex-ai/SKILL.md)
- **Intelligence**: [../intelligence/SKILL.md](../intelligence/SKILL.md)
