# Sub-Skill: Cortex AI Functions

## Metadata
- **Parent**: snowflake-hol-generator
- **Name**: modules/cortex-ai
- **Obligatorio**: ❌ No
- **Duración**: ~10 minutos
- **Dependencias**: Setup completado, datos con texto para analizar

---

## 🎯 Objetivo

Demostrar las funciones de IA integradas en Snowflake para:
- Análisis de sentimiento
- Clasificación de texto
- Resumen automático
- Traducción
- Completar/generar texto

---

## ✅ Compatibilidad Trial

| Función | Trial | Descripción |
|---------|-------|-------------|
| `SENTIMENT()` | ✅ | Análisis de sentimiento (-1 a 1) |
| `CLASSIFY_TEXT()` | ✅ | Clasificación en categorías |
| `SUMMARIZE()` | ✅ | Resumen de texto largo |
| `TRANSLATE()` | ✅ | Traducción entre idiomas |
| `COMPLETE()` | ✅ | Generación de texto con LLM |
| `EXTRACT_ANSWER()` | ✅ | Responder preguntas sobre texto |

> **Nota**: Todas las funciones Cortex AI están disponibles en cuentas trial.

---

## Paso 1: Análisis de Sentimiento

```sql
-- ===========================================
-- ANÁLISIS DE SENTIMIENTO EN REVIEWS/COMENTARIOS
-- ===========================================

USE DATABASE [CLIENTE_HOL];
USE WAREHOUSE [CLIENTE]_WH;

-- Crear tabla de análisis de sentimiento
-- AI_SENTIMENT returns OBJECT since 2025: extract with :categories[0]:sentiment
CREATE OR REPLACE VIEW ANALYTICS.V_REVIEWS_SENTIMIENTO AS
SELECT 
    ID_REVIEW,
    TEXTO_REVIEW,
    FECHA_REVIEW,
    
    -- Extraer label de sentimiento del OBJECT
    AI_SENTIMENT(TEXTO_REVIEW):categories[0]:sentiment::VARCHAR AS SENTIMENT_LABEL,
    
    -- Clasificar en español
    CASE AI_SENTIMENT(TEXTO_REVIEW):categories[0]:sentiment::VARCHAR
        WHEN 'positive' THEN 'POSITIVO'
        WHEN 'negative' THEN 'NEGATIVO'
        ELSE 'NEUTRAL'
    END AS CLASIFICACION_SENTIMIENTO
    
FROM RAW.REVIEWS;

-- Verificar resultados
SELECT * FROM ANALYTICS.V_REVIEWS_SENTIMIENTO LIMIT 10;

-- Distribución de sentimientos
SELECT 
    CLASIFICACION_SENTIMIENTO,
    COUNT(*) AS CANTIDAD
FROM ANALYTICS.V_REVIEWS_SENTIMIENTO
GROUP BY CLASIFICACION_SENTIMIENTO
ORDER BY CANTIDAD DESC;
```

---

## Paso 2: Clasificación de Texto

```sql
-- ===========================================
-- CLASIFICACIÓN AUTOMÁTICA DE TICKETS/CASOS
-- ===========================================

-- Definir categorías y clasificar
SELECT 
    ID_TICKET,
    DESCRIPCION,
    
    -- Clasificar en categorías predefinidas
    SNOWFLAKE.CORTEX.CLASSIFY_TEXT(
        DESCRIPCION,
        ['Problema Técnico', 'Consulta de Precio', 'Devolución', 'Felicitación', 'Otro']
    ):label::STRING AS CATEGORIA_DETECTADA,
    
    -- Score de confianza
    SNOWFLAKE.CORTEX.CLASSIFY_TEXT(
        DESCRIPCION,
        ['Problema Técnico', 'Consulta de Precio', 'Devolución', 'Felicitación', 'Otro']
    ):score::FLOAT AS CONFIANZA
    
FROM RAW.TICKETS_SOPORTE
LIMIT 20;

-- Crear vista con clasificación automática
CREATE OR REPLACE VIEW ANALYTICS.V_TICKETS_CLASIFICADOS AS
SELECT 
    *,
    SNOWFLAKE.CORTEX.CLASSIFY_TEXT(
        DESCRIPCION,
        ['Urgente', 'Normal', 'Baja Prioridad']
    ):label::STRING AS PRIORIDAD_SUGERIDA
FROM RAW.TICKETS_SOPORTE;
```

---

## Paso 3: Resumen Automático

