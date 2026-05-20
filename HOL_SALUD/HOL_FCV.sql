/* ********************************************************************************************
                            HANDS ON LAB — Fundación Cardiovascular de Colombia (FCV)
                            "From S3 to Intelligence" — basado en Zero2Snowflake
   ********************************************************************************************
   Este archivo SQL es la guía del HOL. Copia todo el contenido en un Worksheet de Snowflake.
   Recorre las 12 partes en orden. Comentarios y notas en español.
   Datos sintéticos en s3://demosjparrado/fcv_hol/ (380M registros, 4 tablas, gzip).
   ******************************************************************************************** */


/* ************************************ PARTE 1 ************************************************
   Definimos el ambiente: base de datos, warehouse y esquema.
   ******************************************************************************************** */
USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE DATABASE DB_HOL_FCV
  COMMENT = 'Base de datos del HOL Fundación Cardiovascular de Colombia';

CREATE OR REPLACE WAREHOUSE WH_HOL_FCV
WITH
  WAREHOUSE_SIZE = 'SMALL'
  WAREHOUSE_TYPE = 'STANDARD'
  AUTO_SUSPEND   = 60
  AUTO_RESUME    = TRUE
  MIN_CLUSTER_COUNT = 1
  MAX_CLUSTER_COUNT = 2
  SCALING_POLICY = 'STANDARD';

USE WAREHOUSE WH_HOL_FCV;
USE DATABASE  DB_HOL_FCV;
USE SCHEMA    PUBLIC;


/* ************************************ PARTE 2 ************************************************
   Stage externo a AWS S3 + File Format.
   El bucket s3://demosjparrado/fcv_hol/ contiene 208 archivos .csv.gz, ~7.5 GiB.
   Las credenciales pertenecen a un IAM user read-only sobre el prefijo fcv_hol/*.
   ******************************************************************************************** */

-- File format CSV gzip (datos generados con MAX_FILE_SIZE 1.5 GB, ~25-60 MB por archivo)
CREATE OR REPLACE FILE FORMAT FF_CSV_GZ
  TYPE = CSV
  FIELD_DELIMITER = ';'
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  COMPRESSION = GZIP
  NULL_IF = ('NULL','')
  EMPTY_FIELD_AS_NULL = TRUE
  TIMESTAMP_FORMAT = 'YYYY-MM-DD HH24:MI:SS.FF3'
  SKIP_HEADER = 1
  COMMENT = 'CSV ; gzip para datasets HOL FCV';

-- Stage externo (credenciales embebidas, read-only)
CREATE OR REPLACE STAGE STG_FCV
  URL = 's3://demosjparrado/fcv_hol/'
  CREDENTIALS = (AWS_KEY_ID='<SOLICITAR_AL_INSTRUCTOR>' AWS_SECRET_KEY='<SOLICITAR_AL_INSTRUCTOR>')
  FILE_FORMAT = FF_CSV_GZ
  COMMENT = 'Stage externo HOL FCV - lectura del dataset sintético';

-- Listar lo que hay en el stage
LIST @STG_FCV/admcliente/;
LIST @STG_FCV/admatencion/;
LIST @STG_FCV/hceconsulta/;
LIST @STG_FCV/gendiagnostico/;

-- Validar formato leyendo unas filas crudas sin cargarlas
SELECT $1, $2, $3, $4, $5
FROM @STG_FCV/admcliente/ (FILE_FORMAT => FF_CSV_GZ)
LIMIT 5;


/* ************************************ PARTE 3 ************************************************
   DDL de las 4 tablas con comentarios del Diccionario FCV + COPY INTO.
   Jerarquía: ADMCLIENTE 1:N ADMATENCION 1:N HCECONSULTA 1:N GENDIAGNOSTICO
   ******************************************************************************************** */

CREATE OR REPLACE TABLE ADMCLIENTE (
  IdCliente     NUMBER         COMMENT 'Identificador único del paciente en el ecosistema',
  NomCliente    VARCHAR        COMMENT 'Nombre(s) del paciente',
  ApeCliente    VARCHAR        COMMENT 'Apellido(s) del paciente',
  FecNacimiento TIMESTAMP_NTZ  COMMENT 'Fecha de nacimiento del paciente',
  Genero        VARCHAR        COMMENT 'Género: Femenino, Masculino o Indeterminado'
) COMMENT='Pacientes (clientes) atendidos por la FCV';

