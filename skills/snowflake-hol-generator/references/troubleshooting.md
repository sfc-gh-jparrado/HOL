# Referencia: Troubleshooting

## Metadata
- **Parent**: snowflake-hol-generator
- **Name**: references/troubleshooting
- **Última actualización**: 2024

---

## 🔧 Errores Comunes y Soluciones

Esta referencia documenta los errores más frecuentes en HOLs y sus soluciones.

---

## 🗄️ Errores de SQL

### Error: Object does not exist
```
SQL compilation error: Object 'DATABASE.SCHEMA.TABLE' does not exist or not authorized.
```

**Causas**:
1. La tabla/vista no fue creada
2. Contexto incorrecto (database/schema)
3. Permisos insuficientes

**Soluciones**:
```sql
-- Verificar contexto actual
SELECT CURRENT_DATABASE(), CURRENT_SCHEMA(), CURRENT_ROLE();

-- Verificar si el objeto existe
SHOW TABLES LIKE '%NOMBRE%' IN SCHEMA [DATABASE].[SCHEMA];

-- Establecer contexto correcto
USE DATABASE [CLIENTE_HOL];
USE SCHEMA RAW;
USE ROLE ACCOUNTADMIN;
```

### Error: Invalid identifier
```
SQL compilation error: invalid identifier 'COLUMNA'
```

**Causas**:
1. La columna no existe en la tabla
2. Typo en el nombre
3. Case-sensitivity (si se usaron comillas al crear)

**Soluciones**:
```sql
-- Ver columnas de la tabla
DESCRIBE TABLE [TABLA];

-- Si la columna tiene mayúsculas/minúsculas específicas
SELECT "Columna_Con_Case" FROM tabla;
```

### Error: ARRAY_CONSTRUCT in VALUES
```
SQL compilation error: ARRAY_CONSTRUCT is not supported in VALUES clause
```

**Causa**: No se puede usar ARRAY_CONSTRUCT dentro de INSERT ... VALUES

**Solución**: Usar SELECT UNION ALL
```sql
-- ❌ No funciona
INSERT INTO tabla VALUES (1, ARRAY_CONSTRUCT('a', 'b'));

-- ✅ Funciona
INSERT INTO tabla
SELECT 1, ARRAY_CONSTRUCT('a', 'b')
UNION ALL
SELECT 2, ARRAY_CONSTRUCT('c', 'd');
```

### Error: Ambiguous column reference
```
SQL compilation error: ambiguous column name 'ID'
```

**Causa**: Múltiples tablas en JOIN tienen columna con mismo nombre

**Solución**: Usar alias de tabla
```sql
SELECT 
    t1.ID,      -- Especificar tabla
    t2.ID AS ID_OTRA,
    t1.NOMBRE
FROM TABLA1 t1
JOIN TABLA2 t2 ON t1.ID = t2.TABLA1_ID;
```

---

## 🧠 Errores de Semantic View / Agent

### Error: Function not available
```
Unknown function SYSTEM$CORTEX_ANALYST_FAST_GENERATION
```

**Causa**: Función no disponible en cuentas trial

**Solución**: Usar Snowsight UI
1. Ir a Data → Navigate to vista
2. Click "..." → Create Semantic View
3. Usar Autopilot

### Error: Semantic View creation failed
```
Error creating semantic view: analysis failed
```

**Causas**:
1. Vista tiene tipos de datos no soportados
2. Vista demasiado compleja
3. Nombres de columnas problemáticos

**Soluciones**:
```sql
-- Simplificar la vista base
CREATE OR REPLACE VIEW V_SIMPLE AS
SELECT 
    COLUMN1::VARCHAR AS COL1,     -- Castear a tipos simples
    COLUMN2::NUMBER AS COL2,
    COLUMN3::DATE AS COL3
FROM TABLA_ORIGINAL;

-- Evitar nombres con caracteres especiales
-- ❌ "Año-Mes", "%_Cambio"
-- ✅ ANIO_MES, PCT_CAMBIO
```

### Error: Agent cannot answer question
```
I cannot answer this question based on the available data.
```

**Causas**:
1. La pregunta no mapea a columnas disponibles
2. El modelo semántico no tiene las métricas necesarias
3. Terminología diferente

**Soluciones**:
- Reformular pregunta usando nombres de columnas exactos
- Agregar sinónimos en el Semantic View
- Verificar que las métricas existen

---

## 📊 Errores de Streamlit

