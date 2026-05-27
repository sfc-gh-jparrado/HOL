/* ********************************************************************************************
                   HANDS ON LAB - SeguroPlus Aseguradora Multi-ramo
                   "From S3 to Intelligence" - basado en Zero2Snowflake
********************************************************************************************
 Este archivo SQL es la guía del HOL. Copia todo el contenido en un Worksheet de Snowflake.
 Recorre las 12 partes en orden. Comentarios y notas en español.
 Datos sintéticos en s3://demosjparrado/seguros_hol/ (4 tablas, gzip)
******************************************************************************************** */
-- AWS_KEY_ID     = '<SOLICITAR_AL_INSTRUCTOR>'
-- AWS_SECRET_KEY = '<SOLICITAR_AL_INSTRUCTOR>'

/* ************************************ PARTE 1 ************************************************
   Definimos el ambiente: base de datos, warehouse y esquema.
******************************************************************************************** */
USE ROLE ACCOUNTADMIN;
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';

CREATE OR REPLACE DATABASE DB_HOL_SEGUROS
  COMMENT = 'Base de datos del HOL SeguroPlus (Aseguradora multi-ramo)';

CREATE OR REPLACE WAREHOUSE WH_HOL_SEGUROS
WITH
  WAREHOUSE_SIZE = 'SMALL'
  WAREHOUSE_TYPE = 'STANDARD'
  AUTO_SUSPEND   = 60
  AUTO_RESUME    = TRUE
  MIN_CLUSTER_COUNT = 1
  MAX_CLUSTER_COUNT = 2
  SCALING_POLICY = 'STANDARD';

USE WAREHOUSE WH_HOL_SEGUROS;
USE DATABASE  DB_HOL_SEGUROS;
USE SCHEMA    PUBLIC;


/* ************************************ PARTE 2 ************************************************
   Stage externo a AWS S3 + File Format.
   El bucket s3://demosjparrado/seguros_hol/ contiene archivos .csv.gz
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
  COMMENT = 'CSV ; gzip para datasets HOL Seguros';

-- Stage externo (credenciales embebidas, read-only)
CREATE OR REPLACE STAGE STG_SEGUROS
  URL = 's3://demosjparrado/seguros_hol/'
  CREDENTIALS = (AWS_KEY_ID='<SOLICITAR_AL_INSTRUCTOR>' AWS_SECRET_KEY='<SOLICITAR_AL_INSTRUCTOR>')
  FILE_FORMAT = FF_CSV_GZ
  COMMENT = 'Stage externo HOL Seguros - lectura del dataset sintético';

-- Listar lo que hay en el stage
LIST @STG_SEGUROS/asegurado/;
LIST @STG_SEGUROS/poliza/;
LIST @STG_SEGUROS/siniestro/;
LIST @STG_SEGUROS/cobertura_usada/;

-- Validar formato leyendo unas filas crudas sin cargarlas
SELECT $1, $2, $3, $4, $5, $6, $7, $8, $9
FROM @STG_SEGUROS/asegurado/ (FILE_FORMAT => FF_CSV_GZ)
LIMIT 5;


/* ************************************ PARTE 3 ************************************************
   DDL de las 4 tablas con comentarios + COPY INTO.
   Jerarquía: ASEGURADO 1:N POLIZA 1:N SINIESTRO 1:N COBERTURA_USADA
******************************************************************************************** */

CREATE OR REPLACE TABLE ASEGURADO (
  IdAsegurado     NUMBER         COMMENT 'Identificador único del asegurado en el ecosistema',
  NomAsegurado    VARCHAR        COMMENT 'Nombre(s) del asegurado',
  ApeAsegurado    VARCHAR        COMMENT 'Apellido(s) del asegurado',
  FecNacimiento   TIMESTAMP_NTZ  COMMENT 'Fecha de nacimiento del asegurado',
  Genero          VARCHAR        COMMENT 'Género: Femenino, Masculino o Indeterminado',
  Email           VARCHAR        COMMENT 'Correo electrónico del asegurado',
  Ciudad          VARCHAR        COMMENT 'Ciudad de residencia del asegurado',
  OcupacionRiesgo VARCHAR        COMMENT 'Ocupación del asegurado (afecta tarifa de riesgo)',
  NumDocumento    VARCHAR        COMMENT 'Número de documento de identidad del asegurado'
) COMMENT='Asegurados (clientes / tomadores) de la compañía SeguroPlus';