CREATE OR REPLACE TABLE ADMATENCION (
  IdAtencion       NUMBER         COMMENT 'Identificador único de la atención de salud',
  IdCliente        NUMBER         COMMENT 'FK al paciente (ADMCLIENTE.IdCliente)',
  FecIngreso       TIMESTAMP_NTZ  COMMENT 'Fecha en la que el paciente ingresa al ecosistema',
  FecEgreso        TIMESTAMP_NTZ  COMMENT 'Fecha de egreso (NULL si la atención sigue activa)',
  NomAtencionTipo  VARCHAR        COMMENT 'Tipo de atención: Hospitalización, Consulta Externa, Urgencias, etc.'
) COMMENT='Atenciones de salud prestadas a los pacientes';

CREATE OR REPLACE TABLE HCECONSULTA (
  IdConsulta     NUMBER                  COMMENT 'Identificador único de la consulta',
  IdAtencion     NUMBER                  COMMENT 'FK a la atención (ADMATENCION.IdAtencion)',
  DesMotivoCon   VARCHAR                 COMMENT 'Motivo por el cual el paciente está en la consulta',
  DesSubjetivo   VARCHAR(16777216)       COMMENT 'Información clínica subjetiva (texto libre, formato SOAP)',
  FechaConsulta  TIMESTAMP_NTZ           COMMENT 'Fecha y hora de la consulta',
  Esquema        VARCHAR                 COMMENT 'Categoría del registro en historia clínica'
) COMMENT='Consultas de la historia clínica electrónica (HCE)';

CREATE OR REPLACE TABLE GENDIAGNOSTICO (
  IdConsulta      NUMBER         COMMENT 'FK a la consulta (HCECONSULTA.IdConsulta)',
  IdDiagnostico   NUMBER         COMMENT 'Identificador del diagnóstico',
  NomDiagnostico  VARCHAR        COMMENT 'Nombre del diagnóstico (descriptivo)',
  CodCie9         VARCHAR        COMMENT 'Código CIE asociado al diagnóstico',
  IndPrincipal    NUMBER(1,0)    COMMENT '1 = diagnóstico principal de la consulta, 0 = secundario',
  SecPrioridad    NUMBER         COMMENT 'Orden de prioridad del diagnóstico'
) COMMENT='Diagnósticos asociados a las consultas';

-- COPY INTO desde S3 (carga masiva 380M registros)
COPY INTO ADMCLIENTE     FROM @STG_FCV/admcliente/     ON_ERROR='CONTINUE';
COPY INTO ADMATENCION    FROM @STG_FCV/admatencion/    ON_ERROR='CONTINUE';
COPY INTO HCECONSULTA    FROM @STG_FCV/hceconsulta/    ON_ERROR='CONTINUE';
COPY INTO GENDIAGNOSTICO FROM @STG_FCV/gendiagnostico/ ON_ERROR='CONTINUE';

-- Conteos
SELECT 'ADMCLIENTE' tabla, COUNT(*) registros FROM ADMCLIENTE UNION ALL
SELECT 'ADMATENCION',     COUNT(*)            FROM ADMATENCION UNION ALL
SELECT 'HCECONSULTA',     COUNT(*)            FROM HCECONSULTA UNION ALL
SELECT 'GENDIAGNOSTICO',  COUNT(*)            FROM GENDIAGNOSTICO;


/* ************************************ PARTE 4 ************************************************
   Performance & Warehouse Scaling — comparemos tiempos.
   ******************************************************************************************** */

-- Query analítica con WH SMALL (anota el tiempo)
SELECT
  DATE_TRUNC('month', FecIngreso) AS mes,
  NomAtencionTipo,
  COUNT(*) AS atenciones
FROM ADMATENCION
WHERE FecIngreso >= '2025-01-01'
GROUP BY 1, 2
ORDER BY 1, atenciones DESC;

-- Escalemos a XLARGE
ALTER WAREHOUSE WH_HOL_FCV SET WAREHOUSE_SIZE = 'XLARGE';

-- Re-ejecutemos la query (compara el tiempo)
SELECT
  DATE_TRUNC('month', FecIngreso) AS mes,
  NomAtencionTipo,
  COUNT(*) AS atenciones
FROM ADMATENCION
WHERE FecIngreso >= '2025-01-01'
GROUP BY 1, 2
ORDER BY 1, atenciones DESC;

