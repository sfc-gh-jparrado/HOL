#!/usr/bin/env bash
# ============================================================================
# Demo SET-ICAP - Crear instancia Snowflake Postgres (managed storage)
# ============================================================================
# Crea PG_SETFX con managed storage (SIN storage integration) para habilitar
# el path pg_lake + CATALOG_SOURCE=SNOWFLAKE_POSTGRES (lectura desde Snowflake
# sin ETL). Guarda la conexion 'setfx' en ~/.pg_service.conf y ~/.pgpass.
#
# ⚠️ BILLABLE: crea una instancia Postgres. Requiere ACCOUNTADMIN en demo_aws.
# Uso:  bash scripts/01_create_pg_instance.sh
# ============================================================================
set -euo pipefail

SKILL_DIR="/Applications/Cortex Code.app/Contents/Resources/app/resources/snowflake/skills/cortex-code-skills/snowflake-postgres"
SF_CONN="demo_account_aws"          # cuenta demo_aws (ACCOUNTADMIN)
INSTANCE="PG_SETFX"
COMPUTE_FAMILY="STANDARD_M"          # 1 core / 4GB - suficiente para demo
STORAGE_GB="10"

echo ">> Creando instancia Snowflake Postgres '${INSTANCE}' (managed storage)..."
echo "   Cuenta: ${SF_CONN} | Familia: ${COMPUTE_FAMILY} | Storage: ${STORAGE_GB}GB"
echo "   (NO se adjunta storage integration: managed storage es requisito del"
echo "    path CATALOG_SOURCE=SNOWFLAKE_POSTGRES)"

uv run --project "${SKILL_DIR}" python "${SKILL_DIR}/scripts/pg_connect.py" \
  --create \
  --instance-name "${INSTANCE}" \
  --compute-pool "${COMPUTE_FAMILY}" \
  --storage "${STORAGE_GB}" \
  --auth-authority POSTGRES \
  --comment "Demo SET-ICAP: SET-FX OLTP en Snowflake Postgres (pg_lake)" \
  --use-role ACCOUNTADMIN \
  --snowflake-connection "${SF_CONN}"

echo ""
echo ">> Si el probe TCP marca timeout, falta la network policy con tu IP."
echo "   Crea/asocia una network policy de ingreso Postgres (MODE=POSTGRES_INGRESS)"
echo "   con tu IP publica. Luego prueba:"
echo "     psql \"service=setfx connect_timeout=10\" -c 'SELECT version();'"
echo ""
echo ">> Habilitar pg_lake en la instancia (extensiones):"
echo "   uv run --project \"${SKILL_DIR}\" python \"${SKILL_DIR}/scripts/pg_lake_setup.py\" \\"
echo "     --enable-extensions --connection-name setfx"
