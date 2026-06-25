# Sub-Skill: Data Monetization Architecture

## Metadata
- **Parent**: snowflake-hol-generator
- **Name**: modules/data-monetization
- **Obligatorio**: ❌ No
- **Duración**: ~20 minutos
- **Dependencias**: Setup completado, datos cargados, Semantic View creada (módulo intelligence)

---

## 🎯 Objetivo

Demostrar cómo un único dataset puede generar múltiples productos de datos monetizables, entregados por diferentes canales:

1. **Provider Benchmarking** — Comparación anónima contra el mercado
2. **Payer Intelligence** — Analítica de costos y utilización para pagadores
3. **Real-World Evidence** — Datos longitudinales de-identificados para investigación
4. **Self-Service Analytics** — Consultas en lenguaje natural via Cortex Agent

El módulo muestra la arquitectura completa de monetización en Snowflake: un solo dataset curado genera múltiples líneas de ingreso mediante distintos canales de entrega.

---

## ⚠️ Compatibilidad con Trial

| Característica | Trial | Notas |
|---------------|-------|-------|
| Crear Secure Views | ✅ | Sin restricciones |
| Row Access Policies | ✅ | Funciona completamente |
| Aggregation Policies | ✅ | Funciona completamente |
| Semantic Views | ✅ | Via Snowsight UI |
| Cortex Agents | ✅ | Via Snowsight UI |
| CREATE SHARE | ❌ | Requiere config a nivel organización |
| CREATE LISTING | ❌ | Requiere Marketplace Provider habilitado |
| Reader Accounts | ❌ | No disponible en trial |
| ACCESS_HISTORY views | ⚠️ | Enterprise+ Edition requerida |

### Estrategia para Trial

> **Para cuentas trial**: Simulamos la separación proveedor/consumidor usando **esquemas separados** dentro de la misma cuenta. Los comandos de `CREATE SHARE` y `CREATE LISTING` se muestran **conceptualmente** (comentados) para que el usuario entienda la arquitectura real.

```sql
-- En trial: usamos esquemas para simular separación
-- PRODUCTS    → Esquema del proveedor (vistas de producto)
-- CONSUMERS   → Esquema que simula acceso del consumidor
-- GOVERNANCE  → Esquema de políticas y metering
```

---

## Paso 1: Arquitectura de Monetización

### Concepto

Un dataset curado es la **fuente única de verdad**. Sobre él se construyen múltiples vistas de producto, cada una exponiendo diferentes columnas, niveles de agregación y políticas de acceso. Los canales de entrega son independientes del producto.

```
┌─────────────┐     ┌──────────────┐     ┌─────────────────┐     ┌────────────────────┐
│  Raw Data   │ ──► │ Curated Layer│ ──► │  Product Views  │ ──► │ Delivery Channels  │
│ (Ingest)    │     │ (Cleansed)   │     │ (Secure Views)  │     │                    │
└─────────────┘     └──────────────┘     ├─────────────────┤     ├────────────────────┤
                                         │ 1. Benchmarking │     │ • Marketplace      │
                                         │ 2. Payer Intel  │     │ • Direct Share     │
                                         │ 3. RWE          │     │ • Cortex Agent     │
                                         │ 4. Self-Service │     │ • API / External   │
                                         └─────────────────┘     └────────────────────┘
```

### HTML del Diagrama de Arquitectura

```html
<h2>Arquitectura de Monetización de Datos</h2>

<p>Un único dataset curado genera múltiples productos de datos, cada uno entregado por el canal más apropiado para su audiencia:</p>

<div style="background: linear-gradient(135deg, #f0f4ff 0%, #e8f0fe 100%); border-radius: 12px; padding: 30px; margin: 20px 0;">
    <div style="display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 10px;">
        <!-- Raw Data -->
        <div style="background: #ff6b35; color: white; padding: 15px; border-radius: 8px; text-align: center; min-width: 120px;">
            <strong>Raw Data</strong><br><small>Claims, EHR, Rx</small>
        </div>
        <div style="font-size: 24px; color: #666;">→</div>
        <!-- Curated -->
        <div style="background: #29b5e8; color: white; padding: 15px; border-radius: 8px; text-align: center; min-width: 120px;">
            <strong>Curated Layer</strong><br><small>Limpieza + Enriquecimiento</small>
        </div>
        <div style="font-size: 24px; color: #666;">→</div>
        <!-- Products -->
        <div style="background: #11567f; color: white; padding: 15px; border-radius: 8px; text-align: center; min-width: 160px;">
            <strong>Product Views</strong><br>
            <small>4 productos monetizables</small>
        </div>
        <div style="font-size: 24px; color: #666;">→</div>
        <!-- Channels -->
        <div style="background: #6c47ff; color: white; padding: 15px; border-radius: 8px; text-align: center; min-width: 140px;">
            <strong>Delivery</strong><br>
            <small>Listing / Share / Agent / API</small>
        </div>
    </div>
</div>

<div class="info-box tip">
    <span class="info-icon">💰</span>
    <div class="info-content">
        <h4>Principio de Monetización</h4>
        <p>El valor no está solo en los datos — está en la <strong>perspectiva única</strong> que generas 
        al curar, agregar y contextualizar. Un mismo dataset puede generar 4-5 líneas de ingreso 
        distintas si se presenta de forma relevante para cada audiencia.</p>
    </div>
</div>
```

### SQL: Preparar la Estructura

```sql
-- ===========================================
-- PASO 1: CREAR ESTRUCTURA DE MONETIZACIÓN
-- ===========================================

USE DATABASE [CLIENTE_HOL];
USE WAREHOUSE [CLIENTE]_WH;

-- Esquemas para la arquitectura de monetización
CREATE SCHEMA IF NOT EXISTS PRODUCTS
    COMMENT = 'Vistas de producto monetizables (lo que se comparte)';

CREATE SCHEMA IF NOT EXISTS CONSUMERS
    COMMENT = 'Simula acceso del consumidor (en trial reemplaza shares)';

CREATE SCHEMA IF NOT EXISTS GOVERNANCE
    COMMENT = 'Políticas, metering y control de acceso';

-- Verificar
SHOW SCHEMAS IN DATABASE [CLIENTE_HOL];
```

