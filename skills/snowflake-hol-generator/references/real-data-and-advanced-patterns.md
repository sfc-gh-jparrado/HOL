# Real-Data, Enterprise-Scale & SQL-First HOL Patterns

Patrones probados en HOLs de gran escala con **datos reales en S3** (no sintéticos),
una **capa de consumo viva** con Dynamic Tables, **Cortex multimodal**, y un agente de
**Snowflake CoWork** en español. Complementa el flujo por defecto (datos sintéticos con
`GENERATOR`). Úsalo cuando el cliente quiere impacto de escala real (cientos de millones
de filas), ingesta desde S3, o un HOL "tipo producción".

> **Estilo (preferencias del autor):** todo en **español**; en los comentarios del SQL
> **no** narres conteos de archivos ni tiempos ("se carga en N segundos", "128 archivos");
> el instructor habla eso. Comenta el *qué* y el *por qué*, no la mecánica de nodos.

---

## 1. Modo de datos: real desde S3 (external stage) vs sintético

Cuando el HOL debe impresionar con **escala real**, carga desde un bucket S3 con datos
pre-generados (`.csv.gz`, delimitador `;`) en vez de `GENERATOR`.

```sql
CREATE OR REPLACE FILE FORMAT FF_CSV_GZ
  TYPE=CSV FIELD_DELIMITER=';' FIELD_OPTIONALLY_ENCLOSED_BY='"' COMPRESSION=GZIP
  NULL_IF=('NULL','') EMPTY_FIELD_AS_NULL=TRUE TRIM_SPACE=TRUE SKIP_HEADER=1;

CREATE OR REPLACE STAGE STG_<NS>
  URL='s3://<bucket>/<path>/'
  CREDENTIALS=(AWS_KEY_ID='<SOLICITAR_AL_INSTRUCTOR>' AWS_SECRET_KEY='<SOLICITAR_AL_INSTRUCTOR>')
  FILE_FORMAT=FF_CSV_GZ;

-- Validar el formato leyendo crudo SIN cargar (posicional $1,$2,...):
SELECT $1 AS id, $2 AS fecha FROM @STG_<NS>/hist/<tabla>/ (FILE_FORMAT => FF_CSV_GZ) LIMIT 5;
```

Reglas:
- El **orden de columnas del CSV debe coincidir con el orden del DDL** (COPY mapea por posición).
- **Nunca** incrustes las llaves en el HTML: deja el placeholder `<SOLICITAR_AL_INSTRUCTOR>`.
  Entrega las credenciales (read-only) por canal seguro y **rótalas** antes de enviar al cliente.
- Los datos **se quedan en S3**: el cliente solo necesita el HTML, el `semantic_model.yaml`
  y las credenciales de lectura. No le compartes archivos de datos.

## 2. Demo de Warehouse Scaling (impacto de velocidad)

Carga la tabla grande en `SMALL`, luego `TRUNCATE` + sube a `XLARGE` y recarga, para mostrar
el escalado al vuelo. Vuelve a `SMALL` al terminar (costo).

```sql
COPY INTO <TABLA_GRANDE> FROM @STG_<NS>/hist/<tabla>/;
SELECT COUNT(1) FROM <TABLA_GRANDE>;
TRUNCATE TABLE <TABLA_GRANDE>;
ALTER WAREHOUSE WH_<NS> SET WAREHOUSE_SIZE='XLARGE';
COPY INTO <TABLA_GRANDE> FROM @STG_<NS>/hist/<tabla>/;
-- carga aquí el resto de tablas grandes mientras estás en XLARGE
ALTER WAREHOUSE WH_<NS> SET WAREHOUSE_SIZE='SMALL';
```

> Los archivos deben estar **finamente particionados** (~varias decenas de MB c/u) para que un
> warehouse grande sature sus hilos (COPY paraleliza 1 archivo por hilo). No menciones números
> de archivos en los comentarios; es detalle de preparación del dataset.

## 3. Dynamic Table ÚNICA y plana, sin fan-out

Una sola DT de consumo que replica la "vista plana" del cliente (Tableau-style), uniendo todo
el modelo pero manteniendo **grano = 1 fila por transacción**. La relación uno-a-muchos
(contrapartes/lados) se **aplana por lado** con `LEFT JOIN` filtrados — esto evita el fan-out.

