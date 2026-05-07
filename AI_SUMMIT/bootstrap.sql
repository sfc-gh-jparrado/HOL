-- =====================================================================
-- Workshop AI SUMMIT - BOOTSTRAP (UN SOLO PASO)
-- Copia este bloque, pegalo en un Worksheet de Snowsight y ejecutalo.
-- En menos de 2 minutos tendras todo listo: DB, datos, Cortex Analyst,
-- Cortex Search, Snowflake Intelligence y notebook guiado.
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
