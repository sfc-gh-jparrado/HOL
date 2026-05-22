/* ********************************************************************************************
                   HANDS ON LAB — Fundación Cardiovascular de Colombia (FCV)
                   "From data to Intelligence" — basado en Zero2Snowflake
********************************************************************************************
 Este archivo SQL es la guía del HOL. Copia todo el contenido en un Worksheet de Snowflake.
 Recorre las 12 partes en orden. Comentarios y notas en español.
 Datos sintéticos en s3://demosjparrado/fcv_hol/ (4 tablas, gzip)
******************************************************************************************** */
-- AWS_KEY_ID     = '<SOLICITAR_AL_INSTRUCTOR>'
-- AWS_SECRET_KEY = '<SOLICITAR_AL_INSTRUCTOR>'

/* ************************************ PARTE 1 ************************************************
   Definimos el ambiente: base de datos, warehouse y esquema.
   ******************************************************************************************** */
USE ROLE ACCOUNTADMIN;
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';

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
   El bucket s3://demosjparrado/fcv_hol/ contiene 208 archivos .csv.gz
   ******************************************************************************************** */

-- File format CSV gzip 
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

-- COPY INTO desde S3

-- Antes prueba de performance
COPY INTO GENDIAGNOSTICO FROM @STG_FCV/gendiagnostico/ ;

SELECT 'GENDIAGNOSTICO',  COUNT(*) registros FROM GENDIAGNOSTICO;

TRUNCATE table GENDIAGNOSTICO;

ALTER WAREHOUSE WH_HOL_FCV SET WAREHOUSE_SIZE = 'LARGE';

COPY INTO GENDIAGNOSTICO FROM @STG_FCV/gendiagnostico/ ;

SELECT 'GENDIAGNOSTICO',  COUNT(*) registros FROM GENDIAGNOSTICO;

--
-- Continuemos con la carga
COPY INTO ADMCLIENTE     FROM @STG_FCV/admcliente/     ;
COPY INTO ADMATENCION    FROM @STG_FCV/admatencion/    ;
COPY INTO HCECONSULTA    FROM @STG_FCV/hceconsulta/    ;

ALTER WAREHOUSE WH_HOL_FCV SET WAREHOUSE_SIZE = 'XSMALL';

-- Conteos
SELECT 'ADMCLIENTE' tabla, COUNT(*) registros FROM ADMCLIENTE UNION ALL
SELECT 'ADMATENCION',     COUNT(*)            FROM ADMATENCION UNION ALL
SELECT 'HCECONSULTA',     COUNT(*)            FROM HCECONSULTA UNION ALL
SELECT 'GENDIAGNOSTICO',  COUNT(*)            FROM GENDIAGNOSTICO;


/* ************************************ PARTE 4 ************************************************
   Performance & Warehouse Scaling — comparemos tiempos.
   ******************************************************************************************** */

-- Query analítica con WH XSMALL (anota el tiempo)
SELECT
  DATE_TRUNC('month', FecIngreso) AS mes,
  NomAtencionTipo,
  COUNT(*) AS atenciones
FROM ADMATENCION -- 80 millones de registros
WHERE FecIngreso >= '2025-01-01'
GROUP BY 1, 2
ORDER BY 1, atenciones DESC;

-- Top 10 diagnósticos
SELECT NomDiagnostico, CodCie9, COUNT(*) total
FROM GENDIAGNOSTICO -- 150 millones de registros
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
FROM ADMCLIENTE -- 30 millones de registros
GROUP BY 1, 2
ORDER BY 1, 2;



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
SELECT c.IdCliente, c.NomCliente, c.ApeCliente, c.FecNacimiento, c.Genero,
       co.IdConsulta, co.FechaConsulta, LEFT(co.DesSubjetivo, 200) AS DesSubjetivo_Preview
FROM ADMCLIENTE c -- 30 millones
JOIN ADMATENCION a ON c.IdCliente = a.IdCliente -- 80 millones
JOIN HCECONSULTA co ON a.IdAtencion = co.IdAtencion --120 millones
LIMIT 10;

-- Cambiamos de rol
USE ROLE ANALISTA_CLINICO;

-- Misma query: ahora los datos están enmascarados
SELECT c.IdCliente, c.NomCliente, c.ApeCliente, c.FecNacimiento, c.Genero,
       co.IdConsulta, co.FechaConsulta, LEFT(co.DesSubjetivo, 200) AS DesSubjetivo_Preview
FROM ADMCLIENTE c -- 30 millones
JOIN ADMATENCION a ON c.IdCliente = a.IdCliente -- 80 millones
JOIN HCECONSULTA co ON a.IdAtencion = co.IdAtencion --120 millones
LIMIT 10;

-- Volvemos al rol admin
USE ROLE ACCOUNTADMIN;


/* ************************************ PARTE 7 ************************************************
   Cortex AI Functions sobre datos clínicos — sin extraer datos del entorno.
   ******************************************************************************************** */