CREATE OR REPLACE TABLE POLIZA (
  IdPoliza        NUMBER         COMMENT 'Identificador único de la póliza',
  IdAsegurado     NUMBER         COMMENT 'FK al asegurado (ASEGURADO.IdAsegurado)',
  FecEmision      TIMESTAMP_NTZ  COMMENT 'Fecha de emisión de la póliza',
  FecVigenciaIni  TIMESTAMP_NTZ  COMMENT 'Fecha de inicio de la vigencia',
  FecVigenciaFin  TIMESTAMP_NTZ  COMMENT 'Fecha de fin de la vigencia',
  Ramo            VARCHAR        COMMENT 'Ramo del seguro: Vida Individual, Vida Grupo, Auto Todo Riesgo, SOAT, Hogar, Salud Voluntaria, Accidentes Personales, Responsabilidad Civil',
  TipoPlan        VARCHAR        COMMENT 'Tipo de plan: Basico, Estandar, Plus, Premium, Elite',
  Canal           VARCHAR        COMMENT 'Canal de venta: Broker, Digital, Sucursal, Call Center, Bancaseguros',
  ValorPrima      NUMBER(12,2)   COMMENT 'Valor de la prima anual en COP',
  EstadoPoliza    VARCHAR        COMMENT 'Estado: Vigente, Renovada, Cancelada, Vencida, Suspendida'
) COMMENT='Pólizas / contratos de seguro emitidos por SeguroPlus';

CREATE OR REPLACE TABLE SINIESTRO (
  IdSiniestro      NUMBER                  COMMENT 'Identificador único del siniestro',
  IdPoliza         NUMBER                  COMMENT 'FK a la póliza (POLIZA.IdPoliza)',
  FecOcurrencia    TIMESTAMP_NTZ           COMMENT 'Fecha en que ocurrió el evento',
  FecReporte       TIMESTAMP_NTZ           COMMENT 'Fecha en que el asegurado reportó el siniestro',
  DesNarrativa     VARCHAR(16777216)       COMMENT 'Descripción narrativa del siniestro (texto libre tipo informe de ajustador)',
  TipoSiniestro    VARCHAR                 COMMENT 'Tipo de siniestro: Choque simple, Robo total, Hospitalización, Muerte natural, etc.',
  MontoEstimado    NUMBER(14,2)            COMMENT 'Monto estimado de la indemnización (COP)',
  EstadoSiniestro  VARCHAR                 COMMENT 'Estado: Reportado, En Peritaje, Aprobado, Pagado, Rechazado, En Litigio',
  Esquema          VARCHAR                 COMMENT 'Categoría del registro: REPORTE, PERITAJE o CIERRE'
) COMMENT='Siniestros reportados sobre las pólizas, con narrativa libre';

CREATE OR REPLACE TABLE COBERTURA_USADA (
  IdSiniestro     NUMBER         COMMENT 'FK al siniestro (SINIESTRO.IdSiniestro)',
  IdCobertura     NUMBER         COMMENT 'Identificador de la cobertura activada',
  NomCobertura    VARCHAR        COMMENT 'Nombre de la cobertura activada',
  CodCobertura    VARCHAR        COMMENT 'Código interno de la cobertura',
  MontoPagado     NUMBER(14,2)   COMMENT 'Monto pagado bajo esa cobertura (COP)',
  IndPrincipal    NUMBER(1,0)    COMMENT '1 = cobertura principal del siniestro, 0 = secundaria',
  SecPrioridad    NUMBER         COMMENT 'Orden de prioridad de la cobertura'
) COMMENT='Coberturas activadas / utilizadas en cada siniestro';

-- COPY INTO desde S3

-- Antes prueba de performance
COPY INTO COBERTURA_USADA FROM @STG_SEGUROS/cobertura_usada/ ;

SELECT 'COBERTURA_USADA',  COUNT(*) registros FROM COBERTURA_USADA;

TRUNCATE table COBERTURA_USADA;

ALTER WAREHOUSE WH_HOL_SEGUROS SET WAREHOUSE_SIZE = 'LARGE';

COPY INTO COBERTURA_USADA FROM @STG_SEGUROS/cobertura_usada/ ;

SELECT 'COBERTURA_USADA',  COUNT(*) registros FROM COBERTURA_USADA;

-- Continuemos con la carga
COPY INTO ASEGURADO        FROM @STG_SEGUROS/asegurado/        ;
COPY INTO POLIZA           FROM @STG_SEGUROS/poliza/           ;
COPY INTO SINIESTRO        FROM @STG_SEGUROS/siniestro/        ;

ALTER WAREHOUSE WH_HOL_SEGUROS SET WAREHOUSE_SIZE = 'XSMALL';

