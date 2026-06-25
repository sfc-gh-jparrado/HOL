# Módulo: dbt Semantic Layer en Snowflake

## Metadata

| Campo | Valor |
|-------|-------|
| **Skill padre** | `snowflake-hol-generator` |
| **Módulo** | `dbt-semantic-layer` |
| **Duración estimada** | ~20 minutos |
| **Dependencias** | Setup completado (database, warehouse, schema, roles creados) |
| **Nivel** | Intermedio |
| **Tags** | dbt, semantic-view, git, tasks, scheduling, transformaciones |

---

## Objetivo

Demostrar transformaciones versionadas con dbt Core en Snowflake Workspaces, incluyendo:
- Creación y ejecución de modelos dbt directamente en Snowsight
- Generación de Semantic Views desde definiciones dbt usando el paquete `dbt_semantic_view`
- Flujo de trabajo Git-based con Pull Requests
- Ejecución programada mediante Snowflake TASKs

---

## Compatibilidad Trial

> **IMPORTANTE**: dbt Projects on Snowflake requiere **Enterprise Edition o superior**.
> Esta funcionalidad **NO está disponible en cuentas Trial** (Standard Edition).

| Funcionalidad | Trial (Standard) | Enterprise+ |
|---------------|:-----------------:|:-----------:|
| dbt Projects en Workspaces | Conceptual (screenshots/UI) | SQL completo |
| Semantic Views via dbt | No disponible | SQL completo |
| Git Integration | Lectura conceptual | Funcional completo |
| Snowflake TASKs | Disponible | Disponible |

**Estrategia para Trial:**
- Mostrar capturas de pantalla y navegación en Snowsight UI
- Explicar el flujo conceptualmente con diagramas
- Proveer SQL templates que el participante puede ejecutar cuando tenga acceso Enterprise
- Los TASKs sí funcionan en Trial, se pueden demostrar independientemente

---

## Paso 1: Configurar dbt Project en Snowflake Workspaces

### Descripción
Crear un proyecto dbt directamente desde la interfaz de Snowsight, conectarlo a un repositorio Git y configurar el perfil de conexión.

### Instrucciones UI (Snowsight)

```
1. Navegar a: Data → Projects → + New Project → dbt
2. Nombre del proyecto: HOL_DBT_SEMANTIC
3. Seleccionar warehouse: HOL_WH
4. Seleccionar database/schema: HOL_DB.ANALYTICS
```

### Configuración Git

<!-- HTML SNIPPET: info-box -->
```html
<div class="info-box">
  <p><strong>Requisito previo:</strong> Se necesita un repositorio Git configurado como 
  Git Integration en Snowflake. El instructor debe tener esto preparado antes del lab.</p>
</div>
```

### SQL: Crear Git Integration (Enterprise+)

```sql
-- ============================================================
-- PASO 1: Configurar integración Git y proyecto dbt
-- ============================================================

-- 1.1 Crear API Integration para Git (si no existe)
CREATE OR REPLACE API INTEGRATION git_api_integration
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/')
  ENABLED = TRUE;

-- 1.2 Crear secreto para autenticación Git
CREATE OR REPLACE SECRET git_secret
  TYPE = password
  USERNAME = '<github_username>'
  PASSWORD = '<github_pat_token>';

-- 1.3 Crear repositorio Git en Snowflake
CREATE OR REPLACE GIT REPOSITORY hol_db.analytics.dbt_repo
  API_INTEGRATION = git_api_integration
  GIT_CREDENTIALS = git_secret
  ORIGIN = 'https://github.com/<org>/<repo>.git';

-- 1.4 Verificar conexión
ALTER GIT REPOSITORY hol_db.analytics.dbt_repo FETCH;
SHOW GIT BRANCHES IN hol_db.analytics.dbt_repo;
```

### Configuración profiles.yml

```yaml
# profiles.yml - Configurado automáticamente en Snowflake Workspaces
hol_dbt_semantic:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: "{{ env_var('SNOWFLAKE_ACCOUNT') }}"
      user: "{{ env_var('SNOWFLAKE_USER') }}"
      role: HOL_ROLE
      database: HOL_DB
      warehouse: HOL_WH
      schema: ANALYTICS
      threads: 4
```

### dbt_project.yml