-- 1. Resolver preguntas con LLMs sin APIs
SELECT SNOWFLAKE.CORTEX.COMPLETE(
  'claude-sonnet-4-5',
  'Resume en 5 puntos las ventajas de usar Snowflake Cortex AI para una institución de salud como la FCV. (entrega el resultado con salto de linea)'
) AS respuesta;

-- 2. Resumir notas clínicas con COMPLETE
SELECT
  IdConsulta,
  LEFT(DesSubjetivo, 100) AS preview,
  SNOWFLAKE.CORTEX.COMPLETE(
    'openai-gpt-5.1',
    CONCAT('Resume en máximo 5 palabras la siguiente nota clínica: ', DesSubjetivo)
  ) AS resumen_clinico
FROM HCECONSULTA
SAMPLE (10 ROWS);

-- 3. Valoración clínica multi-aspecto con LLM
SELECT
  IdConsulta,
  DesSubjetivo,
  SNOWFLAKE.CORTEX.COMPLETE(
    'openai-gpt-4.1',
    CONCAT(
      'Evalúa el siguiente texto clínico en escala 1-5 para: urgencia, complejidad, severidad y pronóstico. Responde solo en JSON con el formato {urgencia:N,complejidad:N,severidad:N,pronostico:N}. Texto: ',
      LEFT(DesSubjetivo, 1500)
    )
  ) AS valoracion
FROM HCECONSULTA
SAMPLE (10 ROWS);


-- 4. AI_AGG: insight agregado sobre múltiples notas
SELECT
  AI_AGG(
    DesSubjetivo,
    'Resume en 3 bullets las patologías más frecuentes y su perfil de paciente'
  ) AS insight
FROM HCECONSULTA SAMPLE (100 ROWS)
WHERE FechaConsulta >= '2026-01-01';

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


/* ************************************ PARTE 7B ***********************************************
   Datos no estructurados — PDFs, imágenes y audio procesados con Cortex AI.
   Bucket: s3://demosjparrado/fcv_hol/archivos/  (10 archivos sintéticos)
   ******************************************************************************************** */
USE ROLE ACCOUNTADMIN;
USE DATABASE DB_HOL_FCV; USE SCHEMA PUBLIC; USE WAREHOUSE WH_HOL_FCV;

-- Stage externo dedicado al subprefijo archivos (DIRECTORY ENABLE para list y TO_FILE)
CREATE OR REPLACE STAGE STG_ARCHIVOS_FCV
  URL = 's3://demosjparrado/fcv_hol/archivos/'
  CREDENTIALS = (AWS_KEY_ID='<SOLICITAR_AL_INSTRUCTOR>' AWS_SECRET_KEY='<SOLICITAR_AL_INSTRUCTOR>')
  DIRECTORY = (ENABLE = TRUE);

LIST @STG_ARCHIVOS_FCV;

-- 1. AI_PARSE_DOCUMENT: extraer texto de un PDF de historia clínica
SELECT AI_PARSE_DOCUMENT(
  TO_FILE('@STG_ARCHIVOS_FCV','hc_paciente_001.pdf'),
  {'mode':'OCR'}
) AS contenido_pdf;

-- 2. AI_EXTRACT estructurado sobre PDF de HC
SELECT TO_VARCHAR(AI_EXTRACT(
  file => TO_FILE('@STG_ARCHIVOS_FCV','hc_paciente_001.pdf'),
  responseFormat => [
    ['paciente_nombre','Nombre completo del paciente'],
    ['edad','Edad del paciente'],
    ['motivo','Motivo de consulta'],
    ['ta_mmHg','Tensión arterial registrada'],
    ['fc_lpm','Frecuencia cardíaca'],
    ['saturacion_o2','Saturación de oxígeno'],
    ['diagnostico_principal','Diagnóstico principal'],
    ['plan','Plan terapéutico']
  ]
)) AS hc_estructurada;

-- 3. AI_EXTRACT sobre PDF de laboratorio - tabla con valores y rangos
WITH extraccion AS (
  SELECT AI_EXTRACT(
    file => TO_FILE('@STG_ARCHIVOS_FCV','lab_hemograma_001.pdf'),
    responseFormat => [
      ['hemoglobina','Valor de hemoglobina y si está fuera de rango'],
      ['leucocitos','Valor de leucocitos y estado'],
      ['plaquetas','Valor de plaquetas'],
      ['glucosa','Valor de glucosa y estado'],
      ['troponina','Valor de troponina y estado'],
      ['valores_anormales','Lista de analitos fuera de rango']
    ]
  ) AS resultado
)
SELECT  resultado:response:hemoglobina::STRING AS hemoglobina,
        resultado:response:leucocitos::STRING AS leucocitos,
        resultado:response:plaquetas::STRING AS plaquetas,
        resultado:response:glucosa::STRING AS glucosa,
        resultado:response:troponina::STRING AS troponina,
        resultado:response:valores_anormales::STRING AS valores_anormales
FROM extraccion;