```sql
-- ===========================================
-- RESUMEN DE DOCUMENTOS LARGOS
-- ===========================================

-- Resumir reviews largos
SELECT 
    ID_REVIEW,
    LENGTH(TEXTO_REVIEW) AS LONGITUD_ORIGINAL,
    
    -- Generar resumen
    SNOWFLAKE.CORTEX.SUMMARIZE(TEXTO_REVIEW) AS RESUMEN,
    LENGTH(SNOWFLAKE.CORTEX.SUMMARIZE(TEXTO_REVIEW)) AS LONGITUD_RESUMEN
    
FROM RAW.REVIEWS
WHERE LENGTH(TEXTO_REVIEW) > 200
LIMIT 5;

-- Resumir múltiples reviews en uno solo
WITH REVIEWS_CONCATENADOS AS (
    SELECT LISTAGG(TEXTO_REVIEW, ' --- ') AS TODOS_REVIEWS
    FROM RAW.REVIEWS
    WHERE FECHA_REVIEW >= DATEADD('day', -7, CURRENT_DATE())
)
SELECT 
    SNOWFLAKE.CORTEX.SUMMARIZE(TODOS_REVIEWS) AS RESUMEN_SEMANAL
FROM REVIEWS_CONCATENADOS;
```

---

## Paso 4: Traducción

```sql
-- ===========================================
-- TRADUCCIÓN AUTOMÁTICA
-- ===========================================

-- Traducir reviews de español a inglés
SELECT 
    ID_REVIEW,
    TEXTO_REVIEW AS ORIGINAL_ES,
    
    -- Traducir a inglés
    SNOWFLAKE.CORTEX.TRANSLATE(
        TEXTO_REVIEW, 
        'es',  -- idioma origen
        'en'   -- idioma destino
    ) AS TRADUCCION_EN
    
FROM RAW.REVIEWS
LIMIT 5;

-- Traducir a múltiples idiomas
SELECT 
    NOMBRE_PRODUCTO,
    DESCRIPCION AS DESCRIPCION_ES,
    SNOWFLAKE.CORTEX.TRANSLATE(DESCRIPCION, 'es', 'en') AS DESCRIPCION_EN,
    SNOWFLAKE.CORTEX.TRANSLATE(DESCRIPCION, 'es', 'pt') AS DESCRIPCION_PT,
    SNOWFLAKE.CORTEX.TRANSLATE(DESCRIPCION, 'es', 'fr') AS DESCRIPCION_FR
FROM RAW.PRODUCTOS
LIMIT 5;
```

---

## Paso 5: Generación con COMPLETE()

```sql
-- ===========================================
-- GENERACIÓN DE TEXTO CON LLM
-- ===========================================

-- Generar respuesta automática a review negativo
SELECT 
    ID_REVIEW,
    TEXTO_REVIEW,
    CLASIFICACION_SENTIMIENTO,
    
    -- Generar respuesta personalizada
    AI_COMPLETE(
        'mistral-large2',
        'Eres un agente de servicio al cliente profesional y empático. ' ||
        'Genera una respuesta breve (máximo 2 oraciones) para este review: ' || 
        TEXTO_REVIEW
    )::VARCHAR AS RESPUESTA_SUGERIDA
    
FROM ANALYTICS.V_REVIEWS_SENTIMIENTO
WHERE CLASIFICACION_SENTIMIENTO = 'NEGATIVO'
LIMIT 3;

-- Generar descripción de producto
SELECT 
    NOMBRE_PRODUCTO,
    CATEGORIA,
    
    AI_COMPLETE(
        'mistral-large2',
        'Genera una descripción de marketing atractiva (máximo 50 palabras) para: ' ||
        NOMBRE_PRODUCTO || ' de la categoría ' || CATEGORIA
    )::VARCHAR AS DESCRIPCION_MARKETING
    
FROM RAW.PRODUCTOS
LIMIT 3;
```

---

## Paso 6: Extracción de Respuestas

```sql
-- ===========================================
-- EXTRAER RESPUESTAS DE DOCUMENTOS
-- ===========================================

-- Extraer información específica de texto largo
WITH DOCUMENTO AS (
    SELECT 'La empresa [CLIENTE] fue fundada en 2015 en la ciudad de México. ' ||
           'Actualmente cuenta con 500 empleados y opera en 5 países de Latinoamérica. ' ||
           'Su CEO es Juan Pérez y su CFO es María García. ' ||
           'Los ingresos del último año fueron de $50 millones de dólares.' AS TEXTO
)
SELECT 
    SNOWFLAKE.CORTEX.EXTRACT_ANSWER(TEXTO, '¿Cuántos empleados tiene la empresa?') AS EMPLEADOS,
    SNOWFLAKE.CORTEX.EXTRACT_ANSWER(TEXTO, '¿Quién es el CEO?') AS CEO,
    SNOWFLAKE.CORTEX.EXTRACT_ANSWER(TEXTO, '¿Cuáles fueron los ingresos?') AS INGRESOS
FROM DOCUMENTO;
```

---

## Vista Consolidada: Panel de IA