```yaml
name: 'hol_dbt_semantic'
version: '1.0.0'
config-version: 2

profile: 'hol_dbt_semantic'

model-paths: ["models"]
analysis-paths: ["analyses"]
test-paths: ["tests"]
seed-paths: ["seeds"]
macro-paths: ["macros"]

clean-targets:
  - "target"
  - "dbt_packages"

models:
  hol_dbt_semantic:
    staging:
      +schema: staging
      +materialized: view
    marts:
      +schema: marts
      +materialized: table
```

<!-- HTML SNIPPET: code-block con título -->
```html
<div class="code-block">
  <div class="code-header">
    <span class="code-title">dbt_project.yml</span>
    <button class="copy-btn" onclick="copyCode(this)">Copiar</button>
  </div>
  <pre><code class="language-yaml">name: 'hol_dbt_semantic'
version: '1.0.0'
config-version: 2
profile: 'hol_dbt_semantic'
model-paths: ["models"]
models:
  hol_dbt_semantic:
    staging:
      +schema: staging
      +materialized: view
    marts:
      +schema: marts
      +materialized: table</code></pre>
</div>
```

---

## Paso 2: Crear modelos dbt

### Descripción
Crear modelos de staging (limpieza de datos raw) y marts (métricas de negocio) con tests y documentación.

### Modelo Staging: `models/staging/stg_orders.sql`

```sql
-- models/staging/stg_orders.sql
-- Limpieza y estandarización de la tabla raw de órdenes

WITH source AS (
    SELECT * FROM {{ source('raw', 'orders') }}
),

cleaned AS (
    SELECT
        order_id,
        customer_id,
        TRIM(UPPER(status)) AS order_status,
        order_date::DATE AS order_date,
        amount::NUMBER(12,2) AS order_amount,
        _loaded_at AS ingested_at
    FROM source
    WHERE order_id IS NOT NULL
)

SELECT * FROM cleaned
```

### Modelo Staging: `models/staging/stg_customers.sql`

```sql
-- models/staging/stg_customers.sql
-- Estandarización de datos de clientes

WITH source AS (
    SELECT * FROM {{ source('raw', 'customers') }}
),

cleaned AS (
    SELECT
        customer_id,
        TRIM(first_name) AS first_name,
        TRIM(last_name) AS last_name,
        LOWER(TRIM(email)) AS email,
        created_at::TIMESTAMP_NTZ AS customer_since
    FROM source
    WHERE customer_id IS NOT NULL
)

SELECT * FROM cleaned
```

### Modelo Marts: `models/marts/fct_customer_orders.sql`

```sql
-- models/marts/fct_customer_orders.sql
-- Tabla de hechos: métricas de órdenes por cliente

WITH customers AS (
    SELECT * FROM {{ ref('stg_customers') }}
),

orders AS (
    SELECT * FROM {{ ref('stg_orders') }}
),

customer_orders AS (
    SELECT
        c.customer_id,
        c.first_name,
        c.last_name,
        c.email,
        c.customer_since,
        COUNT(o.order_id) AS total_orders,
        SUM(o.order_amount) AS lifetime_value,
        MIN(o.order_date) AS first_order_date,
        MAX(o.order_date) AS last_order_date,
        AVG(o.order_amount) AS avg_order_value
    FROM customers c
    LEFT JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY 1, 2, 3, 4, 5
)

SELECT
    *,
    DATEDIFF('day', first_order_date, last_order_date) AS customer_tenure_days
FROM customer_orders
```

### Sources: `models/staging/_sources.yml`

```yaml
version: 2

sources:
  - name: raw
    database: HOL_DB
    schema: RAW
    tables:
      - name: orders
        description: "Tabla raw de órdenes ingresada por pipeline"
        loaded_at_field: _loaded_at
        freshness:
          warn_after: {count: 12, period: hour}
          error_after: {count: 24, period: hour}
      - name: customers
        description: "Tabla raw de clientes del sistema fuente"
```

### Schema con tests: `models/staging/_schema.yml`

```yaml
version: 2

models:
  - name: stg_orders
    description: "Órdenes limpias y estandarizadas"
    columns:
      - name: order_id
        description: "Identificador único de la orden"
        tests:
          - unique
          - not_null
      - name: customer_id
        description: "FK al cliente"
        tests:
          - not_null
          - relationships:
              to: ref('stg_customers')
              field: customer_id
      - name: order_status
        tests:
          - accepted_values:
              values: ['COMPLETED', 'PENDING', 'CANCELLED', 'SHIPPED']

  - name: stg_customers
    description: "Clientes estandarizados"
    columns:
      - name: customer_id
        tests:
          - unique
          - not_null
      - name: email
        tests:
          - unique
          - not_null
```

