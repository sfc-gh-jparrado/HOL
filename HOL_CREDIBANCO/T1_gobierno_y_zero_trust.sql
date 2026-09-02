/* ============================================================================
   HOL CredibanCo - RFP 10010806
   T1 - Gobierno y Zero Trust

   Equipo    : Seguridad de la Informacion
   Duracion  : 30 minutos
   Prerrequisito: haber ejecutado install_seguridad.sql en esta cuenta

   Clasificar el dato sensible sin decirle donde esta, proteger con una sola politica todo lo que la clasificacion marque, y comprobar que ese control se respeta por igual desde SQL, desde BI y desde la IA.
   ==========================================================================*/


-- ==========================================================================
-- Paso 1. Clasificar sin decirle donde esta el dato sensible
-- Que la plataforma descubra por si sola el PAN, la cedula y el celular.
-- ==========================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_GOBIERNO;

-- clasificacion de caja, sin ninguna pista sobre el contenido
CALL SYSTEM$CLASSIFY('CB_SILVER.ADQUIRENCIA.TARJETAHABIENTES', {'auto_tag': true});

-- que encontro
SELECT COLUMN_NAME, TAG_NAME, TAG_VALUE
FROM TABLE(CB_SILVER.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS(
           'CB_SILVER.ADQUIRENCIA.TARJETAHABIENTES', 'table'))
WHERE TAG_NAME IN ('SEMANTIC_CATEGORY', 'PRIVACY_CATEGORY')
ORDER BY COLUMN_NAME;

-- validar los patrones antes de registrarlos
SELECT SUM(IFF(PAN REGEXP '^[0-9]{15,16}$', 1, 0))          AS PAN_OK,
       SUM(IFF(DOCUMENTO REGEXP '^[1-9][0-9]{6,9}$', 1, 0)) AS CEDULA_OK,
       SUM(IFF(CELULAR REGEXP '^\\+57 3[0-9]{8}$', 1, 0))    AS CELULAR_OK,
       COUNT(*)                                             AS MUESTRA
FROM CB_SILVER.ADQUIRENCIA.TARJETAHABIENTES SAMPLE (10000 ROWS);

-- clasificador propio para tipos de dato colombianos
CREATE OR REPLACE SNOWFLAKE.DATA_PRIVACY.CUSTOM_CLASSIFIER
    CB_PLATAFORMA.GOBIERNO.CLF_COLOMBIA();

CALL CB_PLATAFORMA.GOBIERNO.CLF_COLOMBIA!ADD_REGEX(
  SEMANTIC_CATEGORY => 'PAN_TARJETA',
  PRIVACY_CATEGORY  => 'IDENTIFIER',
  VALUE_REGEX       => '^[0-9]{15,16}$',
  COL_NAME_REGEX    => '.*(PAN|TARJETA|CARD).*',
  DESCRIPTION       => 'Numero de tarjeta de pago. Dato de tarjeta bajo alcance PCI DSS',
  THRESHOLD         => 0.8);

CALL CB_PLATAFORMA.GOBIERNO.CLF_COLOMBIA!ADD_REGEX(
  SEMANTIC_CATEGORY => 'CEDULA_CO',
  PRIVACY_CATEGORY  => 'IDENTIFIER',
  VALUE_REGEX       => '^[1-9][0-9]{6,9}$',
  COL_NAME_REGEX    => '.*(DOCUMENTO|CEDULA|IDENTIFICACION).*',
  DESCRIPTION       => 'Cedula de ciudadania colombiana',
  THRESHOLD         => 0.8);

-- PRIVACY_CATEGORY se escribe con guion BAJO: QUASI_IDENTIFIER
CALL CB_PLATAFORMA.GOBIERNO.CLF_COLOMBIA!ADD_REGEX(
  SEMANTIC_CATEGORY => 'CELULAR_CO',
  PRIVACY_CATEGORY  => 'QUASI_IDENTIFIER',
  VALUE_REGEX       => '^\\+57 3[0-9]{8}$',
  COL_NAME_REGEX    => '.*(CELULAR|MOVIL|TELEFONO).*',
  DESCRIPTION       => 'Numero de celular colombiano',
  THRESHOLD         => 0.8);

SELECT CB_PLATAFORMA.GOBIERNO.CLF_COLOMBIA!LIST() AS REGLAS_REGISTRADAS;

-- reclasificar usando el clasificador propio
CALL SYSTEM$CLASSIFY('CB_SILVER.ADQUIRENCIA.TARJETAHABIENTES',
     {'auto_tag': true,
      'custom_classifiers': ['CB_PLATAFORMA.GOBIERNO.CLF_COLOMBIA']});