---

## Paso 2: Crear Producto 1 — Provider Benchmarking

### Concepto

Los proveedores (hospitales, clínicas) quieren comparar su desempeño contra el mercado **sin exponer datos individuales de otros**. Este producto agrega métricas por categoría y presenta percentiles.

### SQL

```sql
-- ===========================================
-- PRODUCTO 1: PROVIDER BENCHMARKING
-- ===========================================

USE SCHEMA PRODUCTS;

-- Vista segura: Benchmarking anonimizado
CREATE OR REPLACE SECURE VIEW V_PROVIDER_BENCHMARKING AS
WITH METRICAS_AGREGADAS AS (
    SELECT
        -- Dimensiones de agrupación (nunca individuo)
        [CAMPO_REGION] AS REGION,
        [CAMPO_ESPECIALIDAD] AS ESPECIALIDAD,
        DATE_TRUNC('QUARTER', [CAMPO_FECHA]) AS TRIMESTRE,
        
        -- Métricas de benchmark (agregadas)
        COUNT(DISTINCT [CAMPO_PROVIDER_ID]) AS NUM_PROVIDERS,
        ROUND(AVG([METRICA_COSTO]), 2) AS COSTO_PROMEDIO_MERCADO,
        ROUND(MEDIAN([METRICA_COSTO]), 2) AS COSTO_MEDIANA_MERCADO,
        ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY [METRICA_COSTO]), 2) AS P25_COSTO,
        ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY [METRICA_COSTO]), 2) AS P75_COSTO,
        ROUND(AVG([METRICA_VOLUMEN]), 0) AS VOLUMEN_PROMEDIO,
        ROUND(AVG([METRICA_OUTCOME]), 2) AS OUTCOME_PROMEDIO
        
    FROM CURATED.[TABLA_CURADA]
    GROUP BY 1, 2, 3
    -- Mínimo de providers para anonimato (regla de k-anonimato)
    HAVING COUNT(DISTINCT [CAMPO_PROVIDER_ID]) >= 5
)
SELECT
    REGION,
    ESPECIALIDAD,
    TRIMESTRE,
    NUM_PROVIDERS,
    COSTO_PROMEDIO_MERCADO,
    COSTO_MEDIANA_MERCADO,
    P25_COSTO,
    P75_COSTO,
    VOLUMEN_PROMEDIO,
    OUTCOME_PROMEDIO,
    -- Rango intercuartil como medida de dispersión
    ROUND(P75_COSTO - P25_COSTO, 2) AS IQR_COSTO
FROM METRICAS_AGREGADAS
;

-- Política de agregación: prevenir que filtros granulares expongan individuos
CREATE OR REPLACE AGGREGATION POLICY GOVERNANCE.AGG_POLICY_BENCHMARKING
    AS () RETURNS AGGREGATION_CONSTRAINT ->
    AGGREGATION_CONSTRAINT(MIN_GROUP_SIZE => 5);

-- Aplicar política a la vista
ALTER VIEW PRODUCTS.V_PROVIDER_BENCHMARKING
    SET AGGREGATION POLICY GOVERNANCE.AGG_POLICY_BENCHMARKING;

-- Verificar
SELECT * FROM PRODUCTS.V_PROVIDER_BENCHMARKING LIMIT 10;
```

### HTML

```html
<div class="card">
    <div class="card-icon">📊</div>
    <h4>Producto 1: Provider Benchmarking</h4>
    <p>Permite a cada proveedor compararse contra el mercado sin exponer datos individuales.</p>
    <ul>
        <li><strong>Audiencia:</strong> Hospitales, clínicas, sistemas de salud</li>
        <li><strong>Valor:</strong> "¿Estoy por encima o debajo del promedio?"</li>
        <li><strong>Protección:</strong> k-anonimato (mínimo 5 providers por grupo)</li>
        <li><strong>Canal sugerido:</strong> Marketplace Listing (pago por suscripción)</li>
    </ul>
</div>
```

---

## Paso 3: Crear Producto 2 — Payer Intelligence

### Concepto

Los pagadores (aseguradoras, gobierno) necesitan entender patrones de costos, utilización y drivers de gasto. Ven métricas **diferentes** del mismo dataset base: enfocadas en costo total, variación, y tendencias.

### SQL

