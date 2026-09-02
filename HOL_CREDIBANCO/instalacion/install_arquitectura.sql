/* ============================================================================
   HOL CredibanCo - RFP 10010806
   install_arquitectura.sql

   Cuenta      : ARQUITECTURA
   Equipo       : Arquitectura
   Tracks       : Track 3 - Data Fabric. Track 5 - Monetizacion. Track 8 - Migracion

   Que instala : el cimiento comun mas las capas que estos tracks necesitan
                  ya construidas.
   Que NO       : las tablas Iceberg ni los productos de datos publicados: los crea el
                  equipo durante el track. El external volume si queda listo, porque
                  depende de permisos de nube que no se resuelven en 30 minutos

   Duracion esperada: menos de 10 minutos. Al final imprime un semaforo;
   si alguna linea dice REVISAR, el ambiente no quedo listo.
   ==========================================================================*/

/* ============================================================================
   HOL CredibanCo - RFP 10010806
   00_core.sql : cimiento comun a las cuatro cuentas del workshop

   Este script lo ejecuta CADA cuenta (Seguridad, Ingenieria, Arquitectura,
   Infraestructura) antes de su script de instalacion especifico. Crea las
   capas, los roles, los warehouses etiquetados para costeo y el esquema de
   evidencia que exige el Anexo 11 ("entregar la evidencia de lo ejecutado al
   cierre de cada track").

   Es idempotente: se puede volver a correr completo sin romper nada ni perder
   la evidencia ya registrada.
   ==========================================================================*/

USE ROLE ACCOUNTADMIN;

/* ----------------------------------------------------------------------------
   1. Bases de datos por capa
   El modelo medallion del Anexo 10 requisito 1.4, mas una base de plataforma
   que concentra gobierno, evidencia y telemetria.
   --------------------------------------------------------------------------*/
CREATE DATABASE IF NOT EXISTS CB_RAW
    COMMENT = 'Capa de aterrizaje: archivos crudos tal como llegan del origen';
CREATE DATABASE IF NOT EXISTS CB_SILVER
    COMMENT = 'Capa conformada: tipada, deduplicada y con calidad verificada';
CREATE DATABASE IF NOT EXISTS CB_GOLD
    COMMENT = 'Capa de productos de datos publicados a los dominios';
CREATE DATABASE IF NOT EXISTS CB_PLATAFORMA
    COMMENT = 'Gobierno, evidencia del workshop y telemetria de la plataforma';

CREATE SCHEMA IF NOT EXISTS CB_RAW.LANDING;
CREATE SCHEMA IF NOT EXISTS CB_SILVER.ADQUIRENCIA;
CREATE SCHEMA IF NOT EXISTS CB_GOLD.PRODUCTOS;
CREATE SCHEMA IF NOT EXISTS CB_PLATAFORMA.GOBIERNO;
CREATE SCHEMA IF NOT EXISTS CB_PLATAFORMA.EVIDENCIA;
CREATE SCHEMA IF NOT EXISTS CB_PLATAFORMA.TELEMETRIA;

/* ----------------------------------------------------------------------------
   2. Etiquetas
   CLASIFICACION y CONFIDENCIALIDAD sostienen el enmascaramiento por etiqueta
   del Track 1. DOMINIO, PROYECTO y CASO_USO sostienen la atribucion de costos
   del Track 7: sin etiquetas no hay chargeback por dominio.
   --------------------------------------------------------------------------*/
USE SCHEMA CB_PLATAFORMA.GOBIERNO;

CREATE TAG IF NOT EXISTS CB_PLATAFORMA.GOBIERNO.CLASIFICACION
    ALLOWED_VALUES 'DATO_TARJETA', 'PII', 'FINANCIERO', 'PUBLICO', 'INTERNO'
    COMMENT = 'Naturaleza del dato. La aplica SYSTEM$CLASSIFY o el steward';

CREATE TAG IF NOT EXISTS CB_PLATAFORMA.GOBIERNO.CONFIDENCIALIDAD
    ALLOWED_VALUES 'RESTRINGIDO', 'CONFIDENCIAL', 'USO_INTERNO', 'PUBLICO'
    COMMENT = 'Nivel de manejo segun la politica de seguridad de la informacion';

CREATE TAG IF NOT EXISTS CB_PLATAFORMA.GOBIERNO.DOMINIO
    ALLOWED_VALUES 'ADQUIRENCIA', 'RIESGO', 'CLIENTE', 'MONETIZACION',
                   'PLATAFORMA', 'CIENCIA_DATOS'
    COMMENT = 'Dominio de negocio dueno del objeto o del consumo';

CREATE TAG IF NOT EXISTS CB_PLATAFORMA.GOBIERNO.PROYECTO
    COMMENT = 'Proyecto o iniciativa a la que se imputa el consumo';

CREATE TAG IF NOT EXISTS CB_PLATAFORMA.GOBIERNO.CASO_USO
    COMMENT = 'Caso de uso del catalogo de analitica';

CREATE TAG IF NOT EXISTS CB_PLATAFORMA.GOBIERNO.PCI_CDE
    ALLOWED_VALUES 'DENTRO', 'FUERA'
    COMMENT = 'Marca si el objeto pertenece al entorno de datos de tarjeta';

/* ----------------------------------------------------------------------------
   3. Warehouses
   Uno por patron de carga, no uno por equipo: el aislamiento de workloads es
   el requisito 12.7 del Anexo 10 y se demuestra en el Track 7.
   --------------------------------------------------------------------------*/
CREATE WAREHOUSE IF NOT EXISTS WH_ETL_BATCH
    WAREHOUSE_SIZE = 'MEDIUM' AUTO_SUSPEND = 60 AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Ventana batch nocturna: carga y conformacion';

CREATE WAREHOUSE IF NOT EXISTS WH_ANALITICA
    WAREHOUSE_SIZE = 'SMALL' AUTO_SUSPEND = 60 AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Consumo analitico y BI en horario laboral';

CREATE WAREHOUSE IF NOT EXISTS WH_GOBIERNO
    WAREHOUSE_SIZE = 'XSMALL' AUTO_SUSPEND = 60 AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Clasificacion, politicas y auditoria';

CREATE WAREHOUSE IF NOT EXISTS WH_ML
    WAREHOUSE_SIZE = 'MEDIUM' AUTO_SUSPEND = 60 AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Entrenamiento, inferencia y funciones de IA';

CREATE WAREHOUSE IF NOT EXISTS WH_NEGOCIO
    WAREHOUSE_SIZE = 'XSMALL' AUTO_SUSPEND = 60 AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Autoservicio y consulta en lenguaje natural';

CREATE WAREHOUSE IF NOT EXISTS WH_SANDBOX
    WAREHOUSE_SIZE = 'XSMALL' AUTO_SUSPEND = 60 AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Sandbox aprovisionado por autoservicio';

