# Referencia: Limitaciones de Cuentas Trial

## Metadata
- **Parent**: snowflake-hol-generator
- **Name**: references/trial-limitations
- **Última actualización**: 2024

---

## 📋 Resumen de Limitaciones

Las cuentas trial de Snowflake tienen restricciones importantes que afectan el diseño de HOLs. Esta referencia detalla cada limitación y su alternativa.

---

## ✅ FUNCIONA en Trial

| Característica | Notas |
|---------------|-------|
| Warehouses (hasta XL) | ✅ Todos los tamaños disponibles |
| SQL estándar | ✅ Sin restricciones |
| Time Travel | ✅ Limitado a 24h (vs 90 días Enterprise) |
| Clone (Zero-copy) | ✅ Funciona completamente |
| UNDROP | ✅ Funciona completamente |
| Dynamic Tables | ✅ Sin restricciones |
| Cortex AI Functions | ✅ SENTIMENT, CLASSIFY_TEXT, SUMMARIZE, TRANSLATE, COMPLETE |
| Snowpark Python | ✅ Sin restricciones |
| Streamlit in Snowflake | ✅ Sin restricciones |
| Marketplace (Free) | ✅ Datasets gratuitos disponibles |
| Data Sharing | ✅ Recibir datos compartidos |
| Stages (Internal) | ✅ Sin restricciones |
| Tasks | ✅ Sin restricciones |
| Streams | ✅ Sin restricciones |
| UDFs / Stored Procedures | ✅ Sin restricciones |
| Views / Materialized Views | ✅ Sin restricciones |

---

## ⚠️ LIMITADO en Trial

| Característica | Limitación | Alternativa |
|---------------|------------|-------------|
| Time Travel | Solo 24 horas | Usar offsets cortos en demos |
| Storage | ~$400 créditos totales | Datos sintéticos pequeños |
| Compute | ~$400 créditos totales | Warehouse XS para demos |
| Regiones | Limitadas | Usar región disponible |
| Support | Solo community | Documentación y foros |

---

## ❌ NO DISPONIBLE en Trial

### 1. Snowflake Intelligence via SQL

```sql
-- ❌ ESTO NO FUNCIONA EN TRIAL
SELECT SNOWFLAKE.CORTEX.SYSTEM$CORTEX_ANALYST_FAST_GENERATION(
    DATABASE => 'MI_DB',
    SCHEMA => 'MI_SCHEMA',
    TABLES => ['TABLA1', 'TABLA2']
);
```

**Alternativa**: Usar Snowsight UI → Create Semantic View (Autopilot)

### 2. CREATE SEMANTIC VIEW via SQL (limitado)

```sql
-- ⚠️ PUEDE FALLAR EN TRIAL - Usar UI en su lugar
CREATE SEMANTIC VIEW mi_semantic_view AS ...
```

**Alternativa**: 
1. Crear vista SQL estándar primero
2. Ir a Snowsight → Data → Navigate to the view
3. Click en "..." → Create Semantic View
4. Usar Autopilot para generar automáticamente

### 3. CREATE AGENT via SQL (limitado)

```sql
-- ⚠️ PUEDE FALLAR EN TRIAL - Usar UI en su lugar
CREATE AGENT mi_agente FROM SPECIFICATION $$ ... $$
```

**Alternativa**:
1. Ir a Snowsight → AI & ML → Cortex Agents
2. Click en "+ Create"
3. Configurar via interfaz gráfica

### 4. Marketplace Paid Listings

```
❌ Datasets de pago requieren configuración de billing
```

**Alternativa**: Usar solo datasets FREE del Marketplace

### 5. Private Data Sharing

```
❌ Compartir datos a otras cuentas tiene restricciones
```

**Alternativa**: Demostrar recepción de datos, no envío

### 6. External Functions

```sql
-- ❌ Requiere configuración de API Integration
CREATE EXTERNAL FUNCTION ...
```

**Alternativa**: Usar Cortex AI functions nativas

---

## 🔧 Detección de Tipo de Cuenta

Usar este query para detectar si es trial:

```sql
-- Detectar tipo de cuenta
SELECT 
    CURRENT_ACCOUNT() AS CUENTA,
    CURRENT_REGION() AS REGION,
    SYSTEM$GET_SNOWFLAKE_PLATFORM_INFO() AS INFO_PLATAFORMA;

-- Verificar edición
SELECT 
    PARSE_JSON(SYSTEM$GET_SNOWFLAKE_PLATFORM_INFO()):edition::STRING AS EDICION;
```

---

## 📊 Ajustes Recomendados para HOL Trial

### Tamaño de Datos
```sql
-- En lugar de millones de registros, usar:
-- Ventas: ~5,000 - 10,000 registros
-- Clientes: ~500 - 1,000 registros
-- Productos: ~50 - 200 registros
```

### Warehouse Size
```sql
-- Usar warehouse pequeño para conservar créditos
CREATE WAREHOUSE [CLIENTE]_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE;
```

### Time Travel Demo
```sql
-- Usar offsets cortos que funcionen en trial
SELECT * FROM tabla AT(OFFSET => -60*30);  -- 30 minutos, no días
```

### Evitar Features Enterprise
```sql
-- NO USAR en trial:
-- - Row Access Policies (Enterprise)
-- - Data Masking (Enterprise) 
-- - Multi-cluster warehouses (Enterprise)
-- - 90-day Time Travel (Enterprise)
-- - Failover/Failback (Business Critical)
```

---

## 🎯 Checklist Pre-HOL para Cuentas Trial

- [ ] Verificar créditos disponibles (~$400 iniciales)
- [ ] Crear warehouse XSMALL con auto-suspend 60s
- [ ] Preparar datos sintéticos pequeños (<10K registros)
- [ ] Usar Snowsight UI para Semantic Views y Agents
- [ ] Solo datasets FREE del Marketplace
- [ ] Time Travel con offsets de minutos, no días
- [ ] Evitar features Enterprise-only
- [ ] Tener documentación/screenshots como respaldo

---

## 🚨 Mensajes de Error Comunes

### Error: Function not found
```
Error: SQL compilation error: Unknown function SYSTEM$CORTEX_ANALYST_FAST_GENERATION
```
**Solución**: Usar Snowsight UI para crear Semantic Views

### Error: Insufficient privileges
```
Error: SQL access control error: Insufficient privileges to operate on...
```
**Solución**: Verificar que estás usando el rol correcto (ACCOUNTADMIN para setup)

### Error: Feature not available
```
Error: Feature 'X' is not available for your account edition
```
**Solución**: Buscar alternativa compatible con trial

---

## 📚 Recursos Adicionales

- [Snowflake Trial Documentation](https://docs.snowflake.com/en/user-guide/admin-trial-account)
- [Feature Matrix by Edition](https://docs.snowflake.com/en/user-guide/intro-editions)
- [Cortex AI Functions](https://docs.snowflake.com/en/user-guide/snowflake-cortex/llm-functions)