```sql
-- ===========================================
-- PRODUCTO 2: PAYER INTELLIGENCE
-- ===========================================

USE SCHEMA PRODUCTS;

CREATE OR REPLACE SECURE VIEW V_PAYER_INTELLIGENCE AS
SELECT
    -- Dimensiones relevantes para pagadores
    [CAMPO_PLAN_TIPO] AS TIPO_PLAN,
    [CAMPO_SERVICIO_CATEGORIA] AS CATEGORIA_SERVICIO,
    DATE_TRUNC('MONTH', [CAMPO_FECHA]) AS MES,
    [CAMPO_REGION] AS REGION,
    
    -- Métricas de costo (lo que importa al pagador)
    COUNT(*) AS NUM_CLAIMS,
    COUNT(DISTINCT [CAMPO_MIEMBRO_ID]) AS MIEMBROS_UNICOS,
    ROUND(SUM([METRICA_COSTO_TOTAL]), 2) AS COSTO_TOTAL,
    ROUND(AVG([METRICA_COSTO_TOTAL]), 2) AS COSTO_PROMEDIO_CLAIM,
    ROUND(SUM([METRICA_COSTO_TOTAL]) / NULLIF(COUNT(DISTINCT [CAMPO_MIEMBRO_ID]), 0), 2) AS PMPM,
    
    -- Utilización
    ROUND(AVG([METRICA_DIAS_ESTANCIA]), 1) AS LOS_PROMEDIO,
    ROUND(SUM(CASE WHEN [CAMPO_READMISION] = TRUE THEN 1 ELSE 0 END) * 100.0 / 
          NULLIF(COUNT(*), 0), 2) AS TASA_READMISION_PCT,
    
    -- Drivers de costo
    ROUND(STDDEV([METRICA_COSTO_TOTAL]), 2) AS VARIABILIDAD_COSTO,
    ROUND(SUM(CASE WHEN [METRICA_COSTO_TOTAL] > (
        SELECT PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY [METRICA_COSTO_TOTAL])
        FROM CURATED.[TABLA_CURADA]
    ) THEN [METRICA_COSTO_TOTAL] ELSE 0 END), 2) AS COSTO_OUTLIERS

FROM CURATED.[TABLA_CURADA]
GROUP BY 1, 2, 3, 4
HAVING COUNT(*) >= 10  -- Mínimo de observaciones
;

-- Row Access Policy: cada pagador solo ve datos de sus planes
CREATE OR REPLACE ROW ACCESS POLICY GOVERNANCE.RAP_PAYER_ACCESS
    AS (TIPO_PLAN VARCHAR) RETURNS BOOLEAN ->
    CURRENT_ROLE() IN ('SYSADMIN', 'DATA_ADMIN')
    OR EXISTS (
        SELECT 1 FROM GOVERNANCE.PAYER_ACCESS_MAP
        WHERE ROLE_NAME = CURRENT_ROLE()
        AND PLAN_AUTORIZADO = TIPO_PLAN
    );

-- Aplicar política
ALTER VIEW PRODUCTS.V_PAYER_INTELLIGENCE
    ADD ROW ACCESS POLICY GOVERNANCE.RAP_PAYER_ACCESS ON (TIPO_PLAN);

-- Tabla de mapeo de acceso (para la política)
CREATE TABLE IF NOT EXISTS GOVERNANCE.PAYER_ACCESS_MAP (
    ROLE_NAME VARCHAR,
    PLAN_AUTORIZADO VARCHAR,
    FECHA_INICIO DATE DEFAULT CURRENT_DATE(),
    FECHA_FIN DATE DEFAULT '2099-12-31'
);

-- Verificar
SELECT * FROM PRODUCTS.V_PAYER_INTELLIGENCE LIMIT 10;
```

### HTML

```html
<div class="card">
    <div class="card-icon">🏦</div>
    <h4>Producto 2: Payer Intelligence</h4>
    <p>Analítica de costos y utilización para aseguradoras y pagadores gubernamentales.</p>
    <ul>
        <li><strong>Audiencia:</strong> Aseguradoras, PBMs, Gobierno</li>
        <li><strong>Valor:</strong> PMPM, drivers de costo, tendencias de utilización</li>
        <li><strong>Protección:</strong> Row Access Policy (cada pagador ve solo sus planes)</li>
        <li><strong>Canal sugerido:</strong> Direct Share (relación contractual)</li>
    </ul>
</div>
```

---

## Paso 4: Crear Producto 3 — Real-World Evidence

### Concepto

Investigadores y equipos de analytics necesitan datos longitudinales de-identificados para estudios de cohortes, efectividad comparativa y análisis de patrones poblacionales.

### SQL

```sql
-- ===========================================
-- PRODUCTO 3: REAL-WORLD EVIDENCE (RWE)
-- ===========================================

USE SCHEMA PRODUCTS;

CREATE OR REPLACE SECURE VIEW V_REAL_WORLD_EVIDENCE AS
WITH COHORTES AS (
    SELECT
        -- ID de-identificado (hash irreversible)
        SHA2(CONCAT([CAMPO_PACIENTE_ID]::VARCHAR, 'SALT_RWE_2024'), 256) AS PATIENT_TOKEN,
        
        -- Demografía generalizada (no exacta)
        CASE 
            WHEN [CAMPO_EDAD] BETWEEN 0 AND 17 THEN '0-17'
            WHEN [CAMPO_EDAD] BETWEEN 18 AND 34 THEN '18-34'
            WHEN [CAMPO_EDAD] BETWEEN 35 AND 49 THEN '35-49'
            WHEN [CAMPO_EDAD] BETWEEN 50 AND 64 THEN '50-64'
            ELSE '65+'
        END AS GRUPO_EDAD,
        [CAMPO_GENERO] AS GENERO,
        LEFT([CAMPO_CODIGO_POSTAL], 3) AS ZONA_GEOGRAFICA,  -- Solo primeros 3 dígitos
        
        -- Datos clínicos longitudinales
        [CAMPO_DIAGNOSTICO_PRINCIPAL] AS DIAGNOSTICO,
        [CAMPO_PROCEDIMIENTO] AS PROCEDIMIENTO,
        [CAMPO_MEDICAMENTO] AS MEDICAMENTO,
        
        -- Temporalidad relativa (no fechas exactas)
        DATEDIFF('day', 
            FIRST_VALUE([CAMPO_FECHA]) OVER (PARTITION BY [CAMPO_PACIENTE_ID] ORDER BY [CAMPO_FECHA]),
            [CAMPO_FECHA]
        ) AS DIA_RELATIVO,
        
        -- Outcomes
        [METRICA_OUTCOME] AS OUTCOME_CLINICO,
        [METRICA_COSTO_TOTAL] AS COSTO_EPISODIO,
        [CAMPO_READMISION] AS FLAG_READMISION
        
    FROM CURATED.[TABLA_CURADA]
)
SELECT
    PATIENT_TOKEN,
    GRUPO_EDAD,
    GENERO,
    ZONA_GEOGRAFICA,
    DIAGNOSTICO,
    PROCEDIMIENTO,
    MEDICAMENTO,
    DIA_RELATIVO,
    OUTCOME_CLINICO,
    COSTO_EPISODIO,
    FLAG_READMISION
FROM COHORTES
;

-- Política de proyección: ocultar campos sensibles según el rol
CREATE OR REPLACE PROJECTION POLICY GOVERNANCE.PP_RWE_DEIDENT
    AS () RETURNS PROJECTION_CONSTRAINT ->
    CASE
        WHEN CURRENT_ROLE() IN ('SYSADMIN', 'DATA_ADMIN') 
            THEN PROJECTION_CONSTRAINT(ALLOW => TRUE)
        WHEN CURRENT_ROLE() IN ('RWE_RESEARCHER')
            THEN PROJECTION_CONSTRAINT(ALLOW => TRUE)
        ELSE
            PROJECTION_CONSTRAINT(ALLOW => FALSE)
    END;

-- Verificar conteo de cohortes
SELECT 
    GRUPO_EDAD,
    GENERO,
    DIAGNOSTICO,
    COUNT(DISTINCT PATIENT_TOKEN) AS PACIENTES,
    COUNT(*) AS EVENTOS,
    ROUND(AVG(COSTO_EPISODIO), 2) AS COSTO_PROMEDIO,
    ROUND(AVG(CASE WHEN FLAG_READMISION THEN 1 ELSE 0 END) * 100, 2) AS TASA_READMISION_PCT
FROM PRODUCTS.V_REAL_WORLD_EVIDENCE
GROUP BY 1, 2, 3
HAVING COUNT(DISTINCT PATIENT_TOKEN) >= 10
ORDER BY PACIENTES DESC
LIMIT 20;
```