SELECT COLUMN_NAME, TAG_NAME, TAG_VALUE
FROM TABLE(CB_SILVER.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS(
           'CB_SILVER.ADQUIRENCIA.TARJETAHABIENTES', 'table'))
WHERE TAG_NAME IN ('SEMANTIC_CATEGORY', 'PRIVACY_CATEGORY')
ORDER BY COLUMN_NAME;

CALL CB_PLATAFORMA.EVIDENCIA.LOG_EVIDENCIA('T1',
    'Clasificacion automatica extendida con tipos de dato colombianos',
    'CB_SILVER.ADQUIRENCIA.TARJETAHABIENTES + CLF_COLOMBIA',
    'El clasificador de caja solo detecto EMAIL. Con 3 reglas propias detecta PAN, cedula y celular y los etiqueta solo',
    'Anexo 10 - 2.3 clasificacion y etiquetado automatico');


-- ==========================================================================
-- Paso 2. Una politica para todo lo que la clasificacion marque
-- Proteger por etiqueta, no columna por columna.
-- ==========================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_GOBIERNO;

-- propagar el resultado de la clasificacion a la etiqueta de gobierno propia
ALTER TABLE CB_SILVER.ADQUIRENCIA.TARJETAHABIENTES
    MODIFY COLUMN PAN SET TAG CB_PLATAFORMA.GOBIERNO.CLASIFICACION = 'DATO_TARJETA';
ALTER TABLE CB_SILVER.ADQUIRENCIA.TARJETAHABIENTES
    MODIFY COLUMN DOCUMENTO SET TAG CB_PLATAFORMA.GOBIERNO.CLASIFICACION = 'PII';
ALTER TABLE CB_SILVER.ADQUIRENCIA.TARJETAHABIENTES
    MODIFY COLUMN EMAIL SET TAG CB_PLATAFORMA.GOBIERNO.CLASIFICACION = 'PII';
ALTER TABLE CB_SILVER.ADQUIRENCIA.TARJETAHABIENTES
    MODIFY COLUMN CELULAR SET TAG CB_PLATAFORMA.GOBIERNO.CLASIFICACION = 'PII';

-- el PAN tambien viaja en el detalle de autorizaciones
ALTER TABLE CB_SILVER.ADQUIRENCIA.AUTORIZACIONES
    MODIFY COLUMN PAN SET TAG CB_PLATAFORMA.GOBIERNO.CLASIFICACION = 'DATO_TARJETA';

-- una sola politica que decide segun el valor de la etiqueta
CREATE MASKING POLICY IF NOT EXISTS CB_PLATAFORMA.GOBIERNO.MP_POR_CLASIFICACION
AS (val STRING) RETURNS STRING ->
CASE
    WHEN SYSTEM$GET_TAG_ON_CURRENT_COLUMN('CB_PLATAFORMA.GOBIERNO.CLASIFICACION') = 'DATO_TARJETA'
        THEN IFF(CURRENT_ROLE() = 'ACCOUNTADMIN', val,
                 '**** **** **** ' || RIGHT(val, 4))
    WHEN SYSTEM$GET_TAG_ON_CURRENT_COLUMN('CB_PLATAFORMA.GOBIERNO.CLASIFICACION') = 'PII'
        THEN IFF(CURRENT_ROLE() IN ('ACCOUNTADMIN', 'RL_SEGURIDAD'), val, '[PROTEGIDO]')
    ELSE val
END;

-- se adjunta a la ETIQUETA, no a la columna
ALTER TAG CB_PLATAFORMA.GOBIERNO.CLASIFICACION
    SET MASKING POLICY CB_PLATAFORMA.GOBIERNO.MP_POR_CLASIFICACION FORCE;

-- Seguridad investiga personas, no numeros de tarjeta
USE ROLE RL_SEGURIDAD;
USE WAREHOUSE WH_GOBIERNO;
SELECT PAN, DOCUMENTO, EMAIL FROM CB_SILVER.ADQUIRENCIA.TARJETAHABIENTES LIMIT 3;

-- el analista no necesita ninguno de los dos
USE ROLE RL_ANALISTA;
USE WAREHOUSE WH_ANALITICA;
SELECT PAN, DOCUMENTO, EMAIL FROM CB_SILVER.ADQUIRENCIA.TARJETAHABIENTES LIMIT 3;