```sql
ALTER WAREHOUSE WH_<NS> SET WAREHOUSE_SIZE='X-LARGE';   -- solo para construir la unión
CREATE OR REPLACE DYNAMIC TABLE <CONSUMO>
  TARGET_LAG='1 hour' WAREHOUSE=WH_<NS> REFRESH_MODE=AUTO
AS
SELECT o.*, ec.<...> AS COMPRADOR_<...>, ev.<...> AS VENDEDOR_<...>
FROM <HECHOS> o
JOIN <DIM> ...
LEFT JOIN <PUENTE> cpc ON cpc.OPER_ID=o.ID AND cpc.LADO='C'   -- lado comprador
LEFT JOIN <PUENTE> cpv ON cpv.OPER_ID=o.ID AND cpv.LADO='V';  -- lado vendedor
ALTER WAREHOUSE WH_<NS> SET WAREHOUSE_SIZE='SMALL';
```

**Validación obligatoria de no-fan-out:** `COUNT(*)` de la DT debe ser **igual** al de la tabla
de hechos base. Si es mayor, hay fan-out (revisa los filtros de lado o usa `QUALIFY ROW_NUMBER`).

Esta DT plana es la **única tabla del semantic model de Cortex Analyst** → agregaciones siempre
correctas, sin relaciones que generen doble conteo.

## 4. Cortex AI multimodal (texto + imagen + audio)

Más allá de `AI_COMPLETE` sobre texto, demuestra multimodal con `TO_FILE` desde un stage con
`DIRECTORY=(ENABLE=TRUE)`:

```sql
-- Imagen (visión) con pixtral-large
SELECT SNOWFLAKE.CORTEX.COMPLETE('pixtral-large',
  PROMPT('Analiza este gráfico y resume la tendencia en 3 frases. {0}',
         TO_FILE('@STG_ARCHIVOS', 'grafico.png'))) AS lectura;

-- Audio: transcribir y extraer datos estructurados
WITH t AS (SELECT AI_TRANSCRIBE(TO_FILE('@STG_ARCHIVOS','llamada.mp3')) AS r)
SELECT r:text::STRING AS transcripcion,
       SNOWFLAKE.CORTEX.COMPLETE('claude-sonnet-4-5',
         'Extrae en JSON los campos X,Y,Z de esta llamada: ' || r:text::STRING) AS extraido
FROM t;
```

## 5. Cortex Search: SIEMPRE desde tablas BASE, nunca desde una DT FULL

Cortex Search requiere **change tracking**, y una Dynamic Table en `REFRESH_MODE=FULL` **no lo
soporta** (`Change tracking is not supported on dynamic tables with FULL REFRESH_MODE`).
Construye el servicio sobre las **tablas base** (con su JOIN), no sobre la DT de consumo.

```sql
CREATE OR REPLACE CORTEX SEARCH SERVICE CS_NOTAS
  ON TEXTO_TERM ATTRIBUTES FECHA, ...
  WAREHOUSE=WH_<NS> TARGET_LAG='1 hour'
  AS SELECT o.TEXTO_TERM, o.FECHA, ...
     FROM <HECHOS> o JOIN <DIM> ... WHERE o.TEXTO_TERM IS NOT NULL AND o.TEXTO_TERM <> '';
```

## 6. Dynamic Data Masking en la base Y en la DT

Aplica la política en la tabla base **y** en la DT de consumo, para que Cortex Analyst / CoWork
también enmascaren a roles no-admin. Las DTs soportan `ALTER DYNAMIC TABLE ... MODIFY COLUMN ... SET MASKING POLICY`.

```sql
CREATE OR REPLACE MASKING POLICY MP_X AS (v NUMBER) RETURNS NUMBER ->
  CASE WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN','SYSADMIN') THEN v ELSE 999999 END;
ALTER TABLE <HECHOS>   MODIFY COLUMN <COL> SET MASKING POLICY MP_X;
ALTER DYNAMIC TABLE <CONSUMO> MODIFY COLUMN <COL> SET MASKING POLICY MP_X;
```

## 7. Time Travel: forma robusta + recuperación in-place

Corre todo en **el mismo worksheet** (la variable de sesión `$qid` debe persistir).

```sql
DROP TABLE <T>; UNDROP TABLE <T>;                     -- recuperación instantánea
UPDATE <T> SET <COL>='CORRUPTO';                      -- accidente: UPDATE sin WHERE
SET bad_qid = LAST_QUERY_ID();
SELECT * FROM <T> AT(OFFSET => -180);                 -- requiere ≥3 min de historia (frágil)
SELECT * FROM <T> BEFORE(STATEMENT => $bad_qid);      -- a prueba de tiempo (SIEMPRE funciona)
INSERT OVERWRITE INTO <T> SELECT * FROM <T> BEFORE(STATEMENT => $bad_qid);  -- restaura in-place
```