### HTML

```html
<div class="card">
    <div class="card-icon">🔬</div>
    <h4>Producto 3: Real-World Evidence</h4>
    <p>Datos longitudinales de-identificados para estudios de cohortes e investigación clínica.</p>
    <ul>
        <li><strong>Audiencia:</strong> Pharma, CROs, Investigadores académicos</li>
        <li><strong>Valor:</strong> Efectividad comparativa, patrones poblacionales</li>
        <li><strong>Protección:</strong> De-identificación + generalización + mínimo de cohorte</li>
        <li><strong>Canal sugerido:</strong> Marketplace Listing (licencia por uso)</li>
    </ul>
</div>
```

---

## Paso 5: Crear Producto 4 — Self-Service Analytics via Cortex Agent

### Concepto

El producto "premium": en vez de entregar tablas estáticas, se ofrece acceso conversacional. El consumidor hace preguntas en lenguaje natural y el agente consulta el dataset curado con las políticas ya aplicadas.

### SQL: Vista Base para el Semantic View

```sql
-- ===========================================
-- PRODUCTO 4: SELF-SERVICE ANALYTICS
-- ===========================================

USE SCHEMA PRODUCTS;

-- Vista analítica optimizada para Semantic View
CREATE OR REPLACE SECURE VIEW V_SELF_SERVICE_ANALYTICS AS
SELECT
    -- Dimensiones de tiempo
    [CAMPO_FECHA] AS FECHA,
    DATE_TRUNC('MONTH', [CAMPO_FECHA]) AS MES,
    DATE_TRUNC('QUARTER', [CAMPO_FECHA]) AS TRIMESTRE,
    YEAR([CAMPO_FECHA]) AS ANIO,
    DAYNAME([CAMPO_FECHA]) AS DIA_SEMANA,
    
    -- Dimensiones de negocio
    [CAMPO_REGION] AS REGION,
    [CAMPO_ESPECIALIDAD] AS ESPECIALIDAD,
    [CAMPO_SERVICIO_CATEGORIA] AS CATEGORIA_SERVICIO,
    [CAMPO_PLAN_TIPO] AS TIPO_PLAN,
    
    -- Métricas principales
    [METRICA_COSTO_TOTAL] AS COSTO,
    [METRICA_VOLUMEN] AS VOLUMEN,
    [METRICA_OUTCOME] AS SCORE_CALIDAD,
    [METRICA_DIAS_ESTANCIA] AS DIAS_ESTANCIA,
    
    -- Métricas derivadas
    ROUND([METRICA_COSTO_TOTAL] / NULLIF([METRICA_DIAS_ESTANCIA], 0), 2) AS COSTO_POR_DIA,
    CASE WHEN [CAMPO_READMISION] THEN 'Sí' ELSE 'No' END AS READMISION

FROM CURATED.[TABLA_CURADA]
;

-- Verificar que la vista tiene datos
SELECT COUNT(*) AS TOTAL_REGISTROS FROM PRODUCTS.V_SELF_SERVICE_ANALYTICS;
```

### Instrucciones UI: Crear Semantic View + Agent