### Error: Session not found
```
SnowparkSessionException: Session has been closed
```

**Causa**: Sesión expirada o no inicializada correctamente

**Solución**:
```python
# Streamlit in Snowflake
from snowflake.snowpark.context import get_active_session
session = get_active_session()

# Streamlit local (NO en SiS)
# conn = st.connection("snowflake")
# session = conn.session()
```

### Error: Module not found
```
ModuleNotFoundError: No module named 'pandas'
```

**Causa**: Paquete no instalado en el ambiente

**Solución**: Agregar en el panel de Packages de Streamlit in Snowflake
- pandas
- altair
- snowflake-snowpark-python

### Error: Query timeout
```
OperationalError: Query execution was canceled
```

**Causa**: Query muy pesada o warehouse suspendido

**Solución**:
```python
# Usar cache para evitar re-ejecución
@st.cache_data(ttl=600)  # Cache 10 minutos
def cargar_datos():
    return session.sql("SELECT * FROM tabla LIMIT 1000").to_pandas()

# O usar warehouse más grande
session.sql("USE WAREHOUSE LARGER_WH").collect()
```

---

## ⏰ Errores de Dynamic Tables

### Error: Refresh failed
```
DYNAMIC_TABLE_REFRESH_FAILED: Refresh operation failed
```

**Causas**:
1. Query de la DT tiene error
2. Tablas fuente no existen
3. Permisos insuficientes

**Solución**:
```sql
-- Ver errores de refresh
SELECT 
    NAME,
    STATE,
    STATE_MESSAGE,
    REFRESH_START_TIME
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY())
WHERE NAME = 'MI_DYNAMIC_TABLE'
ORDER BY REFRESH_START_TIME DESC
LIMIT 5;

-- Probar la query manualmente
SELECT * FROM (
    -- Copiar la definición de la DT aquí
) LIMIT 10;
```

### Error: Target lag too small
```
TARGET_LAG must be at least 1 minute
```

**Causa**: Intentando usar lag menor a 1 minuto

**Solución**:
```sql
-- Mínimo es 1 minuto
CREATE DYNAMIC TABLE dt
    TARGET_LAG = '1 minute'  -- No menos de esto
    ...
```

---

## 🔐 Errores de Permisos

### Error: Insufficient privileges
```
SQL access control error: Insufficient privileges
```

**Solución**:
```sql
-- Verificar rol actual
SELECT CURRENT_ROLE();

-- Cambiar a ACCOUNTADMIN para setup
USE ROLE ACCOUNTADMIN;

-- Otorgar permisos específicos
GRANT USAGE ON DATABASE [DB] TO ROLE [ROL];
GRANT USAGE ON SCHEMA [DB].[SCHEMA] TO ROLE [ROL];
GRANT SELECT ON ALL TABLES IN SCHEMA [DB].[SCHEMA] TO ROLE [ROL];
```

---

## 🌐 Errores de Marketplace

### Error: Listing not available
```
The requested listing is not available in your region
```

**Causa**: El dataset no está disponible en la región de la cuenta

**Solución**: Buscar dataset alternativo disponible en tu región

### Error: Cannot get paid listing
```
Billing must be configured to access paid listings
```

**Causa**: Cuenta trial sin billing configurado

**Solución**: Usar solo datasets FREE

---

## 📋 Checklist de Debugging

1. **Verificar contexto**:
   ```sql
   SELECT CURRENT_DATABASE(), CURRENT_SCHEMA(), CURRENT_ROLE(), CURRENT_WAREHOUSE();
   ```

2. **Verificar objetos existen**:
   ```sql
   SHOW TABLES IN SCHEMA [DB].[SCHEMA];
   SHOW VIEWS IN SCHEMA [DB].[SCHEMA];
   ```

3. **Verificar permisos**:
   ```sql
   SHOW GRANTS ON DATABASE [DB];
   SHOW GRANTS TO ROLE [ROL];
   ```

4. **Verificar warehouse activo**:
   ```sql
   SHOW WAREHOUSES;
   ALTER WAREHOUSE [WH] RESUME;
   ```

5. **Ver historial de queries con errores**:
   ```sql
   SELECT 
       QUERY_TEXT,
       ERROR_CODE,
       ERROR_MESSAGE,
       START_TIME
   FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY())
   WHERE ERROR_CODE IS NOT NULL
   ORDER BY START_TIME DESC
   LIMIT 10;
   ```