ALTER WAREHOUSE WH_ETL_BATCH SET TAG CB_PLATAFORMA.GOBIERNO.DOMINIO = 'ADQUIRENCIA',
    CB_PLATAFORMA.GOBIERNO.PROYECTO = 'MIGRACION_CLOUDERA',
    CB_PLATAFORMA.GOBIERNO.CASO_USO = 'INGESTA_AUTORIZACIONES';
ALTER WAREHOUSE WH_ANALITICA SET TAG CB_PLATAFORMA.GOBIERNO.DOMINIO = 'ADQUIRENCIA',
    CB_PLATAFORMA.GOBIERNO.PROYECTO = 'DAINSIGHT',
    CB_PLATAFORMA.GOBIERNO.CASO_USO = 'ANALITICA_COMERCIOS';
ALTER WAREHOUSE WH_GOBIERNO SET TAG CB_PLATAFORMA.GOBIERNO.DOMINIO = 'PLATAFORMA',
    CB_PLATAFORMA.GOBIERNO.PROYECTO = 'GOBIERNO_ZERO_TRUST',
    CB_PLATAFORMA.GOBIERNO.CASO_USO = 'CLASIFICACION_Y_POLITICAS';
ALTER WAREHOUSE WH_ML SET TAG CB_PLATAFORMA.GOBIERNO.DOMINIO = 'CIENCIA_DATOS',
    CB_PLATAFORMA.GOBIERNO.PROYECTO = 'CHURN_COMERCIOS',
    CB_PLATAFORMA.GOBIERNO.CASO_USO = 'CHURN_PYME';
ALTER WAREHOUSE WH_NEGOCIO SET TAG CB_PLATAFORMA.GOBIERNO.DOMINIO = 'CLIENTE',
    CB_PLATAFORMA.GOBIERNO.PROYECTO = 'AUTOSERVICIO',
    CB_PLATAFORMA.GOBIERNO.CASO_USO = 'CONSULTA_LENGUAJE_NATURAL';
ALTER WAREHOUSE WH_SANDBOX SET TAG CB_PLATAFORMA.GOBIERNO.DOMINIO = 'CIENCIA_DATOS',
    CB_PLATAFORMA.GOBIERNO.PROYECTO = 'SANDBOX_AUTOSERVICIO',
    CB_PLATAFORMA.GOBIERNO.CASO_USO = 'EXPLORACION';

/* ----------------------------------------------------------------------------
   4. Roles por equipo
   Minimo privilegio: cada rol ve lo suyo. El Track 1 comprueba que las mismas
   politicas apliquen a SQL, BI e IA con estos mismos roles.
   --------------------------------------------------------------------------*/
CREATE ROLE IF NOT EXISTS RL_SEGURIDAD    COMMENT = 'Seguridad de la Informacion';
CREATE ROLE IF NOT EXISTS RL_INGENIERIA   COMMENT = 'Ingenieria de datos';
CREATE ROLE IF NOT EXISTS RL_ARQUITECTURA COMMENT = 'Arquitectura de datos';
CREATE ROLE IF NOT EXISTS RL_INFRA        COMMENT = 'Infraestructura y operacion';
CREATE ROLE IF NOT EXISTS RL_ANALISTA     COMMENT = 'Analista de datos';
CREATE ROLE IF NOT EXISTS RL_NEGOCIO      COMMENT = 'Usuario de negocio sin SQL';
CREATE ROLE IF NOT EXISTS RL_AUDITOR      COMMENT = 'Lectura de auditoria, sin acceso al dato';

GRANT ROLE RL_SEGURIDAD, RL_INGENIERIA, RL_ARQUITECTURA, RL_INFRA,
           RL_ANALISTA, RL_NEGOCIO, RL_AUDITOR TO ROLE SYSADMIN;

/* Uso de computo. WH_SANDBOX no se concede aqui: lo entrega el flujo de
   aprovisionamiento automatico del Track 6. */
GRANT USAGE ON WAREHOUSE WH_ETL_BATCH TO ROLE RL_INGENIERIA;
GRANT USAGE ON WAREHOUSE WH_ANALITICA TO ROLE RL_ANALISTA;
GRANT USAGE ON WAREHOUSE WH_ANALITICA TO ROLE RL_ARQUITECTURA;
GRANT USAGE ON WAREHOUSE WH_GOBIERNO  TO ROLE RL_SEGURIDAD;
GRANT USAGE ON WAREHOUSE WH_GOBIERNO  TO ROLE RL_AUDITOR;
GRANT USAGE ON WAREHOUSE WH_ML        TO ROLE RL_INGENIERIA;
GRANT USAGE ON WAREHOUSE WH_NEGOCIO   TO ROLE RL_NEGOCIO;

/* Lectura de las capas. RL_AUDITOR queda deliberadamente sin SELECT: solo
   audita metadatos, que es lo que pide la segregacion del requisito 3.5. */
GRANT USAGE ON DATABASE CB_SILVER TO ROLE RL_INGENIERIA;
GRANT USAGE ON DATABASE CB_SILVER TO ROLE RL_ANALISTA;
GRANT USAGE ON DATABASE CB_SILVER TO ROLE RL_ARQUITECTURA;
GRANT USAGE ON DATABASE CB_SILVER TO ROLE RL_SEGURIDAD;
GRANT USAGE ON DATABASE CB_GOLD   TO ROLE RL_ANALISTA;
GRANT USAGE ON DATABASE CB_GOLD   TO ROLE RL_ARQUITECTURA;
GRANT USAGE ON DATABASE CB_GOLD   TO ROLE RL_NEGOCIO;
GRANT USAGE ON DATABASE CB_GOLD   TO ROLE RL_SEGURIDAD;
GRANT USAGE ON DATABASE CB_RAW    TO ROLE RL_INGENIERIA;
GRANT USAGE ON DATABASE CB_PLATAFORMA TO ROLE RL_SEGURIDAD;
GRANT USAGE ON DATABASE CB_PLATAFORMA TO ROLE RL_INFRA;
GRANT USAGE ON DATABASE CB_PLATAFORMA TO ROLE RL_AUDITOR;

GRANT USAGE ON ALL SCHEMAS IN DATABASE CB_SILVER TO ROLE RL_INGENIERIA;
GRANT USAGE ON ALL SCHEMAS IN DATABASE CB_SILVER TO ROLE RL_ANALISTA;
GRANT USAGE ON ALL SCHEMAS IN DATABASE CB_SILVER TO ROLE RL_ARQUITECTURA;
GRANT USAGE ON ALL SCHEMAS IN DATABASE CB_SILVER TO ROLE RL_SEGURIDAD;
GRANT USAGE ON ALL SCHEMAS IN DATABASE CB_GOLD   TO ROLE RL_ANALISTA;
GRANT USAGE ON ALL SCHEMAS IN DATABASE CB_GOLD   TO ROLE RL_ARQUITECTURA;
GRANT USAGE ON ALL SCHEMAS IN DATABASE CB_GOLD   TO ROLE RL_NEGOCIO;
GRANT USAGE ON ALL SCHEMAS IN DATABASE CB_GOLD   TO ROLE RL_SEGURIDAD;
GRANT USAGE ON ALL SCHEMAS IN DATABASE CB_RAW    TO ROLE RL_INGENIERIA;
GRANT USAGE ON ALL SCHEMAS IN DATABASE CB_PLATAFORMA TO ROLE RL_SEGURIDAD;
GRANT USAGE ON ALL SCHEMAS IN DATABASE CB_PLATAFORMA TO ROLE RL_INFRA;
GRANT USAGE ON ALL SCHEMAS IN DATABASE CB_PLATAFORMA TO ROLE RL_AUDITOR;