```html
<h3>Configurar Self-Service Analytics</h3>

<div class="info-box tip">
    <span class="info-icon">🧠</span>
    <div class="info-content">
        <h4>Producto Premium: Analytics Conversacional</h4>
        <p>En vez de compartir una tabla estática, ofreces una <strong>experiencia interactiva</strong>. 
        El consumidor pregunta en lenguaje natural y recibe respuestas contextualizadas. 
        Esto justifica un precio premium porque reduce la barrera técnica.</p>
    </div>
</div>

<ol>
    <li><strong>Crear Semantic View:</strong>
        <ul>
            <li>En Snowsight → <code>Data → Databases → [CLIENTE_HOL] → PRODUCTS</code></li>
            <li>Click en <code>V_SELF_SERVICE_ANALYTICS</code></li>
            <li>Menú <code>⋮</code> → <code>Create Semantic View</code></li>
            <li>Nombre: <code>SV_DATA_PRODUCT_ANALYTICS</code></li>
            <li>Revisar dimensiones y métricas detectadas</li>
            <li>Click <code>Create</code></li>
        </ul>
    </li>
    <li><strong>Crear Cortex Agent:</strong>
        <ul>
            <li>Ir a <code>AI & ML → Cortex Agents</code></li>
            <li>Click <code>+ Create</code></li>
            <li>Nombre: <code>[CLIENTE]_DATA_PRODUCT_AGENT</code></li>
            <li>Schema: <code>PRODUCTS</code></li>
            <li>Agregar Tool → <code>Analyst</code> → <code>SV_DATA_PRODUCT_ANALYTICS</code></li>
            <li>Instrucciones del agente:</li>
        </ul>
        <pre><code>Eres un analista de datos de salud. Responde en español.
Presenta métricas con formato numérico claro.
Si te piden datos a nivel individual, indica que los datos están agregados.
Sugiere análisis complementarios cuando sea relevante.</code></pre>
    </li>
    <li><strong>Probar con preguntas:</strong>
        <ul>
            <li>"¿Cuál es el costo promedio por región este trimestre?"</li>
            <li>"Muestra la tendencia mensual de readmisiones"</li>
            <li>"¿Qué especialidad tiene mejor score de calidad?"</li>
            <li>"Compara el costo por día entre tipos de plan"</li>
        </ul>
    </li>
</ol>
```

### HTML Card

```html
<div class="card">
    <div class="card-icon">🤖</div>
    <h4>Producto 4: Self-Service Analytics</h4>
    <p>Acceso conversacional a los datos via Cortex Agent — el canal premium.</p>
    <ul>
        <li><strong>Audiencia:</strong> Ejecutivos, equipos sin SQL, analistas de negocio</li>
        <li><strong>Valor:</strong> Zero-SQL analytics, respuestas en segundos</li>
        <li><strong>Protección:</strong> Secure View + políticas heredadas de la vista base</li>
        <li><strong>Canal sugerido:</strong> Snowflake Intelligence (acceso por usuario)</li>
    </ul>
</div>
```

---

## Paso 6: Delivery Channels

### Concepto

Cada producto puede entregarse por uno o más canales. La elección depende de la relación comercial, el volumen y el nivel de servicio deseado.

### HTML: Resumen de Canales

```html
<h2>Canales de Entrega</h2>

<p>Cada producto se entrega por el canal más adecuado a su audiencia:</p>

<div class="card-grid">
    <div class="card">
        <div class="card-icon">🏪</div>
        <h4>Marketplace Listing</h4>
        <p><strong>Para:</strong> Benchmarking, RWE</p>
        <p><strong>Modelo:</strong> Suscripción mensual</p>
        <p><strong>Ventaja:</strong> Descubrimiento orgánico, billing integrado</p>
        <p><em>⚠️ Requiere Provider Profile (no trial)</em></p>
    </div>
    <div class="card">
        <div class="card-icon">🔗</div>
        <h4>Direct Share</h4>
        <p><strong>Para:</strong> Payer Intelligence</p>
        <p><strong>Modelo:</strong> Contrato bilateral</p>
        <p><strong>Ventaja:</strong> Control total, relación directa</p>
        <p><em>⚠️ Requiere org setup (no trial)</em></p>
    </div>
    <div class="card">
        <div class="card-icon">🤖</div>
        <h4>Cortex Agent / Intelligence</h4>
        <p><strong>Para:</strong> Self-Service Analytics</p>
        <p><strong>Modelo:</strong> Acceso por usuario/mes</p>
        <p><strong>Ventaja:</strong> Experiencia premium, stickiness alta</p>
        <p><em>✅ Funciona en trial</em></p>
    </div>
    <div class="card">
        <div class="card-icon">⚡</div>
        <h4>API (External Functions)</h4>
        <p><strong>Para:</strong> Integración en apps del consumidor</p>
        <p><strong>Modelo:</strong> Pay-per-call</p>
        <p><strong>Ventaja:</strong> Embeddable, tiempo real</p>
        <p><em>⚠️ Requiere External Access Integration</em></p>
    </div>
</div>
```

### SQL: Marketplace Listing (Conceptual)

```sql
-- ===========================================
-- CANAL 1: MARKETPLACE LISTING
-- ⚠️ CONCEPTUAL — NO FUNCIONA EN TRIAL
-- ===========================================

-- Paso A: Crear el share subyacente
-- (Descomentarear en cuenta con org habilitada)
/*
CREATE SHARE IF NOT EXISTS SHARE_PROVIDER_BENCHMARKING
    COMMENT = 'Provider Benchmarking — Métricas anonimizadas de mercado';

GRANT USAGE ON DATABASE [CLIENTE_HOL] TO SHARE SHARE_PROVIDER_BENCHMARKING;
GRANT USAGE ON SCHEMA [CLIENTE_HOL].PRODUCTS TO SHARE SHARE_PROVIDER_BENCHMARKING;
GRANT SELECT ON VIEW [CLIENTE_HOL].PRODUCTS.V_PROVIDER_BENCHMARKING 
    TO SHARE SHARE_PROVIDER_BENCHMARKING;
*/

-- Paso B: Crear listing en Marketplace
-- (Requiere Snowsight → Data Products → Provider Studio)
/*
-- Via SQL (solo cuentas provider):
CREATE LISTING LISTING_PROVIDER_BENCHMARKING
    IN DATA EXCHANGE SNOWFLAKE_DATA_MARKETPLACE
    AS
    $$
    title: "Healthcare Provider Benchmarking"
    subtitle: "Compare your metrics against anonymized market averages"
    description: "Quarterly benchmarking data across regions and specialties."
    terms_of_service:
        link: "https://[CLIENTE].com/tos"
    business_needs:
        - "Performance benchmarking"
        - "Market positioning"
    targets:
        accounts: ["org1.account1", "org2.account2"]
    $$;

ALTER LISTING LISTING_PROVIDER_BENCHMARKING 
    SET SHARE = SHARE_PROVIDER_BENCHMARKING;
*/

-- En TRIAL: Simular acceso del consumidor con un rol separado
CREATE ROLE IF NOT EXISTS CONSUMER_BENCHMARKING;
GRANT USAGE ON DATABASE [CLIENTE_HOL] TO ROLE CONSUMER_BENCHMARKING;
GRANT USAGE ON SCHEMA [CLIENTE_HOL].PRODUCTS TO ROLE CONSUMER_BENCHMARKING;
GRANT SELECT ON VIEW [CLIENTE_HOL].PRODUCTS.V_PROVIDER_BENCHMARKING TO ROLE CONSUMER_BENCHMARKING;
GRANT USAGE ON WAREHOUSE [CLIENTE]_WH TO ROLE CONSUMER_BENCHMARKING;
```