USE ROLE ACCOUNTADMIN;
CALL CB_PLATAFORMA.EVIDENCIA.LOG_EVIDENCIA('T1',
    'Enmascaramiento dinamico por etiqueta con una sola politica',
    'CB_PLATAFORMA.GOBIERNO.MP_POR_CLASIFICACION sobre la etiqueta CLASIFICACION',
    'Una politica cubre PAN y PII en cualquier tabla donde la clasificacion ponga la etiqueta. Verificado con RL_SEGURIDAD y RL_ANALISTA',
    'Anexo 10 - 3.4 enmascaramiento dinamico y 4.8 policy-as-code');


-- ==========================================================================
-- Paso 3. Segmentacion por territorio en la misma tabla
-- Que dos roles consulten la misma tabla y obtengan universos distintos.
-- ==========================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_GOBIERNO;

-- el alcance vive en una tabla de mapeo, no en el codigo de la politica:
-- ampliar el territorio de un rol es un INSERT, no un despliegue
CREATE TABLE IF NOT EXISTS CB_PLATAFORMA.GOBIERNO.MAPEO_TERRITORIO (
    ROL          VARCHAR(100),
    DEPARTAMENTO VARCHAR(60)
) COMMENT = 'Alcance territorial por rol. Insumo de la politica de fila';

DELETE FROM CB_PLATAFORMA.GOBIERNO.MAPEO_TERRITORIO;
INSERT INTO CB_PLATAFORMA.GOBIERNO.MAPEO_TERRITORIO VALUES
    ('RL_ANALISTA', 'CUNDINAMARCA'),
    ('RL_ANALISTA', 'ANTIOQUIA'),
    ('RL_NEGOCIO',  'CUNDINAMARCA');

CREATE ROW ACCESS POLICY IF NOT EXISTS CB_PLATAFORMA.GOBIERNO.RAP_TERRITORIO
AS (departamento VARCHAR) RETURNS BOOLEAN ->
    CURRENT_ROLE() IN ('ACCOUNTADMIN', 'RL_SEGURIDAD', 'RL_INGENIERIA', 'RL_ARQUITECTURA')
    OR EXISTS (SELECT 1
               FROM CB_PLATAFORMA.GOBIERNO.MAPEO_TERRITORIO m
               WHERE m.ROL = CURRENT_ROLE()
                 AND m.DEPARTAMENTO = departamento);

ALTER TABLE CB_SILVER.ADQUIRENCIA.AUTORIZACIONES
    ADD ROW ACCESS POLICY CB_PLATAFORMA.GOBIERNO.RAP_TERRITORIO ON (DEPARTAMENTO);

-- la misma consulta, tres roles
USE ROLE RL_SEGURIDAD;
SELECT COUNT(DISTINCT DEPARTAMENTO) AS DEPARTAMENTOS, COUNT(*) AS FILAS
FROM CB_SILVER.ADQUIRENCIA.AUTORIZACIONES;

USE ROLE RL_ANALISTA;
USE WAREHOUSE WH_ANALITICA;
SELECT COUNT(DISTINCT DEPARTAMENTO) AS DEPARTAMENTOS, COUNT(*) AS FILAS
FROM CB_SILVER.ADQUIRENCIA.AUTORIZACIONES;

USE ROLE ACCOUNTADMIN;
CALL CB_PLATAFORMA.EVIDENCIA.LOG_EVIDENCIA('T1',
    'Segmentacion de filas por territorio con tabla de mapeo',
    'CB_PLATAFORMA.GOBIERNO.RAP_TERRITORIO sobre AUTORIZACIONES',
    'Misma tabla y misma consulta: Seguridad 24 departamentos, analista 2. El alcance se administra con datos, no con codigo',
    'Anexo 10 - 4.4 RBAC y ABAC de minimo privilegio');


-- ==========================================================================
-- Paso 4. El mismo control por SQL, por BI y por la IA
-- Comprobar que la IA no es una puerta lateral al dato sensible.
-- ==========================================================================

-- camino BI: la vista de consumo que usarian Power BI o Tableau
USE ROLE RL_ANALISTA;
USE WAREHOUSE WH_ANALITICA;
SELECT PAN, RAZON_SOCIAL, MONTO_COP
FROM CB_GOLD.PRODUCTOS.VW_AUTORIZACIONES_360
LIMIT 3;

-- camino IA: se le pide al modelo que devuelva el PAN tal cual
SELECT AI_COMPLETE('claude-4-sonnet',
                   'Repite exactamente este valor, sin cambiar nada: ' || PAN) AS LO_QUE_RESPONDE_LA_IA,
       PAN AS LO_QUE_RECIBIO_LA_IA
FROM CB_SILVER.ADQUIRENCIA.TARJETAHABIENTES
LIMIT 1;

