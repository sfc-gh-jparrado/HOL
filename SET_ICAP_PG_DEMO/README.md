# Demo SET-ICAP · Postgres en Snowflake + Sincronización sin ETL (pg_lake)

**Objetivo de negocio:** mostrarle a SET-ICAP cómo su base de datos operativa (hoy en
PostgreSQL) puede **vivir dentro de Snowflake** como **Snowflake Postgres**, y cómo sus
datos se exponen a la plataforma analítica de Snowflake **sin ETL, sin pipelines, sin
copias** — usando **pg_lake** (tablas Iceberg) + un **Catalog-Linked Database**.

Mientras la aplicación transaccional sigue escribiendo en Postgres (igual que hoy), los
cambios aparecen en Snowflake en **segundos**, listos para analítica, Cortex AI e
Intelligence.

> Esta es una **demo separada del HOL**. El HOL principal usa Snowpipe + cargas automáticas
> desde S3. Esta demo muestra la alternativa nativa Postgres → Snowflake sin ETL.

---

## La narrativa para el cliente

```
   APP SET-FX (OLTP)                     SNOWFLAKE (analítica, sin ETL)
   ┌──────────────────┐                  ┌────────────────────────────────┐
   │ Snowflake        │  pg_lake         │ Catalog Integration             │
   │ Postgres         │  escribe Iceberg │ (CATALOG_SOURCE=SNOWFLAKE_POSTGRES)
   │  operation_set_fx├─────────────────►│        │                       │
   │  (Iceberg)       │  (managed S3)    │        ▼                       │
   │                  │                  │ Catalog-Linked Database (CLD)   │
   │  ▲ INSERT/UPDATE │                  │  SELECT live ... (refresh ~30s) │
   │  │ simulador     │                  │        │                       │
   └──┼───────────────┘                  │        ▼ Cortex AI / DT / Agent │
      │ datos cambian constantemente     └────────────────────────────────┘
```

**Mensaje clave:** *"No mueves los datos. No construyes pipelines. Tu Postgres vive en
Snowflake y la analítica lo ve en vivo."*

---

## Requisitos

- Cuenta `demo_account_aws` (SFSENORTHAMERICA-DEMO_JPARRADO) con **ACCOUNTADMIN**.
- Snowflake Postgres habilitado (verificado: `SHOW POSTGRES INSTANCES` corre sin error).
- `psql` instalado localmente (para el seed y el simulador).
- Python `~/miniforge3/bin/python` (psycopg / numpy).

> **Nota de arquitectura:** para el path `CATALOG_SOURCE = SNOWFLAKE_POSTGRES` la instancia
> Postgres debe usar **managed storage** (NO adjuntar storage integration / bucket propio).
> pg_lake escribe Iceberg en un bucket administrado por Snowflake y el catálogo lo lee.

---

## Pasos (runbook)

### 1. Crear la instancia Snowflake Postgres ⚠️ billable — requiere tu aprobación
```bash
bash scripts/01_create_pg_instance.sh
```
Crea `PG_SETFX` (managed storage), guarda la conexión `setfx` en `~/.pg_service.conf` y
aplica una network policy con tu IP.

### 2. Crear el esquema SET-FX como Iceberg y sembrar datos
```bash
psql "service=setfx connect_timeout=10" -f sql/02_pg_schema_seed.sql
```
Crea `entidad` y `operation_set_fx` (tablas **Iceberg** vía pg_lake) y carga ~2,000
operaciones iniciales.

### 3. Exponer a Snowflake sin ETL (catalog integration + CLD)
En `demo_account_aws` (Snowsight o `snow sql -c demo_account_aws`):
```bash
snow sql -c demo_account_aws -f sql/03_snowflake_catalog_cld.sql
```
Crea la catalog integration `CI_SETFX_PG`, el CLD `DB_SETFX_LIVE` (read-only) y consultas
que muestran los datos en vivo.

### 4. Iniciar el simulador (datos cambian constantemente)
```bash
export PGSERVICE=setfx
~/miniforge3/bin/python scripts/pg_simulator.py --loop --interval 10
```
Cada 10 s inserta nuevas operaciones FX y mueve la TRM. En Snowflake, vuelve a correr la
consulta del CLD: el conteo y el VWAP **cambian solos** (refresh ~30 s), sin ETL.

### 5. (Demo) Analítica viva en Snowflake
Corre las consultas de la sección "DEMO EN VIVO" de `sql/03_snowflake_catalog_cld.sql`:
VWAP en vivo, top entidades, y un `AI_COMPLETE` que comenta las condiciones del mercado.

---

## Guion de demo (5 min)

1. **"Aquí está su Postgres, en Snowflake"** — muestra `SHOW POSTGRES INSTANCES` y una
   consulta `psql` a `operation_set_fx`.
2. **"Sin mover datos, Snowflake ya lo ve"** — `SELECT COUNT(*) FROM DB_SETFX_LIVE.public.operation_set_fx;`
3. **"Y cambia en vivo"** — con el simulador corriendo, repite el COUNT/VWAP cada ~30 s.
4. **"Sobre eso, todo Snowflake"** — Cortex AI sobre los datos del CLD, sin pipeline.
5. **Cierre:** *"Cero ETL, cero duplicación, una sola fuente de verdad."*

---

## Limpieza
```bash
bash scripts/99_cleanup.sh   # DROP CLD, catalog integration, y la instancia PG (detiene cobro)
```

---

## Archivos
| Archivo | Descripción |
|---------|-------------|
| `scripts/01_create_pg_instance.sh` | Crea la instancia Snowflake Postgres (managed) |
| `sql/02_pg_schema_seed.sql` | DDL Iceberg + seed inicial (corre en Postgres) |
| `scripts/pg_simulator.py` | Inserta/actualiza operaciones constantemente |
| `sql/03_snowflake_catalog_cld.sql` | Catalog integration + CLD + demo en vivo (Snowflake) |
| `scripts/99_cleanup.sh` | Limpieza de todos los objetos |