-- 4. AI_COMPLETE multimodal con pixtral-large sobre cédula de identidad
SELECT SNOWFLAKE.CORTEX.COMPLETE(
  'pixtral-large',
  PROMPT('Extrae los datos de esta cedula colombiana: numero, nombre completo, fecha de nacimiento, lugar de nacimiento, fecha de expedicion. {0}',
         TO_FILE('@STG_ARCHIVOS_FCV','cedula.jpg'))
) AS cedula_datos;

-- 5. AI_COMPLETE sobre receta médica - extraer medicamentos + dosis
SELECT SNOWFLAKE.CORTEX.COMPLETE(
  'claude-opus-4-5',
  PROMPT('Lee esta receta medica y devuelve en JSON la lista de medicamentos con su dosis y frecuencia. {0}',
         TO_FILE('@STG_ARCHIVOS_FCV','receta_medica_001.png'))
) AS receta_meds;

-- 6. AI_TRANSCRIBE: transcribir audio de consulta a texto
SELECT TO_VARCHAR(AI_TRANSCRIBE(
  TO_FILE('@STG_ARCHIVOS_FCV','consulta_audio_001.mp3')
)) AS transcripcion;

-- 7. AI_TRANSCRIBE: transcribir llamada de soporte + análisis de sentimiento
WITH transcripcion AS (
    SELECT AI_TRANSCRIBE(
      TO_FILE('@STG_ARCHIVOS_FCV','problema-servicio.mp3'),
      {'timestamp_granularity': 'speaker'}
    ) AS resultado
) 
SELECT
  resultado,
  AI_SENTIMENT(resultado:text::STRING, ['servicios','resolución','tiempo_de_espera']) AS sentimiento,
  SNOWFLAKE.CORTEX.COMPLETE('claude-opus-4-5', PROMPT('Analiza la transcripción y genera recomendaciones al asesor de sevicio: {0}', resultado:text::STRING))
FROM transcripcion;




/* ************************************ PARTE 8 ************************************************
   Cortex Search — búsqueda semántica sobre el texto clínico.
   Construimos una vista enriquecida con contexto (atención + diagnósticos) y la indexamos.
   ******************************************************************************************** */

ALTER WAREHOUSE WH_HOL_FCV SET WAREHOUSE_SIZE = 'MEDIUM';

-- Vista enriquecida (limitamos para que la indexación del HOL sea ágil)
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
LIMIT 50000;

-- Podemos hacer el cortex search por código o por UI

-- Cortex Search Service vía SQL
CREATE OR REPLACE CORTEX SEARCH SERVICE CSS_HCE
  ON Texto -- campo para hacer el search
  ATTRIBUTES Esquema, NomAtencionTipo, FechaConsulta, Diagnosticos, IdConsulta, IdCliente -- atributos para aplicar filtros
  WAREHOUSE = WH_HOL_FCV
  TARGET_LAG = '1 hour'
  AS
  SELECT IdConsulta, IdCliente, FechaConsulta, Esquema, NomAtencionTipo,
         DesMotivoCon, Texto, Diagnosticos
  FROM T_CONSULTAS_ENRIQUECIDAS;


-- Verifica el estado
SHOW CORTEX SEARCH SERVICES LIKE 'CSS_HCE';

-- Demo de búsqueda semántica
SELECT PARSE_JSON(SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
  'DB_HOL_FCV.PUBLIC.CSS_HCE',
  '{
     "query": "pacientes con sospecha de tromboembolismo pulmonar",
     "columns": ["IdConsulta","FechaConsulta","Esquema","Diagnosticos","Texto"],
     "limit": 5
   }'
))['results'] AS resultados;



/* ************************************ PARTE 9 ************************************************
   Cortex Analyst — Semantic View sobre las 4 tablas para text-to-SQL.
   ******************************************************************************************** */

-- Vamos a AI Studio

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

-- Vamos a ver las tablas dinámicas en el catalogo. 
-- Una automatización fácil y muy potente sin necesidad de ETLs/ELTs


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
   4. Response instructions (ejemplo):
        "Genera sugerencias de preguntas para permitirle al usuario continuar profundizando el análisis.
         Todo el contenido generado,  incluyendo el razonamiento paso a paso, debe  ser en español."
   5. En Access, agrega el rol "Analista_Clinico"
   6. Pruebas con rol ACCOUNTADMIN (ve todo el detalle):
        - Cuántas atenciones de Hospitalización Por Urgencias tuvimos en 2026?
        - Top 5 diagnósticos principales del año
        - Muéstrame consultas con sospecha de tromboembolismo pulmonar
        - Qué nota clínica tiene mayor severidad este mes?
        - Dame el nombre de los 10 pacientes con mayor cantidad de días de hospitalización en 2026
   7. **Cambia de rol y repite la última pregunta**:
        Vuelve al agente y repite "Dame el nombre de los 10 pacientes con mayor cantidad de días de hospitalización en 2026"
        La respuesta no incluirá los datos sensibles que están bajo el gobierno definido.
   ******************************************************************************************** */