-- Conteos
SELECT 'ASEGURADO'        tabla, COUNT(*) registros FROM ASEGURADO        UNION ALL
SELECT 'POLIZA',                  COUNT(*)            FROM POLIZA          UNION ALL
SELECT 'SINIESTRO',               COUNT(*)            FROM SINIESTRO       UNION ALL
SELECT 'COBERTURA_USADA',         COUNT(*)            FROM COBERTURA_USADA;


/* ************************************ PARTE 4 ************************************************
   Performance & Warehouse Scaling - comparemos tiempos.
******************************************************************************************** */

-- Pólizas vigentes por ramo y mes (anota el tiempo)
SELECT
  DATE_TRUNC('month', FecEmision) AS mes,
  Ramo,
  COUNT(*) AS polizas,
  SUM(ValorPrima) AS prima_emitida
FROM POLIZA -- 80 millones de registros
WHERE FecEmision >= '2025-01-01' AND EstadoPoliza IN ('Vigente','Renovada')
GROUP BY 1, 2
ORDER BY 1, prima_emitida DESC;

-- Top 10 tipos de siniestro
SELECT TipoSiniestro, COUNT(*) AS total, AVG(MontoEstimado) AS monto_prom
FROM SINIESTRO -- 120 millones de registros
GROUP BY 1
ORDER BY total DESC
LIMIT 10;

-- Ratio de siniestralidad por ramo (siniestros pagados / primas)
SELECT
  p.Ramo,
  COUNT(DISTINCT s.IdSiniestro) AS siniestros,
  SUM(s.MontoEstimado)          AS monto_estimado,
  SUM(p.ValorPrima)             AS prima_total,
  ROUND(SUM(s.MontoEstimado) / NULLIF(SUM(p.ValorPrima),0), 4) AS ratio_siniestralidad
FROM POLIZA p
LEFT JOIN SINIESTRO s ON s.IdPoliza = p.IdPoliza
GROUP BY 1
ORDER BY ratio_siniestralidad DESC;

-- Distribución demográfica de asegurados
SELECT
  Genero,
  OcupacionRiesgo,
  CASE
    WHEN DATEDIFF(year, FecNacimiento, CURRENT_DATE()) < 30 THEN '18-29 jóvenes'
    WHEN DATEDIFF(year, FecNacimiento, CURRENT_DATE()) < 45 THEN '30-44 adultos jóvenes'
    WHEN DATEDIFF(year, FecNacimiento, CURRENT_DATE()) < 65 THEN '45-64 adultos'
    ELSE '65+ adultos mayores'
  END bucket,
  COUNT(*) asegurados
FROM ASEGURADO -- 30 millones de registros
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3;



/* ************************************ PARTE 5 ************************************************
   Time Travel y Zero-Copy Cloning - recuperación instantánea sin duplicar almacenamiento.
******************************************************************************************** */

-- Clonemos una tabla
CREATE OR REPLACE TABLE ASEGURADO_DEV CLONE ASEGURADO;

-- Clonemos toda la base de datos (dev environment instantáneo)
CREATE OR REPLACE DATABASE DB_HOL_SEGUROS_DEV CLONE DB_HOL_SEGUROS;

-- Error intencional: borremos producción
DROP DATABASE DB_HOL_SEGUROS;

-- Restauración con UNDROP (no necesitamos llamar al DBA)
UNDROP DATABASE DB_HOL_SEGUROS;

-- Verifica que sigue todo
USE DATABASE DB_HOL_SEGUROS;
USE SCHEMA PUBLIC;
SELECT COUNT(*) FROM ASEGURADO;


/* ************************************ PARTE 6 ************************************************
   Masking dinámico condicional por rol - clave para Snowflake Intelligence.
   ACCOUNTADMIN ve todo. ANALISTA_TECNICO ve datos enmascarados.
******************************************************************************************** */
USE ROLE ACCOUNTADMIN;
USE DATABASE DB_HOL_SEGUROS;
USE SCHEMA PUBLIC;

-- Rol restringido
CREATE OR REPLACE ROLE ANALISTA_TECNICO;
GRANT USAGE  ON DATABASE  DB_HOL_SEGUROS                       TO ROLE ANALISTA_TECNICO;
GRANT USAGE  ON SCHEMA    DB_HOL_SEGUROS.PUBLIC                TO ROLE ANALISTA_TECNICO;
GRANT SELECT ON ALL TABLES IN SCHEMA DB_HOL_SEGUROS.PUBLIC     TO ROLE ANALISTA_TECNICO;
GRANT USAGE  ON WAREHOUSE WH_HOL_SEGUROS                       TO ROLE ANALISTA_TECNICO;

-- Asigna el rol a tu usuario (REEMPLAZA POR TU USUARIO)
GRANT ROLE ANALISTA_TECNICO TO USER JPARRADO;

