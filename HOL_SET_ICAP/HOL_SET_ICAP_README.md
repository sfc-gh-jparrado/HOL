# HOL SET-ICAP — Mercado de Divisas SET-FX

**"De S3 a Snowflake Intelligence, en tiempo real"**

Hands-on Lab para **SET-ICAP**, la compañía líder en negociación y registro de divisas y
valores OTC en Colombia (filial de la Bolsa de Valores de Colombia y de TP ICAP Group,
operadora del sistema electrónico **SET-FX**).

> **Datos 100% sintéticos** generados para fines demostrativos. No representan operaciones
> reales de SET-ICAP ni de las entidades mencionadas.

---

## Qué demuestra este HOL

| Capacidad | Parte | Descripción |
|-----------|-------|-------------|
| Ingesta desde S3 | 2-3 | Stage externo + `COPY INTO` de 1 año de operaciones FX |
| **Snowpipe en tiempo real** ⭐ | 4 | Captura automática de operaciones nuevas cada 5 min |
| Time Travel & Cloning | 5 | Recuperación instantánea y ambientes dev sin copiar datos |
| Dynamic Data Masking | 6 | Anonimización de contrapartes para analistas |
| Cortex AI Functions | 7 | Clasificación, análisis y sentimiento de mercado con IA |
| Dynamic Tables | 8 | VWAP y rankings que se refrescan solos |
| Streamlit in Snowflake | 9 | Tablero interactivo del mercado SET-FX |
| Cortex Analyst | 10 | Semantic View para preguntas en lenguaje natural |
| Snowflake Intelligence | 11 | Agente conversacional experto del mercado FX |

**Lo nuevo frente a los HOL de Retail/Salud:** ingesta *streaming* con **Snowpipe**.
Un proceso externo deposita operaciones en S3 cada 5 minutos y Snowflake las captura
automáticamente, simulando el flujo real del sistema SET-FX.

---

## Requisitos

- Cuenta Snowflake (trial sirve) con rol **ACCOUNTADMIN**.
- Región con **Cortex** disponible (el HOL habilita `CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION'`).
- Credenciales del stage S3 (las entrega el instructor).

---

## Modelo de datos

```
                       ┌─────────────────────┐
   CURRENCY ◄──────────┤  OPERATION_SET_FX   ├──────────► ENTIDAD (compradora/vendedora)
   MERCADO  ◄──────────┤   (118K filas hist) │            │  └─ SUCURSAL ◄─ USUARIO
   PARIDAD  ◄──────────┤                     │            │
   SUB_MERCADO ◄───────┘                     │            COMITENTE ◄─ CIIU
                                              │
                       OPERATION_SET_FX_CONTRAPARTE (2 filas/operación: lado C y V)
```

| Tabla | Filas | Tipo |
|-------|-------|------|
| `currency`, `mercado`, `paridad_moneda`, `sub_mercado`, `ciiu` | 8-15 | Catálogos |
| `entidad` | 50 | IMCs (bancos, comisionistas) |
| `sucursal` | 123 | Mesas de dinero |
| `usuario` | 316 | Traders/brokers |
| `comitente` | 800 | Clientes finales (domésticos/offshore) |
| `operation_set_fx` | 118,389 | Operaciones FX (1 año) |
| `operation_set_fx_contraparte` | 236,778 | Contrapartes por operación |

**Campo clave:** `precio` = TRM (COP por USD). La serie histórica va de ~4,340 (jun-2025)
a ~3,450 (jun-2026), reflejando la apreciación del peso colombiano.

---

## Datos en S3

```
s3://demosjparrado/set_icap_hol/
├── hist/                # Histórico (csv.gz, ';', cargado con COPY INTO)
│   ├── currency/  mercado/  paridad_moneda/  sub_mercado/  ciiu/
│   ├── entidad/  sucursal/  usuario/  comitente/
│   ├── operation_set_fx/
│   └── operation_set_fx_contraparte/
└── stream/              # Landing de Snowpipe (un archivo cada 5 min)
    └── set_fx_YYYYMMDD_HHMMSS.csv.gz
```

---

## Cómo correr el HOL