### SQL: Direct Share (Conceptual)

```sql
-- ===========================================
-- CANAL 2: DIRECT SHARE
-- ⚠️ CONCEPTUAL — NO FUNCIONA EN TRIAL
-- ===========================================

/*
-- Share directo para pagadores (relación contractual)
CREATE SHARE IF NOT EXISTS SHARE_PAYER_INTEL_[PAYER_NAME]
    COMMENT = 'Payer Intelligence para [PAYER_NAME]';

GRANT USAGE ON DATABASE [CLIENTE_HOL] TO SHARE SHARE_PAYER_INTEL_[PAYER_NAME];
GRANT USAGE ON SCHEMA [CLIENTE_HOL].PRODUCTS TO SHARE SHARE_PAYER_INTEL_[PAYER_NAME];
GRANT SELECT ON VIEW [CLIENTE_HOL].PRODUCTS.V_PAYER_INTELLIGENCE 
    TO SHARE SHARE_PAYER_INTEL_[PAYER_NAME];

-- Agregar la cuenta del pagador
ALTER SHARE SHARE_PAYER_INTEL_[PAYER_NAME] 
    ADD ACCOUNTS = [ORG].[PAYER_ACCOUNT];
*/

-- En TRIAL: Simular con rol separado
CREATE ROLE IF NOT EXISTS CONSUMER_PAYER_ACME;
GRANT USAGE ON DATABASE [CLIENTE_HOL] TO ROLE CONSUMER_PAYER_ACME;
GRANT USAGE ON SCHEMA [CLIENTE_HOL].PRODUCTS TO ROLE CONSUMER_PAYER_ACME;
GRANT SELECT ON VIEW [CLIENTE_HOL].PRODUCTS.V_PAYER_INTELLIGENCE TO ROLE CONSUMER_PAYER_ACME;
GRANT USAGE ON WAREHOUSE [CLIENTE]_WH TO ROLE CONSUMER_PAYER_ACME;
```

### SQL: Cortex Agent (Funciona en Trial)

```sql
-- ===========================================
-- CANAL 3: CORTEX AGENT (FUNCIONA EN TRIAL)
-- ===========================================

-- El agente ya fue creado en Paso 5 via Snowsight UI.
-- Aquí verificamos que funcione:

-- Verificar Semantic View
SHOW SEMANTIC VIEWS IN SCHEMA [CLIENTE_HOL].PRODUCTS;

-- Verificar que el agente puede acceder a la vista
DESCRIBE SEMANTIC VIEW [CLIENTE_HOL].PRODUCTS.SV_DATA_PRODUCT_ANALYTICS;
```

### SQL: API via External Functions (Conceptual)

```sql
-- ===========================================
-- CANAL 4: API VIA EXTERNAL FUNCTIONS
-- ⚠️ CONCEPTUAL — Requiere External Access Integration
-- ===========================================

/*
-- Ejemplo: Crear una función que expone benchmarking via API
CREATE OR REPLACE FUNCTION PRODUCTS.API_GET_BENCHMARK(
    P_REGION VARCHAR,
    P_ESPECIALIDAD VARCHAR,
    P_TRIMESTRE DATE
)
RETURNS TABLE (
    COSTO_PROMEDIO NUMBER(12,2),
    COSTO_MEDIANA NUMBER(12,2),
    P25 NUMBER(12,2),
    P75 NUMBER(12,2),
    NUM_PROVIDERS INT
)
AS
$$
    SELECT 
        COSTO_PROMEDIO_MERCADO,
        COSTO_MEDIANA_MERCADO,
        P25_COSTO,
        P75_COSTO,
        NUM_PROVIDERS
    FROM PRODUCTS.V_PROVIDER_BENCHMARKING
    WHERE REGION = P_REGION
      AND ESPECIALIDAD = P_ESPECIALIDAD
      AND TRIMESTRE = P_TRIMESTRE
$$;
*/
```

---

## Paso 7: Gobernanza y Metering

### Concepto

Monitorear quién consume qué producto, con qué frecuencia, y cuántos créditos genera. Esto alimenta decisiones de pricing y detección de uso indebido.

### SQL: Metering y Access Tracking

