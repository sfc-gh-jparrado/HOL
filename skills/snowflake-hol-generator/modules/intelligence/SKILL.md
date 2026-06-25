# Sub-Skill: Snowflake Intelligence (Cortex Analyst)

## Metadata
- **Parent**: snowflake-hol-generator
- **Name**: modules/intelligence
- **Obligatorio**: ❌ No (pero muy recomendado)
- **Duración**: ~15 minutos
- **Dependencias**: Setup completado, datos cargados

---

## 🎯 Objetivo

Demostrar cómo hacer preguntas en lenguaje natural a los datos usando:
- Semantic Views (modelo semántico)
- Cortex Agents (interfaz conversacional)
- Todo via **Snowsight UI** (compatible con trial)

---

## ⚠️ CRÍTICO: Compatibilidad con Trial

### ❌ NO USAR (no funciona en trial)
```sql
-- ESTO NO FUNCIONA EN CUENTAS TRIAL
SET yaml_model = (SELECT SNOWFLAKE.CORTEX.SYSTEM$CORTEX_ANALYST_FAST_GENERATION(...));
```

### ✅ USAR SIEMPRE (funciona en trial)
- **Snowsight UI → Semantic View Autopilot**
- **Snowsight UI → Create Agent**

---

## Paso 1: Crear Vista Analítica Base

Antes de crear el Semantic View, necesitamos una vista que consolide los datos:

```sql
-- ===========================================
-- PASO 1: CREAR VISTA ANALÍTICA
-- ===========================================

USE DATABASE [CLIENTE_HOL];
USE SCHEMA ANALYTICS;

CREATE OR REPLACE VIEW V_[ENTIDAD]_ANALISIS AS
SELECT 
    -- Dimensiones de tiempo
    [FECHA_CAMPO] AS FECHA,
    DATE_TRUNC('MONTH', [FECHA_CAMPO]) AS MES,
    DATE_TRUNC('QUARTER', [FECHA_CAMPO]) AS TRIMESTRE,
    YEAR([FECHA_CAMPO]) AS ANIO,
    
    -- Dimensiones de negocio
    [DIMENSION_1],
    [DIMENSION_2],
    [DIMENSION_3],
    
    -- Métricas
    [METRICA_1],
    [METRICA_2],
    ROUND([METRICA_1] - [METRICA_COSTO], 2) AS MARGEN,
    ROUND(([METRICA_1] - [METRICA_COSTO]) / NULLIF([METRICA_1], 0) * 100, 2) AS MARGEN_PCT
    
FROM [TABLA_BASE]
-- JOINs con otras tablas si es necesario
;

-- Verificar vista creada
SELECT * FROM V_[ENTIDAD]_ANALISIS LIMIT 10;
```

---

## Paso 2: Crear Semantic View (via Snowsight UI)

### Instrucciones para el Usuario (incluir en HTML)

```html
<div class="info-box tip">
    <span class="info-icon">🧠</span>
    <div class="info-content">
        <h4>Creando el Modelo Semántico con Autopilot</h4>
        <p>Snowflake puede generar automáticamente un modelo semántico basado en tu vista. 
        Esto permite hacer preguntas en lenguaje natural.</p>
    </div>
</div>

<h3>Instrucciones paso a paso:</h3>

<ol>
    <li><strong>Navegar a la vista:</strong>
        <ul>
            <li>En Snowsight, ve a <code>Data → Databases</code></li>
            <li>Navega a <code>[CLIENTE_HOL] → ANALYTICS → Views</code></li>
            <li>Haz clic en <code>V_[ENTIDAD]_ANALISIS</code></li>
        </ul>
    </li>
    <li><strong>Iniciar Autopilot:</strong>
        <ul>
            <li>En la parte superior derecha, haz clic en el menú <code>⋮</code> (tres puntos)</li>
            <li>Selecciona <code>Create Semantic View</code></li>
        </ul>
    </li>
    <li><strong>Configurar el Semantic View:</strong>
        <ul>
            <li><strong>Nombre:</strong> <code>SV_[ENTIDAD]_[CLIENTE]</code></li>
            <li><strong>Schema:</strong> <code>ANALYTICS</code></li>
            <li>Snowflake analizará automáticamente las columnas</li>
        </ul>
    </li>
    <li><strong>Revisar y ajustar:</strong>
        <ul>
            <li>Revisa las <strong>dimensiones</strong> detectadas (campos categóricos)</li>
            <li>Revisa las <strong>métricas</strong> detectadas (campos numéricos)</li>
            <li>Ajusta descripciones si es necesario</li>
        </ul>
    </li>
    <li><strong>Crear:</strong>
        <ul>
            <li>Click en <code>Create</code></li>
            <li>Espera ~30 segundos mientras se genera el modelo</li>
        </ul>
    </li>
</ol>
```

### Verificación SQL (después de crear via UI)
```sql
-- Verificar que el Semantic View fue creado
SHOW SEMANTIC VIEWS IN SCHEMA [CLIENTE_HOL].ANALYTICS;

-- Describir el Semantic View
DESCRIBE SEMANTIC VIEW [CLIENTE_HOL].ANALYTICS.SV_[ENTIDAD]_[CLIENTE];
```

---

## Paso 3: Crear Cortex Agent (via Snowsight UI)

### Instrucciones para el Usuario (incluir en HTML)