### Schema marts: `models/marts/_schema.yml`

```yaml
version: 2

models:
  - name: fct_customer_orders
    description: "Métricas consolidadas de órdenes por cliente"
    columns:
      - name: customer_id
        description: "PK - Identificador del cliente"
        tests:
          - unique
          - not_null
      - name: lifetime_value
        description: "Valor total histórico de compras"
      - name: total_orders
        description: "Número total de órdenes realizadas"
      - name: avg_order_value
        description: "Valor promedio por orden"
```

<!-- HTML SNIPPET: paso con numeración -->
```html
<div class="step-container">
  <div class="step-number">2</div>
  <div class="step-content">
    <h3>Crear modelos dbt</h3>
    <p>Crea los siguientes archivos en tu proyecto dbt. Los modelos de 
    <strong>staging</strong> limpian datos raw, y los de <strong>marts</strong> 
    calculan métricas de negocio.</p>
  </div>
</div>
```

---

## Paso 3: dbt_semantic_view package

### Descripción
Instalar el paquete `dbt_semantic_view` que permite generar Snowflake Semantic Views automáticamente a partir de definiciones YAML en dbt.

<!-- HTML SNIPPET: warning-box -->
```html
<div class="warning-box">
  <p><strong>Enterprise+ requerido:</strong> Las Semantic Views son una funcionalidad 
  de Snowflake Enterprise Edition. En cuentas Trial, este paso es solo demostrativo.</p>
</div>
```

### packages.yml

```yaml
packages:
  - package: Snowflake-Labs/dbt_semantic_view
    version: [">=0.1.0", "<1.0.0"]
```

### Instalar dependencias

```bash
# Ejecutar desde la terminal del Workspace o vía EXECUTE DBT PROJECT
dbt deps
```

### Definición de Semantic Model: `models/semantic/sem_customer_orders.yml`

```yaml
version: 2

semantic_models:
  - name: sem_customer_orders
    description: "Modelo semántico de órdenes por cliente para análisis con Cortex Analyst"
    model: ref('fct_customer_orders')
    defaults:
      agg_time_dimension: first_order_date

    entities:
      - name: customer
        type: primary
        expr: customer_id

    dimensions:
      - name: customer_name
        type: categorical
        expr: first_name || ' ' || last_name
        description: "Nombre completo del cliente"
      - name: email
        type: categorical
        description: "Email del cliente"
      - name: first_order_date
        type: time
        type_params:
          time_granularity: day
        description: "Fecha de la primera orden"
      - name: last_order_date
        type: time
        type_params:
          time_granularity: day
        description: "Fecha de la última orden"

    measures:
      - name: total_orders
        agg: sum
        expr: total_orders
        description: "Total de órdenes acumuladas"
      - name: total_revenue
        agg: sum
        expr: lifetime_value
        description: "Ingreso total por cliente"
      - name: avg_order_value
        agg: average
        expr: avg_order_value
        description: "Valor promedio de orden"
      - name: customer_count
        agg: count_distinct
        expr: customer_id
        description: "Número de clientes únicos"
```

### Modelo semantic_view: `models/semantic/semantic_customer_view.sql`

```sql
-- models/semantic/semantic_customer_view.sql
-- Este modelo usa la materialización semantic_view del paquete dbt_semantic_view

{{
  config(
    materialized='semantic_view',
    semantic_model='sem_customer_orders'
  )
}}

-- El paquete dbt_semantic_view genera automáticamente la DDL
-- CREATE OR REPLACE SEMANTIC VIEW ... basándose en el semantic model YAML
SELECT * FROM {{ ref('fct_customer_orders') }}
```

### SQL equivalente generado (referencia)