-- Política para nombres y apellidos
CREATE OR REPLACE MASKING POLICY mp_nombre AS (val STRING) RETURNS STRING ->
  CASE
    WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN') THEN val
    ELSE '****'
  END;

-- Política para email (preserva dominio, oculta usuario)
CREATE OR REPLACE MASKING POLICY mp_email AS (val STRING) RETURNS STRING ->
  CASE
    WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN') THEN val
    ELSE CONCAT('****@', SPLIT_PART(val, '@', 2))
  END;

-- Política para fecha de nacimiento (solo año visible al rol restringido)
CREATE OR REPLACE MASKING POLICY mp_fecnac AS (val TIMESTAMP_NTZ) RETURNS TIMESTAMP_NTZ ->
  CASE
    WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN') THEN val
    ELSE DATE_TRUNC('year', val)::TIMESTAMP_NTZ
  END;

-- Política para número de documento (oculta dígitos centrales)
CREATE OR REPLACE MASKING POLICY mp_documento AS (val STRING) RETURNS STRING ->
  CASE
    WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN') THEN val
    ELSE CONCAT(LEFT(val,2),'******',RIGHT(val,2))
  END;

-- Política para narrativa de siniestro (preserva preview, oculta el resto)
CREATE OR REPLACE MASKING POLICY mp_narrativa AS (val STRING) RETURNS STRING ->
  CASE
    WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN') THEN val
    ELSE LEFT(val, 80) || ' ... [INFORMACIÓN TÉCNICA RESTRINGIDA POR POLÍTICA DE PRIVACIDAD]'
  END;

-- Asociación a las columnas
ALTER TABLE ASEGURADO MODIFY COLUMN NomAsegurado    SET MASKING POLICY mp_nombre;
ALTER TABLE ASEGURADO MODIFY COLUMN ApeAsegurado    SET MASKING POLICY mp_nombre;
ALTER TABLE ASEGURADO MODIFY COLUMN FecNacimiento   SET MASKING POLICY mp_fecnac;
ALTER TABLE ASEGURADO MODIFY COLUMN Email           SET MASKING POLICY mp_email;
ALTER TABLE ASEGURADO MODIFY COLUMN NumDocumento    SET MASKING POLICY mp_documento;
ALTER TABLE SINIESTRO MODIFY COLUMN DesNarrativa    SET MASKING POLICY mp_narrativa;


-- Consulta como ACCOUNTADMIN (ve todo)
SELECT a.IdAsegurado, a.NomAsegurado, a.ApeAsegurado, a.FecNacimiento, a.Email, a.NumDocumento,
       p.Ramo, s.IdSiniestro, s.TipoSiniestro, LEFT(s.DesNarrativa, 200) AS Narrativa_Preview
FROM ASEGURADO a -- 30 millones
JOIN POLIZA p     ON p.IdAsegurado = a.IdAsegurado   -- 80 millones
JOIN SINIESTRO s  ON s.IdPoliza    = p.IdPoliza      -- 120 millones
LIMIT 10;

-- Cambiamos de rol
USE ROLE ANALISTA_TECNICO;

-- Misma query: ahora los datos están enmascarados
SELECT a.IdAsegurado, a.NomAsegurado, a.ApeAsegurado, a.FecNacimiento, a.Email, a.NumDocumento,
       p.Ramo, s.IdSiniestro, s.TipoSiniestro, LEFT(s.DesNarrativa, 200) AS Narrativa_Preview
FROM ASEGURADO a
JOIN POLIZA p     ON p.IdAsegurado = a.IdAsegurado
JOIN SINIESTRO s  ON s.IdPoliza    = p.IdPoliza
LIMIT 10;

-- Volvemos al rol admin
USE ROLE ACCOUNTADMIN;


/* ************************************ PARTE 7 ************************************************
   Cortex AI Functions sobre datos del negocio asegurador.
******************************************************************************************** */

-- 1. Resolver preguntas con LLMs sin APIs
SELECT SNOWFLAKE.CORTEX.COMPLETE(
  'claude-sonnet-4-5',
  'Resume en 5 puntos las ventajas de usar Snowflake Cortex AI para una compañía aseguradora multi-ramo como SeguroPlus. (entrega el resultado con salto de línea)'
) AS respuesta;

-- 2. Resumir narrativas de siniestro con COMPLETE
SELECT
  IdSiniestro,
  TipoSiniestro,
  LEFT(DesNarrativa, 100) AS preview,
  SNOWFLAKE.CORTEX.COMPLETE(
    'openai-gpt-5.1',
    CONCAT('Resume en máximo 5 palabras la siguiente narrativa de siniestro: ', DesNarrativa)
  ) AS resumen_siniestro