GRANT SELECT ON FUTURE TABLES IN DATABASE CB_SILVER TO ROLE RL_INGENIERIA;
GRANT SELECT ON FUTURE TABLES IN DATABASE CB_SILVER TO ROLE RL_ANALISTA;
GRANT SELECT ON FUTURE TABLES IN DATABASE CB_SILVER TO ROLE RL_ARQUITECTURA;
GRANT SELECT ON FUTURE TABLES IN DATABASE CB_SILVER TO ROLE RL_SEGURIDAD;
GRANT SELECT ON FUTURE VIEWS  IN DATABASE CB_SILVER TO ROLE RL_ANALISTA;
GRANT SELECT ON FUTURE TABLES IN DATABASE CB_GOLD   TO ROLE RL_ANALISTA;
GRANT SELECT ON FUTURE TABLES IN DATABASE CB_GOLD   TO ROLE RL_ARQUITECTURA;
GRANT SELECT ON FUTURE TABLES IN DATABASE CB_GOLD   TO ROLE RL_NEGOCIO;
GRANT SELECT ON FUTURE TABLES IN DATABASE CB_GOLD   TO ROLE RL_SEGURIDAD;
GRANT SELECT ON FUTURE VIEWS  IN DATABASE CB_GOLD   TO ROLE RL_NEGOCIO;
GRANT SELECT ON FUTURE VIEWS  IN DATABASE CB_GOLD   TO ROLE RL_ANALISTA;

GRANT SELECT ON ALL TABLES IN DATABASE CB_SILVER TO ROLE RL_INGENIERIA;
GRANT SELECT ON ALL TABLES IN DATABASE CB_SILVER TO ROLE RL_ANALISTA;
GRANT SELECT ON ALL TABLES IN DATABASE CB_SILVER TO ROLE RL_ARQUITECTURA;
GRANT SELECT ON ALL TABLES IN DATABASE CB_SILVER TO ROLE RL_SEGURIDAD;
GRANT SELECT ON ALL TABLES IN DATABASE CB_GOLD   TO ROLE RL_ANALISTA;
GRANT SELECT ON ALL TABLES IN DATABASE CB_GOLD   TO ROLE RL_ARQUITECTURA;
GRANT SELECT ON ALL TABLES IN DATABASE CB_GOLD   TO ROLE RL_NEGOCIO;
GRANT SELECT ON ALL TABLES IN DATABASE CB_GOLD   TO ROLE RL_SEGURIDAD;

/* El equipo de ingenieria construye; los demas consumen. */
GRANT ALL PRIVILEGES ON SCHEMA CB_RAW.LANDING          TO ROLE RL_INGENIERIA;
GRANT ALL PRIVILEGES ON SCHEMA CB_SILVER.ADQUIRENCIA   TO ROLE RL_INGENIERIA;
GRANT ALL PRIVILEGES ON SCHEMA CB_GOLD.PRODUCTOS       TO ROLE RL_INGENIERIA;
GRANT ALL PRIVILEGES ON SCHEMA CB_GOLD.PRODUCTOS       TO ROLE RL_ARQUITECTURA;
GRANT ALL PRIVILEGES ON SCHEMA CB_PLATAFORMA.GOBIERNO  TO ROLE RL_SEGURIDAD;
GRANT ALL PRIVILEGES ON SCHEMA CB_PLATAFORMA.TELEMETRIA TO ROLE RL_INFRA;

/* Auditoria y observabilidad sin acceso al dato. */
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE RL_AUDITOR;
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE RL_SEGURIDAD;
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE RL_INFRA;

/* Aplicar politicas y clasificar es potestad de Seguridad, no de quien
   construye. Esto es lo que se verifica en el criterio 2 (Zero Trust). */
GRANT APPLY MASKING POLICY ON ACCOUNT TO ROLE RL_SEGURIDAD;
GRANT APPLY ROW ACCESS POLICY ON ACCOUNT TO ROLE RL_SEGURIDAD;
GRANT APPLY TAG ON ACCOUNT TO ROLE RL_SEGURIDAD;

/* ----------------------------------------------------------------------------
   5. Acceso a S3
   PRERREQUISITO: la storage integration debe existir y su rol de IAM debe
   confiar en el ARN y el external id que emite Snowflake. En las cuentas de
   CredibanCo se crea con el rol del cliente; el nombre se mantiene estable
   para que el resto de los scripts no cambie.

   CREATE STORAGE INTEGRATION SI_HOL_CB
       TYPE = EXTERNAL_STAGE STORAGE_PROVIDER = 'S3'
       STORAGE_AWS_ROLE_ARN = '<arn del rol>'
       STORAGE_ALLOWED_LOCATIONS = ('s3://demosjparrado/hol_credibanco/')
       ENABLED = TRUE;
   --------------------------------------------------------------------------*/
USE SCHEMA CB_RAW.LANDING;

CREATE FILE FORMAT IF NOT EXISTS CB_RAW.LANDING.FF_CSV_GZ
    TYPE = CSV FIELD_DELIMITER = ',' SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"' COMPRESSION = GZIP
    NULL_IF = ('', 'NULL', '\\N') EMPTY_FIELD_AS_NULL = TRUE
    COMMENT = 'Archivos del batch nocturno';

/* El escaner vectorizado NO es opcional. El escaner legado interpreta los
   timestamps del parquet como si fueran segundos: FECHA_HORA aterriza en el ano
   39268581 y el COPY reporta cero errores. Las columnas DATE no se afectan, asi
   que el defecto pasa inadvertido si solo se revisa la fecha. */
CREATE FILE FORMAT IF NOT EXISTS CB_RAW.LANDING.FF_PARQUET
    TYPE = PARQUET
    USE_VECTORIZED_SCANNER = TRUE
    COMMENT = 'Capas conformadas y productos de datos';

CREATE FILE FORMAT IF NOT EXISTS CB_RAW.LANDING.FF_JSON_GZ
    TYPE = JSON COMPRESSION = GZIP STRIP_OUTER_ARRAY = FALSE
    COMMENT = 'Eventos del topico de autorizaciones';