```sql
-- ============================================================
-- SQL generado por dbt_semantic_view (referencia)
-- ============================================================

CREATE OR REPLACE SEMANTIC VIEW hol_db.analytics.semantic_customer_view
  AS SNOWFLAKE.SEMANTIC.SEMANTIC_VIEW(
    '
    name: sem_customer_orders
    tables:
      - name: fct_customer_orders
        base_table:
          database: HOL_DB
          schema: MARTS
          table: FCT_CUSTOMER_ORDERS
        primary_key:
          columns:
            - customer_id
        dimensions:
          - name: customer_name
            expr: first_name || '' '' || last_name
            data_type: VARCHAR
            description: Nombre completo del cliente
          - name: email
            data_type: VARCHAR
            description: Email del cliente
        time_dimensions:
          - name: first_order_date
            data_type: DATE
            description: Fecha de la primera orden
          - name: last_order_date
            data_type: DATE
            description: Fecha de la última orden
        measures:
          - name: total_orders
            expr: SUM(total_orders)
            data_type: NUMBER
            description: Total de órdenes acumuladas
          - name: total_revenue
            expr: SUM(lifetime_value)
            data_type: NUMBER(12,2)
            description: Ingreso total por cliente
          - name: avg_order_value
            expr: AVG(avg_order_value)
            data_type: NUMBER(12,2)
            description: Valor promedio de orden
          - name: customer_count
            expr: COUNT(DISTINCT customer_id)
            data_type: NUMBER
            description: Número de clientes únicos
    '
  );
```

<!-- HTML SNIPPET: info-box semántico -->
```html
<div class="info-box">
  <p><strong>Beneficio clave:</strong> Al definir el semantic model en dbt, la Semantic View 
  se mantiene sincronizada con los cambios en tus modelos. Cada <code>dbt run</code> 
  regenera la vista semántica, asegurando consistencia entre transformaciones y la capa 
  de análisis de Cortex Analyst.</p>
</div>
```

---

## Paso 4: Git-based PR Workflow

### Descripción
Implementar un flujo de trabajo basado en Git con branches y Pull Requests para cambios controlados en los modelos dbt.

### Flujo de trabajo en Snowflake Workspaces

```
1. Desde Snowsight → Workspace del proyecto dbt
2. Click en el branch indicator (esquina superior)
3. "Create New Branch" → nombre: feature/add-revenue-metrics
4. Realizar cambios en los modelos
5. Stage changes (seleccionar archivos modificados)
6. Commit con mensaje descriptivo
7. Push branch al remoto
8. Crear Pull Request desde la UI de Git (GitHub/GitLab)
```

### SQL: Sincronizar cambios desde Git

```sql
-- ============================================================
-- PASO 4: Sincronizar repositorio Git y ejecutar proyecto
-- ============================================================

-- 4.1 Fetch últimos cambios del repositorio
ALTER GIT REPOSITORY hol_db.analytics.dbt_repo FETCH;

-- 4.2 Listar branches disponibles
SHOW GIT BRANCHES IN hol_db.analytics.dbt_repo;

-- 4.3 Ejecutar dbt project desde un branch específico
-- (Enterprise+ con dbt Projects on Snowflake)
EXECUTE DBT PROJECT hol_db.analytics.hol_dbt_semantic
  FROM @hol_db.analytics.dbt_repo/branches/main
  WITH PROFILES_YML = 'profiles.yml';
```

### Ejemplo de mensaje de commit

```
feat(marts): add customer lifetime value metrics

- Added fct_customer_orders model with LTV calculation
- Added semantic model for Cortex Analyst integration
- Added tests for unique/not_null constraints
```

<!-- HTML SNIPPET: best-practice box -->
```html
<div class="best-practice-box">
  <h4>Mejores prácticas para PRs en dbt</h4>
  <ul>
    <li>Un PR por feature o fix - mantener cambios pequeños y revisables</li>
    <li>Incluir cambios de schema.yml (tests/docs) junto con el modelo</li>
    <li>Ejecutar <code>dbt test</code> antes de crear el PR</li>
    <li>Usar convención de commits: <code>feat:</code>, <code>fix:</code>, <code>docs:</code></li>
    <li>Solicitar review de al menos un data engineer del equipo</li>
  </ul>
</div>
```

---

## Paso 5: Scheduling con Snowflake TASKs

### Descripción
Crear un TASK de Snowflake que ejecute `dbt run` de forma programada, asegurando que las transformaciones y semantic views se actualicen automáticamente.