-- Top 10 diagnósticos
SELECT NomDiagnostico, CodCie9, COUNT(*) total
FROM GENDIAGNOSTICO
GROUP BY 1, 2
ORDER BY total DESC
LIMIT 10;

-- Distribución por género y bucket etario
SELECT
  Genero,
  CASE
    WHEN DATEDIFF(year, FecNacimiento, CURRENT_DATE()) < 13  THEN '00-12 pediátricos'
    WHEN DATEDIFF(year, FecNacimiento, CURRENT_DATE()) < 19  THEN '13-18 adolescentes'
    WHEN DATEDIFF(year, FecNacimiento, CURRENT_DATE()) < 66  THEN '19-65 adultos'
    ELSE '66+ adultos mayores'
  END bucket,
  COUNT(*) pacientes
FROM ADMCLIENTE
GROUP BY 1, 2
ORDER BY 1, 2;

-- Volvamos a SMALL
ALTER WAREHOUSE WH_HOL_FCV SET WAREHOUSE_SIZE = 'SMALL';


/* ************************************ PARTE 5 ************************************************
   Time Travel y Zero-Copy Cloning — recuperación instantánea sin duplicar almacenamiento.
   ******************************************************************************************** */

-- Clonemos una tabla
CREATE OR REPLACE TABLE ADMCLIENTE_DEV CLONE ADMCLIENTE;

-- Clonemos toda la base de datos (dev environment instantáneo)
CREATE OR REPLACE DATABASE DB_HOL_FCV_DEV CLONE DB_HOL_FCV;

-- Error intencional: borremos producción
DROP DATABASE DB_HOL_FCV;

-- Restauración con UNDROP (no necesitamos llamar al DBA)
UNDROP DATABASE DB_HOL_FCV;

-- Verifica que sigue todo
USE DATABASE DB_HOL_FCV;
USE SCHEMA PUBLIC;
SELECT COUNT(*) FROM ADMCLIENTE;


/* ************************************ PARTE 6 ************************************************
   Masking dinámico condicional por rol — clave para Snowflake Intelligence.
   ACCOUNTADMIN ve todo. ANALISTA_CLINICO ve datos enmascarados.
   ******************************************************************************************** */
USE ROLE ACCOUNTADMIN;
USE DATABASE DB_HOL_FCV;
USE SCHEMA PUBLIC;

-- Rol restringido
CREATE OR REPLACE ROLE ANALISTA_CLINICO;
GRANT USAGE  ON DATABASE  DB_HOL_FCV                     TO ROLE ANALISTA_CLINICO;
GRANT USAGE  ON SCHEMA    DB_HOL_FCV.PUBLIC              TO ROLE ANALISTA_CLINICO;
GRANT SELECT ON ALL TABLES IN SCHEMA DB_HOL_FCV.PUBLIC   TO ROLE ANALISTA_CLINICO;
GRANT USAGE  ON WAREHOUSE WH_HOL_FCV                     TO ROLE ANALISTA_CLINICO;

-- Asigna el rol a tu usuario (REEMPLAZA POR TU USUARIO)
GRANT ROLE ANALISTA_CLINICO TO USER JPARRADO;

-- Política para nombres y apellidos
CREATE OR REPLACE MASKING POLICY mp_nombre AS (val STRING) RETURNS STRING ->
  CASE
    WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN') THEN val
    ELSE '****'
  END;

-- Política para fecha de nacimiento (solo año visible al rol restringido)
CREATE OR REPLACE MASKING POLICY mp_fecnac AS (val TIMESTAMP_NTZ) RETURNS TIMESTAMP_NTZ ->
  CASE
    WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN') THEN val
    ELSE DATE_TRUNC('year', val)::TIMESTAMP_NTZ
  END;

-- Política para texto clínico (preserva un breve preview, oculta el resto)
CREATE OR REPLACE MASKING POLICY mp_texto_clinico AS (val STRING) RETURNS STRING ->
  CASE
    WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN') THEN val
    ELSE LEFT(val, 50) || ' ... [INFORMACIÓN CLÍNICA RESTRINGIDA POR POLÍTICA DE PRIVACIDAD]'
  END;

-- Asociación a las columnas
ALTER TABLE ADMCLIENTE  MODIFY COLUMN NomCliente    SET MASKING POLICY mp_nombre;
ALTER TABLE ADMCLIENTE  MODIFY COLUMN ApeCliente    SET MASKING POLICY mp_nombre;
ALTER TABLE ADMCLIENTE  MODIFY COLUMN FecNacimiento SET MASKING POLICY mp_fecnac;
ALTER TABLE HCECONSULTA MODIFY COLUMN DesSubjetivo  SET MASKING POLICY mp_texto_clinico;

