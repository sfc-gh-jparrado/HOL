#!/usr/bin/env bash
# ============================================================================
# Demo SET-ICAP - Limpieza completa
# ============================================================================
# Elimina los objetos de Snowflake y la instancia Postgres (detiene el cobro).
# Uso:  bash scripts/99_cleanup.sh
# ============================================================================
set -uo pipefail

SKILL_DIR="/Applications/Cortex Code.app/Contents/Resources/app/resources/snowflake/skills/cortex-code-skills/snowflake-postgres"
SF_CONN="demo_account_aws"
INSTANCE="PG_SETFX"

echo ">> 1. Eliminar objetos de Snowflake (CLD + catalog integration)..."
snow sql -c "${SF_CONN}" -q "
USE ROLE ACCOUNTADMIN;
DROP DATABASE IF EXISTS DB_SETFX_LIVE;
DROP CATALOG INTEGRATION IF EXISTS CI_SETFX_PG;
" || echo "   (revisa manualmente si snow CLI no está configurado)"

echo ">> 2. Eliminar la instancia Snowflake Postgres (detiene cobro)..."
snow sql -c "${SF_CONN}" -q "
USE ROLE ACCOUNTADMIN;
DROP POSTGRES INSTANCE IF EXISTS ${INSTANCE};
" || echo "   (o ejecútalo desde Snowsight: DROP POSTGRES INSTANCE ${INSTANCE};)"

echo ">> 3. (Opcional) quitar la conexión local 'setfx' de ~/.pg_service.conf y ~/.pgpass."
echo "Listo."