<!-- HTML SNIPPET: info-box -->
```html
<div class="info-box">
  <p><strong>Disponible en Trial:</strong> Los Snowflake TASKs funcionan en todas las 
  ediciones. Puedes crear y probar TASKs incluso en cuentas Trial, aunque el 
  <code>EXECUTE DBT PROJECT</code> dentro del TASK requiere Enterprise+.</p>
</div>
```

### SQL: Crear TASK para ejecución programada

```sql
-- ============================================================
-- PASO 5: Scheduling con Snowflake TASKs
-- ============================================================

-- 5.1 Crear TASK que ejecuta dbt project cada 6 horas
CREATE OR REPLACE TASK hol_db.analytics.task_dbt_run
  WAREHOUSE = HOL_WH
  SCHEDULE = 'USING CRON 0 */6 * * * America/Los_Angeles'
  COMMENT = 'Ejecuta dbt project para actualizar modelos y semantic views'
AS
  EXECUTE DBT PROJECT hol_db.analytics.hol_dbt_semantic
    FROM @hol_db.analytics.dbt_repo/branches/main
    WITH PROFILES_YML = 'profiles.yml';

-- 5.2 Ejemplos de CRON syntax
-- Cada hora:          'USING CRON 0 * * * * UTC'
-- Cada 6 horas:       'USING CRON 0 */6 * * * UTC'
-- Diario a las 6 AM:  'USING CRON 0 6 * * * America/Mexico_City'
-- Lun-Vie 8 AM:       'USING CRON 0 8 * * 1-5 America/Mexico_City'
-- Cada 30 minutos:    'USING CRON */30 * * * * UTC'

-- 5.3 Activar el TASK
ALTER TASK hol_db.analytics.task_dbt_run RESUME;

-- 5.4 Ejecutar manualmente para probar
EXECUTE TASK hol_db.analytics.task_dbt_run;

-- 5.5 (Opcional) TASK con dependencia - ejecutar tests después del run
CREATE OR REPLACE TASK hol_db.analytics.task_dbt_test
  WAREHOUSE = HOL_WH
  AFTER hol_db.analytics.task_dbt_run
  COMMENT = 'Ejecuta dbt test después del run para validar calidad'
AS
  EXECUTE DBT PROJECT hol_db.analytics.hol_dbt_semantic
    FROM @hol_db.analytics.dbt_repo/branches/main
    WITH PROFILES_YML = 'profiles.yml'
    ARGS = 'test';

ALTER TASK hol_db.analytics.task_dbt_test RESUME;
```

### Diagrama de ejecución (TASK Graph)

```
┌─────────────────────────┐
│   task_dbt_run          │
│   CRON: 0 */6 * * *    │
│   → dbt run             │
└───────────┬─────────────┘
            │ (AFTER)
            ▼
┌─────────────────────────┐
│   task_dbt_test         │
│   → dbt test            │
└─────────────────────────┘
```

<!-- HTML SNIPPET: schedule visualization -->
```html
<div class="schedule-box">
  <h4>Referencia rápida: CRON Syntax</h4>
  <table class="cron-table">
    <thead>
      <tr>
        <th>Campo</th><th>Valores</th><th>Descripción</th>
      </tr>
    </thead>
    <tbody>
      <tr><td>Minuto</td><td>0-59</td><td>Minuto de la hora</td></tr>
      <tr><td>Hora</td><td>0-23</td><td>Hora del día</td></tr>
      <tr><td>Día del mes</td><td>1-31</td><td>Día del mes</td></tr>
      <tr><td>Mes</td><td>1-12</td><td>Mes del año</td></tr>
      <tr><td>Día de semana</td><td>0-6 (Dom=0)</td><td>Día de la semana</td></tr>
    </tbody>
  </table>
</div>
```

---

## Verificación

### SQL: Verificar objetos creados por dbt