-- Consulta como ACCOUNTADMIN (ve todo)
SELECT IdCliente, NomCliente, ApeCliente, FecNacimiento, Genero
FROM ADMCLIENTE LIMIT 10;

SELECT IdConsulta, FechaConsulta, LEFT(DesSubjetivo, 200) AS DesSubjetivo_Preview
FROM HCECONSULTA LIMIT 5;

-- Cambiamos de rol
USE ROLE ANALISTA_CLINICO;
USE DATABASE DB_HOL_FCV;
USE SCHEMA PUBLIC;
USE WAREHOUSE WH_HOL_FCV;

-- Misma query: ahora los datos están enmascarados
SELECT IdCliente, NomCliente, ApeCliente, FecNacimiento, Genero
FROM ADMCLIENTE LIMIT 10;

SELECT IdConsulta, FechaConsulta, LEFT(DesSubjetivo, 300) AS DesSubjetivo_Preview
FROM HCECONSULTA LIMIT 5;

-- Volvemos al rol admin
USE ROLE ACCOUNTADMIN;


/* ************************************ PARTE 7 ************************************************
   Cortex AI Functions sobre datos clínicos — sin extraer datos del entorno.
   ******************************************************************************************** */
USE ROLE ACCOUNTADMIN;
USE DATABASE DB_HOL_FCV;
USE SCHEMA PUBLIC;
USE WAREHOUSE WH_HOL_FCV;

-- 1. Resolver preguntas con LLMs sin APIs
SELECT SNOWFLAKE.CORTEX.COMPLETE(
  'claude-3-5-sonnet',
  'Resume en 5 puntos las ventajas de usar Snowflake Cortex AI para una institución de salud como la FCV.'
) AS respuesta;

-- 2. Resumir notas clínicas con AI_COMPLETE
SELECT
  IdConsulta,
  LEFT(DesSubjetivo, 100) AS preview,
  SNOWFLAKE.CORTEX.AI_COMPLETE(
    'claude-3-5-sonnet',
    CONCAT('Resume en máximo 30 palabras la siguiente nota clínica: ', DesSubjetivo)
  ) AS resumen_clinico
FROM HCECONSULTA
SAMPLE (10 ROWS);

-- 3. Análisis de sentimiento clínico multi-aspecto
SELECT
  IdConsulta,
  SNOWFLAKE.CORTEX.AI_SENTIMENT(
    DesSubjetivo,
    ['urgencia','complejidad','severidad','pronóstico']
  ) AS valoracion
FROM HCECONSULTA
SAMPLE (10 ROWS);

-- 4. AI_AGG: insight agregado sobre múltiples notas
SELECT
  NomAtencionTipo,
  AI_AGG(
    DesSubjetivo,
    'Resume en 3 bullets las patologías más frecuentes y su perfil de paciente'
  ) AS insight
FROM HCECONSULTA h JOIN ADMATENCION a ON a.IdAtencion = h.IdAtencion
WHERE h.FechaConsulta >= '2026-01-01'
SAMPLE (50 ROWS)
GROUP BY NomAtencionTipo
LIMIT 5;

-- 5. AI_EXTRACT: estructurar información de la nota clínica
SELECT
  IdConsulta,
  AI_EXTRACT(
    text => DesSubjetivo,
    responseFormat => [
      ['edad_paciente',     'Cuál es la edad mencionada?'],
      ['ta_mmHg',           'Cuál es la tensión arterial registrada?'],
      ['fc_lpm',            'Cuál es la frecuencia cardiaca?'],
      ['saturacion_o2',     'Cuál es la saturación de oxígeno?'],
      ['antecedentes',      'Qué antecedentes patológicos se mencionan?'],
      ['plan_terapeutico',  'Cuál es el plan o conducta a seguir?']
    ]
  ) AS estructurado
FROM HCECONSULTA
SAMPLE (5 ROWS);

-- 6. AI_TRANSLATE
SELECT
  IdConsulta,
  SNOWFLAKE.CORTEX.AI_TRANSLATE(LEFT(DesSubjetivo, 400), 'es', 'en') AS translation
FROM HCECONSULTA
SAMPLE (3 ROWS);


