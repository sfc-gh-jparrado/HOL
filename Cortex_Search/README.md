# RAG con Snowflake Cortex Search - Guía en Español

## Descripción General

En este quickstart te mostraremos cómo construir de forma rápida y segura una aplicación RAG (Retrieval Augmented Generation) full-stack en Snowflake sin tener que construir integraciones, gestionar infraestructura o lidiar con preocupaciones de seguridad relacionadas con datos que se mueven fuera del marco de gobernanza de Snowflake.

Esta guía aprovecha **Cortex Search**, un servicio completamente gestionado que crea automáticamente embeddings para tus datos y realiza recuperaciones usando un motor de búsqueda híbrido, combinando embeddings para similitud semántica más búsqueda por palabras clave para similitud léxica, logrando una calidad de recuperación de última generación.

## ¿Qué es RAG?

**Retrieval Augmented Generation (RAG)** es una técnica que combina:
1. **Recuperación**: Buscar información relevante en un corpus de documentos
2. **Generación**: Usar un LLM para generar respuestas basadas en esa información

RAG permite que los modelos de lenguaje respondan preguntas sobre datos específicos de tu organización, manteniendo las respuestas fundamentadas en hechos reales.

## ¿Por Qué Snowflake Cortex Search?

**Cortex Search** simplifica dramáticamente la construcción de aplicaciones RAG al:
- ✅ Crear y gestionar embeddings automáticamente
- ✅ Usar búsqueda híbrida (semántica + léxica) para mejor recuperación
- ✅ Mantenerse actualizado automáticamente con tus datos
- ✅ Eliminar la necesidad de infraestructura externa de vectores
- ✅ Mantener todo dentro de Snowflake (seguridad y gobernanza)

## Contenido del Repositorio

```
Cortex_Search/
│
├── README.md                                  # Este archivo
├── RAG_Usando_Snowflake_Cortex_Search.ipynb  # Notebook de Snowflake con todo el proceso
│
└── documentos/                                # Documentos PDF originales (en inglés)
    ├── Carver Skis Specification Guide.pdf
    ├── RacingFast Skis Specification Guide.pdf
    ├── OutPiste Skis Specification Guide.pdf
    ├── Premium_Bicycle_User_Guide.pdf
    ├── The_Xtreme_Road_Bike_105_SL.pdf
    ├── The_Ultimate_Downhill_Bike.pdf
    ├── Mondracer_Infant_Bike.pdf
    └── Ski_Boots_TDBootz_Special.pdf
```

## Prerrequisitos

### Cuenta de Snowflake
- Una cuenta activa de Snowflake
- Rol con permisos para:
  - Crear bases de datos, schemas y tablas
  - Crear stages
  - Crear servicios de Cortex Search
  - Crear stored procedures y tasks
  - Usar funciones de Snowflake Cortex (PARSE_DOCUMENT, CLASSIFY_TEXT, etc.)

### Warehouse
- Un warehouse compute (pequeño es suficiente para este ejemplo)
- El warehouse debe estar activo o puedes usar `COMPUTE_WH` (por defecto)

### Conocimientos
- SQL básico
- Conceptos básicos de RAG (recomendado pero no obligatorio)
- Familiaridad con Snowflake (recomendado)

## Instalación Rápida

### Paso 1: Configurar Base de Datos

```sql
-- Crear base de datos y schema
CREATE DATABASE IF NOT EXISTS CC_QUICKSTART_CORTEX_SEARCH_DOCS;
USE DATABASE CC_QUICKSTART_CORTEX_SEARCH_DOCS;

CREATE SCHEMA IF NOT EXISTS DATA;
USE SCHEMA DATA;

-- Usar el warehouse
USE WAREHOUSE COMPUTE_WH;  -- Cambia por tu warehouse
```

### Paso 2: Crear Stage y Subir Documentos

```sql
-- Crear stage con cifrado y tabla de directorio habilitada
CREATE OR REPLACE STAGE docs 
ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE') 
DIRECTORY = (ENABLE = true);
```