FROM SINIESTRO
LIMIT 10;

-- 3. Valoración técnica multi-aspecto con LLM (severidad, urgencia, sospecha de fraude, gravedad)
SELECT
  IdSiniestro,
  TipoSiniestro,
  DesNarrativa,
  SNOWFLAKE.CORTEX.COMPLETE(
    'openai-gpt-4.1',
    CONCAT(
      'Evalúa la siguiente narrativa de siniestro en escala 1-5 para: severidad, urgencia, sospecha_fraude y gravedad_personas. Responde solo en JSON con el formato {severidad:N,urgencia:N,sospecha_fraude:N,gravedad_personas:N}. Texto: ',
      LEFT(DesNarrativa, 1500)
    )
  ) AS valoracion
FROM SINIESTRO
LIMIT 10;


-- 4. AI_AGG: insight agregado sobre múltiples narrativas
SELECT
  AI_AGG(
    DesNarrativa,
    'Resume en 3 bullets las causas más frecuentes de siniestros, los daños típicos reportados y oportunidades de mejora en la prevención'
  ) AS insight
FROM (
  SELECT DesNarrativa
  FROM SINIESTRO
  WHERE FecOcurrencia >= '2026-01-01'
  LIMIT 100
);

-- 5. AI_EXTRACT: estructurar información de la narrativa
SELECT
  IdSiniestro,
  AI_EXTRACT(
    text => DesNarrativa,
    responseFormat => [
      ['lugar_evento',          '¿Dónde ocurrió el evento?'],
      ['parte_responsable',     '¿Quién es responsable según la narrativa (asegurado, tercero, fortuito)?'],
      ['daños_reportados',      '¿Qué daños se reportan?'],
      ['hay_lesionados',        '¿Hay personas lesionadas o fallecidas?'],
      ['testigos',              '¿Hay testigos mencionados?'],
      ['condiciones_climaticas','¿Qué condiciones climáticas se mencionan?']
    ]
  ) AS estructurado
FROM SINIESTRO
LIMIT 5;

-- 6. AI_TRANSLATE
SELECT
  IdSiniestro,
  SNOWFLAKE.CORTEX.AI_TRANSLATE(LEFT(DesNarrativa, 400), 'es', 'en') AS translation
FROM SINIESTRO
LIMIT 3;


/* ************************************ PARTE 7B ***********************************************
   Datos no estructurados - PDFs, imágenes y audio procesados con Cortex AI.
   Bucket: s3://demosjparrado/seguros_hol/archivos/ (archivos sintéticos)
******************************************************************************************** */
USE ROLE ACCOUNTADMIN;
USE DATABASE DB_HOL_SEGUROS; USE SCHEMA PUBLIC; USE WAREHOUSE WH_HOL_SEGUROS;

-- Stage externo dedicado al subprefijo archivos (DIRECTORY ENABLE para list y TO_FILE)
CREATE OR REPLACE STAGE STG_ARCHIVOS_SEGUROS
  URL = 's3://demosjparrado/seguros_hol/archivos/'
  CREDENTIALS = (AWS_KEY_ID='<SOLICITAR_AL_INSTRUCTOR>' AWS_SECRET_KEY='<SOLICITAR_AL_INSTRUCTOR>')
  DIRECTORY = (ENABLE = TRUE);

LIST @STG_ARCHIVOS_SEGUROS;

-- 1. AI_PARSE_DOCUMENT: extraer texto de la póliza física
SELECT AI_PARSE_DOCUMENT(
  TO_FILE('@STG_ARCHIVOS_SEGUROS','poliza_001.pdf'),
  {'mode':'OCR'}
) AS contenido_poliza;

-- 2. AI_EXTRACT estructurado sobre PDF de póliza
SELECT TO_VARCHAR(AI_EXTRACT(
  file => TO_FILE('@STG_ARCHIVOS_SEGUROS','poliza_001.pdf'),
  responseFormat => [
    ['numero_poliza',       'Número de la póliza'],
    ['ramo',                'Ramo del seguro'],
    ['tomador',             'Nombre completo del tomador / asegurado'],
    ['identificacion',      'Documento de identidad del tomador'],
    ['vigencia_inicio',     'Fecha de inicio de la vigencia'],
    ['vigencia_fin',        'Fecha de fin de la vigencia'],
    ['valor_asegurado',     'Valor asegurado'],
    ['prima_anual',         'Valor de la prima anual'],
    ['coberturas',          'Lista de coberturas contratadas']
  ]
)) AS poliza_estructurada;