1. Abre `HOL_SET_ICAP.sql` en un Worksheet de Snowflake.
2. Reemplaza `<SOLICITAR_AL_INSTRUCTOR>` por las credenciales del stage.
3. Ejecuta las **Partes 1 a 4** (setup, carga histórica y Snowpipe).
4. **Inicia el generador de streaming** (en una terminal del instructor) para que el
   Snowpipe tenga datos nuevos que capturar:

   ```bash
   export AWS_PROFILE=contributor-484577546576
   # Bucle continuo, un lote cada 5 minutos:
   ~/miniforge3/bin/python scripts/gen_set_icap_stream.py --loop --interval 300
   ```

   Para una demo rápida (varios lotes seguidos):
   ```bash
   for i in 1 2 3; do ~/miniforge3/bin/python scripts/gen_set_icap_stream.py --once; sleep 5; done
   ```
5. Vuelve al Worksheet y ejecuta el resto de las consultas de la Parte 4 para ver
   las operaciones ingeridas (`SELECT COUNT(*) FROM OPERATION_FX_STREAM;`).
6. Continúa con las **Partes 5 a 12**.

> Las Partes **9, 10 y 11** (Streamlit, Semantic View y Agente) se construyen en la UI de
> Snowsight; el SQL incluye las instrucciones paso a paso.

---

## Snowpipe: auto-ingesta (event-driven)

El HOL usa **auto-ingesta real**: cada archivo nuevo en `set_icap_hol/stream/` dispara una
notificación de evento de S3 hacia una cola SQS de Snowflake y el pipe carga los datos en
segundos, sin tareas.

```
S3 (ObjectCreated) --> SQS (Snowflake) --> PIPE_FX_STREAM --> OPERATION_FX_STREAM
```

Pasos (Parte 4 del SQL):
1. `CREATE PIPE PIPE_FX_STREAM AUTO_INGEST = TRUE AS COPY INTO ...`
2. `SHOW PIPES` → copiar la columna `notification_channel` (ARN de SQS).
3. Conectar S3 → SQS una sola vez (terminal del instructor):
   ```bash
   aws s3api put-bucket-notification-configuration --bucket demosjparrado \
     --notification-configuration '{"QueueConfigurations":[{"Id":"seticap-snowpipe-autoingest",
       "QueueArn":"<NOTIFICATION_CHANNEL>","Events":["s3:ObjectCreated:*"],
       "Filter":{"Key":{"FilterRules":[{"Name":"prefix","Value":"set_icap_hol/stream/"},
       {"Name":"suffix","Value":".csv.gz"}]}}}]}'
   ```
4. `ALTER PIPE PIPE_FX_STREAM REFRESH;` para traer el backlog inicial.

> El comando `put-bucket-notification-configuration` **reemplaza** la config de notificaciones
> del bucket. Si el bucket ya tiene otras, léelas con `get-bucket-notification-configuration`
> y fusiónalas en un solo JSON.

**Fallback** (sin acceso a eventos S3): `AUTO_INGEST=FALSE` + un `TASK` que ejecute
`ALTER PIPE PIPE_FX_STREAM REFRESH` cada 5 minutos.

---

## Regenerar los datos (opcional)

```bash
export AWS_PROFILE=contributor-484577546576
# Histórico completo (1 año):
~/miniforge3/bin/python scripts/gen_set_icap_datos.py --upload
# Solo local (debug, sin subir):
~/miniforge3/bin/python scripts/gen_set_icap_datos.py
```

---

## Limpieza

La **Parte 12** del SQL suspende el task y elimina la base de datos, el warehouse y el rol.
Recuerda **detener el generador de streaming** (Ctrl-C) y, para HOL públicos, **rotar** la
llave IAM de lectura del stage.

---

## Archivos

| Archivo | Descripción |
|---------|-------------|
| `HOL_SET_ICAP.sql` | Script principal del HOL (12 partes) |
| `HOL_SET_ICAP_semantic_model.yaml` | Semantic View `SV_SET_FX` para Cortex Analyst |
| `HOL_SET_ICAP_README.md` | Esta guía |
| `scripts/gen_set_icap_datos.py` | Generador de datos históricos → S3 |
| `scripts/gen_set_icap_stream.py` | Generador de streaming (cada 5 min) → S3 |
| `set_icap_hol.html` | Versión HTML interactiva (lab único) |
| `workshop/` | Versión workshop: 3 labs + índice |
