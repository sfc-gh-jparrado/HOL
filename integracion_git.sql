use role accountadmin;

Create database if not exists DB_EMPRESA_HOL;

CREATE OR REPLACE WAREHOUSE ml_wh WITH 
WAREHOUSE_TYPE = standard WAREHOUSE_SIZE = Medium
AUTO_SUSPEND = 5 AUTO_RESUME = True;


-- Crear api integration para este repositorio publico
create or replace api integration git_api_integration_hol
api_provider = git_https_api
api_allowed_prefixes = ('https://github.com/sfc-gh-jparrado/HOL')
enabled = true
comment='integracion para el repositorio hol jorge parrado'
;

show integrations;
DESC INTEGRATION git_api_integration_hol;

-- crear repositorio en la base de datos apuntando a la integración
CREATE GIT REPOSITORY demos
ORIGIN = 'https://github.com/sfc-gh-jparrado/HOL'
API_INTEGRATION = 'GIT_API_INTEGRATION_HOL';