-- 3. AI_EXTRACT sobre informe de peritaje
WITH extraccion AS (
  SELECT AI_EXTRACT(
    file => TO_FILE('@STG_ARCHIVOS_SEGUROS','peritaje_choque_001.pdf'),
    responseFormat => [
      ['numero_siniestro',  'Número del siniestro'],
      ['perito',            'Nombre del perito asignado'],
      ['lugar_inspeccion',  'Lugar de inspección'],
      ['daños',             'Lista de daños observados'],
      ['estimacion_total',  'Monto estimado total de la reparación'],
      ['concepto',          'Concepto del perito (procedente / improcedente)'],
      ['tiempo_reparacion', 'Tiempo estimado de reparación']
    ]
  ) AS resultado
)
SELECT
  resultado:response:numero_siniestro::STRING  AS numero_siniestro,
  resultado:response:perito::STRING            AS perito,
  resultado:response:lugar_inspeccion::STRING  AS lugar_inspeccion,
  resultado:response:daños::STRING             AS daños,
  resultado:response:estimacion_total::STRING  AS estimacion_total,
  resultado:response:concepto::STRING          AS concepto,
  resultado:response:tiempo_reparacion::STRING AS tiempo_reparacion
FROM extraccion;

-- 4. AI_EXTRACT sobre factura de taller (proveedor de reparación)
SELECT TO_VARCHAR(AI_EXTRACT(
  file => TO_FILE('@STG_ARCHIVOS_SEGUROS','factura_taller_001.pdf'),
  responseFormat => [
    ['numero_factura',  'Número de la factura'],
    ['taller',          'Nombre del taller'],
    ['vehiculo',        'Vehículo intervenido (marca, modelo, placa)'],
    ['items',           'Lista de items facturados (mano de obra, repuestos, pintura)'],
    ['subtotal',        'Subtotal antes de IVA'],
    ['iva',             'Valor del IVA'],
    ['total',           'Total a cargo de la aseguradora']
  ]
)) AS factura_estructurada;

-- 5. AI_COMPLETE multimodal con pixtral-large sobre foto de vehículo siniestrado
--    (analógo al análisis de góndola del HOL_RETAIL pero para siniestros auto)
SELECT SNOWFLAKE.CORTEX.COMPLETE(
  'pixtral-large',
  PROMPT('Eres un perito de seguros experto en peritaje de siniestros vehiculares. Analiza esta foto de un vehículo siniestrado y devuelve un JSON con: 1) marca_modelo_estimado, 2) parte_afectada (lista de zonas dañadas: capó, puerta, parachoques, etc.), 3) severidad (leve/media/grave/total), 4) tipo_siniestro_probable (choque frontal, lateral, volcamiento, incendio, etc.), 5) estimacion_reparacion_cop (rango aproximado), 6) recomendacion_cobertura (qué coberturas activar: RC, daños propios, vehículo de reemplazo, etc.), 7) recomendacion_perito (siguiente paso operativo). Responde solo en JSON y en español. {0}',
         TO_FILE('@STG_ARCHIVOS_SEGUROS','foto_siniestro_auto_001.jpg'))
) AS analisis_siniestro_auto;

-- 6. AI_PARSE_DOCUMENT sobre historia clínica de siniestro de salud
SELECT AI_PARSE_DOCUMENT(
  TO_FILE('@STG_ARCHIVOS_SEGUROS','historia_clinica_siniestro_001.pdf'),
  {'mode':'OCR'}
) AS contenido_hc;

-- 7. AI_TRANSCRIBE: transcribir reporte telefónico del asegurado
SELECT TO_VARCHAR(AI_TRANSCRIBE(
  TO_FILE('@STG_ARCHIVOS_SEGUROS','audio_reporte_siniestro.mp3')
)) AS transcripcion_reporte;

-- 8. AI_TRANSCRIBE: transcribir reclamación + análisis de sentimiento + recomendaciones
WITH transcripcion AS (
    SELECT AI_TRANSCRIBE(
      TO_FILE('@STG_ARCHIVOS_SEGUROS','audio_reclamacion.mp3'),
      {'timestamp_granularity': 'speaker'}
    ) AS resultado
)
SELECT
  resultado:text::STRING AS texto_reclamacion,
  AI_SENTIMENT(resultado:text::STRING, ['servicio','tiempo_de_respuesta','indemnizacion','vehiculo_reemplazo']) AS sentimiento,
  SNOWFLAKE.CORTEX.COMPLETE('claude-opus-4-5', PROMPT('Analiza esta transcripción de reclamación a una aseguradora y genera 3 recomendaciones priorizadas para servicio al cliente y para el equipo de operaciones de siniestros. Responde en español. {0}', resultado:text::STRING)) AS recomendaciones
