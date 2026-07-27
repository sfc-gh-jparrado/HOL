# HOL ACH — El incidente de las 3:00 AM (PSE, batch)

HOL integrado (1 hora) para **ACH Colombia** sobre el dominio **PSE**: seguridad, gobierno y desarrollo con Snowflake + Cortex Code (Coco). **Todo en batch**: los datos se cargan desde S3 con `COPY` y se analizan. Sin Snowpipe ni tiempo real.

- Guía: `index.html` → https://sfc-gh-jparrado.github.io/HOL/HOL_ACH_2/
- Dos rutas con selector global: **Opción 1 · Full-stack** (Node.js + Coco Desktop + CLI + Podman) y **Opción 2 · Solo navegador**.
- Narrativa: un anillo de fraude golpea un comercio a las 3:00 AM y un banco dispara sus rechazos. Detectar → contener → prevenir.

## Datos (en S3 del instructor)
- `s3://demosjparrado/hol_ach_2/pse_hist/` — ~30M transacciones PSE.
- `.../comercios/` — dimensión comercios (501).
- `.../bancos/` — dimensión bancos (20).
- Modelo destino: `PSE_TRANSACTIONS`, `COMERCIOS`, `BANCOS` en `HOL_SEC.INCIDENTE`.
- El estudiante **no toca AWS**: solo lee el bucket con la llave IAM read-only embebida en el `STAGE` (`COPY` desde S3). Sin `INSERT INTO` en el lab.

## Scripts
- `scripts/pse_gen.sql` — (instructor) genera el histórico en Snowflake, agrega PK/FK y lo descarga (UNLOAD) a S3, incluidas las dimensiones.
- `scripts/feeder_pse.py`, `start_feeder.sh`, `stop_feeder.sh` — **OPCIONAL / avanzado**: simulan un feed de streaming a S3. **No forman parte del HOL batch**; se conservan por si se quiere demostrar ingesta continua (Snowpipe) por separado.

> El Módulo 4 (desarrollo) no trae scripts de referencia: cada ruta lo construye con un **prompt de Coco** — Opción 1 crea una app **React en SPCS** con el skill externo [`snowflake-dashboard-viz`](https://github.com/sfc-gh-jparrado/cortex-code-skills); Opción 2 crea un **dashboard Streamlit-in-Snowflake** vía Coco en Snowsight.

## Cómo correr (estudiante)
1. **Módulo 1 · Setup**: ejecuta el bloque del `index.html` (crea entorno, PK/FK, stage y `COPY` de las 3 tablas desde S3).
2. **Módulo 2 · Detectar**: detecciones de fraude (rechazos por banco, velocity, monto atípico, comercio bajo ataque).
3. **Módulo 3 · Contener**: gobierno (clasificar PII, enmascarar email/documento/nombre, acceso por banco, triage con Cortex AI).
4. **Módulo 4 · Prevenir**: 4.1 crea el semantic view `sv_pse` por la **UI de Snowsight** (auto-detecta los joins desde las FK); 4.2 agente Cortex en CoWork. Luego, según la ruta: **Opción 1** = app React en SPCS (skill `snowflake-dashboard-viz`); **Opción 2** = dashboard Streamlit vía Coco en Snowsight.
5. **Módulo 5 · Cierre**: limpieza (`DROP DATABASE`).

## Operación (instructor)
- Regenerar/actualizar datos: correr `scripts/pse_gen.sql` (requiere AWS SSO y llave IAM con escritura temporal para el UNLOAD; revertir a read-only después).
- Refresco batch: para traer datos nuevos, re-ejecutar el `COPY` o programar una `TASK`.
- Rotar/borrar la llave IAM read-only del stage cuando el HOL deje de usarse.

Datos 100% sintéticos, sin PII real.
