# HOL SuperPlus Retail FMCG — "From S3 to Intelligence"

Hands-on Lab end-to-end para una cadena de supermercados / retail FMCG: carga
masiva desde S3 + gobierno con masking dinamico + Cortex AI + Cortex Search +
Cortex Analyst + Snowflake Intelligence.

---

## Prerrequisitos

- Cuenta Snowflake con rol `ACCOUNTADMIN`.
- Region AWS — los datos viven en `us-east-1` (Snowflake hara egress
  cross-region si tu cuenta esta en otra region, sigue funcionando).
- Permisos para crear `DATABASE`, `WAREHOUSE`, `ROLE`, `MASKING POLICY`,
  `CORTEX SEARCH SERVICE`, `SEMANTIC VIEW`, `DYNAMIC TABLE`.

## Datos del HOL

Bucket publico controlado por credenciales read-only:
```
s3://demosjparrado/retail_hol/
  cliente/         16 archivos  ·  30M filas
  ticket/          ~80 archivos ·  80M filas
  linea_ticket/    ~80 archivos · 120M filas
  promo_aplicada/  ~80 archivos · 150M filas
  total: ~348 archivos · ~7 GiB · 380M registros
```

Modelo logico:
```
CLIENTE  ──1:N──>  TICKET  ──1:N──>  LINEA_TICKET  ──1:N──>  PROMO_APLICADA
(comprador)        (compra)          (item + resena)         (descuento aplicado)
```

## Archivos del HOL

| Archivo | Uso |
|---|---|
| `HOL_RETAIL.sql` | Script principal — copiar en un Worksheet y recorrer parte por parte |
| `HOL_RETAIL_semantic_model.yaml` | Modelo semantico para Cortex Analyst (alternativa al `CREATE SEMANTIC VIEW`) |
| `HOL_RETAIL_README.md` | Esta guia |
| `archivos/` | PDFs, imagenes y audio sinteticos para Cortex AI multimodal (PARTE 7B) |

## Tiempo estimado

| Parte | Contenido | Duracion |
|---|---|---|
| 1 | Setup BD/WH | 2 min |
| 2 | Stage S3 + file format | 3 min |
| 3 | DDL + COPY INTO 380M | 6-12 min (con WH SMALL); 3-5 min (XLARGE) |
| 4 | Performance & scaling | 8 min |
| 5 | Time travel + cloning | 5 min |
| 6 | **Masking dinamico** | 8 min |
| 7 | Cortex AI functions | 12 min |
| 7B | Cortex AI multimodal (PDFs / imagenes / audio) | 10 min |
| 8 | Cortex Search service | 10-15 min (incluye indexacion) |
| 9 | Semantic view + Cortex Analyst | 8 min |
| 10 | Dynamic Tables | 5 min |
| 11 | Snowflake Intelligence (UI) | 15 min |
| 12 | Recursos / ejercicio CoCo | 2 min |
| **Total** | | **~95-105 min** |

## Recorrido sugerido del facilitador

### Parte 6 — masking (corazon del HOL)
- Mostrar primero la query como `ACCOUNTADMIN` para ver `Juliana Carolina
  Arboleda Romero`, `1977-03-22`, `cliente7@correo.com`, resena completa.
- Cambiar a `ANALISTA_COMERCIAL` y ejecutar la **misma** query. Resultado:
  - `NomCliente = ****`
  - `ApeCliente = ****`
  - `FecNacimiento = 1977-01-01` (solo ano)
  - `Email = ****@correo.com`
  - `DesResena` truncado con la leyenda de privacidad.
- Esto es lo que convierte al agente Intelligence en **gobierno automatico**:
  el agente hereda el rol del usuario.

### Parte 11 — agente Intelligence
1. AI & ML → Snowflake Intelligence → + Crear agente → `AGT_RETAIL`.
2. Tools:
   - Cortex Search → `CSS_RESENAS`
   - Cortex Analyst → `SV_RETAIL`
3. Orchestrator:
   ```
   Eres asistente comercial de SuperPlus. Cuando preguntan metricas usa Cortex Analyst.
   Cuando preguntan por experiencia del cliente o busquedas en resenas, usa Cortex Search.
   Cita siempre los IdLinea, NomProducto o las dimensiones usadas. Responde en espanol.
   ```
4. Pruebas:
   - "Cuantos tickets de App Movil tuvimos en 2026?" → Analyst
   - "Top 5 promociones aplicadas del ano" → Analyst
   - "Muestrame resenas con queja de cadena de frio o producto vencido" → Search
   - "Resume las quejas mas frecuentes del ultimo mes" → Search + AI_AGG