FROM transcripcion;




/* ************************************ PARTE 8 ************************************************
   Cortex Search - búsqueda semántica sobre las narrativas de siniestro.
   Construimos una vista enriquecida con contexto (póliza + ramo + coberturas) y la indexamos.
******************************************************************************************** */

ALTER WAREHOUSE WH_HOL_SEGUROS SET WAREHOUSE_SIZE = 'MEDIUM';

-- Vista enriquecida (limitamos para que la indexación del HOL sea ágil)
CREATE OR REPLACE TABLE T_SINIESTROS_ENRIQUECIDOS AS
SELECT
  s.IdSiniestro,
  s.IdPoliza,
  p.IdAsegurado,
  s.FecOcurrencia,
  s.FecReporte,
  s.Esquema,
  s.TipoSiniestro,
  s.MontoEstimado,
  s.EstadoSiniestro,
  s.DesNarrativa                                                 AS Texto,
  p.Ramo,
  p.TipoPlan,
  p.Canal,
  LISTAGG(c.NomCobertura, '; ') WITHIN GROUP (ORDER BY c.SecPrioridad) AS Coberturas
FROM SINIESTRO s
JOIN POLIZA p ON p.IdPoliza = s.IdPoliza
LEFT JOIN COBERTURA_USADA c ON c.IdSiniestro = s.IdSiniestro
WHERE s.FecOcurrencia >= DATEADD(year, -1, CURRENT_DATE())
GROUP BY ALL
LIMIT 50000;

-- Cortex Search Service vía SQL
CREATE OR REPLACE CORTEX SEARCH SERVICE CSS_SINIESTROS
  ON Texto -- campo para hacer la búsqueda
  ATTRIBUTES Esquema, Ramo, TipoPlan, Canal, TipoSiniestro, EstadoSiniestro, FecOcurrencia, Coberturas, IdSiniestro, IdPoliza, IdAsegurado
  WAREHOUSE = WH_HOL_SEGUROS
  TARGET_LAG = '1 hour'
  AS
  SELECT IdSiniestro, IdPoliza, IdAsegurado, FecOcurrencia, FecReporte, Esquema,
         Ramo, TipoPlan, Canal, TipoSiniestro, EstadoSiniestro, MontoEstimado,
         Texto, Coberturas
  FROM T_SINIESTROS_ENRIQUECIDOS;


-- Verifica el estado
SHOW CORTEX SEARCH SERVICES LIKE 'CSS_SINIESTROS';

-- Demo de búsqueda semántica
SELECT PARSE_JSON(SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
  'DB_HOL_SEGUROS.PUBLIC.CSS_SINIESTROS',
  '{
     "query": "siniestros con sospecha de fraude o robo de vehículo en zona urbana",
     "columns": ["IdSiniestro","FecOcurrencia","Ramo","TipoSiniestro","EstadoSiniestro","Texto"],
     "limit": 5
   }'
))['results'] AS resultados;



/* ************************************ PARTE 9 ************************************************
   Cortex Analyst - Semantic View sobre las 4 tablas para text-to-SQL.
******************************************************************************************** */

-- Vamos a AI Studio

/* ************************************ PARTE 10 ***********************************************
   Dynamic Tables - pipeline incremental para KPIs.
******************************************************************************************** */

CREATE OR REPLACE DYNAMIC TABLE DT_KPI_SINIESTRALIDAD_MENSUAL
  TARGET_LAG = '1 hour'
  WAREHOUSE  = WH_HOL_SEGUROS
  AS
SELECT
  DATE_TRUNC('month', s.FecOcurrencia)                                        AS mes,
  p.Ramo                                                                      AS ramo,
  p.TipoPlan                                                                  AS plan,
  p.Canal                                                                     AS canal,
  s.TipoSiniestro                                                             AS tipo_siniestro,
  s.EstadoSiniestro                                                           AS estado,
  COUNT(*)                                                                    AS siniestros,
  COUNT(DISTINCT p.IdAsegurado)                                               AS asegurados_unicos,
  SUM(s.MontoEstimado)                                                        AS monto_estimado_total,
  AVG(s.MontoEstimado)                                                        AS monto_estimado_prom,
  AVG(DATEDIFF(day, s.FecOcurrencia, s.FecReporte))                           AS dias_reporte_prom
FROM SINIESTRO s
JOIN POLIZA p ON p.IdPoliza = s.IdPoliza
GROUP BY 1,2,3,4,5,6;