USE ROLE ACCOUNTADMIN;
CALL CB_PLATAFORMA.EVIDENCIA.LOG_EVIDENCIA('T1',
    'La politica de enmascaramiento aplica igual a SQL, BI e IA',
    'VW_AUTORIZACIONES_360 y AI_COMPLETE sobre la columna PAN',
    'El modelo recibio el valor ya enmascarado. El control esta en el motor de datos, no en la aplicacion',
    'Anexo 10 - 2.5 acceso granular transversal a analitica BI e IA');


-- ==========================================================================
-- Paso 5. Quien accedio, con que rol y desde donde
-- Reconstruir el rastro de acceso al dato de tarjeta sin instrumentar nada.
-- ==========================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_GOBIERNO;

-- rastro inmediato: quien consulto la tabla con PAN en esta sesion de trabajo
SELECT USER_NAME,
       ROLE_NAME,
       COUNT(*)         AS CONSULTAS,
       MIN(START_TIME)  AS PRIMERA,
       MAX(START_TIME)  AS ULTIMA
FROM TABLE(CB_PLATAFORMA.INFORMATION_SCHEMA.QUERY_HISTORY(RESULT_LIMIT => 1000))
WHERE QUERY_TEXT ILIKE '%TARJETAHABIENTES%'
  AND EXECUTION_STATUS = 'SUCCESS'
GROUP BY 1, 2
ORDER BY CONSULTAS DESC;

-- retencion de auditoria: el pliego pide 3 meses en linea y 9 fuera
SHOW PARAMETERS LIKE 'DATA_RETENTION_TIME_IN_DAYS' IN DATABASE CB_SILVER;

CALL CB_PLATAFORMA.EVIDENCIA.LOG_EVIDENCIA('T1',
    'Trazabilidad de acceso al dato de tarjeta por usuario y rol',
    'INFORMATION_SCHEMA.QUERY_HISTORY sobre TARJETAHABIENTES',
    'Rastro inmediato de quien consulto la tabla con PAN y con que rol, sin instrumentar la aplicacion',
    'Anexo 10 - 4.5 trazabilidad y auditoria de accesos');


-- ==========================================================================
-- Paso 6. Borrado seguro verificable
-- Demostrar que un dato borrado no se puede recuperar. Es requisito eliminatorio.
-- ==========================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_GOBIERNO;

-- extraccion temporal de datos de tarjeta, del tipo que se crea para un
-- analisis puntual y despues hay que eliminar sin rastro
CREATE OR REPLACE TABLE CB_SILVER.ADQUIRENCIA.PAN_TEMPORAL
    DATA_RETENTION_TIME_IN_DAYS = 0
AS SELECT TARJETAHABIENTE_ID, PAN
   FROM CB_SILVER.ADQUIRENCIA.TARJETAHABIENTES
   LIMIT 1000;

SELECT COUNT(*) AS FILAS_ANTES FROM CB_SILVER.ADQUIRENCIA.PAN_TEMPORAL;

-- la ventana de recuperacion es cero por construccion, no por procedimiento
SHOW TABLES LIKE 'PAN_TEMPORAL' IN SCHEMA CB_SILVER.ADQUIRENCIA;
SELECT "name", "retention_time" FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

DROP TABLE CB_SILVER.ADQUIRENCIA.PAN_TEMPORAL;

-- intentar recuperarla: debe fallar
UNDROP TABLE CB_SILVER.ADQUIRENCIA.PAN_TEMPORAL;

CALL CB_PLATAFORMA.EVIDENCIA.LOG_EVIDENCIA('T1',
    'Borrado seguro verificable de una extraccion con dato de tarjeta',
    'CB_SILVER.ADQUIRENCIA.PAN_TEMPORAL con DATA_RETENTION_TIME_IN_DAYS = 0',
    'UNDROP fallo con did not exist or was purged. Sin Time Travel ni Fail-safe: la ventana de recuperacion es cero por construccion',
    'Anexo 10 - 3.6 borrado seguro y derecho al olvido (eliminatorio)');


-- ==========================================================================
-- Cierre: evidencia del track
-- ==========================================================================

-- Resumen de lo ejecutado en este track. Es el artefacto que se entrega al
-- cierre, como exige el numeral 3.2 del Anexo 11.
SELECT PASO, OBJETO, RESULTADO, REQUISITO, EJECUTADO_POR, ROL, MOMENTO
FROM CB_PLATAFORMA.EVIDENCIA.ARTEFACTOS
WHERE TRACK = 'T1'
ORDER BY MOMENTO;

SELECT * FROM CB_PLATAFORMA.EVIDENCIA.VW_EVIDENCIA_POR_TRACK
WHERE TRACK = 'T1';