CREATE STAGE IF NOT EXISTS CB_RAW.LANDING.STG_HOL
    STORAGE_INTEGRATION = SI_HOL_CB
    URL = 's3://demosjparrado/hol_credibanco/'
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Origen unico de las capas del HOL';

-- Sin este refresh la directory table sale vacia y las vistas de documentos y
-- de muestra Cloudera no devuelven nada.
ALTER STAGE CB_RAW.LANDING.STG_HOL REFRESH;

GRANT USAGE ON STAGE CB_RAW.LANDING.STG_HOL TO ROLE RL_INGENIERIA;
GRANT USAGE ON STAGE CB_RAW.LANDING.STG_HOL TO ROLE RL_ARQUITECTURA;
GRANT READ ON STAGE CB_RAW.LANDING.STG_HOL TO ROLE RL_INGENIERIA;
GRANT USAGE ON FILE FORMAT CB_RAW.LANDING.FF_CSV_GZ TO ROLE RL_INGENIERIA;
GRANT USAGE ON FILE FORMAT CB_RAW.LANDING.FF_PARQUET TO ROLE RL_INGENIERIA;
GRANT USAGE ON FILE FORMAT CB_RAW.LANDING.FF_JSON_GZ TO ROLE RL_INGENIERIA;

/* ----------------------------------------------------------------------------
   6. Evidencia del workshop
   El Anexo 11 obliga a entregar configuraciones, capturas y artefactos al
   cierre de cada track. Cada paso de cada lab llama a LOG_EVIDENCIA, de modo
   que la evidencia se produce sola mientras el equipo trabaja.
   --------------------------------------------------------------------------*/
USE SCHEMA CB_PLATAFORMA.EVIDENCIA;

CREATE TABLE IF NOT EXISTS CB_PLATAFORMA.EVIDENCIA.ARTEFACTOS (
    EVIDENCIA_ID   NUMBER IDENTITY START 1 INCREMENT 1,
    TRACK          VARCHAR(40)  NOT NULL,
    PASO           VARCHAR(200) NOT NULL,
    OBJETO         VARCHAR(400),
    RESULTADO      VARCHAR(4000),
    REQUISITO      VARCHAR(200) COMMENT 'Requisito del Anexo 10 que acredita',
    EJECUTADO_POR  VARCHAR(200) DEFAULT CURRENT_USER(),
    ROL            VARCHAR(200) DEFAULT CURRENT_ROLE(),
    WAREHOUSE      VARCHAR(200) DEFAULT CURRENT_WAREHOUSE(),
    QUERY_ID       VARCHAR(100),
    MOMENTO        TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
) COMMENT = 'Bitacora de lo ejecutado en el workshop, por track y por paso';