```sql
-- ===========================================
-- VISTA CONSOLIDADA CON TODAS LAS FUNCIONES IA
-- ===========================================

CREATE OR REPLACE VIEW ANALYTICS.V_REVIEWS_ENRIQUECIDOS AS
SELECT 
    r.ID_REVIEW,
    r.TEXTO_REVIEW,
    r.FECHA_REVIEW,
    
    -- Sentimiento (OBJECT → label)
    AI_SENTIMENT(r.TEXTO_REVIEW):categories[0]:sentiment::VARCHAR AS SENTIMENT_RAW,
    
    CASE AI_SENTIMENT(r.TEXTO_REVIEW):categories[0]:sentiment::VARCHAR
        WHEN 'positive' THEN '😊 Positivo'
        WHEN 'negative' THEN '😞 Negativo'
        ELSE '😐 Neutral'
    END AS SENTIMIENTO,
    
    -- Clasificación
    AI_CLASSIFY_TEXT(
        r.TEXTO_REVIEW,
        ['Calidad Producto', 'Servicio', 'Precio', 'Entrega', 'Otro']
    ):label::STRING AS TEMA_PRINCIPAL,
    
    -- Resumen (solo para reviews largos)
    CASE 
        WHEN LENGTH(r.TEXTO_REVIEW) > 100 
        THEN SNOWFLAKE.CORTEX.SUMMARIZE(r.TEXTO_REVIEW)
        ELSE r.TEXTO_REVIEW
    END AS RESUMEN

FROM RAW.REVIEWS r;

-- Verificar vista
SELECT * FROM ANALYTICS.V_REVIEWS_ENRIQUECIDOS LIMIT 5;
```

---

## Contenido HTML para el HOL

```html
<h2>🤖 Funciones de Inteligencia Artificial</h2>

<p>Snowflake Cortex incluye funciones de IA que puedes usar directamente en SQL:</p>

<div class="card-grid">
    <div class="card">
        <div class="card-icon">😊</div>
        <h4>SENTIMENT()</h4>
        <p>Analiza el sentimiento de un texto y devuelve un score de -1 (negativo) a 1 (positivo)</p>
    </div>
    <div class="card">
        <div class="card-icon">🏷️</div>
        <h4>CLASSIFY_TEXT()</h4>
        <p>Clasifica texto automáticamente en categorías que tú defines</p>
    </div>
    <div class="card">
        <div class="card-icon">📝</div>
        <h4>SUMMARIZE()</h4>
        <p>Resume textos largos en versiones más cortas y concisas</p>
    </div>
    <div class="card">
        <div class="card-icon">🌐</div>
        <h4>TRANSLATE()</h4>
        <p>Traduce texto entre múltiples idiomas automáticamente</p>
    </div>
</div>

<div class="info-box tip">
    <span class="info-icon">💡</span>
    <div class="info-content">
        <h4>Sin Configuración Adicional</h4>
        <p>Estas funciones están listas para usar - no necesitas configurar modelos, 
        infraestructura ni APIs externas. Todo corre dentro de Snowflake.</p>
    </div>
</div>
```

---

## Multimodal: imagen y audio (opcional, alto impacto)

Para impresionar con datos NO estructurados, agrega un paso multimodal. Requiere un stage con
`DIRECTORY=(ENABLE=TRUE)` y archivos (`.png`, `.mp3`) accesibles vía `TO_FILE`.

```sql
-- IMAGEN (visión) con pixtral-large: interpretar un gráfico
SELECT SNOWFLAKE.CORTEX.COMPLETE('pixtral-large',
  PROMPT('Analiza este gráfico: describe la tendencia y resume en 3 frases. {0}',
         TO_FILE('@STG_ARCHIVOS', 'grafico.png'))) AS lectura;

-- AUDIO: transcribir y luego extraer datos estructurados de la transcripción
WITH t AS (SELECT AI_TRANSCRIBE(TO_FILE('@STG_ARCHIVOS','llamada.mp3')) AS r)
SELECT r:text::STRING AS transcripcion,
       SNOWFLAKE.CORTEX.COMPLETE('claude-sonnet-4-5',
         'Extrae en JSON los campos X,Y,Z de esta llamada: ' || r:text::STRING) AS extraido
FROM t;
```

> `AI_TRANSCRIBE` devuelve un OBJECT; usa `r:text::STRING` para el texto. `PROMPT(... {0}, TO_FILE(...))`
> inyecta el archivo en el placeholder `{0}`. Detalle completo en
> [../../references/real-data-and-advanced-patterns.md](../../references/real-data-and-advanced-patterns.md) (§4).

---

## Siguiente Módulo

- **Dynamic Tables**: [../dynamic-tables/SKILL.md](../dynamic-tables/SKILL.md)
- **Time Travel**: [../time-travel/SKILL.md](../time-travel/SKILL.md)