```sql
-- ===========================================
-- PASO 7: GOBERNANZA Y METERING
-- ===========================================

USE SCHEMA GOVERNANCE;

-- ⚠️ ACCESS_HISTORY requiere Enterprise Edition o superior
-- En trial Standard Edition, estas consultas no funcionarán

-- 7A: Consumo por producto (qué vistas se consultan más)
-- Requiere: Enterprise+ Edition
/*
SELECT
    query_history.USER_NAME,
    query_history.ROLE_NAME,
    access_history.DIRECT_OBJECTS_ACCESSED[0]:objectName::VARCHAR AS OBJETO_ACCEDIDO,
    CASE 
        WHEN OBJETO_ACCEDIDO LIKE '%BENCHMARKING%' THEN 'Provider Benchmarking'
        WHEN OBJETO_ACCEDIDO LIKE '%PAYER%' THEN 'Payer Intelligence'
        WHEN OBJETO_ACCEDIDO LIKE '%REAL_WORLD%' THEN 'Real-World Evidence'
        WHEN OBJETO_ACCEDIDO LIKE '%SELF_SERVICE%' THEN 'Self-Service Analytics'
        ELSE 'Otro'
    END AS PRODUCTO,
    COUNT(*) AS NUM_CONSULTAS,
    MIN(query_history.START_TIME) AS PRIMERA_CONSULTA,
    MAX(query_history.START_TIME) AS ULTIMA_CONSULTA
FROM SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY access_history
JOIN SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY query_history
    ON access_history.QUERY_ID = query_history.QUERY_ID
WHERE query_history.START_TIME >= DATEADD('day', -30, CURRENT_TIMESTAMP())
  AND OBJETO_ACCEDIDO LIKE '%PRODUCTS%'
GROUP BY 1, 2, 3, 4
ORDER BY NUM_CONSULTAS DESC;
*/

-- 7B: Para TRIAL — Metering simplificado usando QUERY_HISTORY
SELECT
    USER_NAME,
    ROLE_NAME,
    COUNT(*) AS NUM_QUERIES,
    SUM(CREDITS_USED_CLOUD_SERVICES) AS CREDITOS_CLOUD,
    ROUND(SUM(TOTAL_ELAPSED_TIME) / 1000, 2) AS TIEMPO_TOTAL_SEG,
    MIN(START_TIME) AS PRIMERA_QUERY,
    MAX(START_TIME) AS ULTIMA_QUERY
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY(
    DATE_RANGE_START => DATEADD('day', -7, CURRENT_TIMESTAMP()),
    RESULT_LIMIT => 10000
))
WHERE QUERY_TEXT ILIKE '%PRODUCTS.V_%'
GROUP BY 1, 2
ORDER BY NUM_QUERIES DESC;

-- 7C: Dashboard de metering por producto
CREATE OR REPLACE VIEW GOVERNANCE.V_METERING_DASHBOARD AS
SELECT
    DATE_TRUNC('DAY', START_TIME) AS FECHA,
    USER_NAME,
    ROLE_NAME,
    CASE 
        WHEN QUERY_TEXT ILIKE '%BENCHMARKING%' THEN 'Provider Benchmarking'
        WHEN QUERY_TEXT ILIKE '%PAYER%' THEN 'Payer Intelligence'
        WHEN QUERY_TEXT ILIKE '%REAL_WORLD%' OR QUERY_TEXT ILIKE '%RWE%' THEN 'Real-World Evidence'
        WHEN QUERY_TEXT ILIKE '%SELF_SERVICE%' OR QUERY_TEXT ILIKE '%SV_DATA_PRODUCT%' THEN 'Self-Service Analytics'
        ELSE 'No Clasificado'
    END AS PRODUCTO,
    COUNT(*) AS CONSULTAS,
    ROUND(SUM(TOTAL_ELAPSED_TIME) / 1000, 2) AS TIEMPO_SEG
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY(
    DATE_RANGE_START => DATEADD('day', -30, CURRENT_TIMESTAMP()),
    RESULT_LIMIT => 10000
))
WHERE QUERY_TEXT ILIKE '%PRODUCTS%'
GROUP BY 1, 2, 3, 4;

-- Verificar metering
SELECT 
    PRODUCTO,
    SUM(CONSULTAS) AS TOTAL_CONSULTAS,
    COUNT(DISTINCT USER_NAME) AS USUARIOS_UNICOS,
    ROUND(SUM(TIEMPO_SEG), 2) AS TIEMPO_TOTAL_SEG
FROM GOVERNANCE.V_METERING_DASHBOARD
WHERE PRODUCTO != 'No Clasificado'
GROUP BY 1
ORDER BY TOTAL_CONSULTAS DESC;
```

### HTML: Gobernanza

```html
<h2>Gobernanza y Metering</h2>

<div class="info-box warning">
    <span class="info-icon">⚠️</span>
    <div class="info-content">
        <h4>Nota sobre Edición</h4>
        <p><code>ACCESS_HISTORY</code> y <code>READER_ACCOUNT_USAGE</code> requieren 
        <strong>Enterprise Edition</strong> o superior. En trial Standard, usamos 
        <code>INFORMATION_SCHEMA.QUERY_HISTORY</code> como alternativa simplificada.</p>
    </div>
</div>

<div class="card-grid">
    <div class="card">
        <div class="card-icon">📈</div>
        <h4>Metering por Producto</h4>
        <p>Cuántas consultas recibe cada producto y quién lo consume.</p>
    </div>
    <div class="card">
        <div class="card-icon">🔐</div>
        <h4>Auditoría de Acceso</h4>
        <p>Qué roles acceden a qué datos y con qué frecuencia.</p>
    </div>
    <div class="card">
        <div class="card-icon">💵</div>
        <h4>Créditos por Consumidor</h4>
        <p>Costo de compute generado por cada consumer account.</p>
    </div>
    <div class="card">
        <div class="card-icon">🚨</div>
        <h4>Alertas de Uso</h4>
        <p>Detectar consumo anómalo o intentos de extracción masiva.</p>
    </div>
</div>

<div class="info-box tip">
    <span class="info-icon">💡</span>
    <div class="info-content">
        <h4>Tip: Billing por Producto</h4>
        <p>Combina metering con <strong>Resource Monitors</strong> y <strong>Tags</strong> 
        para asignar costos de compute a cada producto. Esto permite pricing basado en 
        consumo real (pay-per-query) o detectar cuándo un consumidor excede su cuota.</p>
    </div>
</div>
```

---

## Verificación Final