/* ************************************ PARTE 8 ************************************************
   Cortex Search — búsqueda semántica sobre el texto clínico.
   Construimos una vista enriquecida con contexto (atención + diagnósticos) y la indexamos.
   ******************************************************************************************** */

-- Vista enriquecida (limitamos para que la indexación del HOL sea ágil ~5-10 min)
CREATE OR REPLACE TABLE T_CONSULTAS_ENRIQUECIDAS AS
SELECT
  h.IdConsulta,
  h.IdAtencion,
  a.IdCliente,
  h.FechaConsulta,
  h.Esquema,
  h.DesMotivoCon,
  h.DesSubjetivo                                               AS Texto,
  a.NomAtencionTipo,
  LISTAGG(g.NomDiagnostico, '; ') WITHIN GROUP (ORDER BY g.SecPrioridad) AS Diagnosticos
FROM HCECONSULTA h
JOIN ADMATENCION a ON a.IdAtencion = h.IdAtencion
LEFT JOIN GENDIAGNOSTICO g ON g.IdConsulta = h.IdConsulta
WHERE h.FechaConsulta >= DATEADD(year, -1, CURRENT_DATE())
GROUP BY ALL
LIMIT 500000;

-- Cortex Search Service
CREATE OR REPLACE CORTEX SEARCH SERVICE CSS_HCE
  ON Texto
  ATTRIBUTES Esquema, NomAtencionTipo, FechaConsulta, Diagnosticos, IdConsulta, IdCliente
  WAREHOUSE = WH_HOL_FCV
  TARGET_LAG = '1 hour'
  AS
  SELECT IdConsulta, IdCliente, FechaConsulta, Esquema, NomAtencionTipo,
         DesMotivoCon, Texto, Diagnosticos
  FROM T_CONSULTAS_ENRIQUECIDAS;

-- Verifica el estado
SHOW CORTEX SEARCH SERVICES LIKE 'CSS_HCE';
DESCRIBE CORTEX SEARCH SERVICE CSS_HCE;

-- Demo de búsqueda semántica
SELECT PARSE_JSON(SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
  'DB_HOL_FCV.PUBLIC.CSS_HCE',
  '{
     "query": "pacientes con sospecha de tromboembolismo pulmonar",
     "columns": ["IdConsulta","FechaConsulta","Esquema","Diagnosticos","Texto"],
     "limit": 5
   }'
))['results'] AS resultados;

-- Otra demo con filtro
SELECT PARSE_JSON(SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
  'DB_HOL_FCV.PUBLIC.CSS_HCE',
  '{
     "query": "postoperatorio de revascularización miocárdica",
     "columns": ["IdConsulta","FechaConsulta","NomAtencionTipo","Diagnosticos"],
     "filter": { "@eq": { "NomAtencionTipo": "Hospitalizacion Por Programacion" } },
     "limit": 5
   }'
))['results'] AS resultados;


/* ************************************ PARTE 9 ************************************************
   Cortex Analyst — Semantic View sobre las 4 tablas para text-to-SQL.
   ******************************************************************************************** */