```sql
-- ============================================================
-- VERIFICACIÓN: Confirmar que todo se creó correctamente
-- ============================================================

-- V1: Verificar tablas/vistas creadas por dbt
SHOW OBJECTS IN SCHEMA hol_db.analytics;
SHOW OBJECTS IN SCHEMA hol_db.staging;
SHOW OBJECTS IN SCHEMA hol_db.marts;

-- V2: Verificar que la Semantic View existe (Enterprise+)
SHOW SEMANTIC VIEWS IN SCHEMA hol_db.analytics;

-- V3: Describir la semantic view
DESCRIBE SEMANTIC VIEW hol_db.analytics.semantic_customer_view;

-- V4: Verificar datos en el modelo marts
SELECT
    COUNT(*) AS total_customers,
    SUM(total_orders) AS all_orders,
    ROUND(AVG(lifetime_value), 2) AS avg_ltv
FROM hol_db.marts.fct_customer_orders;

-- V5: Verificar historial de ejecución del TASK
SELECT
    name,
    state,
    scheduled_time,
    completed_time,
    error_code,
    error_message
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    TASK_NAME => 'TASK_DBT_RUN',
    SCHEDULED_TIME_RANGE_START => DATEADD('hour', -24, CURRENT_TIMESTAMP())
))
ORDER BY scheduled_time DESC
LIMIT 10;

-- V6: Verificar ejecución del dbt project
SELECT *
FROM TABLE(INFORMATION_SCHEMA.DBT_PROJECT_RUN_HISTORY())
ORDER BY start_time DESC
LIMIT 5;

-- V7: Verificar que la semantic view responde queries
-- (Usar con Cortex Analyst o directamente)
SELECT * FROM hol_db.analytics.semantic_customer_view LIMIT 5;
```

<!-- HTML SNIPPET: verificación checklist -->
```html
<div class="verification-checklist">
  <h4>Checklist de verificación</h4>
  <ul class="checklist">
    <li><input type="checkbox"> Modelos staging creados como VIEWs</li>
    <li><input type="checkbox"> Modelo marts creado como TABLE</li>
    <li><input type="checkbox"> Semantic View generada correctamente</li>
    <li><input type="checkbox"> TASK creado y en estado STARTED</li>
    <li><input type="checkbox"> TASK ejecutado al menos una vez sin errores</li>
    <li><input type="checkbox"> Datos accesibles via Semantic View</li>
  </ul>
</div>
```

---

## Troubleshooting

### Error: Autenticación Git fallida

```
Error: Authentication failed for repository
```

**Causa:** Token de acceso personal (PAT) expirado o permisos insuficientes.

**Solución:**
```sql
-- Recrear el secreto con un token válido
CREATE OR REPLACE SECRET git_secret
  TYPE = password
  USERNAME = '<github_username>'
  PASSWORD = '<new_github_pat_token>';

-- El PAT necesita permisos: repo (Full control of private repositories)
-- Para GitHub: Settings → Developer Settings → Personal Access Tokens → Fine-grained
-- Permisos mínimos: Contents (Read), Metadata (Read)
```

### Error: Package resolution failed

```
Error: Could not find package 'Snowflake-Labs/dbt_semantic_view'
```

**Causa:** El paquete no se encuentra en el registry o hay incompatibilidad de versiones.

**Solución:**
```yaml
# Verificar packages.yml - usar la versión correcta
packages:
  - package: Snowflake-Labs/dbt_semantic_view
    version: [">=0.1.0", "<1.0.0"]

# Alternativa: instalar desde Git directamente
packages:
  - git: "https://github.com/Snowflake-Labs/dbt_semantic_view.git"
    revision: main
```

```bash
# Limpiar cache y reinstalar
dbt clean
dbt deps
```

### Error: TASK falla en ejecución

```
Error: Task TASK_DBT_RUN failed with error: Insufficient privileges
```

**Causa:** El rol del TASK no tiene permisos para ejecutar el dbt project.

**Solución:**
```sql
-- Verificar owner del TASK
SHOW TASKS LIKE 'TASK_DBT_RUN' IN SCHEMA hol_db.analytics;

-- Otorgar permisos necesarios
GRANT USAGE ON DATABASE HOL_DB TO ROLE HOL_ROLE;
GRANT USAGE ON ALL SCHEMAS IN DATABASE HOL_DB TO ROLE HOL_ROLE;
GRANT CREATE TABLE ON SCHEMA hol_db.marts TO ROLE HOL_ROLE;
GRANT CREATE VIEW ON SCHEMA hol_db.staging TO ROLE HOL_ROLE;
GRANT USAGE ON WAREHOUSE HOL_WH TO ROLE HOL_ROLE;

-- Permitir ejecución de TASKs
GRANT EXECUTE TASK ON ACCOUNT TO ROLE HOL_ROLE;
```

### Error: Semantic View no se genera

```
Error: Unsupported materialization 'semantic_view'
```

**Causa:** El paquete `dbt_semantic_view` no está instalado o la versión de dbt es incompatible.