- `BEFORE(STATEMENT => $qid)` es la forma a recomendar; `AT(OFFSET => -N)` falla si la tabla no
  tiene N segundos de historia (en una corrida rápida puede no haberla).
- Clon zero-copy para ambiente DEV: `CREATE OR REPLACE DATABASE <DB>_DEV CLONE <DB>;`

## 8. Cortex Analyst (semantic model) + agente CoWork en español

- **Semantic model** sobre la **única DT plana** (sin relaciones → sin fan-out). YAML con `name`,
  `base_table` totalmente calificada (`database/schema/table`), `dimensions`, `time_dimensions`,
  `metrics` (`SUM/AVG/COUNT`, VWAP). Valida ejecutándolo con Cortex Analyst (genera SQL real).
- **Agente** (Snowflake CoWork, se crea en UI): conecta Analyst + los Cortex Search. Instrucciones:
  > Razona y responde **siempre en español**; usa Analyst para cifras/rankings y Search para
  > notas/entidades; **al final propón 3 preguntas de seguimiento**; entrega respuesta **formateada
  > (markdown) y con gráfico** cuando aplique.
- Esta preferencia (markdown + gráfico + 3 preguntas) aplica a **todo agente o ventana flotante**
  que generes, no solo en el HOL.

## 9. Streamlit vía PROMPT de Cortex Code (no a mano)

En vez de escribir el `app.py`, el HOL incluye un **prompt** para que el usuario lo genere con
Cortex Code (CoCo): tema oscuro, acento `#29B5E8`, solo componentes nativos de Streamlit,
agregaciones en SQL, `@st.cache_data(ttl=600)`, robustez ante DataFrames vacíos. Apunta a la DT
de consumo.

## 10. Arquitectura SQL-first → HTML (mantener un solo origen)

Para HOLs grandes, mantén **un master `.sql`** con marcadores `PARTE N` y genera el HTML desde él
con un script (array `STEPS`). Beneficio: el HTML nunca se desincroniza del SQL.

- El regex que reemplaza el bloque debe tolerar espacios antes del cierre: `const STEPS = \[.*?\n\s*\];`
  (un cierre ` ];` con espacio hace fallar el build en silencio).
- Hazlo **idempotente**: si el `STEPS` generado es idéntico, no reescribas ni falles.
- **No edites el HTML a mano**; edita el SQL y regenera. Verifica que el `STEPS` generado coincide
  con el del HTML (comparación de longitud/igualdad) tras cualquier cambio.

## 11. Validación end-to-end en namespace AISLADO

Antes de entregar, corre las 12 partes **statement por statement** contra la cuenta, pero en un
**namespace de validación** (`DB_<NS>_TEST` / `WH_<NS>_TEST`), porque la Parte 1 hace
`CREATE OR REPLACE DATABASE` / `WAREHOUSE` — correrla con el nombre productivo **destruiría**
apps/agentes ya desplegados ahí. Al terminar, `DROP` del namespace de prueba.

Checklist de validación (todo debe pasar sin error):
- COPY y conteos por tabla (incluye los grandes).
- DT: `COUNT(DT) == COUNT(base)` (no fan-out).
- Masking: con un rol no-admin la columna sensible devuelve el valor anónimo.
- Cortex: COMPLETE (texto), pixtral (imagen), AI_TRANSCRIBE (audio).
- Cortex Search `ACTIVE` + `SEARCH_PREVIEW` devuelve resultados.
- Semantic model: Cortex Analyst genera SQL válido.
- Agente: responde por REST en español, markdown, con 3 preguntas.

> El tool de ejecución SQL puede correr como `ACCOUNTADMIN`; para probar el masking con un rol
> no-admin, crea un rol `_TEST`, otórgaselo a tu rol/usuario y haz `USE ROLE` dentro de la misma
> llamada multi-statement.

## 12. Entregables al cliente

- `set_..._hol.html` (la guía con todo el código).
- `..._semantic_model.yaml` (para Cortex Analyst en la Parte 10).
- Credenciales S3 read-only por **canal seguro** (no en el HTML).
- Opcionales avanzados: app React/SPCS con chat flotante del agente (ver skill
  `snowflake-dashboard-viz`), y módulo Postgres→Iceberg sin ETL (Snowflake Postgres + pg_lake +
  `CATALOG_SOURCE=SNOWFLAKE_POSTGRES` + Catalog-Linked Database, refresh mínimo 30s).
