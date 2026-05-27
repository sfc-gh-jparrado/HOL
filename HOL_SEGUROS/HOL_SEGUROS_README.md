# HOL SeguroPlus Aseguradora Multi-ramo — "From S3 to Intelligence"

Hands-on Lab end-to-end para una compañía aseguradora multi-ramo (vida, auto,
hogar, salud, SOAT): carga masiva desde S3 + gobierno con masking dinámico +
Cortex AI + Cortex Search + Cortex Analyst + Snowflake Intelligence.

---

## Prerrequisitos

- Cuenta Snowflake con rol `ACCOUNTADMIN`.
- Región AWS — los datos viven en `us-east-1` (Snowflake hará egress
  cross-region si tu cuenta está en otra región, sigue funcionando).
- Permisos para crear `DATABASE`, `WAREHOUSE`, `ROLE`, `MASKING POLICY`,
  `CORTEX SEARCH SERVICE`, `SEMANTIC VIEW`, `DYNAMIC TABLE`.

## Datos del HOL

Bucket público controlado por credenciales read-only:
```
s3://demosjparrado/seguros_hol/
  asegurado/        ~16 archivos  ·  30M filas
  poliza/           ~80 archivos  ·  80M filas
  siniestro/       ~160 archivos  · 120M filas
  cobertura_usada/  ~80 archivos  · 150M filas
  total: ~416 archivos · ~8.5 GiB · 380M registros
```

Modelo lógico:
```
ASEGURADO  ──1:N──>  POLIZA  ──1:N──>  SINIESTRO  ──1:N──>  COBERTURA_USADA
(persona)            (contrato)        (evento + narrativa)  (cobertura activada)
```

## Archivos del HOL

| Archivo | Uso |
|---|---|
| `HOL_SEGUROS.sql` | Script principal — copiar en un Worksheet y recorrer parte por parte |
| `HOL_SEGUROS_semantic_model.yaml` | Modelo semántico para Cortex Analyst (alternativa al `CREATE SEMANTIC VIEW`) |
| `HOL_SEGUROS_README.md` | Esta guía |
| `archivos/` | PDFs (póliza, peritaje, factura taller, historia clínica), imagen de auto siniestrado y audios sintéticos para Cortex AI multimodal (PARTE 7B) |

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
| 7B | Cortex AI multimodal (PDFs / imágenes / audio) | 12 min |
| 8 | Cortex Search service | 10-15 min (incluye indexación) |
| 9 | Semantic view + Cortex Analyst | 8 min |
| 10 | Dynamic Tables | 5 min |
| 11 | Snowflake Intelligence (UI) | 15 min |
| 12 | Recursos / ejercicio CoCo | 2 min |
| **Total** | | **~95-105 min** |

## Recorrido sugerido del facilitador

### Parte 6 — masking (corazón del HOL)
- Mostrar primero la query como `ACCOUNTADMIN` para ver `Juliana Carolina
  Arboleda Romero`, fecha de nacimiento exacta, email completo, número de
  documento completo y narrativa de siniestro entera.
- Cambiar a `ANALISTA_TECNICO` y ejecutar la **misma** query. Resultado:
  - `NomAsegurado = ****`, `ApeAsegurado = ****`
  - `FecNacimiento = 1977-01-01` (solo año)
  - `Email = ****@correo.com`
  - `NumDocumento = 10******92`
  - `DesNarrativa` truncado con la leyenda de privacidad.
- Esto convierte al agente Intelligence en **gobierno automático**: el agente
  hereda el rol del usuario que lo invoca.

### Parte 11 — agente Intelligence
1. AI & ML → Snowflake Intelligence → + Crear agente → `AGT_SEGUROS`.
2. Tools:
   - Cortex Search → `CSS_SINIESTROS`
   - Cortex Analyst → `SV_SEGUROS`
3. Orchestrator:
   ```
   Eres asistente técnico de SeguroPlus. Cuando preguntan métricas, usa Cortex Analyst.
   Cuando preguntan por casos puntuales o búsquedas en narrativas, usa Cortex Search.
   Cita siempre los IdSiniestro, IdPoliza o las dimensiones usadas. Responde en español.
   ```
4. Pruebas:
   - "¿Cuántos siniestros del ramo Auto tuvimos en 2026?" → Analyst
   - "Top 5 tipos de siniestro con mayor monto promedio" → Analyst
   - "Muéstrame siniestros con sospecha de fraude o robo de vehículo" → Search
   - "Resume las causas más frecuentes de siniestros del último mes" → Search + AI_AGG
5. Repetir con `USE ROLE ANALISTA_TECNICO` para ver el masking en acción.

## Troubleshooting