CREATE OR REPLACE DYNAMIC TABLE DT_TOP_TIPOS_SINIESTRO
  TARGET_LAG = '1 hour'
  WAREHOUSE  = WH_HOL_SEGUROS
  AS
SELECT
  DATE_TRUNC('month', s.FecOcurrencia)  AS mes,
  s.TipoSiniestro,
  p.Ramo,
  COUNT(*)              AS frecuencia,
  SUM(s.MontoEstimado)  AS monto_total,
  AVG(s.MontoEstimado)  AS monto_promedio
FROM SINIESTRO s
JOIN POLIZA p ON p.IdPoliza = s.IdPoliza
GROUP BY 1,2,3;

-- Vamos a ver las tablas dinámicas en el catálogo.
-- Una automatización fácil y muy potente sin necesidad de ETLs/ELTs


/* ************************************ PARTE 11 ***********************************************
   Snowflake Intelligence - Agente con Cortex Search + Cortex Analyst.
--------------------------------------------------------------------------------------------
   Pasos en la UI (no se hacen vía SQL, sigue las instrucciones):

   1. AI & ML  ->  Snowflake Intelligence  ->  + Crear agente
      Nombre: AGT_SEGUROS
      DB/Schema: DB_HOL_SEGUROS.PUBLIC
   2. Tools  ->  Add tool
        - Cortex Search  -> CSS_SINIESTROS  (busca en narrativas de siniestro)
        - Cortex Analyst -> SV_SEGUROS      (responde con métricas / SQL)
   3. Orchestrator instructions (ejemplo):
        "Eres asistente técnico de SeguroPlus. Cuando preguntan métricas de pólizas,
         siniestros, primas, ratios o asegurados, usa Cortex Analyst.
         Cuando preguntan por casos puntuales, búsquedas en narrativas o
         sospechas de fraude, usa Cortex Search.
         Cita siempre los IdSiniestro, IdPoliza o las dimensiones usadas. Responde en español."
   4. Response instructions (ejemplo):
        "Genera sugerencias de preguntas para permitirle al usuario continuar
         profundizando el análisis. Todo el contenido generado, incluyendo el
         razonamiento paso a paso, debe ser en español."
   5. En Access, agrega el rol "ANALISTA_TECNICO"
   6. Pruebas con rol ACCOUNTADMIN (ve todo el detalle):
        - ¿Cuántos siniestros por ramo tuvimos en 2026?
        - Top 5 tipos de siniestro con mayor monto promedio
        - Muéstrame siniestros con sospecha de fraude o robo de vehículo
        - ¿Qué ramo tiene mejor ratio de siniestralidad este año?
        - Dame el nombre y documento de los 10 asegurados con mayor monto pagado en 2026
   7. **Cambia de rol y repite la última pregunta**:
        Vuelve al agente y repite "Dame el nombre y documento de los 10 asegurados con mayor monto pagado en 2026".
        La respuesta no incluirá los datos sensibles que están bajo el gobierno definido.

******************************************************************************************** */


/* ************************************ PARTE 12 ***********************************************
   Con CoCo todo es aún más FÁCIL y RÁPIDO!!
--------------------------------------------------------------------------------------------

   Ejercicio: Creación de un modelo de ML en segundos usando las Dynamic Tables
   creadas en la PARTE 10 como feature store (KPIs pre-agregados, siempre frescos).

   PROMPT:
   Crea un notebook que utilice DB_HOL_SEGUROS.PUBLIC.DT_KPI_SINIESTRALIDAD_MENSUAL
   (mes, ramo, plan, canal, tipo_siniestro, estado, siniestros, asegurados_unicos,
   monto_estimado_total, monto_estimado_prom, dias_reporte_prom) y
   DB_HOL_SEGUROS.PUBLIC.DT_TOP_TIPOS_SINIESTRO (mes, tipo_siniestro, ramo,
   frecuencia, monto_total, monto_promedio) como feature store.

   Construye dos modelos de ML:
     1) Detección de sospecha de fraude por siniestro (clasificación binaria
        usando narrativas + monto + tipo + tiempo de reporte como features).
     2) Forecast de siniestralidad mensual por ramo a 3 meses (time series con
        SNOWFLAKE.ML.FORECAST sobre DT_KPI_SINIESTRALIDAD_MENSUAL).

   Realiza análisis EDA con gráficos (estacionalidad por ramo, tipo de siniestro
   más costoso, distribución de tiempo de reporte, ratios de siniestralidad por
   plan), descripción de los resultados y genera 3 experimentos para elegir el
   mejor modelo. Crea un feature store sobre las dynamic tables y registra 2
   versiones del modelo en el Snowflake Model Registry.

******************************************************************************************** */
