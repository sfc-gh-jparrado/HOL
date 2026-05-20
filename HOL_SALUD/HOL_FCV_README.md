# HOL Fundación Cardiovascular de Colombia (FCV) — "From S3 to Intelligence"

Hands-on Lab end-to-end: carga masiva desde S3 + gobierno con masking dinámico + Cortex AI + Cortex Search + Cortex Analyst + Snowflake Intelligence.

---

## Prerrequisitos

- Cuenta Snowflake con rol `ACCOUNTADMIN`.
- Región AWS — los datos viven en `us-east-1` (Snowflake hará egress cross-region si tu cuenta está en otra región, sigue funcionando).
- Permisos para crear `DATABASE`, `WAREHOUSE`, `ROLE`, `MASKING POLICY`, `CORTEX SEARCH SERVICE`, `SEMANTIC VIEW`, `DYNAMIC TABLE`.

## Datos del HOL

Bucket público controlado por credenciales read-only:
```
s3://demosjparrado/fcv_hol/
  admcliente/      16 archivos  · 30M filas
  admatencion/     64 archivos  · 80M filas
  hceconsulta/     64 archivos  · 120M filas
  gendiagnostico/  64 archivos  · 150M filas
  total: 208 archivos · ~7.5 GiB · 380M registros
```

Modelo lógico:
```
ADMCLIENTE  ──1:N──>  ADMATENCION  ──1:N──>  HCECONSULTA  ──1:N──>  GENDIAGNOSTICO
(paciente)            (atención)             (consulta HCE)         (diagnósticos)
```

## Archivos del HOL

| Archivo | Uso |
|---|---|
| `HOL_FCV.sql` | Script principal — copiar en un Worksheet y recorrer parte por parte |
| `HOL_FCV_semantic_model.yaml` | Modelo semántico para Cortex Analyst (alternativa al `CREATE SEMANTIC VIEW`) |
| `HOL_FCV_README.md` | Esta guía |

## Tiempo estimado

| Parte | Contenido | Duración |
|---|---|---|
| 1 | Setup BD/WH | 2 min |
| 2 | Stage S3 + file format | 3 min |
| 3 | DDL + COPY INTO 380M | 6-12 min (con WH SMALL); 3-5 min (XLARGE) |
| 4 | Performance & scaling | 8 min |
| 5 | Time travel + cloning | 5 min |
| 6 | **Masking dinámico** | 8 min |
| 7 | Cortex AI functions | 12 min |
| 8 | Cortex Search service | 10-15 min (incluye indexación) |
| 9 | Semantic view + Cortex Analyst | 8 min |
| 10 | Dynamic Tables | 5 min |
| 11 | Snowflake Intelligence (UI) | 15 min |
| 12 | Recursos | 2 min |
| **Total** | | **~90-100 min** |

## Recorrido sugerido del facilitador

### Parte 6 — masking (corazón del HOL)
- Mostrar primero la query como `ACCOUNTADMIN` para ver `Juliana Carolina Arboleda Romero`, `1977-03-22`, nota completa.
- Cambiar a `ANALISTA_CLINICO` y ejecutar la **misma** query. Resultado:
  - `NomCliente = ****`
  - `ApeCliente = ****`
  - `FecNacimiento = 1977-01-01` (solo año)
  - `DesSubjetivo` truncado con la leyenda de privacidad.
- Esto es lo que convierte al agente Intelligence en **gobierno automático**: el agente hereda el rol del usuario.

### Parte 11 — agente Intelligence
1. AI & ML → Snowflake Intelligence → + Crear agente → `AGT_FCV`.
2. Tools:
   - Cortex Search → `CSS_HCE`
   - Cortex Analyst → `SV_FCV`
3. Orchestrator:
   ```
   Eres asistente clínico de la FCV. Cuando preguntan métricas usa Cortex Analyst.
   Cuando preguntan por casos clínicos o búsquedas en notas, usa Cortex Search.
   Cita siempre los IdConsulta o las dimensiones usadas. Responde en español.
   ```
4. Pruebas:
   - "Cuántas atenciones de Hospitalización Por Urgencias tuvimos en 2026?" → Analyst
   - "Top 5 diagnósticos principales del año" → Analyst
   - "Muéstrame consultas con sospecha de tromboembolismo pulmonar" → Search
   - "Resume las patologías más complejas del último mes" → Search + AI_AGG
