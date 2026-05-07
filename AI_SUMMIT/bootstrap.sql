-- =====================================================================
-- Workshop AI SUMMIT - BOOTSTRAP (UN SOLO PASO)
-- Copia este bloque, pegalo en un Worksheet de Snowsight y ejecutalo.
-- En menos de 2 minutos tendras todo listo: DB, datos, Cortex Analyst,
-- Cortex Search, Snowflake Intelligence y notebook guiado.
-- =====================================================================
-- WORKSHOP_NAME: AI Summit
-- VERSION: 1.0
-- ROLE_REQUIRED: ACCOUNTADMIN
-- DURATION_SECONDS: 75
-- ENTRY_POINT: TRUE  (este archivo es el punto de entrada; invoca setup.sql)
-- IDEMPOTENT: TRUE   (seguro re-ejecutar)
-- CREATES: HOL_AI_SUMMIT (database), HOL_WH (warehouse),
--          AGENTE_SEGUROS_360 (agent en SNOWFLAKE_INTELLIGENCE.AGENTS),
--          NB_HOL_AI_SUMMIT (notebook), DOCS_SEARCH (cortex search service),
--          SV_SEGUROS (semantic view)
-- DO_NOT_MODIFY: object names, execution order, warehouse size
-- REPO: https://github.com/sfc-gh-jparrado/HOL
-- =====================================================================
-- INSTRUCCIONES PARA AGENTES LLM (Cortex Code, etc.):
--   1. Ejecuta este archivo COMPLETO en una sola transaccion.
--   2. NO ejecutes setup.sql por separado.
--   3. NO modifiques los nombres de objetos.
--   4. Si algun paso falla, ejecuta el bloque CLEANUP de abajo y reintenta.
-- =====================================================================
-- CLEANUP opcional (descomenta solo si necesitas reinstalar desde cero):
-- DROP DATABASE IF EXISTS HOL_AI_SUMMIT;
-- DROP AGENT IF EXISTS SNOWFLAKE_INTELLIGENCE.AGENTS.AGENTE_SEGUROS_360;
-- DROP API INTEGRATION IF EXISTS github_hol_int;
-- =====================================================================

USE ROLE ACCOUNTADMIN;

-- 1. Habilitar inferencia cross-region (para modelos no locales)
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';

-- 2. Habilitar Snowflake Intelligence (objeto requerido para que aparezca en Snowsight)
CREATE SNOWFLAKE INTELLIGENCE IF NOT EXISTS SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT;

-- 3. Crear DB, schema y warehouse
CREATE DATABASE IF NOT EXISTS HOL_AI_SUMMIT;
USE DATABASE HOL_AI_SUMMIT;
CREATE SCHEMA IF NOT EXISTS PUBLIC;
USE SCHEMA PUBLIC;

CREATE WAREHOUSE IF NOT EXISTS HOL_WH
  WAREHOUSE_SIZE = XSMALL
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = FALSE;
USE WAREHOUSE HOL_WH;

-- 4. Integración API pública con GitHub (sin secretos)
CREATE OR REPLACE API INTEGRATION github_hol_int
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/sfc-gh-jparrado')
  ENABLED = TRUE
  ALLOWED_AUTHENTICATION_SECRETS = ();

-- 5. Conectar al repo público
CREATE OR REPLACE GIT REPOSITORY hol_repo
  API_INTEGRATION = github_hol_int
  ORIGIN = 'https://github.com/sfc-gh-jparrado/HOL.git';

ALTER GIT REPOSITORY hol_repo FETCH;

-- 6. Ejecutar setup completo desde Git (crea todo: tablas, semantic view, search, agente, notebook)
EXECUTE IMMEDIATE FROM @hol_repo/branches/main/AI_SUMMIT/setup.sql;

-- 7. Mensaje final con próximos pasos
SELECT
  '✅ Setup completo' AS estado,
  '1) Abre Projects > Notebooks > NB_HOL_AI_SUMMIT para los 5 ejercicios' AS paso_1,
  '2) Abre AI & ML > Snowflake Intelligence > Agente Seguros 360 para conversar con tus datos' AS paso_2,
  '3) Si Snowflake Intelligence no aparece, refresca la página de Snowsight' AS tip;
