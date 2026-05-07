# Guion de Prompts para Cortex Code (HOL AI Summit)

> **Como usarlo:** Abre **Cortex Code** en Snowsight (atajo `Cmd/Ctrl + I` o icono de chispa en el panel lateral). Asegurate de estar en el contexto `HOL_AI_SUMMIT.PUBLIC` con el warehouse `HOL_WH`. Pega cada prompt y deja que Cortex Code genere el SQL.

---

## Prompt 1 - Vista de imagenes clasificadas

```
Crea una vista llamada V_IMAGENES_CLASIFICADAS que recorra todos los archivos del stage @IMAGENES y agregue una columna con la clasificacion del tipo de imagen entre las opciones: cedula, accidente vehicular, factura, logo corporativo, otro. Usa AI_CLASSIFY sobre el resultado de AI_COMPLETE con un modelo multimodal.
```

**SQL esperado (fallback):**
```sql
CREATE OR REPLACE VIEW V_IMAGENES_CLASIFICADAS AS
SELECT
  RELATIVE_PATH AS archivo,
  AI_CLASSIFY(
    AI_COMPLETE('claude-4-sonnet', 'Describe brevemente esta imagen en una sola frase.', TO_FILE('@IMAGENES', RELATIVE_PATH)),
    ['cedula', 'accidente vehicular', 'factura', 'logo corporativo', 'otro']
  ):labels[0]::VARCHAR AS tipo
FROM DIRECTORY(@IMAGENES);
```

---

## Prompt 2 - Vista 360 multimodal

```
Crea una vista V_HOL_360 que unifique las filas de DOCS_PARSED y TRANSCRIPCIONES con columnas: tipo_fuente (documento o audio), archivo, contenido, sentimiento (NULL para documentos).
```

**SQL esperado (fallback):**
```sql
CREATE OR REPLACE VIEW V_HOL_360 AS
SELECT 'documento' AS tipo_fuente, file_name AS archivo, content AS contenido, NULL::VARCHAR AS sentimiento FROM DOCS_PARSED
UNION ALL
SELECT 'audio', file_name, transcripcion, sentimiento FROM TRANSCRIPCIONES;
```

---

## Prompt 3 - Conversa con el agente

```
Generame un SELECT que llame a AI_COMPLETE con claude-4-sonnet y le pase como contexto las filas de V_HOL_360 (todas) preguntandole: que sentimiento expresa el cliente en las llamadas y cuales son los terminos clave de los contratos de arrendamiento? Responde en espanol.
```

---

## Prompt 4 - Streamlit dashboard

```
Crea una aplicacion Streamlit in Snowflake llamada DASHBOARD_HOL en el schema HOL_AI_SUMMIT.PUBLIC con:
- Una metrica con el total de archivos procesados (sumando DOCS_PARSED + TRANSCRIPCIONES + DIRECTORY(@IMAGENES))
- Un grafico de barras con el sentimiento de las llamadas (tabla TRANSCRIPCIONES)
- Un campo de chat que invoque AI_COMPLETE con la pregunta del usuario y contexto de V_HOL_360
- Diseno limpio en espanol
```

---

## Bonus - Pruebas rapidas adicionales

- *"Crea un dynamic table que mantenga DOCS_PARSED actualizada cada vez que se agregue un archivo nuevo al stage DOCUMENTOS."*
- *"Genera un task que ejecute AI_TRANSCRIBE diariamente sobre los nuevos archivos del stage AUDIO."*
- *"Hazme un row access policy para que solo el rol HR_ROLE pueda ver el contenido de los contratos."*

---

## Mensaje para el asistente del HOL

> Cortex Code te permite construir pipelines de IA, agentes y apps escribiendo en lenguaje natural. **No necesitas saber SQL avanzado**, no necesitas mover datos a otra plataforma, y todo queda gobernado por Snowflake. Esto es lo que diferencia a Snowflake de Databricks, Fabric, BigQuery o Redshift: **una sola plataforma, una experiencia conversacional, resultados productivos en minutos**.