**Subir documentos manualmente:**
1. Ve a **Data** en el menú izquierdo de Snowflake
2. Selecciona tu base de datos `CC_QUICKSTART_CORTEX_SEARCH_DOCS`
3. Selecciona tu schema `DATA`
4. Haz clic en **Stages** y luego en `DOCS`
5. Haz clic en el botón **+Files** (arriba a la derecha)
6. Arrastra y suelta los archivos `.txt` de la carpeta `documentos/`

**O usar SnowSQL:**
```bash
snowsql -c my_connection
```

```sql
PUT file:///ruta/a/documentos/*.pdf @docs AUTO_COMPRESS=FALSE;
```

**O usar Python:**
```python
from snowflake.snowpark import Session
import glob

session = Session.builder.configs({...}).create()

# Subir todos los PDFs
for pdf_file in glob.glob("documentos/*.pdf"):
    session.file.put(pdf_file, "@docs", auto_compress=False)
```

### Paso 3: Verificar Archivos Subidos

```sql
-- Listar archivos en el stage
LS @docs;
```

Deberías ver 8 archivos PDF listados.

### Paso 4: Ejecutar el Notebook

Opción 1: **Notebook de Snowflake (Recomendado)**
1. Ve a **Projects** > **Notebooks** en Snowflake
2. Haz clic en **+ Notebook**
3. Importa el archivo `RAG_Usando_Snowflake_Cortex_Search.ipynb`
4. Ejecuta cada celda secuencialmente

Opción 2: **Ejecutar SQL Manualmente**
- Copia y pega el código SQL del notebook en un worksheet de Snowflake
- Ejecuta cada bloque en orden

## Guía Paso a Paso

### 1. Procesamiento de Documentos

#### 1.1. Extraer Texto de Documentos PDF

Snowflake puede procesar documentos PDF usando la función `PARSE_DOCUMENT`. Esta función soporta PDF, DOCX, PPTX, TXT, HTML, XML, Markdown y otros formatos:

```sql
CREATE OR REPLACE TEMPORARY TABLE RAW_TEXT AS
SELECT 
    RELATIVE_PATH,
    SIZE,
    FILE_URL,
    BUILD_SCOPED_FILE_URL(@docs, relative_path) AS SCOPED_FILE_URL,
    TO_VARCHAR (
        SNOWFLAKE.CORTEX.PARSE_DOCUMENT (
            '@docs',
            RELATIVE_PATH,
            {'mode': 'LAYOUT'}
        ):content
    ) AS EXTRACTED_LAYOUT 
FROM 
    DIRECTORY('@docs');
```

**¿Qué hace esto?**
- `PARSE_DOCUMENT`: Extrae texto de archivos PDF manteniendo la estructura
- `mode: LAYOUT`: Preserva el layout del documento incluyendo tablas, columnas, formato
- `DIRECTORY`: Lee metadata de archivos del stage (nombre, tamaño, URL)
- El texto extraído mantiene el formato original del PDF

#### 1.2. Crear Tabla para Chunks

```sql
CREATE OR REPLACE TABLE DOCS_CHUNKS_TABLE ( 
    RELATIVE_PATH STRING,
    SIZE NUMBER(38,0),
    FILE_URL STRING,
    SCOPED_FILE_URL STRING,
    CHUNK STRING,          -- El fragmento de texto
    CHUNK_INDEX INTEGER,   -- Posición del fragmento
    CATEGORY STRING        -- Categoría del documento
);
```

#### 1.3. Fragmentar Documentos (Chunking)

```sql
INSERT INTO DOCS_CHUNKS_TABLE (relative_path, size, file_url,
                            scoped_file_url, chunk, chunk_index)
SELECT 
    relative_path, 
    size,
    file_url, 
    scoped_file_url,
    c.value::TEXT AS chunk,
    c.INDEX::INTEGER AS chunk_index
FROM 
    RAW_TEXT,
    LATERAL FLATTEN(
        input => SNOWFLAKE.CORTEX.SPLIT_TEXT_RECURSIVE_CHARACTER (
            EXTRACTED_LAYOUT,
            'markdown',
            1512,  -- Tamaño máximo del chunk
            256,   -- Overlap entre chunks
            ['\n\n', '\n', ' ', '']  -- Separadores
        )
    ) c;
```

