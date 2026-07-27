# HOL ACH — El incidente de las 3:00 AM (PSE en tiempo real)

HOL integrado (1 hora) para **ACH Colombia** sobre el dominio **PSE**: seguridad, gobierno y desarrollo con Snowflake + Cortex Code (Coco).

- Guía: `index.html` → publicada en https://sfc-gh-jparrado.github.io/HOL/HOL_ACH_2/
- Narrativa: un anillo de fraude golpea un comercio a las 3:00 AM y un banco dispara sus rechazos. Detectar → contener → prevenir.

## Datos
- Histórico: ~30M transacciones PSE en `s3://demosjparrado/hol_ach_2/pse_hist/` (+ `comercios/`).
- Feed en vivo: `s3://demosjparrado/hol_ach_2/pse_stream/` (lo alimenta el feeder).
- Modelo: `PSE_TRANSACTIONS`, `COMERCIOS`, `BANCOS` en `HOL_SEC.INCIDENTE`.

## Scripts
- `scripts/pse_gen.sql` — genera el histórico en Snowflake y lo descarga (UNLOAD) a S3.
- `scripts/feeder_pse.py` — feeder de tiempo real (sube lotes a `pse_stream/` vía AWS SSO).
- `scripts/start_feeder.sh [intervalo_seg] [batch]` / `scripts/stop_feeder.sh` — arrancar/detener el feeder.
- `scripts/app_pse_monitor.py` — dashboard Streamlit-in-Snowflake que lee las Dynamic Tables.

## Cómo correr
1. Ejecuta el bloque de Setup del `index.html` (crea entorno, stage y carga el histórico).
2. Crea el PIPE de auto-ingest y las Dynamic Tables (Acto 3 del `index.html`).
3. Configura la notificación de evento del bucket hacia el `notification_channel` del PIPE.
4. Arranca el feeder durante la sesión: `cd scripts && ./start_feeder.sh 15 800` (requiere AWS SSO activo).
5. Despliega `app_pse_monitor.py` en Snowsight (Streamlit) o construye el Cortex Agent (Ambiente 2).

## Operación y costo
El feed en vivo mantiene Snowpipe y las Dynamic Tables activos. **Arranca el feeder solo durante la sesión y deténlo al final.** Al terminar:
- `./stop_feeder.sh`
- `ALTER DYNAMIC TABLE ... SUSPEND` (las tres) y `ALTER PIPE pse_pipe SET PIPE_EXECUTION_PAUSED = TRUE`
- `DROP DATABASE HOL_SEC; DROP WAREHOUSE HOL_WH;`
- Rotar/borrar la llave IAM read-only del stage cuando el HOL deje de usarse.

Datos 100% sintéticos, sin PII real.
