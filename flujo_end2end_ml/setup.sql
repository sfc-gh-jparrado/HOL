-- Usando ACCOUNTADMIN, crear un nuevo rol para este ejercicio 
USE ROLE ACCOUNTADMIN;
SET USERNAME = (SELECT CURRENT_USER());
SET ALLOW_EXTERNAL_ACCESS_FOR_TRIAL_ACCOUNTS = TRUE;
CREATE OR REPLACE ROLE E2E_SNOW_MLOPS_ROLE;

-- Otorgar permisos necesarios para crear databases, compute pools, y service endpoints al nuevo rol
GRANT CREATE DATABASE on ACCOUNT to ROLE E2E_SNOW_MLOPS_ROLE; 
GRANT CREATE COMPUTE POOL on ACCOUNT to ROLE E2E_SNOW_MLOPS_ROLE;
GRANT CREATE WAREHOUSE ON ACCOUNT to ROLE E2E_SNOW_MLOPS_ROLE;
GRANT BIND SERVICE ENDPOINT on ACCOUNT to ROLE E2E_SNOW_MLOPS_ROLE;

-- otorgar nuevo rol al usuario y cambiar a ese rol
GRANT ROLE E2E_SNOW_MLOPS_ROLE to USER identifier($USERNAME);
USE ROLE E2E_SNOW_MLOPS_ROLE;

-- Crear warehouse
CREATE OR REPLACE WAREHOUSE E2E_SNOW_MLOPS_WH WITH WAREHOUSE_SIZE='MEDIUM';

-- Crear Database 
CREATE OR REPLACE DATABASE E2E_SNOW_MLOPS_DB;

-- Crear Schema
CREATE OR REPLACE SCHEMA MLOPS_SCHEMA;

-- Crear compute pool
CREATE COMPUTE POOL IF NOT EXISTS MLOPS_COMPUTE_POOL 
 MIN_NODES = 1
 MAX_NODES = 1
 INSTANCE_FAMILY = CPU_X64_M;

-- Usando accountadmin, otorgar privilegio para crear network rules e integrations en la db recién creada
USE ROLE ACCOUNTADMIN;
-- GRANT CREATE NETWORK RULE on SCHEMA MLOPS_SCHEMA to ROLE E2E_SNOW_MLOPS_ROLE;
GRANT CREATE INTEGRATION on ACCOUNT to ROLE E2E_SNOW_MLOPS_ROLE;
USE ROLE E2E_SNOW_MLOPS_ROLE;

-- Crear una integración API con Github
CREATE OR REPLACE API INTEGRATION GITHUB_INTEGRATION_E2E_SNOW_MLOPS
   api_provider = git_https_api
   api_allowed_prefixes = ('https://github.com/Snowflake-Labs')
   enabled = true
   comment='Integración Git con el repositorio Github de demostración de Snowflake.';

-- Crear la integración con el repositorio de demostración de Github
CREATE OR REPLACE GIT REPOSITORY GITHUB_REPO_E2E_SNOW_MLOPS
   ORIGIN = 'https://github.com/Snowflake-Labs/sfguide-build-end-to-end-ml-workflow-in-snowflake' 
   API_INTEGRATION = 'GITHUB_INTEGRATION_E2E_SNOW_MLOPS' 
   COMMENT = 'Repositorio Github ';

-- Obtener los archivos más recientes del repositorio Github
ALTER GIT REPOSITORY GITHUB_REPO_E2E_SNOW_MLOPS FETCH;

-- Copiar notebook en snowflake y configurar runtime settings
CREATE OR REPLACE NOTEBOOK E2E_SNOW_MLOPS_DB.MLOPS_SCHEMA.TRAIN_DEPLOY_MONITOR_ML
FROM '@E2E_SNOW_MLOPS_DB.MLOPS_SCHEMA.GITHUB_REPO_E2E_SNOW_MLOPS/branches/main/' 
MAIN_FILE = 'train_deploy_monitor_ML_in_snowflake.ipynb' QUERY_WAREHOUSE = E2E_SNOW_MLOPS_WH
RUNTIME_NAME = 'SYSTEM$BASIC_RUNTIME' 
COMPUTE_POOL = 'MLOPS_COMPUTE_POOL'
IDLE_AUTO_SHUTDOWN_TIME_SECONDS = 3600;

--¡LISTO! Ahora puedes acceder a tu notebook recién creado con tu E2E_SNOW_MLOPS_ROLE y ejecutar el flujo de trabajo de extremo a extremo!

SHOW NOTEBOOKS;

GRANT USAGE ON DATABASE E2E_SNOW_MLOPS_DB to ROLE ACCOUNTADMIN;
GRANT USAGE ON SCHEMA MLOPS_SCHEMA to ROLE ACCOUNTADMIN;