**Parámetros de Chunking:**
- **Tamaño del chunk (1512)**: Cada fragmento tendrá máximo ~1512 caracteres
- **Overlap (256)**: Habrá 256 caracteres de solapamiento entre chunks consecutivos
- **Separadores**: Define dónde cortar el texto (párrafos, líneas, espacios)

**¿Por qué chunking?**
- Los LLMs tienen límites de tokens
- Chunks más pequeños = búsquedas más precisas
- El overlap asegura que no se pierda contexto en los límites

### 2. Clasificación Automática de Documentos

```sql
CREATE OR REPLACE TEMPORARY TABLE docs_categories AS 
WITH unique_documents AS (
    SELECT
        DISTINCT relative_path, 
        chunk
    FROM
        docs_chunks_table
    WHERE 
        chunk_index = 0  -- Solo el primer chunk
),
docs_category_cte AS (
    SELECT
        relative_path,
        TRIM(
            SNOWFLAKE.CORTEX.CLASSIFY_TEXT (
                'Título:' || relative_path || ' Contenido:' || chunk, 
                ['Bicicleta', 'Esquí']  -- Categorías posibles
            )['label'], 
            '"'
        ) AS category
    FROM
        unique_documents
)
SELECT * FROM docs_category_cte;
```

**¿Qué hace CLASSIFY_TEXT?**
- Usa un LLM para clasificar documentos automáticamente
- Le pasas el texto y las categorías posibles
- Devuelve la categoría más probable

**Actualizar tabla con categorías:**

```sql
UPDATE docs_chunks_table 
SET category = docs_categories.category
FROM docs_categories
WHERE docs_chunks_table.relative_path = docs_categories.relative_path;
```

### 3. Crear Servicio Cortex Search

Este es el paso clave:

```sql
CREATE OR REPLACE CORTEX SEARCH SERVICE CC_SEARCH_SERVICE_CS
ON chunk                 -- Columna para crear embeddings
ATTRIBUTES category      -- Columnas para filtrado
WAREHOUSE = COMPUTE_WH   -- Warehouse para mantenimiento
TARGET_LAG = '1 minute'  -- Frecuencia de actualización
AS (
    SELECT 
        chunk,
        chunk_index,
        relative_path,
        file_url,
        category
    FROM docs_chunks_table
);
```

**Componentes del Servicio:**
- **ON chunk**: Cortex Search creará embeddings del campo `chunk` automáticamente
- **ATTRIBUTES category**: Campos que pueden usarse para filtrar búsquedas
- **TARGET_LAG**: Qué tan frecuentemente se actualiza el índice
- **WAREHOUSE**: Qué warehouse usar para mantenimiento (usa créditos)

**¿Qué sucede internamente?**
1. Cortex Search lee todos los chunks
2. Crea embeddings usando modelos de Snowflake
3. Crea un índice híbrido (semántico + léxico)
4. Mantiene el índice actualizado automáticamente

### 4. Consultar el Servicio

#### Consulta Básica

```sql
SELECT 
    chunk,
    relative_path,
    category
FROM TABLE(
    CC_SEARCH_SERVICE_CS.SEARCH(
        '¿cuáles son las especificaciones de las bicicletas de carretera?',
        10  -- Top 10 resultados
    )
);
```

#### Consulta con Filtro

```sql
SELECT 
    chunk,
    relative_path,
    category
FROM TABLE(
    CC_SEARCH_SERVICE_CS.SEARCH(
        '¿qué productos de esquí están disponibles?',
        10,
        {'category': 'Esquí'}  -- Filtrar solo categoría Esquí
    )
);
```

**Tipos de Búsqueda:**
- **Semántica**: Encuentra chunks con significado similar (usa embeddings)
- **Léxica**: Encuentra chunks con palabras clave específicas
- **Híbrida**: Combina ambas para mejor precisión

### 5. Usar RAG con Cortex LLM

Ahora podemos combinar la búsqueda con un LLM para generar respuestas:

```sql
-- Paso 1: Buscar contexto relevante
WITH search_results AS (
    SELECT chunk
    FROM TABLE(
        CC_SEARCH_SERVICE_CS.SEARCH(
            '¿cuáles son las diferencias entre las bicicletas de carretera y las de montaña?',
            5
        )
    )
),
-- Paso 2: Concatenar contexto
context_string AS (
    SELECT LISTAGG(chunk, '\n\n') AS context
    FROM search_results
)
-- Paso 3: Generar respuesta con LLM
SELECT 
    SNOWFLAKE.CORTEX.COMPLETE(
        'mixtral-8x7b',
        CONCAT(
            'Basándote en el siguiente contexto, responde la pregunta del usuario.\n\n',
            'Contexto:\n',
            context,
            '\n\nPregunta: ¿cuáles son las diferencias entre las bicicletas de carretera y las de montaña?\n\n',
            'Respuesta:'
        )
    ) AS respuesta
FROM context_string;
```

**Flujo RAG:**
1. **Retrieve**: Buscar chunks relevantes con Cortex Search
2. **Augment**: Agregar ese contexto al prompt
3. **Generate**: Pedir al LLM que genere respuesta basada en el contexto

## Mantenimiento Automático

### Detectar Cambios con Streams

Streams de Snowflake capturan cambios (inserts, updates, deletes) en tablas o stages:

```sql
CREATE OR REPLACE STREAM insert_docs_stream ON STAGE docs;
CREATE OR REPLACE STREAM delete_docs_stream ON STAGE docs;
```

### Procesar Cambios con Stored Procedure

El stored procedure `insert_delete_docs_sp()` procesa automáticamente:
- Nuevos archivos agregados al stage
- Archivos eliminados del stage
- Actualiza la tabla de chunks
- Reclasifica nuevos documentos

Ver notebook para código completo.

### Automatizar con Tasks

```sql
CREATE OR REPLACE TASK insert_delete_docs_task
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = '5 minute'
    WHEN SYSTEM$STREAM_HAS_DATA('delete_docs_stream')
AS
    CALL insert_delete_docs_sp();

ALTER TASK insert_delete_docs_task RESUME;
```

**¿Cómo funciona?**
1. Task se ejecuta cada 5 minutos
2. Verifica si hay cambios en el stream
3. Si hay cambios, ejecuta el stored procedure
4. El stored procedure actualiza la tabla
5. Cortex Search detecta los cambios y actualiza el índice automáticamente

## Aplicación Streamlit (Opcional)

Para crear una interfaz de chat, puedes usar Streamlit en Snowflake. Código de ejemplo:

```python
import streamlit as st
import snowflake.snowpark as snowpark

# Título
st.title("🤖 Asistente RAG con Cortex Search")

# Input del usuario
question = st.text_input("Haz una pregunta sobre los documentos:")

if question:
    # Buscar contexto
    search_query = f"""
    SELECT chunk
    FROM TABLE(
        CC_SEARCH_SERVICE_CS.SEARCH('{question}', 5)
    )
    """
    
    results = session.sql(search_query).collect()
    context = "\n\n".join([row['CHUNK'] for row in results])
    
    # Generar respuesta
    llm_query = f"""
    SELECT SNOWFLAKE.CORTEX.COMPLETE(
        'mixtral-8x7b',
        'Contexto: {context}\\n\\nPregunta: {question}\\n\\nRespuesta:'
    ) AS respuesta
    """
    
    response = session.sql(llm_query).collect()[0]['RESPUESTA']
    st.write(response)
```

## Mejores Prácticas

### Chunking
- **Tamaño óptimo**: 512-2048 caracteres dependiendo del tipo de documento
- **Overlap**: 10-20% del tamaño del chunk
- **Separadores**: Usar separadores semánticos (párrafos, secciones)

### Búsqueda
- **Número de resultados**: 3-10 chunks típicamente
- **Filtros**: Usar `ATTRIBUTES` para filtrar por categoría, fecha, etc.
- **Reranking**: Considerar reordenar resultados con scoring adicional

### LLM
- **Modelos disponibles**: `mixtral-8x7b`, `llama2-70b-chat`, `mistral-large`, etc.
- **Prompt engineering**: Ser específico sobre formato de respuesta deseado
- **Límites de contexto**: Vigilar el tamaño total del prompt