CREATE OR REPLACE PROCEDURE CB_PLATAFORMA.EVIDENCIA.LOG_EVIDENCIA(
    P_TRACK VARCHAR, P_PASO VARCHAR, P_OBJETO VARCHAR,
    P_RESULTADO VARCHAR, P_REQUISITO VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'Registra un artefacto de evidencia junto con quien y con que rol lo produjo'
AS
$$
BEGIN
    INSERT INTO CB_PLATAFORMA.EVIDENCIA.ARTEFACTOS
        (TRACK, PASO, OBJETO, RESULTADO, REQUISITO, QUERY_ID)
    VALUES (:P_TRACK, :P_PASO, :P_OBJETO, :P_RESULTADO, :P_REQUISITO,
            LAST_QUERY_ID());
    RETURN 'Evidencia registrada: ' || :P_TRACK || ' / ' || :P_PASO;
END;
$$;

/* Vista de cierre: es lo que se exporta y se entrega al final de cada track. */
CREATE OR REPLACE VIEW CB_PLATAFORMA.EVIDENCIA.VW_EVIDENCIA_POR_TRACK AS
SELECT TRACK,
       COUNT(*)                              AS PASOS_EJECUTADOS,
       COUNT(DISTINCT REQUISITO)             AS REQUISITOS_ACREDITADOS,
       COUNT(DISTINCT EJECUTADO_POR)         AS PARTICIPANTES,
       MIN(MOMENTO)                          AS INICIO,
       MAX(MOMENTO)                          AS FIN,
       DATEDIFF('minute', MIN(MOMENTO), MAX(MOMENTO)) AS DURACION_MIN
FROM CB_PLATAFORMA.EVIDENCIA.ARTEFACTOS
GROUP BY TRACK
ORDER BY INICIO;

GRANT USAGE ON PROCEDURE CB_PLATAFORMA.EVIDENCIA.LOG_EVIDENCIA(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR)
    TO ROLE PUBLIC;
GRANT INSERT, SELECT ON TABLE CB_PLATAFORMA.EVIDENCIA.ARTEFACTOS TO ROLE PUBLIC;
GRANT SELECT ON VIEW CB_PLATAFORMA.EVIDENCIA.VW_EVIDENCIA_POR_TRACK TO ROLE PUBLIC;

/* ----------------------------------------------------------------------------
   7. Semaforo
   Se resuelve con SHOW y RESULT_SCAN, no con ACCOUNT_USAGE: esas vistas tienen
   latencia de hasta dos horas y darian FALTA sobre objetos recien creados.
   Si alguna linea sale en FALTA, el ambiente no quedo listo.
   --------------------------------------------------------------------------*/
SHOW WAREHOUSES LIKE 'WH\_%';
SELECT 'Warehouses' AS COMPONENTE, 6 AS ESPERADO, COUNT(*) AS ENCONTRADO,
       IFF(COUNT(*) >= 6, 'OK', 'FALTA') AS ESTADO
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
WHERE "name" IN ('WH_ETL_BATCH','WH_ANALITICA','WH_GOBIERNO','WH_ML',
                 'WH_NEGOCIO','WH_SANDBOX');

SHOW ROLES LIKE 'RL\_%';
SELECT 'Roles' AS COMPONENTE, 7 AS ESPERADO, COUNT(*) AS ENCONTRADO,
       IFF(COUNT(*) >= 7, 'OK', 'FALTA') AS ESTADO
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
WHERE "name" IN ('RL_SEGURIDAD','RL_INGENIERIA','RL_ARQUITECTURA','RL_INFRA',
                 'RL_ANALISTA','RL_NEGOCIO','RL_AUDITOR');

SHOW TAGS IN SCHEMA CB_PLATAFORMA.GOBIERNO;
SELECT 'Etiquetas de gobierno' AS COMPONENTE, 6 AS ESPERADO, COUNT(*) AS ENCONTRADO,
       IFF(COUNT(*) >= 6, 'OK', 'FALTA') AS ESTADO
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

SELECT 'Bases de datos' AS COMPONENTE, 4 AS ESPERADO, COUNT(*) AS ENCONTRADO,
       IFF(COUNT(*) >= 4, 'OK', 'FALTA') AS ESTADO
FROM CB_PLATAFORMA.INFORMATION_SCHEMA.DATABASES
WHERE DATABASE_NAME IN ('CB_RAW','CB_SILVER','CB_GOLD','CB_PLATAFORMA');

/* El stage se verifica aparte: si el rol de IAM no confia en la integracion,
   este LIST falla y hay que arreglarlo antes de seguir. */
LIST @CB_RAW.LANDING.STG_HOL/silver/ PATTERN = '.*comercios.*';

CALL CB_PLATAFORMA.EVIDENCIA.LOG_EVIDENCIA(
    'CORE', 'Cimiento de la plataforma desplegado',
    'CB_RAW / CB_SILVER / CB_GOLD / CB_PLATAFORMA',
    'Capas, etiquetas de gobierno y costo, roles por equipo, warehouses por patron de carga y bitacora de evidencia',
    'Anexo 10 - 5.1 lakehouse unificado');

/* == Modelo ============================================================ */

CREATE TABLE IF NOT EXISTS CB_SILVER.ADQUIRENCIA.COMERCIOS (
    COMERCIO_ID         NUMBER(12,0)  NOT NULL,
    NIT                 VARCHAR(20),
    RAZON_SOCIAL        VARCHAR(200),
    NOMBRE_COMERCIAL    VARCHAR(200),
    MCC                 VARCHAR(4),
    SECTOR              VARCHAR(80),
    CIUDAD              VARCHAR(60),
    DEPARTAMENTO        VARCHAR(60),
    SEGMENTO            VARCHAR(20),
    FECHA_VINCULACION   DATE,
    ESTADO              VARCHAR(20),
    EMAIL_CONTACTO      VARCHAR(200),
    TELEFONO_CONTACTO   VARCHAR(40),
    TASA_DESCUENTO_PCT  NUMBER(5,2),
    CONSTRAINT PK_COMERCIOS PRIMARY KEY (COMERCIO_ID)
) COMMENT = 'Maestro de comercios afiliados';

CREATE TABLE IF NOT EXISTS CB_SILVER.ADQUIRENCIA.TERMINALES (
    TERMINAL_ID     VARCHAR(20)  NOT NULL,
    COMERCIO_ID     NUMBER(12,0) NOT NULL,
    TIPO_TERMINAL   VARCHAR(30),
    CIUDAD          VARCHAR(60),
    SERIAL          VARCHAR(40),
    VERSION_SW      VARCHAR(20),
    ESTADO          VARCHAR(30),
    CONSTRAINT PK_TERMINALES PRIMARY KEY (TERMINAL_ID),
    CONSTRAINT FK_TERM_COM FOREIGN KEY (COMERCIO_ID)
        REFERENCES CB_SILVER.ADQUIRENCIA.COMERCIOS (COMERCIO_ID)
) COMMENT = 'Parque de terminales por comercio';

CREATE TABLE IF NOT EXISTS CB_SILVER.ADQUIRENCIA.TARJETAHABIENTES (
    TARJETAHABIENTE_ID  NUMBER(12,0) NOT NULL,
    PAN                 VARCHAR(19),
    NOMBRE_COMPLETO     VARCHAR(200),
    DOCUMENTO           VARCHAR(20),
    TIPO_DOCUMENTO      VARCHAR(4),
    EMAIL               VARCHAR(200),
    CELULAR             VARCHAR(40),
    FRANQUICIA          VARCHAR(30),
    BANCO_EMISOR        VARCHAR(60),
    EDAD                NUMBER(3,0),
    CIUDAD_RESIDENCIA   VARCHAR(60),
    SEGMENTO_CLIENTE    VARCHAR(20),
    CONSTRAINT PK_TARJETAHABIENTES PRIMARY KEY (TARJETAHABIENTE_ID)
) COMMENT = 'Tarjetahabientes. Contiene PAN y datos personales sinteticos: es el objeto que la clasificacion automatica debe detectar';

CREATE TABLE IF NOT EXISTS CB_SILVER.ADQUIRENCIA.AUTORIZACIONES (
    AUTORIZACION_ID        VARCHAR(30)   NOT NULL,
    FECHA_HORA             TIMESTAMP_NTZ,
    FECHA                  DATE,
    TERMINAL_ID            VARCHAR(20),
    COMERCIO_ID            NUMBER(12,0),
    MCC                    VARCHAR(4),
    SECTOR                 VARCHAR(80),
    CIUDAD_COMERCIO        VARCHAR(60),
    DEPARTAMENTO           VARCHAR(60),
    SEGMENTO_COMERCIO      VARCHAR(20),
    TARJETAHABIENTE_ID     NUMBER(12,0),
    PAN                    VARCHAR(19),
    FRANQUICIA             VARCHAR(30),
    MODO_ENTRADA           VARCHAR(20),
    MONTO_COP              NUMBER(18,2),
    CODIGO_RESPUESTA       VARCHAR(4),
    DESCRIPCION_RESPUESTA  VARCHAR(80),
    APROBADA               BOOLEAN,
    ES_INTERNACIONAL       BOOLEAN,
    MARCA_FRAUDE           BOOLEAN,
    NUMERO_CUOTAS          NUMBER(3,0)
) COMMENT = 'Autorizaciones conformadas. Equivale a autorizaciones_master_rt de la linea base Cloudera';

CREATE TABLE IF NOT EXISTS CB_GOLD.PRODUCTOS.COMERCIO_FEATURES_CHURN (
    COMERCIO_ID            NUMBER(12,0) NOT NULL,
    TRX_APROBADAS_TOTAL    NUMBER(18,0),
    MONTO_APROBADO_TOTAL   NUMBER(24,2),
    TICKET_PROMEDIO        NUMBER(18,2),
    TRX_TOTAL              NUMBER(18,0),
    TASA_APROBACION        NUMBER(6,4),
    TRX_FRAUDE             NUMBER(12,0),
    TASA_FRAUDE            NUMBER(9,6),
    MESES_ACTIVO           NUMBER(4,0),
    MONTO_ULT_3M           NUMBER(24,2),
    TENDENCIA_3M           NUMBER(10,4),
    CHURN                  NUMBER(1,0),
    SECTOR                 VARCHAR(80),
    CIUDAD                 VARCHAR(60),
    DEPARTAMENTO           VARCHAR(60),
    SEGMENTO               VARCHAR(20),
    FECHA_VINCULACION      DATE,
    TASA_DESCUENTO_PCT     NUMBER(5,2),
    CONSTRAINT PK_FEAT_CHURN PRIMARY KEY (COMERCIO_ID)
) COMMENT = 'Producto de datos: features de abandono de comercio. CHURN es la etiqueta';

CREATE TABLE IF NOT EXISTS CB_GOLD.PRODUCTOS.CUSTOMER_360 (
    TARJETAHABIENTE_ID  NUMBER(12,0) NOT NULL,
    TRX_APROBADAS       NUMBER(18,0),
    MONTO_TOTAL         NUMBER(24,2),
    TICKET_PROMEDIO     NUMBER(18,2),
    FRANQUICIA          VARCHAR(30),
    BANCO_EMISOR        VARCHAR(60),
    EDAD                NUMBER(3,0),
    CIUDAD_RESIDENCIA   VARCHAR(60),
    SEGMENTO_CLIENTE    VARCHAR(20),
    CONSTRAINT PK_C360 PRIMARY KEY (TARJETAHABIENTE_ID)
) COMMENT = 'Producto de datos: vision unica del tarjetahabiente';

/* == Carga de las capas aguas arriba =================================== */

-- 180.000 comercios afiliados
COPY INTO CB_SILVER.ADQUIRENCIA.COMERCIOS
FROM @CB_RAW.LANDING.STG_HOL/silver/comercios.parquet
FILE_FORMAT = (FORMAT_NAME = 'CB_RAW.LANDING.FF_PARQUET')
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
ON_ERROR = ABORT_STATEMENT;

-- 607.119 terminales
COPY INTO CB_SILVER.ADQUIRENCIA.TERMINALES
FROM @CB_RAW.LANDING.STG_HOL/silver/terminales.parquet
FILE_FORMAT = (FORMAT_NAME = 'CB_RAW.LANDING.FF_PARQUET')
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
ON_ERROR = ABORT_STATEMENT;

-- 2.500.000 tarjetahabientes con PAN y datos personales sinteticos
COPY INTO CB_SILVER.ADQUIRENCIA.TARJETAHABIENTES
FROM @CB_RAW.LANDING.STG_HOL/silver/tarjetahabientes.parquet
FILE_FORMAT = (FORMAT_NAME = 'CB_RAW.LANDING.FF_PARQUET')
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
ON_ERROR = ABORT_STATEMENT;

-- 40,4 millones de autorizaciones: 24 meses completos
COPY INTO CB_SILVER.ADQUIRENCIA.AUTORIZACIONES
FROM @CB_RAW.LANDING.STG_HOL/silver/
PATTERN = '.*autorizaciones_[0-9]{6}[.]parquet'
FILE_FORMAT = (FORMAT_NAME = 'CB_RAW.LANDING.FF_PARQUET')
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
ON_ERROR = ABORT_STATEMENT;

-- El particionado por mes se aprovecha con clustering por fecha, que es lo que
-- hace visible el pruning en el track de administracion.
ALTER TABLE CB_SILVER.ADQUIRENCIA.AUTORIZACIONES CLUSTER BY (FECHA);

-- Features de churn ya calculadas por el equipo de ingenieria
COPY INTO CB_GOLD.PRODUCTOS.COMERCIO_FEATURES_CHURN
FROM @CB_RAW.LANDING.STG_HOL/gold/comercio_features_churn.parquet
FILE_FORMAT = (FORMAT_NAME = 'CB_RAW.LANDING.FF_PARQUET')
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
ON_ERROR = ABORT_STATEMENT;

-- Vision unica del tarjetahabiente
COPY INTO CB_GOLD.PRODUCTOS.CUSTOMER_360
FROM @CB_RAW.LANDING.STG_HOL/gold/customer_360.parquet
FILE_FORMAT = (FORMAT_NAME = 'CB_RAW.LANDING.FF_PARQUET')
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
ON_ERROR = ABORT_STATEMENT;

/* == Objetos de consumo =============================================== */

-- Vista de consumo: es la que usan BI, el agente de IA y el usuario de negocio.
-- Que las tres cosas lean por aqui es lo que permite demostrar, en el track de
-- gobierno, que una sola politica aplica a los tres caminos.
CREATE OR REPLACE VIEW CB_GOLD.PRODUCTOS.VW_AUTORIZACIONES_360 AS
SELECT a.AUTORIZACION_ID,
       a.FECHA,
       a.FECHA_HORA,
       a.MONTO_COP,
       a.APROBADA,
       a.MARCA_FRAUDE,
       a.ES_INTERNACIONAL,
       a.MODO_ENTRADA,
       a.FRANQUICIA,
       a.CODIGO_RESPUESTA,
       a.DESCRIPCION_RESPUESTA,
       a.NUMERO_CUOTAS,
       a.PAN,
       c.COMERCIO_ID,
       c.RAZON_SOCIAL,
       c.NOMBRE_COMERCIAL,
       c.MCC,
       c.SECTOR,
       c.CIUDAD           AS CIUDAD_COMERCIO,
       c.DEPARTAMENTO,
       c.SEGMENTO         AS SEGMENTO_COMERCIO,
       c.TASA_DESCUENTO_PCT,
       t.TIPO_TERMINAL,
       h.TARJETAHABIENTE_ID,
       h.SEGMENTO_CLIENTE,
       h.BANCO_EMISOR,
       h.CIUDAD_RESIDENCIA
FROM CB_SILVER.ADQUIRENCIA.AUTORIZACIONES a
JOIN CB_SILVER.ADQUIRENCIA.COMERCIOS       c ON c.COMERCIO_ID = a.COMERCIO_ID
LEFT JOIN CB_SILVER.ADQUIRENCIA.TERMINALES t ON t.TERMINAL_ID = a.TERMINAL_ID
LEFT JOIN CB_SILVER.ADQUIRENCIA.TARJETAHABIENTES h
       ON h.TARJETAHABIENTE_ID = a.TARJETAHABIENTE_ID;

GRANT SELECT ON VIEW CB_GOLD.PRODUCTOS.VW_AUTORIZACIONES_360 TO ROLE RL_ANALISTA;
GRANT SELECT ON VIEW CB_GOLD.PRODUCTOS.VW_AUTORIZACIONES_360 TO ROLE RL_NEGOCIO;
GRANT SELECT ON VIEW CB_GOLD.PRODUCTOS.VW_AUTORIZACIONES_360 TO ROLE RL_SEGURIDAD;
GRANT SELECT ON VIEW CB_GOLD.PRODUCTOS.VW_AUTORIZACIONES_360 TO ROLE RL_ARQUITECTURA;

-- Agregado que consumen el autoservicio, el semantic view y el share a terceros.
CREATE OR REPLACE TABLE CB_GOLD.PRODUCTOS.VENTAS_MENSUALES_COMERCIO AS
SELECT c.COMERCIO_ID,
       c.RAZON_SOCIAL,
       c.SECTOR,
       c.MCC,
       c.CIUDAD                              AS CIUDAD_COMERCIO,
       c.DEPARTAMENTO,
       c.SEGMENTO                            AS SEGMENTO_COMERCIO,
       DATE_TRUNC('month', a.FECHA)           AS MES,
       COUNT(*)                               AS TRX_TOTAL,
       COUNT_IF(a.APROBADA)                   AS TRX_APROBADAS,
       SUM(IFF(a.APROBADA, a.MONTO_COP, 0))   AS MONTO_APROBADO_COP,
       AVG(IFF(a.APROBADA, a.MONTO_COP, NULL)) AS TICKET_PROMEDIO_COP,
       COUNT_IF(a.MARCA_FRAUDE)               AS TRX_FRAUDE,
       COUNT_IF(a.ES_INTERNACIONAL)           AS TRX_INTERNACIONALES,
       COUNT(DISTINCT a.TARJETAHABIENTE_ID)   AS CLIENTES_UNICOS
FROM CB_SILVER.ADQUIRENCIA.AUTORIZACIONES a
JOIN CB_SILVER.ADQUIRENCIA.COMERCIOS c ON c.COMERCIO_ID = a.COMERCIO_ID
GROUP BY ALL;

ALTER TABLE CB_GOLD.PRODUCTOS.VENTAS_MENSUALES_COMERCIO
    SET TAG CB_PLATAFORMA.GOBIERNO.DOMINIO = 'ADQUIRENCIA',
            CB_PLATAFORMA.GOBIERNO.CLASIFICACION = 'FINANCIERO',
            CB_PLATAFORMA.GOBIERNO.CONFIDENCIALIDAD = 'USO_INTERNO',
            CB_PLATAFORMA.GOBIERNO.PCI_CDE = 'FUERA';

GRANT SELECT ON TABLE CB_GOLD.PRODUCTOS.VENTAS_MENSUALES_COMERCIO TO ROLE RL_ANALISTA;
GRANT SELECT ON TABLE CB_GOLD.PRODUCTOS.VENTAS_MENSUALES_COMERCIO TO ROLE RL_NEGOCIO;
GRANT SELECT ON TABLE CB_GOLD.PRODUCTOS.VENTAS_MENSUALES_COMERCIO TO ROLE RL_ARQUITECTURA;

-- El PAN y los datos personales quedan marcados desde la instalacion. En el
-- track de gobierno se comprueba que la clasificacion automatica llega al mismo
-- resultado sin que nadie se lo diga.
ALTER TABLE CB_SILVER.ADQUIRENCIA.TARJETAHABIENTES
    SET TAG CB_PLATAFORMA.GOBIERNO.DOMINIO = 'CLIENTE',
            CB_PLATAFORMA.GOBIERNO.PCI_CDE = 'DENTRO',
            CB_PLATAFORMA.GOBIERNO.CONFIDENCIALIDAD = 'RESTRINGIDO';
ALTER TABLE CB_SILVER.ADQUIRENCIA.AUTORIZACIONES
    SET TAG CB_PLATAFORMA.GOBIERNO.DOMINIO = 'ADQUIRENCIA',
            CB_PLATAFORMA.GOBIERNO.PCI_CDE = 'DENTRO',
            CB_PLATAFORMA.GOBIERNO.CONFIDENCIALIDAD = 'CONFIDENCIAL';
ALTER TABLE CB_SILVER.ADQUIRENCIA.COMERCIOS
    SET TAG CB_PLATAFORMA.GOBIERNO.DOMINIO = 'ADQUIRENCIA',
            CB_PLATAFORMA.GOBIERNO.PCI_CDE = 'FUERA',
            CB_PLATAFORMA.GOBIERNO.CONFIDENCIALIDAD = 'USO_INTERNO';

/* == Dominios del data mesh ===========================================
   Un esquema por dominio con su propio rol de dominio. El gobierno federado
   del requisito 2.7 se demuestra sobre estos objetos.
   ====================================================================== */
CREATE SCHEMA IF NOT EXISTS CB_GOLD.DOM_ADQUIRENCIA
    COMMENT = 'Dominio Adquirencia. Producto: ventas y aprobacion por comercio';
CREATE SCHEMA IF NOT EXISTS CB_GOLD.DOM_RIESGO
    COMMENT = 'Dominio Riesgo. Producto: senales de fraude y SARLAFT';
CREATE SCHEMA IF NOT EXISTS CB_GOLD.DOM_CLIENTE
    COMMENT = 'Dominio Cliente. Producto: vision unica del tarjetahabiente';

CREATE ROLE IF NOT EXISTS RL_DOM_ADQUIRENCIA COMMENT = 'Data owner del dominio Adquirencia';
CREATE ROLE IF NOT EXISTS RL_DOM_RIESGO      COMMENT = 'Data owner del dominio Riesgo';
CREATE ROLE IF NOT EXISTS RL_DOM_CLIENTE     COMMENT = 'Data owner del dominio Cliente';
GRANT ROLE RL_DOM_ADQUIRENCIA, RL_DOM_RIESGO, RL_DOM_CLIENTE TO ROLE RL_ARQUITECTURA;

GRANT USAGE ON DATABASE CB_GOLD TO ROLE RL_DOM_ADQUIRENCIA;
GRANT USAGE ON DATABASE CB_GOLD TO ROLE RL_DOM_RIESGO;
GRANT USAGE ON DATABASE CB_GOLD TO ROLE RL_DOM_CLIENTE;
GRANT ALL PRIVILEGES ON SCHEMA CB_GOLD.DOM_ADQUIRENCIA TO ROLE RL_DOM_ADQUIRENCIA;
GRANT ALL PRIVILEGES ON SCHEMA CB_GOLD.DOM_RIESGO      TO ROLE RL_DOM_RIESGO;
GRANT ALL PRIVILEGES ON SCHEMA CB_GOLD.DOM_CLIENTE     TO ROLE RL_DOM_CLIENTE;

/* == Muestra de migracion Cloudera ====================================
   Los archivos HiveQL, Spark y Oozie de la muestra viven en el stage. En el
   workshop real esta muestra la entrega CredibanCo; hasta entonces se usa una
   equivalente construida sobre el mismo modelo de datos.
   ====================================================================== */
CREATE SCHEMA IF NOT EXISTS CB_PLATAFORMA.MIGRACION
    COMMENT = 'Assessment y conversion de la linea base Cloudera';

ALTER STAGE CB_RAW.LANDING.STG_HOL REFRESH;

CREATE OR REPLACE VIEW CB_PLATAFORMA.MIGRACION.VW_MUESTRA_CLOUDERA AS
SELECT RELATIVE_PATH,
       SIZE,
       CASE WHEN RELATIVE_PATH ILIKE '%.hql' THEN 'HIVEQL'
            WHEN RELATIVE_PATH ILIKE '%.py'  THEN 'PYSPARK'
            WHEN RELATIVE_PATH ILIKE '%.xml' THEN 'OOZIE'
            WHEN RELATIVE_PATH ILIKE '%.sql' THEN 'IMPALA'
            ELSE 'OTRO' END AS TECNOLOGIA,
       BUILD_SCOPED_FILE_URL(@CB_RAW.LANDING.STG_HOL, RELATIVE_PATH) AS URL_ARCHIVO
FROM DIRECTORY(@CB_RAW.LANDING.STG_HOL)
WHERE RELATIVE_PATH LIKE 'cloudera_sample/%';

GRANT USAGE ON SCHEMA CB_PLATAFORMA.MIGRACION TO ROLE RL_ARQUITECTURA;
GRANT SELECT ON VIEW CB_PLATAFORMA.MIGRACION.VW_MUESTRA_CLOUDERA TO ROLE RL_ARQUITECTURA;

/* == Catalogo de productos de datos ===================================
   Es el catalogo que el usuario de negocio recorre en el flujo
   descubrir-solicitar-consumir del Track 6. Se instala con contenido porque el
   track evalua la experiencia de quien lo consume, no la de quien lo carga.
   ====================================================================== */
CREATE TABLE IF NOT EXISTS CB_PLATAFORMA.GOBIERNO.CATALOGO_PRODUCTOS (
    PRODUCTO_ID     VARCHAR(20)  NOT NULL,
    NOMBRE          VARCHAR(200),
    DOMINIO         VARCHAR(40),
    DESCRIPCION     VARCHAR(1000),
    OBJETO          VARCHAR(400),
    DUENO           VARCHAR(100),
    SLA_FRESCURA    VARCHAR(60),
    CLASIFICACION   VARCHAR(40),
    REQUIERE_APROBACION BOOLEAN,
    CONSTRAINT PK_CATALOGO PRIMARY KEY (PRODUCTO_ID)
) COMMENT = 'Catalogo de negocio: que productos de datos existen y como se solicitan';

MERGE INTO CB_PLATAFORMA.GOBIERNO.CATALOGO_PRODUCTOS t
USING (
    SELECT * FROM VALUES
      ('DP-001','Ventas mensuales por comercio','ADQUIRENCIA',
       'Volumen, monto aprobado, ticket promedio y clientes unicos por comercio y mes. Base de DaInsight.',
       'CB_GOLD.PRODUCTOS.VENTAS_MENSUALES_COMERCIO','Dominio Adquirencia','Diaria 06:00','USO_INTERNO',FALSE),
      ('DP-002','Vision unica del tarjetahabiente','CLIENTE',
       'Customer 360: comportamiento transaccional agregado por tarjetahabiente.',
       'CB_GOLD.PRODUCTOS.CUSTOMER_360','Dominio Cliente','Diaria 06:00','CONFIDENCIAL',TRUE),
      ('DP-003','Features de abandono de comercio','ADQUIRENCIA',
       'Variables predictoras y etiqueta de churn por comercio. Insumo del modelo de retencion.',
       'CB_GOLD.PRODUCTOS.COMERCIO_FEATURES_CHURN','Dominio Adquirencia','Semanal','USO_INTERNO',FALSE),
      ('DP-004','Autorizaciones 360','ADQUIRENCIA',
       'Detalle de autorizaciones enriquecido con comercio, terminal y tarjetahabiente. Contiene PAN enmascarado.',
       'CB_GOLD.PRODUCTOS.VW_AUTORIZACIONES_360','Dominio Adquirencia','Continua','RESTRINGIDO',TRUE)
    AS s(PRODUCTO_ID,NOMBRE,DOMINIO,DESCRIPCION,OBJETO,DUENO,SLA_FRESCURA,CLASIFICACION,REQUIERE_APROBACION)
) s ON t.PRODUCTO_ID = s.PRODUCTO_ID
WHEN NOT MATCHED THEN INSERT
    (PRODUCTO_ID,NOMBRE,DOMINIO,DESCRIPCION,OBJETO,DUENO,SLA_FRESCURA,CLASIFICACION,REQUIERE_APROBACION)
    VALUES (s.PRODUCTO_ID,s.NOMBRE,s.DOMINIO,s.DESCRIPCION,s.OBJETO,s.DUENO,
            s.SLA_FRESCURA,s.CLASIFICACION,s.REQUIERE_APROBACION);

GRANT SELECT ON TABLE CB_PLATAFORMA.GOBIERNO.CATALOGO_PRODUCTOS TO ROLE RL_NEGOCIO;
GRANT SELECT ON TABLE CB_PLATAFORMA.GOBIERNO.CATALOGO_PRODUCTOS TO ROLE RL_ANALISTA;
GRANT SELECT ON TABLE CB_PLATAFORMA.GOBIERNO.CATALOGO_PRODUCTOS TO ROLE RL_INFRA;

/* ----------------------------------------------------------------------------
       Semaforo de la instalacion
       Cada linea debe decir OK. Si alguna dice REVISAR, el ambiente no quedo
       listo y hay que resolverlo antes de que empiece la sesion.
       --------------------------------------------------------------------------*/
    WITH control AS (
        SELECT 'Comercios' AS OBJETO, 180000 AS ESPERADO, (SELECT COUNT(*) FROM CB_SILVER.ADQUIRENCIA.COMERCIOS) AS ENCONTRADO
UNION ALL
SELECT 'Terminales' AS OBJETO, 607119 AS ESPERADO, (SELECT COUNT(*) FROM CB_SILVER.ADQUIRENCIA.TERMINALES) AS ENCONTRADO
UNION ALL
SELECT 'Tarjetahabientes' AS OBJETO, 2500000 AS ESPERADO, (SELECT COUNT(*) FROM CB_SILVER.ADQUIRENCIA.TARJETAHABIENTES) AS ENCONTRADO
UNION ALL
SELECT 'Autorizaciones' AS OBJETO, 40443173 AS ESPERADO, (SELECT COUNT(*) FROM CB_SILVER.ADQUIRENCIA.AUTORIZACIONES) AS ENCONTRADO
UNION ALL
SELECT 'Features de churn' AS OBJETO, 180000 AS ESPERADO, (SELECT COUNT(*) FROM CB_GOLD.PRODUCTOS.COMERCIO_FEATURES_CHURN) AS ENCONTRADO
UNION ALL
SELECT 'Customer 360' AS OBJETO, 2499999 AS ESPERADO, (SELECT COUNT(*) FROM CB_GOLD.PRODUCTOS.CUSTOMER_360) AS ENCONTRADO
UNION ALL
SELECT 'Catalogo de productos' AS OBJETO, 4 AS ESPERADO, (SELECT COUNT(*) FROM CB_PLATAFORMA.GOBIERNO.CATALOGO_PRODUCTOS) AS ENCONTRADO
    )
    SELECT OBJETO, ESPERADO, ENCONTRADO,
           IFF(ENCONTRADO = ESPERADO, 'OK',
               IFF(ENCONTRADO BETWEEN ESPERADO * 0.99 AND ESPERADO * 1.01,
                   'OK (tolerancia 1%)', 'REVISAR')) AS ESTADO
    FROM control;

CALL CB_PLATAFORMA.EVIDENCIA.LOG_EVIDENCIA('INSTALL-ARQUITECTURA', 'Ambiente de arquitectura, monetizacion y migracion instalado',
    'CB_GOLD.DOM_* + CB_PLATAFORMA.MIGRACION',
    'Dominios con rol propio, productos de datos base y muestra Cloudera disponible para el assessment',
    'Anexo 10 - 5.2 data mesh con gobierno federado');