**Solución:**
```bash
# Verificar que el paquete está instalado
dbt deps --check

# Verificar versión de dbt (requiere >= 1.7)
dbt --version
```

```sql
-- Verificar que la edición soporta semantic views
SELECT SYSTEM$GET_SNOWFLAKE_PLATFORM_INFO();
-- Debe mostrar Edition: Enterprise o superior
```

### Error: Branch no encontrado

```
Error: Git reference 'branches/feature/xyz' not found
```

**Causa:** El branch no existe en el remoto o no se ha hecho fetch.

**Solución:**
```sql
-- Sincronizar con remoto
ALTER GIT REPOSITORY hol_db.analytics.dbt_repo FETCH;

-- Listar branches disponibles
SHOW GIT BRANCHES IN hol_db.analytics.dbt_repo;

-- Verificar el nombre exacto (case-sensitive)
LIST @hol_db.analytics.dbt_repo/branches/;
```

### Error: TASK auto-suspendido

```
Warning: Task has been auto-suspended after consecutive failures
```

**Causa:** El TASK falló múltiples veces consecutivas (default: 10 veces).

**Solución:**
```sql
-- Verificar historial de errores
SELECT name, state, error_message, scheduled_time
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    TASK_NAME => 'TASK_DBT_RUN'
))
WHERE state = 'FAILED'
ORDER BY scheduled_time DESC
LIMIT 5;

-- Corregir el error subyacente, luego reactivar
ALTER TASK hol_db.analytics.task_dbt_run RESUME;

-- Opcional: ajustar umbral de auto-suspensión
ALTER TASK hol_db.analytics.task_dbt_run
  SET SUSPEND_TASK_AFTER_NUM_FAILURES = 5;
```

<!-- HTML SNIPPET: troubleshooting-box -->
```html
<div class="troubleshooting-box">
  <h4>Errores comunes y soluciones rápidas</h4>
  <table class="troubleshooting-table">
    <thead>
      <tr><th>Síntoma</th><th>Causa probable</th><th>Acción</th></tr>
    </thead>
    <tbody>
      <tr>
        <td>Authentication failed</td>
        <td>PAT expirado</td>
        <td>Regenerar token, recrear SECRET</td>
      </tr>
      <tr>
        <td>Package not found</td>
        <td>Nombre/versión incorrecta</td>
        <td>Verificar packages.yml, dbt clean + deps</td>
      </tr>
      <tr>
        <td>Insufficient privileges</td>
        <td>Permisos del rol</td>
        <td>GRANT permisos necesarios al rol del TASK</td>
      </tr>
      <tr>
        <td>Materialization unsupported</td>
        <td>Paquete no instalado</td>
        <td>dbt deps, verificar versión dbt >= 1.7</td>
      </tr>
      <tr>
        <td>Branch not found</td>
        <td>No se hizo FETCH</td>
        <td>ALTER GIT REPOSITORY ... FETCH</td>
      </tr>
      <tr>
        <td>TASK auto-suspended</td>
        <td>Fallos consecutivos</td>
        <td>Corregir error, RESUME TASK</td>
      </tr>
    </tbody>
  </table>
</div>
```

---

## Limpieza (Opcional)

```sql
-- ============================================================
-- LIMPIEZA: Remover objetos creados en este módulo
-- ============================================================

-- Suspender y eliminar TASKs
ALTER TASK IF EXISTS hol_db.analytics.task_dbt_test SUSPEND;
ALTER TASK IF EXISTS hol_db.analytics.task_dbt_run SUSPEND;
DROP TASK IF EXISTS hol_db.analytics.task_dbt_test;
DROP TASK IF EXISTS hol_db.analytics.task_dbt_run;

-- Eliminar semantic view
DROP SEMANTIC VIEW IF EXISTS hol_db.analytics.semantic_customer_view;

-- Eliminar objetos dbt
DROP TABLE IF EXISTS hol_db.marts.fct_customer_orders;
DROP VIEW IF EXISTS hol_db.staging.stg_orders;
DROP VIEW IF EXISTS hol_db.staging.stg_customers;

-- Eliminar repositorio Git
DROP GIT REPOSITORY IF EXISTS hol_db.analytics.dbt_repo;
DROP SECRET IF EXISTS git_secret;
DROP API INTEGRATION IF EXISTS git_api_integration;
```
