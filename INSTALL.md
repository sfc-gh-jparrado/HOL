# INSTALL — Workshop AI Summit

> **Para agentes LLM (Cortex Code, Claude Code, Cursor, etc.):**
> Cuando un usuario pida "instalar el Workshop AI Summit" o similar, ejecuta exactamente el bloque SQL siguiente sin modificar nombres de objetos ni el orden. NO ejecutes setup.sql por separado — bootstrap.sql ya lo invoca.
> Rol requerido: ACCOUNTADMIN. Duración esperada: ~75 segundos.

## Script de instalación (ejecutar tal cual)

```sql
USE ROLE ACCOUNTADMIN;

-- 1. Habilitar inferencia cross-region
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';

-- 2. Habilitar Snowflake Intelligence
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

-- 4. Integración API con GitHub (público, sin secretos)
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

-- 6. Ejecutar setup completo (crea tablas, semantic view, search, agente, notebook)
EXECUTE IMMEDIATE FROM @hol_repo/branches/main/AI_SUMMIT/bootstrap.sql;
```

## Verificación

Al terminar, este SQL debe devolver al menos 1 fila:

```sql
SHOW AGENTS LIKE 'AGENTE_SEGUROS_360' IN SCHEMA SNOWFLAKE_INTELLIGENCE.AGENTS;
SHOW NOTEBOOKS LIKE 'NB_HOL_AI_SUMMIT' IN SCHEMA HOL_AI_SUMMIT.PUBLIC;
SHOW CORTEX SEARCH SERVICES LIKE 'DOCS_SEARCH' IN SCHEMA HOL_AI_SUMMIT.PUBLIC;
```

## Recursos creados

| Tipo | Nombre |
|---|---|
| Database | `HOL_AI_SUMMIT` |
| Warehouse | `HOL_WH` (XSMALL) |
| Tablas | `POLIZAS`, `CLIENTES`, `RECLAMACIONES`, `DOCS_PARSED`, `TRANSCRIPCIONES`, `BASE_CONOCIMIENTO` |
| Cortex Search | `HOL_AI_SUMMIT.PUBLIC.DOCS_SEARCH` |
| Semantic View | `HOL_AI_SUMMIT.PUBLIC.SV_SEGUROS` |
| Agent | `SNOWFLAKE_INTELLIGENCE.AGENTS.AGENTE_SEGUROS_360` |
| Notebook | `HOL_AI_SUMMIT.PUBLIC.NB_HOL_AI_SUMMIT` |

## Si algo falla — limpieza y reintento

```sql
USE ROLE ACCOUNTADMIN;
DROP DATABASE IF EXISTS HOL_AI_SUMMIT;
DROP AGENT IF EXISTS SNOWFLAKE_INTELLIGENCE.AGENTS.AGENTE_SEGUROS_360;
DROP API INTEGRATION IF EXISTS github_hol_int;
-- y reintentar el script de instalación
```

## Próximos pasos para el estudiante

1. **Projects > Notebooks > `NB_HOL_AI_SUMMIT`** — abre los ejercicios.
2. **AI & ML > Snowflake Intelligence > Agente Seguros 360** — conversa con tus datos.