### Costos
- **Cortex Search**: Cobra por GB almacenado y queries ejecutadas
- **Cortex LLM**: Cobra por tokens generados
- **Warehouse**: Cobra por tiempo de compute activo
- **Storage**: Cobra por GB almacenado

## Casos de Uso

Esta arquitectura RAG es ideal para:

- 📚 **Knowledge Bases**: Responder preguntas sobre documentación interna
- 🏢 **Soporte al Cliente**: Asistentes que consultan manuales de producto
- 📋 **Análisis de Contratos**: Extraer información de contratos legales
- 🔬 **Investigación**: Buscar información en papers científicos
- 💼 **Due Diligence**: Analizar documentos financieros
- 📊 **Reportes**: Generar resúmenes de documentos complejos

## Solución de Problemas

### Error: "Cortex Search service not found"
- Verifica que creaste el servicio correctamente
- Asegúrate de estar en el database y schema correcto
- Revisa que el nombre del servicio sea exacto (case-sensitive)

### Error: "Permission denied"
- Tu rol necesita permisos para usar Cortex features
- Contacta a tu administrador de Snowflake

### Los resultados no son relevantes
- Revisa el chunking (quizás los chunks son muy grandes/pequeños)
- Prueba ajustar los separadores en `SPLIT_TEXT_RECURSIVE_CHARACTER`
- Considera agregar más contexto en los prompts del LLM

### La task no se ejecuta
- Verifica que la task esté RESUMED: `ALTER TASK insert_delete_docs_task RESUME;`
- Revisa los logs: `SELECT * FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())`
- Asegúrate de que el warehouse esté disponible

## Recursos Adicionales

### Documentación Oficial de Snowflake
- [Cortex Search](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-search)
- [Cortex LLM Functions](https://docs.snowflake.com/en/user-guide/snowflake-cortex/llm-functions)
- [Parse Document](https://docs.snowflake.com/en/sql-reference/functions/parse_document)
- [Classify Text](https://docs.snowflake.com/en/sql-reference/functions/classify_text-snowflake-cortex)

### Tutoriales y Quickstarts
- [Official Cortex Search Quickstart](https://quickstarts.snowflake.com/guide/ask_questions_to_your_own_documents_with_snowflake_cortex_search/)
- [RAG with Snowflake Cortex](https://quickstarts.snowflake.com/)

### Comunidad
- [Snowflake Community](https://community.snowflake.com/)
- [Stack Overflow - Snowflake](https://stackoverflow.com/questions/tagged/snowflake)

## Próximos Pasos

Una vez que domines este ejemplo básico, considera:

1. **Agregar más fuentes de datos**: PDFs complejos, tablas de Snowflake, APIs externas
2. **Implementar reranking**: Mejorar la calidad de los resultados con scoring adicional
3. **Agregar memoria de conversación**: Hacer que el chatbot recuerde el contexto
4. **Integrar con herramientas externas**: Email, Slack, MS Teams
5. **Implementar evaluaciones**: Medir la calidad de las respuestas RAG
6. **Optimizar prompts**: Experimentar con diferentes estrategias de prompting
7. **Agregar guardrails**: Validar inputs/outputs, detectar contenido inapropiado

## Contribuciones

Este proyecto es parte del repositorio de Hands-On Labs de Snowflake. Si encuentras errores o tienes sugerencias:

1. Abre un issue en el repositorio
2. Propón cambios con un pull request
3. Contacta al mantenedor del repo

## Licencia

Este proyecto está basado en el quickstart original de Snowflake, adaptado al español.

---

## Créditos

**Adaptado por**: Juan Pablo Arrado  
**Basado en**: [Snowflake Cortex Search RAG Quickstart](https://github.com/Snowflake-Labs/sfguide-ask-questions-to-your-documents-using-rag-with-snowflake-cortex-search)  
**Fecha**: Noviembre 2025  

---

**¿Preguntas? ¿Comentarios?**

Abre un issue en el repositorio o contacta al equipo de Snowflake.

¡Feliz construcción de aplicaciones RAG! 🚀

