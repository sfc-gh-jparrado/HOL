-- =====================================================================
-- HOL AI SUMMIT - SETUP COMPLETO
-- Este script es invocado por bootstrap.sql via EXECUTE IMMEDIATE FROM @hol_repo.
-- Crea toda la infraestructura del HOL: stages, datos copiados desde Git,
-- tabla de PDFs parseados, Cortex Search Service, agente y notebook.
-- =====================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE HOL_AI_SUMMIT;
USE SCHEMA PUBLIC;
USE WAREHOUSE HOL_WH;

-- ---------------------------------------------------------------------
-- 1. Stages internos para imagenes, documentos y audio
-- ---------------------------------------------------------------------
CREATE OR REPLACE STAGE IMAGENES
  DIRECTORY = (ENABLE = TRUE)
  ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');

CREATE OR REPLACE STAGE DOCUMENTOS
  DIRECTORY = (ENABLE = TRUE)
  ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');

CREATE OR REPLACE STAGE AUDIO
  DIRECTORY = (ENABLE = TRUE)
  ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');

-- ---------------------------------------------------------------------
-- 2. Copiar archivos desde el repo Git al stage interno
-- ---------------------------------------------------------------------
COPY FILES INTO @IMAGENES
  FROM @hol_repo/branches/main/AI_SUMMIT/datasets/imagenes/;

COPY FILES INTO @DOCUMENTOS
  FROM @hol_repo/branches/main/AI_SUMMIT/datasets/documentos/;

COPY FILES INTO @AUDIO
  FROM @hol_repo/branches/main/AI_SUMMIT/datasets/audio/;

ALTER STAGE IMAGENES REFRESH;
ALTER STAGE DOCUMENTOS REFRESH;
ALTER STAGE AUDIO REFRESH;

-- ---------------------------------------------------------------------
-- 3. Tabla con documentos parseados (AI_PARSE_DOCUMENT soporta DOCX nativo)
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE DOCS_PARSED AS
SELECT
  RELATIVE_PATH AS file_name,
  TO_VARCHAR(
    AI_PARSE_DOCUMENT(
      TO_FILE('@DOCUMENTOS', RELATIVE_PATH),
      {'mode': 'LAYOUT'}
    ):content
  ) AS content
FROM DIRECTORY(@DOCUMENTOS);

-- ---------------------------------------------------------------------
-- 4. Tabla de transcripciones de audio
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE TRANSCRIPCIONES AS
SELECT
  RELATIVE_PATH AS file_name,
  TO_VARCHAR(
    AI_TRANSCRIBE(TO_FILE('@AUDIO', RELATIVE_PATH)):text
  ) AS transcripcion,
  AI_SENTIMENT(
    TO_VARCHAR(AI_TRANSCRIBE(TO_FILE('@AUDIO', RELATIVE_PATH)):text)
  ):categories[0]:sentiment::VARCHAR AS sentimiento
FROM DIRECTORY(@AUDIO);

-- ---------------------------------------------------------------------
-- 5. Cortex Search Service sobre documentos
-- ---------------------------------------------------------------------
CREATE OR REPLACE CORTEX SEARCH SERVICE DOCS_SEARCH
  ON content
  ATTRIBUTES file_name
  WAREHOUSE = HOL_WH
  TARGET_LAG = '1 hour'
  EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'
AS (SELECT content, file_name FROM DOCS_PARSED);

-- ---------------------------------------------------------------------
-- 6. Agente Cortex pre-configurado
-- ---------------------------------------------------------------------
CREATE OR REPLACE AGENT HOL_AI_SUMMIT.PUBLIC.AGENTE_HOL
  WITH PROFILE='{"display_name": "Agente HOL Multimodal"}'
  COMMENT = 'Agente del HOL AI Summit - responde sobre contratos y llamadas'
  FROM SPECIFICATION $$
{
  "models": {"orchestration": "claude-3-5-sonnet"},
  "instructions": {
    "response": "Responde siempre en espanol, de forma clara y profesional. Cita la fuente (documento o audio) cuando uses informacion especifica.",
    "orchestration": "Si la pregunta es sobre contratos o documentos, usa la herramienta DOCS_SEARCH. Si es sobre llamadas, sentimientos o servicio al cliente, consulta TRANSCRIPCIONES."
  },
  "tools": [
    {
      "tool_spec": {
        "type": "cortex_search",
        "name": "buscar_documentos",
        "description": "Busca informacion en los contratos y documentos parseados"
      }
    },
    {
      "tool_spec": {
        "type": "sql_exec",
        "name": "consultar_transcripciones",
        "description": "Ejecuta SQL sobre la tabla TRANSCRIPCIONES con llamadas y sentimientos"
      }
    }
  ],
  "tool_resources": {
    "buscar_documentos": {
      "name": "HOL_AI_SUMMIT.PUBLIC.DOCS_SEARCH",
      "max_results": 4,
      "id_column": "file_name"
    },
    "consultar_transcripciones": {
      "query_timeout": 60
    }
  }
}
$$;

-- ---------------------------------------------------------------------
-- 7. Crear el notebook desde el repo Git
-- ---------------------------------------------------------------------
CREATE OR REPLACE NOTEBOOK NB_HOL_AI_SUMMIT
  FROM '@hol_repo/branches/main/AI_SUMMIT/'
  MAIN_FILE = 'notebook_ai_summit.ipynb'
  QUERY_WAREHOUSE = HOL_WH;

ALTER NOTEBOOK NB_HOL_AI_SUMMIT ADD LIVE VERSION FROM LAST;

-- ---------------------------------------------------------------------
-- 8. Resumen final
-- ---------------------------------------------------------------------
SELECT 'Setup completo.' AS status,
       'Abre Snowsight > Projects > Notebooks > NB_HOL_AI_SUMMIT' AS siguiente_paso,
       'Tambien puedes probar el agente en AI & ML > Agents > AGENTE_HOL' AS bonus;
