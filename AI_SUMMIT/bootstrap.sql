-- =====================================================================
-- HOL AI SUMMIT - BOOTSTRAP
-- Pega este bloque en un worksheet de Snowsight y ejecutalo completo.
-- En menos de 1 minuto tendras todo listo: DB, stages, datos, search, agente.
-- Region recomendada: AWS US West 2 / EU (soportan AI_TRANSCRIBE).
-- =====================================================================

USE ROLE ACCOUNTADMIN;

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

-- Integracion API publica con GitHub (sin secrets)
CREATE OR REPLACE API INTEGRATION github_hol_int
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/sfc-gh-jparrado')
  ENABLED = TRUE
  ALLOWED_AUTHENTICATION_SECRETS = ();

-- Conexion al repo publico
CREATE OR REPLACE GIT REPOSITORY hol_repo
  API_INTEGRATION = github_hol_int
  ORIGIN = 'https://github.com/sfc-gh-jparrado/HOL.git';

ALTER GIT REPOSITORY hol_repo FETCH;

-- Ejecuta el setup completo desde Git
EXECUTE IMMEDIATE FROM @hol_repo/branches/main/AI_SUMMIT/setup.sql;

-- Verificacion rapida
SHOW STAGES;
SHOW TABLES;
SHOW CORTEX SEARCH SERVICES;

SELECT 'Listo! Abre el notebook NB_HOL_AI_SUMMIT en Projects > Notebooks' AS siguiente_paso;