5. Repetir con `USE ROLE ANALISTA_CLINICO` para ver el masking en acción.

## Troubleshooting

| Síntoma | Causa probable | Solución |
|---|---|---|
| `COPY INTO` 0 filas cargadas | Credenciales caducas o IAM key rotada | Pedir al instructor el SQL actualizado |
| `Cortex Search service still indexing` | Indexación inicial en curso | Esperar 5-10 min, validar con `SHOW CORTEX SEARCH SERVICES` |
| Cortex Analyst "no relevant data" | Semantic view sin verified queries útiles | Re-cargar `HOL_FCV_semantic_model.yaml` desde stage |
| Masking no se aplica al agente | El agente se ejecuta con un rol distinto | Verificar `CURRENT_ROLE()` en la sesión que invoca al agente |
| Dynamic Table en estado `PENDING` muchos minutos | WH suspendido | Resume manualmente con `ALTER WAREHOUSE WH_HOL_FCV RESUME` |
| `Insufficient privileges` al crear masking policy | Falta `CREATE MASKING POLICY ON SCHEMA` | `USE ROLE ACCOUNTADMIN` antes de la PARTE 6 |

## Limpieza al finalizar

```sql
USE ROLE ACCOUNTADMIN;
DROP DATABASE IF EXISTS DB_HOL_FCV;
DROP DATABASE IF EXISTS DB_HOL_FCV_DEV;
DROP WAREHOUSE IF EXISTS WH_HOL_FCV;
DROP ROLE IF EXISTS ANALISTA_CLINICO;
```

Y al final del HOL, el instructor debe rotar las credenciales AWS:
```bash
aws iam delete-access-key --user-name snowflake-fcv-hol-reader \
  --access-key-id <ACCESS_KEY_ID> \
  --profile contributor-484577546576
```

---

## Anexo — Enhancements clasificados por nivel

### Básico (≤ 30 min de extensión)
- **Snowflake Notebooks**: análisis exploratorio Python+SQL, ideal para data scientists clínicos.
- **Streamlit in Snowflake**: dashboard ejecutivo (ocupación, top dx, atenciones por mes).
- **Sensitive Data Classification** (`SYSTEM$CLASSIFY`): auto-detectar PII en las tablas — gobierno automático.

### Intermedio (≥ 1 h)
- **Tag-based masking**: política aplicada a tags PII en lugar de columna a columna.
- **Snowpipe Streaming**: feed en vivo de signos vitales o admisiones de urgencias.
- **Snowpark Python**: feature engineering distribuido (cohortes, comorbilidades).
- **Cost Intelligence / Account Usage**: créditos por warehouse, queries más caras.
- **Network Policies / PrivateLink**: restringir por IP o enlace privado AWS — clave para health.
- **Data Sharing**: KPIs agregados (sin PHI) compartidos con aseguradoras o entes regulatorios.

### Avanzado (≥ ½ día)
- **AI_PARSE_DOCUMENT / Document AI**: extraer datos de HCE escaneadas (PDF/imagen).
- **AI_TRANSCRIBE**: notas de voz médico → texto, alimentando HCECONSULTA.
- **Iceberg Tables + Catalog Integration**: interoperabilidad con AWS Glue / Lake Formation.
- **Snowpark ML / SNOWFLAKE.ML.FORECAST**: predecir ocupación hospitalaria semanal.
- **Cortex Fine-Tuning**: ajustar un modelo al lenguaje clínico de la FCV.

## ¿Qué les llamará la atención al cliente FCV?

1. **Masking dinámico + agente Intelligence** — un mismo prompt, distinto detalle por rol; demuestra gobierno cero-fricción.
2. **Cortex Search sobre 500K notas SOAP** — búsqueda semántica clínica que no requiere etiquetas previas.
3. **Cortex Analyst en español** — médicos no SQL pueden hacer text-to-SQL hablando español sobre las 4 tablas.
4. **AI_EXTRACT estructurando notas libres** — convertir HCE en datos analíticos.
5. **Dynamic Tables incrementales** — KPIs siempre frescos sin orquestación externa.
6. **Carga 380M filas en minutos** — argumento de capacidad.