5. Repetir con `USE ROLE ANALISTA_COMERCIAL` para ver el masking en accion.

## Troubleshooting

| Sintoma | Causa probable | Solucion |
|---|---|---|
| `COPY INTO` 0 filas cargadas | Credenciales caducas o IAM key rotada | Pedir al instructor el SQL actualizado |
| `Cortex Search service still indexing` | Indexacion inicial en curso | Esperar 5-10 min, validar con `SHOW CORTEX SEARCH SERVICES` |
| Cortex Analyst "no relevant data" | Semantic view sin verified queries utiles | Re-cargar `HOL_RETAIL_semantic_model.yaml` desde stage |
| Masking no se aplica al agente | El agente se ejecuta con un rol distinto | Verificar `CURRENT_ROLE()` en la sesion que invoca al agente |
| Dynamic Table en estado `PENDING` muchos minutos | WH suspendido | Resume manualmente con `ALTER WAREHOUSE WH_HOL_RETAIL RESUME` |
| `Insufficient privileges` al crear masking policy | Falta `CREATE MASKING POLICY ON SCHEMA` | `USE ROLE ACCOUNTADMIN` antes de la PARTE 6 |

## Limpieza al finalizar

```sql
USE ROLE ACCOUNTADMIN;
DROP DATABASE IF EXISTS DB_HOL_RETAIL;
DROP DATABASE IF EXISTS DB_HOL_RETAIL_DEV;
DROP WAREHOUSE IF EXISTS WH_HOL_RETAIL;
DROP ROLE IF EXISTS ANALISTA_COMERCIAL;
```

Y al final del HOL, el instructor debe rotar las credenciales AWS:
```bash
aws iam delete-access-key --user-name snowflake-retail-hol-rw \
  --access-key-id <ACCESS_KEY_ID> \
  --profile contributor-484577546576
```

---

## Anexo — Enhancements clasificados por nivel

### Basico (≤ 30 min de extension)
- **Snowflake Notebooks**: analisis exploratorio Python+SQL para data scientists comerciales.
- **Streamlit in Snowflake**: dashboard ejecutivo (ventas por tienda, top productos, ticket promedio por canal).
- **Sensitive Data Classification** (`SYSTEM$CLASSIFY`): auto-detectar PII en CLIENTE — gobierno automatico.

### Intermedio (≥ 1 h)
- **Tag-based masking**: politica aplicada a tags PII en lugar de columna a columna.
- **Snowpipe Streaming**: feed en vivo de tickets POS o eventos de ecommerce.
- **Snowpark Python**: feature engineering distribuido (RFM, clusters de clientes).
- **Cost Intelligence / Account Usage**: creditos por warehouse, queries mas caras.
- **Network Policies / PrivateLink**: restringir por IP o enlace privado AWS.
- **Data Sharing**: KPIs agregados (sin PII) compartidos con marcas / proveedores FMCG.

### Avanzado (≥ ½ dia)
- **AI_PARSE_DOCUMENT / Document AI**: extraer datos de facturas y notas credito escaneadas (PDF/imagen).
- **AI_TRANSCRIBE**: llamadas de servicio al cliente → texto, alimentando un dataset de NPS.
- **Iceberg Tables + Catalog Integration**: interoperabilidad con AWS Glue / Lake Formation.
- **Snowpark ML / SNOWFLAKE.ML.FORECAST**: predecir demanda semanal por categoria.
- **Cortex Fine-Tuning**: ajustar un modelo al lenguaje comercial de SuperPlus.

## Que les llamara la atencion al cliente Retail

1. **Masking dinamico + agente Intelligence** — un mismo prompt, distinto detalle por rol; demuestra gobierno cero-friccion sobre PII de clientes.
2. **Cortex Search sobre 50K resenas** — busqueda semantica de Voice-of-Customer que no requiere etiquetas previas.
3. **Cortex Analyst en espanol** — gerentes comerciales no SQL pueden hacer text-to-SQL hablando espanol sobre las 4 tablas.
4. **AI_EXTRACT estructurando resenas libres** — convertir texto de Voice-of-Customer en datos analiticos (satisfaccion, quejas, intencion de recompra).
5. **Dynamic Tables incrementales** — KPIs siempre frescos sin orquestacion externa.
6. **Carga 380M filas en minutos** — argumento de capacidad para retail con miles de tickets/dia.