CREATE OR REPLACE SEMANTIC VIEW SV_FCV
  TABLES (
    paciente AS ADMCLIENTE
      PRIMARY KEY (IdCliente)
      COMMENT='Pacientes',
    atencion AS ADMATENCION
      PRIMARY KEY (IdAtencion)
      COMMENT='Atenciones',
    consulta AS HCECONSULTA
      PRIMARY KEY (IdConsulta)
      COMMENT='Consultas HCE',
    diagnostico AS GENDIAGNOSTICO
      COMMENT='Diagnósticos por consulta'
  )
  RELATIONSHIPS (
    atencion_paciente   AS atencion(IdCliente)    REFERENCES paciente(IdCliente),
    consulta_atencion   AS consulta(IdAtencion)   REFERENCES atencion(IdAtencion),
    diagnostico_consulta AS diagnostico(IdConsulta) REFERENCES consulta(IdConsulta)
  )
  DIMENSIONS (
    paciente.genero        AS Genero        WITH SYNONYMS=('género','sexo')        COMMENT='Género del paciente',
    paciente.edad          AS DATEDIFF(year, FecNacimiento, CURRENT_DATE())        COMMENT='Edad en años',
    atencion.tipo          AS NomAtencionTipo WITH SYNONYMS=('tipo de atención')   COMMENT='Tipo de atención',
    atencion.fec_ingreso   AS FecIngreso                                            COMMENT='Fecha de ingreso',
    atencion.anio_ingreso  AS YEAR(FecIngreso)                                      COMMENT='Año de ingreso',
    atencion.mes_ingreso   AS DATE_TRUNC('month', FecIngreso)                       COMMENT='Mes de ingreso',
    consulta.esquema       AS Esquema                                               COMMENT='Esquema HCE',
    consulta.fecha         AS FechaConsulta                                         COMMENT='Fecha de la consulta',
    diagnostico.nombre     AS NomDiagnostico                                        COMMENT='Nombre del diagnóstico',
    diagnostico.codigo     AS CodCie9                                               COMMENT='Código CIE',
    diagnostico.principal  AS IndPrincipal                                          COMMENT='1 = principal'
  )
  METRICS (
    paciente.num_pacientes      AS COUNT(DISTINCT paciente.IdCliente)   COMMENT='# Pacientes únicos',
    atencion.num_atenciones     AS COUNT(atencion.IdAtencion)           COMMENT='# Atenciones',
    consulta.num_consultas      AS COUNT(consulta.IdConsulta)           COMMENT='# Consultas',
    diagnostico.num_diagnosticos AS COUNT(*)                            COMMENT='# Diagnósticos',
    paciente.edad_promedio      AS AVG(DATEDIFF(year, paciente.FecNacimiento, CURRENT_DATE())) COMMENT='Edad promedio',
    atencion.dias_estancia      AS AVG(DATEDIFF(day, atencion.FecIngreso, atencion.FecEgreso)) COMMENT='Días de estancia promedio'
  )
  COMMENT='Modelo semántico FCV — pacientes, atenciones, consultas y diagnósticos';

-- Validar la semantic view
SHOW SEMANTIC VIEWS LIKE 'SV_FCV';

-- Una consulta de prueba directa contra el modelo
SELECT * FROM SEMANTIC_VIEW(
  SV_FCV
  DIMENSIONS atencion.anio_ingreso, atencion.tipo
  METRICS atencion.num_atenciones
)
ORDER BY 1, 3 DESC;


/* ************************************ PARTE 10 ***********************************************
   Dynamic Tables — pipeline incremental para KPIs.
   ******************************************************************************************** */

CREATE OR REPLACE DYNAMIC TABLE DT_KPI_MENSUAL
  TARGET_LAG = '1 hour'
  WAREHOUSE  = WH_HOL_FCV
  AS
SELECT
  DATE_TRUNC('month', a.FecIngreso)                                         AS mes,
  a.NomAtencionTipo                                                         AS tipo,
  c.Genero                                                                  AS genero,
  CASE
    WHEN DATEDIFF(year, c.FecNacimiento, CURRENT_DATE()) < 13 THEN 'pediatrico'
    WHEN DATEDIFF(year, c.FecNacimiento, CURRENT_DATE()) < 19 THEN 'adolescente'
    WHEN DATEDIFF(year, c.FecNacimiento, CURRENT_DATE()) < 66 THEN 'adulto'
    ELSE 'adulto mayor'
  END                                                                       AS bucket_edad,
  COUNT(*)                                                                  AS atenciones,
  COUNT(DISTINCT a.IdCliente)                                               AS pacientes_unicos,
  AVG(DATEDIFF(day, a.FecIngreso, a.FecEgreso))                             AS dias_estancia_prom
FROM ADMATENCION a
JOIN ADMCLIENTE c ON c.IdCliente = a.IdCliente
GROUP BY 1,2,3,4;

CREATE OR REPLACE DYNAMIC TABLE DT_TOP_DIAGNOSTICOS
  TARGET_LAG = '1 hour'
  WAREHOUSE  = WH_HOL_FCV
  AS
SELECT
  DATE_TRUNC('month', h.FechaConsulta)  AS mes,
  g.NomDiagnostico,
  g.CodCie9,
  COUNT(*) AS frecuencia
FROM GENDIAGNOSTICO g
JOIN HCECONSULTA h ON h.IdConsulta = g.IdConsulta
WHERE g.IndPrincipal = 1
GROUP BY 1,2,3;

-- Estado y refresh history
SHOW DYNAMIC TABLES LIKE 'DT_%';
SELECT * FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY())
ORDER BY DATA_TIMESTAMP DESC LIMIT 10;


