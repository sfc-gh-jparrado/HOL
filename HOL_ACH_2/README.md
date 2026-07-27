# HOL ACH — El incidente de las 3:00 AM (PSE, batch)

HOL integrado (1 hora) para **ACH Colombia** sobre el dominio **PSE**: seguridad, gobierno y desarrollo con Snowflake + Cortex Code (Coco). **Todo en batch**: los datos se cargan desde S3 con `COPY` y se analizan. Sin Snowpipe ni tiempo real.

- Guía: `index.html` → https://sfc-gh-jparrado.github.io/HOL/HOL_ACH_2/
- Dos módulos con selector global: **A · Full-stack** (Node.js + Coco Desktop + CLI + Podman) y **B · Solo navegador**.
- Narrativa: un anillo de fraude golpea un comercio a las 3:00 AM y un banco dispara sus rechazos. Detectar → contener → prevenir.

## Datos (en S3 del instructor)
- `s3://demosjparrado/hol_ach_2/pse_hist/` — ~30M transacciones PSE.
- `.../comercios/` — dimensión comercios (501).
- `.../bancos/` — dimensión bancos (20).
- Modelo destino: `PSE_TRANSACTIONS`, `COMERCIOS`, `BANCOS` en `HOL_SEC.INCIDENTE`.
- El estudiante **no toca AWS**: solo lee el bucket con la llave IAM read-only embebida en el `STAGE` (`COPY` desde S3). Sin `INSERT INTO` en el lab.

## Scripts
- `scripts/pse_gen.sql` — (instructor) genera el histórico en Snowflake y lo descarga (UNLOAD) a S3, incluidas las dimensiones.
- `scripts/app_pse_monitor.py` — dashboard Streamlit-in-Snowflake de monitoreo (KPIs, volumen, alertas) que lee `PSE_TRANSACTIONS` (Módulo A / SPCS).
- `scripts/app_pse_explorer.py` — explorador visual Streamlit-in-Snowflake con **Plotly**: KPIs, gauges de % rechazo por banco, bar-race del volumen por comercio hora a hora, y mapa de calor día×hora. Detecta el día del incidente automáticamente (Módulo B por Snowsight; también sirve en A por SPCS). Requiere el paquete `plotly`.
- `scripts/feeder_pse.py`, `start_feeder.sh`, `stop_feeder.sh` — **OPCIONAL / avanzado**: simulan un feed de streaming a S3. **No forman parte del HOL batch**; se conservan por si se quiere demostrar ingesta continua (Snowpipe) por separado.

## Cómo correr (estudiante)
1. Ejecuta el bloque de Setup del `index.html` (crea entorno, stage y `COPY` de las 3 tablas desde S3).
2. Acto 1: detecciones de fraude (rechazos por banco, velocity, monto atípico, comercio bajo ataque).
3. Acto 2: gobierno (clasificar, enmascarar documento, acceso por banco, triage con IA).
4. Acto 3: ambos módulos crean el **semantic view `sv_pse`** (métricas: transacciones, monto, % rechazo; dimensiones: banco, comercio, ciudad, estado, fecha, hora). Módulo A = capa semántica + dashboard (`app_pse_monitor.py`); Módulo B = semantic view + Cortex Agent en CoWork + explorador visual Plotly (`app_pse_explorer.py`).

## Operación (instructor)
- Regenerar/actualizar datos: correr `scripts/pse_gen.sql` (requiere AWS SSO y llave IAM con escritura temporal para el UNLOAD; revertir a read-only después).
- Refresco batch: para traer datos nuevos, re-ejecutar el `COPY` o programar una `TASK`.
- Rotar/borrar la llave IAM read-only del stage cuando el HOL deje de usarse.

Datos 100% sintéticos, sin PII real.
