/* ============================================================================
   Demo SET-ICAP - Leer Postgres desde Snowflake SIN ETL (pg_lake + CLD)
   Se ejecuta EN SNOWFLAKE (cuenta demo_aws, ACCOUNTADMIN).
   Requiere: instancia PG_SETFX (managed storage) con tablas Iceberg sembradas
   (sql/02_pg_schema_seed.sql) y pg_lake habilitado.
============================================================================ */
USE ROLE ACCOUNTADMIN;

/* ----------------------------------------------------------------------------
   1. Catalog Integration hacia la instancia Postgres (managed storage).
      Lee los metadatos Iceberg que pg_lake mantiene; sin copiar datos.
---------------------------------------------------------------------------- */
CREATE OR REPLACE CATALOG INTEGRATION CI_SETFX_PG
  CATALOG_SOURCE = SNOWFLAKE_POSTGRES
  TABLE_FORMAT   = ICEBERG
  REST_CONFIG = (
    POSTGRES_INSTANCE      = 'PG_SETFX',          -- nombre de la instancia
    CATALOG_NAME           = 'postgres',           -- base de datos PG (default)
    ACCESS_DELEGATION_MODE = VENDED_CREDENTIALS
  )
  ENABLED = TRUE;

-- Refresco cada 30s para que la demo muestre cambios casi en vivo
ALTER CATALOG INTEGRATION CI_SETFX_PG SET REFRESH_INTERVAL_SECONDS = 30;

DESCRIBE CATALOG INTEGRATION CI_SETFX_PG;

/* ----------------------------------------------------------------------------
   2. Catalog-Linked Database (CLD): expone TODAS las tablas Iceberg del
      Postgres como una base read-only en Snowflake. Sin ETL, sin pipelines.
      ALLOWED_WRITE_OPERATIONS = NONE es obligatorio para SNOWFLAKE_POSTGRES.
---------------------------------------------------------------------------- */
CREATE OR REPLACE DATABASE DB_SETFX_LIVE
  LINKED_CATALOG = (
    CATALOG = 'CI_SETFX_PG',
    ALLOWED_WRITE_OPERATIONS = NONE
  );

-- Las tablas del Postgres aparecen solas (ventana de refresco ~30s)
SHOW TABLES IN DATABASE DB_SETFX_LIVE;

/* ----------------------------------------------------------------------------
   3. PRUEBA: los datos del Postgres ya son consultables desde Snowflake
---------------------------------------------------------------------------- */
SELECT COUNT(*) AS operaciones_visibles_en_snowflake
FROM DB_SETFX_LIVE.public.operation_set_fx;

SELECT * FROM DB_SETFX_LIVE.public.operation_set_fx LIMIT 10;

/* ============================================================================
   DEMO EN VIVO  (con scripts/pg_simulator.py corriendo en --loop)
   Repite estas consultas cada ~30s: el conteo y el VWAP CAMBIAN SOLOS.
============================================================================ */

-- 3.1 VWAP en vivo del USD/COP (mercado contado), directo desde Postgres
SELECT
  COUNT(*)                                                   AS num_ops,
  ROUND(SUM(precio * monto_usd) / NULLIF(SUM(monto_usd),0),2) AS vwap_usdcop,
  ROUND(SUM(monto_usd)/1e6, 2)                               AS volumen_musd,
  MAX(ts_carga)                                              AS ultima_actualizacion
FROM DB_SETFX_LIVE.public.operation_set_fx
WHERE NOT anulada AND mercado = 76;

-- 3.2 Top entidades por volumen comprado (join CLD con su propio catálogo)
SELECT e.entidad_sigla, e.entidad_nombre, e.entidad_clase,
       COUNT(*) AS ops, ROUND(SUM(o.monto_usd)/1e6,1) AS vol_compra_musd
FROM DB_SETFX_LIVE.public.operation_set_fx o
JOIN DB_SETFX_LIVE.public.entidad e ON o.entidad_compradora = e.entidad_id
WHERE NOT o.anulada
GROUP BY 1,2,3 ORDER BY vol_compra_musd DESC LIMIT 10;

-- 3.3 Cortex AI directamente sobre datos que viven en Postgres (sin moverlos)
SELECT AI_COMPLETE('claude-sonnet-4-5',
  'Eres analista del mercado cambiario colombiano SET-FX. En una frase, comenta las ' ||
  'condiciones del mercado: TRM (VWAP) ' ||
  (SELECT ROUND(SUM(precio*monto_usd)/NULLIF(SUM(monto_usd),0),2)::VARCHAR
     FROM DB_SETFX_LIVE.public.operation_set_fx WHERE NOT anulada AND mercado=76) ||
  ' COP/USD, volumen ' ||
  (SELECT ROUND(SUM(monto_usd)/1e6,1)::VARCHAR
     FROM DB_SETFX_LIVE.public.operation_set_fx WHERE NOT anulada) ||
  'M USD.') AS lectura_de_mercado;

/* ----------------------------------------------------------------------------
   4. (Opcional) Materializar una vista o Dynamic Table sobre el CLD para
      analítica pesada, manteniendo el Postgres como única fuente de verdad.
---------------------------------------------------------------------------- */
-- CREATE OR REPLACE VIEW V_SETFX_LIVE AS
--   SELECT * FROM DB_SETFX_LIVE.public.operation_set_fx WHERE NOT anulada;

/* ============================================================================
   LIMPIEZA (ver scripts/99_cleanup.sh para el flujo completo incl. la instancia)
============================================================================ */
-- DROP DATABASE IF EXISTS DB_SETFX_LIVE;
-- DROP CATALOG INTEGRATION IF EXISTS CI_SETFX_PG;