/* ************************************ PARTE 11 ***********************************************
   Snowflake Intelligence — Agente con Cortex Search + Cortex Analyst.
   --------------------------------------------------------------------------------------------
   Pasos en la UI (no se hacen vía SQL, sigue las instrucciones):

   1. AI & ML  ->  Snowflake Intelligence  ->  + Crear agente
      Nombre: AGT_FCV
      DB/Schema: DB_HOL_FCV.PUBLIC
   2. Tools  ->  Add tool
        - Cortex Search  -> CSS_HCE  (busca en notas clínicas)
        - Cortex Analyst -> SV_FCV   (responde con métricas / SQL)
   3. Orchestrator instructions (ejemplo):
        "Eres asistente clínico de la FCV. Cuando preguntan métricas usa Cortex Analyst.
         Cuando preguntan por casos clínicos o búsquedas en notas, usa Cortex Search.
         Cita siempre los IdConsulta o las dimensiones usadas. Responde en español."
   4. Pruebas con rol ACCOUNTADMIN (ve todo el detalle):
        - Cuántas atenciones de Hospitalización Por Urgencias tuvimos en 2026?
        - Top 5 diagnósticos principales del año
        - Muéstrame consultas con sospecha de tromboembolismo pulmonar
        - Qué nota clínica tiene mayor severidad este mes?
   5. **Demo del masking**:
        USE ROLE ANALISTA_CLINICO;  -- en una sesión Snowflake
        Vuelve al agente y repite "Muéstrame la nota clínica del IdConsulta X"
        El texto vendrá enmascarado: 50 caracteres + "[INFORMACIÓN CLÍNICA RESTRINGIDA...]"
   ******************************************************************************************** */


/* ************************************ PARTE 12 ***********************************************
   Recursos y siguientes pasos
   ******************************************************************************************** */
-- Quickstart oficial Zero to Snowflake
-- https://quickstarts.snowflake.com/guide/zero_to_snowflake/index.html
--
-- Cortex Analyst:    https://quickstarts.snowflake.com/guide/getting_started_with_cortex_analyst
-- Cortex Search:     https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-search/cortex-search-overview
-- Snowflake Intelligence: https://docs.snowflake.com/user-guide/snowflake-cortex/snowflake-intelligence
-- Dynamic Tables:    https://docs.snowflake.com/en/user-guide/dynamic-tables-about
-- Masking Policies:  https://docs.snowflake.com/en/user-guide/security-column-ddm-intro
-- Streamlit in Snowflake: https://docs.snowflake.com/en/developer-guide/streamlit/about-streamlit
-- Snowpark ML:       https://docs.snowflake.com/en/developer-guide/snowflake-ml/snowpark-ml
-- AI_PARSE_DOCUMENT y Document AI: https://docs.snowflake.com/en/user-guide/snowflake-cortex/document-ai/overview
-- Snowflake-Labs (HOLs públicos): https://github.com/Snowflake-Labs


/* ************************************ ANEXO **************************************************
   Enhancements para la siguiente iteración del HOL — clasificados por nivel.
   --------------------------------------------------------------------------------------------
   BÁSICO
     - Snowflake Notebooks: análisis exploratorio Python+SQL interactivo.
     - Streamlit in Snowflake: dashboard ejecutivo (ocupación, top dx, atenciones por mes).
     - Sensitive Data Classification (SYSTEM$CLASSIFY): auto-detectar PII en las tablas.

   INTERMEDIO
     - Tag-based masking: política aplicada a tags PII en lugar de columna a columna.
     - Snowpipe Streaming: feed en vivo de signos vitales o admisiones de urgencias.
     - Snowpark Python: feature engineering distribuido (cohorts, comorbilidades).
     - Account Usage / Cost Intelligence: créditos por warehouse, queries más caras.
     - Network Policies / PrivateLink: restringir acceso por IP o enlace privado AWS.
     - Data Sharing: KPIs agregados (sin PHI) compartidos con aseguradoras o entes regulatorios.

   AVANZADO
     - AI_PARSE_DOCUMENT / Document AI: extraer datos de HCE escaneadas en PDF/imagen.
     - AI_TRANSCRIBE: notas de voz médico → texto, alimentando HCECONSULTA.
     - Iceberg Tables + Catalog Integration: interoperabilidad con AWS Glue / Lake Formation.
     - Snowpark ML / SNOWFLAKE.ML.FORECAST: predecir ocupación hospitalaria semanal.
     - Cortex Fine-Tuning: ajustar un modelo al lenguaje clínico de la FCV.
   ******************************************************************************************** */