```sql
-- ===========================================
-- VERIFICACIÓN: TODOS LOS PRODUCTOS ACCESIBLES
-- ===========================================

-- 1. Verificar que las secure views existen y son accesibles
SELECT 'V_PROVIDER_BENCHMARKING' AS PRODUCTO, COUNT(*) AS REGISTROS
FROM PRODUCTS.V_PROVIDER_BENCHMARKING

UNION ALL

SELECT 'V_PAYER_INTELLIGENCE', COUNT(*)
FROM PRODUCTS.V_PAYER_INTELLIGENCE

UNION ALL

SELECT 'V_REAL_WORLD_EVIDENCE', COUNT(*)
FROM PRODUCTS.V_REAL_WORLD_EVIDENCE

UNION ALL

SELECT 'V_SELF_SERVICE_ANALYTICS', COUNT(*)
FROM PRODUCTS.V_SELF_SERVICE_ANALYTICS;

-- 2. Verificar que las vistas son SECURE
SELECT 
    TABLE_NAME,
    IS_SECURE,
    TABLE_TYPE
FROM INFORMATION_SCHEMA.VIEWS
WHERE TABLE_SCHEMA = 'PRODUCTS'
  AND TABLE_NAME LIKE 'V_%'
ORDER BY TABLE_NAME;

-- 3. Verificar políticas aplicadas
SHOW AGGREGATION POLICIES IN SCHEMA GOVERNANCE;
SHOW ROW ACCESS POLICIES IN SCHEMA GOVERNANCE;

-- 4. Verificar roles de consumidor (simulación trial)
SHOW ROLES LIKE 'CONSUMER_%';

-- 5. Verificar Semantic View (si se creó)
SHOW SEMANTIC VIEWS IN SCHEMA PRODUCTS;

-- 6. Resumen de arquitectura
SELECT
    'Productos Creados' AS METRICA, 
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.VIEWS WHERE TABLE_SCHEMA = 'PRODUCTS' AND IS_SECURE = 'YES')::VARCHAR AS VALOR
UNION ALL
SELECT 'Políticas de Gobernanza', 
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.APPLICABLE_ROLES WHERE ROLE_NAME LIKE 'CONSUMER_%')::VARCHAR
UNION ALL
SELECT 'Vista de Metering', 
    CASE WHEN EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.VIEWS WHERE TABLE_NAME = 'V_METERING_DASHBOARD') 
         THEN 'Activa' ELSE 'No creada' END;
```

### HTML de Verificación

```html
<h2>Verificación Final</h2>

<div class="info-box success">
    <span class="info-icon">✅</span>
    <div class="info-content">
        <h4>Checklist de Monetización</h4>
        <ul>
            <li>☐ 4 productos de datos creados como Secure Views</li>
            <li>☐ Aggregation Policy aplicada a Benchmarking</li>
            <li>☐ Row Access Policy aplicada a Payer Intelligence</li>
            <li>☐ De-identificación verificada en RWE (sin datos individuales)</li>
            <li>☐ Semantic View + Agent funcional para Self-Service</li>
            <li>☐ Roles de consumidor creados (simulación trial)</li>
            <li>☐ Vista de metering activa</li>
        </ul>
    </div>
</div>
```

---

## Troubleshooting

### Error: "Insufficient privileges to operate on share"
**Causa**: `CREATE SHARE` requiere el rol `ACCOUNTADMIN` y la cuenta debe tener organización configurada.
**Solución**: En trial, usar la simulación con roles. En producción, ejecutar como `ACCOUNTADMIN` y verificar que la organización está habilitada con `SELECT SYSTEM$IS_LISTING_TERMS_ACCEPTED()`.

### Error: "Listing creation requires a provider profile"
**Causa**: Para publicar en Marketplace, se requiere Provider Studio setup completo.
**Solución**: En trial, demostrar conceptualmente. En producción: Snowsight → Data Products → Provider Studio → Completar perfil.

### Error: "Secure view takes significantly longer"
**Causa**: Secure Views desactivan optimizaciones del query planner por seguridad.
**Solución**: Pre-agregar datos en la vista curada. Usar materialized views o Dynamic Tables como capa intermedia. Agregar `CLUSTER BY` en tablas base si hay patrones de filtrado predecibles.

### Error: "Row access policy returned no rows"
**Causa**: El mapeo en `PAYER_ACCESS_MAP` no tiene entrada para el rol actual.
**Solución**: Verificar con `SELECT CURRENT_ROLE()` e insertar el mapeo correspondiente:
```sql
INSERT INTO GOVERNANCE.PAYER_ACCESS_MAP (ROLE_NAME, PLAN_AUTORIZADO)
VALUES (CURRENT_ROLE(), '[PLAN_TIPO]');
```

### Error: "Aggregation policy violation"
**Causa**: La consulta del consumidor aplica filtros que reducen el grupo por debajo del mínimo (k=5).
**Solución**: Esto es **comportamiento esperado** — la política está protegiendo la privacidad. Indicar al consumidor que use agrupaciones más amplias.

### Error: "Share replication lag"
**Causa**: Los consumidores en otra región ven datos desactualizados.
**Solución**: Habilitar replicación del share: `ALTER SHARE ... ENABLE REPLICATION TO ACCOUNTS IN REGION ...`. El lag típico es 1-5 minutos.

### Error: "QUERY_HISTORY function returned 0 rows for metering"
**Causa**: No se han ejecutado consultas contra las vistas de productos aún.
**Solución**: Ejecutar al menos una consulta a cada vista de producto antes de verificar metering. El `INFORMATION_SCHEMA.QUERY_HISTORY` tiene retención de 7 días por defecto.

---

## Siguiente Módulo

Después de Data Monetization, continuar con:
- **Dynamic Tables**: [../dynamic-tables/SKILL.md](../dynamic-tables/SKILL.md) — para mantener los productos actualizados automáticamente
- **Streamlit**: [../streamlit/SKILL.md](../streamlit/SKILL.md) — para crear un dashboard de metering interactivo