```html
<h3>Crear el Agente de IA</h3>

<ol>
    <li><strong>Navegar a Cortex Agents:</strong>
        <ul>
            <li>En Snowsight, ve a <code>AI & ML → Cortex Agents</code></li>
            <li>O usa el menú lateral izquierdo → <code>Agents</code></li>
        </ul>
    </li>
    <li><strong>Crear nuevo agente:</strong>
        <ul>
            <li>Click en <code>+ Create</code></li>
            <li><strong>Nombre:</strong> <code>[CLIENTE]_ASSISTANT</code></li>
            <li><strong>Database:</strong> <code>[CLIENTE_HOL]</code></li>
            <li><strong>Schema:</strong> <code>AGENTS</code></li>
        </ul>
    </li>
    <li><strong>Configurar herramientas:</strong>
        <ul>
            <li>En la sección <code>Tools</code>, click <code>+ Add Tool</code></li>
            <li>Selecciona <code>Analyst</code></li>
            <li>Elige el Semantic View: <code>SV_[ENTIDAD]_[CLIENTE]</code></li>
        </ul>
    </li>
    <li><strong>Agregar instrucciones (opcional):</strong>
        <pre><code>Eres un asistente experto en análisis de datos de [CLIENTE].
Responde en español de forma concisa.
Cuando presentes números, usa formato con separadores de miles.
Si no tienes datos para responder, indícalo claramente.</code></pre>
    </li>
    <li><strong>Guardar:</strong>
        <ul>
            <li>Click en <code>Create</code></li>
        </ul>
    </li>
</ol>
```

---

## Paso 4: Probar el Agente con Preguntas

### Preguntas de Ejemplo por Categoría

```html
<h3>🧪 Prueba tu Agente</h3>

<p>Haz clic en el agente creado y prueba estas preguntas:</p>

<div class="card-grid">
    <div class="card">
        <div class="card-icon">📊</div>
        <h4>Resumen General</h4>
        <p>"¿Cuál es el total de ventas del último mes?"</p>
        <p>"Dame un resumen de las métricas principales"</p>
    </div>
    <div class="card">
        <div class="card-icon">📈</div>
        <h4>Tendencias</h4>
        <p>"¿Cómo han evolucionado las ventas por mes?"</p>
        <p>"Muestra la tendencia trimestral"</p>
    </div>
    <div class="card">
        <div class="card-icon">🏆</div>
        <h4>Rankings</h4>
        <p>"¿Cuáles son los 5 productos más vendidos?"</p>
        <p>"Top 3 regiones por margen"</p>
    </div>
    <div class="card">
        <div class="card-icon">🔍</div>
        <h4>Filtros</h4>
        <p>"Ventas de [CATEGORIA] en [REGION]"</p>
        <p>"Margen promedio por categoría"</p>
    </div>
</div>
```

### Preguntas Template por Industria

| Industria | Preguntas Sugeridas |
|-----------|---------------------|
| **Retail** | "Ventas por tienda", "Productos más vendidos", "Tendencia estacional" |
| **Manufactura** | "Producción por línea", "Costos por producto", "Eficiencia de planta" |
| **Finanzas** | "Ingresos por segmento", "Cartera vencida", "ROI por producto" |
| **Healthcare** | "Pacientes atendidos", "Ocupación de camas", "Tiempo de espera promedio" |
| **Pharma** | "Ventas por representante", "Cobertura de médicos", "Margen por línea" |

---

## Paso 5: Agregar Segundo Semantic View (Opcional)

### Para enriquecer el agente con más datos:

```html
<h3>Agregar más fuentes de datos al Agente</h3>

<p>Puedes agregar múltiples Semantic Views a un mismo agente:</p>

<ol>
    <li>Ve al agente creado → <code>Edit</code></li>
    <li>En <code>Tools</code>, click <code>+ Add Tool</code></li>
    <li>Selecciona otro <code>Analyst</code></li>
    <li>Elige un Semantic View diferente (ej: inventario, clientes, etc.)</li>
    <li>Click <code>Save</code></li>
</ol>

<div class="info-box tip">
    <span class="info-icon">💡</span>
    <div class="info-content">
        <h4>Multi-Source Agent</h4>
        <p>Con múltiples Semantic Views, el agente puede correlacionar información 
        de diferentes fuentes. Por ejemplo: "¿Qué productos con bajo inventario 
        tienen alta demanda?"</p>
    </div>
</div>
```

---

## Troubleshooting

### Error: "Semantic View creation failed"
**Causa**: La vista tiene tipos de datos no soportados o es muy compleja.
**Solución**: Simplificar la vista, usar solo tipos básicos (VARCHAR, NUMBER, DATE).

### Error: "Agent cannot answer"
**Causa**: La pregunta no se puede mapear a las columnas disponibles.
**Solución**: Reformular la pregunta usando términos que coincidan con los nombres de columnas.

### Error: "Function not available"
**Causa**: Cuenta trial con restricciones.
**Solución**: Usar exclusivamente Snowsight UI, no SQL directo para Semantic Views.

---

## Verificación Final

```sql
-- Verificar objetos de Intelligence creados
SELECT 'Semantic Views' AS TIPO, COUNT(*) AS CANTIDAD
FROM INFORMATION_SCHEMA.VIEWS 
WHERE TABLE_SCHEMA = 'ANALYTICS' AND TABLE_NAME LIKE 'SV_%'

UNION ALL

SELECT 'Agents' AS TIPO, COUNT(*) AS CANTIDAD
FROM [CLIENTE_HOL].INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'AGENTS';
```

---

## Siguiente Módulo

Después de Intelligence, continuar con:
- **Cortex AI Functions**: [../cortex-ai/SKILL.md](../cortex-ai/SKILL.md)
- **Dynamic Tables**: [../dynamic-tables/SKILL.md](../dynamic-tables/SKILL.md)
