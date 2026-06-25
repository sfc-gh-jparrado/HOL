# SET-ICAP · Postgres en Snowflake → Iceberg sin ETL

Demo de **replicación automática sin ETL/ELT**: Postgres (gestionado dentro de Snowflake)
escribe tablas **Apache Iceberg** en almacenamiento gestionado; Snowflake lee **los mismos
archivos** a través de una *Catalog-Linked Database* (CLD). No hay pipeline, ni copia, ni
transformación intermedia — es el **mismo dato físico** visto desde dos motores.

## Qué se construyó

**En Postgres (`PG_SETFX`, PostgreSQL 18, almacenamiento gestionado):**
- Tabla Iceberg `public.operaciones_live` (operaciones FX USD/COP).
- Función `public.gen_operaciones_live()` que inserta 3–5 operaciones realistas por ciclo.
- Job **pg_cron** `setfx_live_30s` que ejecuta la función **cada 30 segundos**.

**En Snowflake (cuenta demo):**
- Catalog Integration `CI_PG_SETFX` (`CATALOG_SOURCE = SNOWFLAKE_POSTGRES`, `VENDED_CREDENTIALS`).
- Catalog-Linked Database `PG_SETFX_LAKE` (read-only, `ALLOWED_WRITE_OPERATIONS = NONE`,
  auto-refresh ~30 s). Expone **todas** las tablas Iceberg de Postgres, presentes y futuras:
  `entidad`, `operaciones_live`, `operation_set_fx`.

```
Postgres (pg_cron INSERT cada 30s)
        │  escribe Iceberg en almacenamiento gestionado (S3 interno)
        ▼
  [ mismos archivos Iceberg + metadata ]
        ▲
        │  Snowflake los lee vía CLD (auto-refresh 30s, sin copiar)
Snowflake  SELECT * FROM PG_SETFX_LAKE.PUBLIC.OPERACIONES_LIVE
```

## Cómo abrir las dos puntas en la demo

### 1) Postgres — el dato naciendo
```bash
export PATH="/opt/homebrew/opt/libpq/bin:$PATH"   # si psql no está en PATH (brew install libpq)
psql "service=pg_setfx"
```
```sql
-- el job está corriendo cada 30s
SELECT jobid, schedule, command, active FROM cron.job;

-- el contador sube solo
SELECT count(*), max(id_operacion), max(ts_operacion) FROM public.operaciones_live;

-- últimas operaciones generadas
SELECT id_operacion, ts_operacion, entidad_compradora, entidad_vendedora, monto_usd, tasa_cop, plazo
FROM public.operaciones_live ORDER BY id_operacion DESC LIMIT 10;
```

### 2) Snowflake — el mismo dato, sin moverlo (Snowsight, cuenta demo)
```sql
-- el CLD está sano y muestra las tablas de Postgres
SELECT SYSTEM$CATALOG_LINK_STATUS('PG_SETFX_LAKE');
SHOW TABLES IN DATABASE PG_SETFX_LAKE;

-- mismo conteo (con ~30s de rezago por el ciclo de refresh)
SELECT count(*), max(id_operacion), max(ts_operacion)
FROM PG_SETFX_LAKE.PUBLIC.OPERACIONES_LIVE;
```

**Truco de demo:** pon las dos ventanas lado a lado y ve corriendo el `count(*)` en cada una.
Postgres va siempre unas filas adelante; Snowflake lo alcanza en la siguiente ventana de
refresh (~30 s). Eso demuestra que es replicación **viva y automática, sin ETL**.

## Speech corto (≈45 s)

> "Lo que ven a la izquierda es Postgres generando operaciones FX en vivo — un OLTP normal,
> el sistema transaccional de SET-FX. A la derecha es Snowflake. **No hay ningún pipeline,
> ningún job de ETL, ninguna copia.** Snowflake está leyendo exactamente los mismos archivos
> Iceberg que Postgres acaba de escribir, y el contador sube solo cada treinta segundos.
>
> ¿Por qué Postgres **dentro** de Snowflake y no en otra nube u on-premise? Tres razones:
> **cero movimiento de datos** — el transaccional y el analítico comparten el mismo Iceberg,
> así que no pagas ni esperas un ETL para analizar lo operativo; **un solo plano de gobierno
> y seguridad** — los mismos roles, políticas de enmascaramiento y auditoría de Snowflake
> aplican al dato operativo, sin reconciliar permisos entre nubes; y **una sola factura y un
> solo equipo** — sin mover datos entre proveedores, sin egress, sin un stack de replicación
> que mantener. Tu base transaccional y tu analítica por fin viven en el mismo lugar."

## Apagar / limpiar (al terminar la demo)
```sql
-- Postgres: parar la generación
SELECT cron.unschedule('setfx_live_30s');
```
```sql
-- Snowflake: quitar la exposición (en este orden)
DROP DATABASE IF EXISTS PG_SETFX_LAKE;
DROP CATALOG INTEGRATION IF EXISTS CI_PG_SETFX;
```
> Para reanudar la generación: `SELECT cron.schedule('setfx_live_30s','30 seconds',$$SELECT public.gen_operaciones_live();$$);`
