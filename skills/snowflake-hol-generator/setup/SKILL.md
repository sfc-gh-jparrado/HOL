# Sub-Skill: Setup Inicial

## Metadata
- **Parent**: snowflake-hol-generator
- **Name**: setup
- **Obligatorio**: ✅ SÍ (siempre ejecutar primero)
- **Duración**: ~8 minutos

---

## 🎯 Objetivo

Crear la infraestructura base del laboratorio:
- Database y schemas
- Warehouse
- Verificar capacidades de la cuenta (trial vs enterprise)
- Cargar datos sintéticos base

---

## Variables a Definir

```
[CLIENTE]           = Nombre del cliente (ej: ACME)
[CLIENTE_HOL]       = Nombre de la base de datos (ej: ACME_HOL)
[CLIENTE_WH]        = Nombre del warehouse (ej: ACME_WH)
[INDUSTRIA]         = Industria del cliente
```

---

## SQL Template: Setup Completo

```sql
-- =====================================================
-- [CLIENTE] HANDS-ON LAB
-- MÓDULO 0: SETUP INICIAL
-- Duración: ~8 minutos
-- =====================================================

-- ===========================================
-- PASO 0.1: VERIFICAR CAPACIDADES DE LA CUENTA
-- ===========================================

-- Verificar si es cuenta trial (buscar en account parameters)
SHOW PARAMETERS LIKE 'ACCOUNT_LOCATOR' IN ACCOUNT;

-- Verificar Cortex AI disponible
SELECT SNOWFLAKE.CORTEX.SENTIMENT('test') AS test_cortex;
-- Si falla, Cortex no está habilitado

-- Verificar región (algunas funciones varían por región)
SELECT CURRENT_REGION();

-- ===========================================
-- PASO 0.2: CREAR INFRAESTRUCTURA BASE
-- ===========================================

-- Crear base de datos principal
CREATE OR REPLACE DATABASE [CLIENTE_HOL]
    COMMENT = 'Base de datos para Hands-on Lab de [CLIENTE]';

-- Crear schemas organizados
CREATE OR REPLACE SCHEMA [CLIENTE_HOL].RAW_DATA
    COMMENT = 'Datos crudos importados';
    
CREATE OR REPLACE SCHEMA [CLIENTE_HOL].ANALYTICS
    COMMENT = 'Vistas analíticas y modelos semánticos';
    
CREATE OR REPLACE SCHEMA [CLIENTE_HOL].AGENTS
    COMMENT = 'Cortex Agents y configuraciones de IA';

-- Crear warehouse optimizado para demos
CREATE OR REPLACE WAREHOUSE [CLIENTE_WH]
    WITH 
    WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Warehouse para laboratorio [CLIENTE]';

-- Activar warehouse
USE WAREHOUSE [CLIENTE_WH];
USE DATABASE [CLIENTE_HOL];
USE SCHEMA RAW_DATA;

-- ===========================================
-- PASO 0.3: VERIFICACIÓN DE SETUP
-- ===========================================

-- Verificar objetos creados
SHOW DATABASES LIKE '[CLIENTE]%';
SHOW WAREHOUSES LIKE '[CLIENTE]%';
SHOW SCHEMAS IN DATABASE [CLIENTE_HOL];

-- Verificar estado del warehouse
SELECT 
    NAME,
    STATE,
    SIZE,
    AUTO_SUSPEND,
    AUTO_RESUME
FROM TABLE(INFORMATION_SCHEMA.WAREHOUSE_METERING_HISTORY(
    DATE_RANGE_START => DATEADD('hour', -1, CURRENT_TIMESTAMP())
))
WHERE WAREHOUSE_NAME = '[CLIENTE_WH]';

SELECT '✅ Setup completado exitosamente' AS STATUS;
```

---

## Verificaciones Post-Setup

### Query de Verificación
```sql
-- Ejecutar después del setup para confirmar todo está listo
SELECT 
    'Database' AS COMPONENTE, 
    DATABASE_NAME AS NOMBRE,
    CREATED AS CREADO
FROM INFORMATION_SCHEMA.DATABASES 
WHERE DATABASE_NAME = '[CLIENTE_HOL]'

UNION ALL

SELECT 
    'Schema' AS COMPONENTE,
    SCHEMA_NAME AS NOMBRE,
    CREATED AS CREADO
FROM [CLIENTE_HOL].INFORMATION_SCHEMA.SCHEMATA
WHERE SCHEMA_NAME IN ('RAW_DATA', 'ANALYTICS', 'AGENTS')

ORDER BY COMPONENTE, NOMBRE;
```

### Resultado Esperado
```
| COMPONENTE | NOMBRE      | CREADO              |
|------------|-------------|---------------------|
| Database   | [CLIENTE]_HOL | 2024-XX-XX ...     |
| Schema     | AGENTS      | 2024-XX-XX ...      |
| Schema     | ANALYTICS   | 2024-XX-XX ...      |
| Schema     | RAW_DATA    | 2024-XX-XX ...      |
```

---

## Detección de Cuenta Trial

### Indicadores de Cuenta Trial
```sql
-- Método 1: Verificar edición de cuenta
SELECT SYSTEM$GET_TAG('snowflake.account.edition', CURRENT_ACCOUNT(), 'account');

-- Método 2: Verificar créditos (trial tiene límite)
SELECT * FROM SNOWFLAKE.ORGANIZATION_USAGE.REMAINING_BALANCE_DAILY;

-- Método 3: Intentar función avanzada
-- Si esto falla con "Unknown function", es trial con restricciones
SELECT SNOWFLAKE.CORTEX.COMPLETE('llama3.2-3b', 'test');
```

### Ajustes para Trial

Si se detecta cuenta trial:
1. ❌ NO usar `SYSTEM$CORTEX_ANALYST_FAST_GENERATION`
2. ✅ Usar Snowsight UI para Semantic Views
3. ✅ Usar Snowsight UI para Cortex Agents
4. ⚠️ Limitar Time Travel a 1 día (no 90)
5. ⚠️ Omitir Data Sharing si no está configurado

---

## Info Boxes para el HTML

### Tip: Warehouse Auto-Suspend
```html
<div class="info-box tip">
    <span class="info-icon">💡</span>
    <div class="info-content">
        <h4>Auto-Suspend Optimizado</h4>
        <p>El warehouse se suspende automáticamente después de 60 segundos de inactividad, 
        minimizando costos. Se reactiva automáticamente cuando ejecutas una query.</p>
    </div>
</div>
```

### Warning: Cuenta Trial
```html
<div class="info-box warning">
    <span class="info-icon">⚠️</span>
    <div class="info-content">
        <h4>Nota para Cuentas Trial</h4>
        <p>Algunas funciones avanzadas pueden no estar disponibles en cuentas trial. 
        Este laboratorio está diseñado para funcionar completamente en trial, usando 
        alternativas de Snowsight UI cuando sea necesario.</p>
    </div>
</div>
```

---

## Cleanup Parcial (si se necesita reiniciar)

```sql
-- Para reiniciar solo el setup (mantiene warehouse)
DROP DATABASE IF EXISTS [CLIENTE_HOL];

-- Para reiniciar completamente
DROP DATABASE IF EXISTS [CLIENTE_HOL];
DROP WAREHOUSE IF EXISTS [CLIENTE_WH];
```

---

## Siguiente Paso

Después del setup, cargar datos sintéticos según la industria:
- **Load**: `../industries/[INDUSTRIA]/SKILL.md`