| Síntoma | Causa probable | Solución |
|---|---|---|
| `COPY INTO` 0 filas cargadas | Credenciales caducas o IAM key rotada | Pedir al instructor el SQL actualizado |
| `Cortex Search service still indexing` | Indexación inicial en curso | Esperar 5-10 min, validar con `SHOW CORTEX SEARCH SERVICES` |
| Cortex Analyst "no relevant data" | Semantic view sin verified queries útiles | Re-cargar `HOL_SEGUROS_semantic_model.yaml` desde stage |
| Masking no se aplica al agente | El agente se ejecuta con un rol distinto | Verificar `CURRENT_ROLE()` en la sesión que invoca al agente |
| Dynamic Table en estado `PENDING` muchos minutos | WH suspendido | Resume manualmente con `ALTER WAREHOUSE WH_HOL_SEGUROS RESUME` |
| `Insufficient privileges` al crear masking policy | Falta `CREATE MASKING POLICY ON SCHEMA` | `USE ROLE ACCOUNTADMIN` antes de la PARTE 6 |

## Limpieza al finalizar

```sql
USE ROLE ACCOUNTADMIN;
DROP DATABASE  IF EXISTS DB_HOL_SEGUROS;
DROP DATABASE  IF EXISTS DB_HOL_SEGUROS_DEV;
DROP WAREHOUSE IF EXISTS WH_HOL_SEGUROS;
DROP ROLE      IF EXISTS ANALISTA_TECNICO;
```

Y al final del HOL, el instructor debe rotar las credenciales AWS:
```bash
aws iam delete-access-key --user-name snowflake-seguros-hol-rw \
  --access-key-id <ACCESS_KEY_ID> \
  --profile contributor-484577546576
```

---

## Anexo — Enhancements clasificados por nivel

### Básico (≤ 30 min de extensión)
- **Snowflake Notebooks**: análisis exploratorio Python+SQL para actuarios y analistas técnicos.
- **Streamlit in Snowflake**: dashboard ejecutivo (siniestralidad por ramo, prima vs siniestros por canal, top causas).
- **Sensitive Data Classification** (`SYSTEM$CLASSIFY`): auto-detectar PII en ASEGURADO — gobierno automático.

### Intermedio (≥ 1 h)
- **Tag-based masking**: política aplicada a tags PII en lugar de columna a columna.
- **Snowpipe Streaming**: feed en vivo de reporte de siniestros (call center / app móvil del asegurado).
- **Snowpark Python**: feature engineering distribuido (RFM de asegurados, scoring de fraude).
- **Cost Intelligence / Account Usage**: créditos por warehouse, queries más caras.
- **Network Policies / PrivateLink**: restringir por IP o enlace privado AWS — clave para regulación financiera.
- **Data Sharing**: KPIs agregados (sin PII) compartidos con reaseguradoras o SuperFinanciera.

### Avanzado (≥ ½ día)
- **AI_PARSE_DOCUMENT / Document AI**: extraer datos de pólizas físicas escaneadas y peritajes.
- **AI_TRANSCRIBE**: llamadas de call center → texto, alimentando el dataset de NPS y detección de fraude.
- **Iceberg Tables + Catalog Integration**: interoperabilidad con AWS Glue / Lake Formation para reservas técnicas.
- **Snowpark ML / SNOWFLAKE.ML.FORECAST**: predecir siniestralidad por ramo y reservas técnicas mensuales.
- **Cortex Fine-Tuning**: ajustar un modelo al lenguaje técnico de seguros y peritajes de SeguroPlus.

## ¿Qué le llamará la atención al cliente Aseguradora?

1. **Masking dinámico + agente Intelligence** — un mismo prompt, distinto detalle por rol; demuestra gobierno cero-fricción sobre PII de asegurados (regulación financiera).
2. **Cortex Search sobre 50K narrativas de siniestro** — búsqueda semántica de casos similares (sospecha de fraude, patrones recurrentes) sin etiquetado previo.
3. **Cortex Analyst en español** — actuarios y suscriptores no SQL pueden hacer text-to-SQL hablando español sobre las 4 tablas (ratios, siniestralidad, prima emitida).
4. **AI_EXTRACT estructurando narrativas libres** — convertir texto de ajustadores en datos analíticos (parte responsable, daños, lesionados, testigos, condiciones climáticas).
5. **Análisis multimodal de fotos de siniestro** — pixtral analiza foto de vehículo y propone severidad, parte afectada, estimación y coberturas a activar.
6. **Dynamic Tables incrementales** — KPIs siempre frescos (ratio de siniestralidad, prima emitida) sin orquestación externa.
7. **Carga 380M filas en minutos** — argumento de capacidad para una operación nacional con miles de pólizas y siniestros por día.
