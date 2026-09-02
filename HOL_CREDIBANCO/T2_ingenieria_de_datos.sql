/* ============================================================================
   HOL CredibanCo - RFP 10010806
   T2 - Ingenieria de datos

   Equipo    : Data & Analytics
   Duracion  : 30 minutos
   Prerrequisito: haber ejecutado install_ingenieria.sql en esta cuenta

   Un solo pipeline con las tres modalidades que pide el pliego: carga batch del archivo nocturno, CDC del maestro de comercios y flujo continuo de eventos de autorizacion, con calidad embebida y linaje automatico.
   ==========================================================================*/


-- ==========================================================================
-- Paso 1. Batch: el archivo del cierre nocturno
-- Cargar el mes faltante desde los archivos crudos y medir el resultado.
-- ==========================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_ETL_BATCH;

-- que hay en la capa cruda
LIST @CB_RAW.LANDING.STG_HOL/raw/;

-- tabla de aterrizaje: se recibe TODO como texto y sin reglas.
-- Rechazar en la puerta obliga a reprocesar el archivo completo; aterrizar
-- primero y validar despues permite aislar la fila mala.
CREATE OR REPLACE TABLE CB_RAW.LANDING.AUTORIZACIONES_BRONZE (
    AUTORIZACION_ID     VARCHAR,
    FECHA_HORA          VARCHAR,
    TERMINAL_ID         VARCHAR,
    COMERCIO_ID         VARCHAR,
    TARJETAHABIENTE_ID  VARCHAR,
    PAN                 VARCHAR,
    FRANQUICIA          VARCHAR,
    MODO_ENTRADA        VARCHAR,
    MONTO_COP           VARCHAR,
    CODIGO_RESPUESTA    VARCHAR,
    NUMERO_CUOTAS       VARCHAR,
    ARCHIVO_ORIGEN      VARCHAR,
    FILA_EN_ARCHIVO     NUMBER,
    CARGADO_EN          TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
) COMMENT = 'Aterrizaje crudo del cierre nocturno, sin tipar';

COPY INTO CB_RAW.LANDING.AUTORIZACIONES_BRONZE
    (AUTORIZACION_ID, FECHA_HORA, TERMINAL_ID, COMERCIO_ID, TARJETAHABIENTE_ID,
     PAN, FRANQUICIA, MODO_ENTRADA, MONTO_COP, CODIGO_RESPUESTA, NUMERO_CUOTAS,
     ARCHIVO_ORIGEN, FILA_EN_ARCHIVO)
FROM (
    SELECT $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11,
           METADATA$FILENAME, METADATA$FILE_ROW_NUMBER
    FROM @CB_RAW.LANDING.STG_HOL/raw/
)
FILE_FORMAT = (FORMAT_NAME = 'CB_RAW.LANDING.FF_CSV_GZ')
ON_ERROR = CONTINUE;

-- resultado de la carga, archivo por archivo
SELECT ARCHIVO_ORIGEN,
       COUNT(*)              AS FILAS,
       MIN(FILA_EN_ARCHIVO)  AS PRIMERA_LINEA,
       MAX(FILA_EN_ARCHIVO)  AS ULTIMA_LINEA
FROM CB_RAW.LANDING.AUTORIZACIONES_BRONZE
GROUP BY ARCHIVO_ORIGEN
ORDER BY ARCHIVO_ORIGEN;

-- historial de carga: que archivos entraron, cuantos errores y cuando
SELECT FILE_NAME, STATUS, ROW_COUNT, ROW_PARSED, ERROR_COUNT, LAST_LOAD_TIME
FROM TABLE(CB_RAW.INFORMATION_SCHEMA.COPY_HISTORY(
           TABLE_NAME => 'CB_RAW.LANDING.AUTORIZACIONES_BRONZE',
           START_TIME => DATEADD('hour', -2, CURRENT_TIMESTAMP())))
ORDER BY LAST_LOAD_TIME DESC;

CALL CB_PLATAFORMA.EVIDENCIA.LOG_EVIDENCIA('T2',
    'Carga batch del cierre nocturno con trazabilidad por archivo y linea',
    'CB_RAW.LANDING.AUTORIZACIONES_BRONZE desde 8 archivos CSV comprimidos',
    'Cerca de 1,6 millones de filas aterrizadas con archivo y numero de linea de origen, mas historial de carga con conteo de errores',
    'Anexo 10 - 1.1 ingesta batch y 1.4 patron medallion');


-- ==========================================================================
-- Paso 2. Flujo continuo de eventos de autorizacion
-- Ingerir eventos JSON de forma continua, sin programar una ventana.
-- ==========================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_ETL_BATCH;

-- destino de los eventos: el JSON se guarda completo y las claves de uso
-- frecuente se exponen como columnas calculadas
CREATE OR REPLACE TABLE CB_RAW.LANDING.EVENTOS_AUTORIZACION (
    EVENTO          VARIANT,
    ARCHIVO_ORIGEN  VARCHAR,
    RECIBIDO_EN     TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
) COMMENT = 'Eventos del topico de autorizaciones tal como llegan';

-- el pipe es declarativo: se define una vez y queda vivo
CREATE OR REPLACE PIPE CB_RAW.LANDING.PIPE_EVENTOS
    AUTO_INGEST = FALSE
AS
COPY INTO CB_RAW.LANDING.EVENTOS_AUTORIZACION (EVENTO, ARCHIVO_ORIGEN)
FROM (
    SELECT $1, METADATA$FILENAME
    FROM @CB_RAW.LANDING.STG_HOL/kafka_sim/
)
FILE_FORMAT = (FORMAT_NAME = 'CB_RAW.LANDING.FF_JSON_GZ');

ALTER PIPE CB_RAW.LANDING.PIPE_EVENTOS REFRESH;

-- el pipe procesa por su cuenta: se consulta su estado
SELECT SYSTEM$PIPE_STATUS('CB_RAW.LANDING.PIPE_EVENTOS') AS ESTADO_DEL_PIPE;

-- llegaron los eventos
SELECT COUNT(*) AS EVENTOS FROM CB_RAW.LANDING.EVENTOS_AUTORIZACION;

-- el JSON se consulta sin aplanarlo primero ni declarar un esquema
SELECT EVENTO:eventId::STRING                        AS EVENTO_ID,
       EVENTO:eventTimestamp::TIMESTAMP_NTZ          AS MOMENTO,
       EVENTO:schemaVersion::STRING                  AS VERSION_ESQUEMA,
       EVENTO:payload:comercioId::NUMBER             AS COMERCIO_ID,
       EVENTO:payload:montoCop::NUMBER               AS MONTO_COP,
       EVENTO:payload:modoEntrada::STRING            AS MODO_ENTRADA,
       EVENTO:payload:codigoRespuesta::STRING        AS CODIGO_RESPUESTA
FROM CB_RAW.LANDING.EVENTOS_AUTORIZACION
LIMIT 5;

-- agregacion sobre el flujo: tasa de aprobacion por modo de entrada
SELECT EVENTO:payload:modoEntrada::STRING AS MODO_ENTRADA,
       COUNT(*)                                                       AS EVENTOS,
       ROUND(100.0 * COUNT_IF(EVENTO:payload:aprobada::BOOLEAN) / COUNT(*), 2) AS PCT_APROBACION
FROM CB_RAW.LANDING.EVENTOS_AUTORIZACION
GROUP BY MODO_ENTRADA
ORDER BY EVENTOS DESC;

CALL CB_PLATAFORMA.EVIDENCIA.LOG_EVIDENCIA('T2',
    'Ingesta continua de eventos JSON con pipe declarativo',
    'CB_RAW.LANDING.PIPE_EVENTOS y EVENTOS_AUTORIZACION',
    'Cerca de 300.000 eventos ingeridos por un pipe declarativo y consultados por atributo anidado, con la version de esquema conservada',
    'Anexo 10 - 1.1 ingesta streaming y 1.2 pipelines declarativos');


-- ==========================================================================
-- Paso 3. CDC: aplicar 45.000 cambios al maestro
-- Consumir la salida de un CDC y aplicarla sin perder ni duplicar operaciones.
-- ==========================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_ETL_BATCH;

-- que trae el CDC
SELECT CDC_OPERACION, COUNT(*) AS OPERACIONES
FROM CB_RAW.LANDING.COMERCIOS_CDC
GROUP BY CDC_OPERACION
ORDER BY OPERACIONES DESC;

-- estado del maestro antes de aplicar
SELECT COUNT(*) AS COMERCIOS,
       COUNT_IF(ESTADO = 'ACTIVO')   AS ACTIVOS,
       COUNT_IF(ESTADO = 'RETIRADO') AS RETIRADOS,
       ROUND(AVG(TASA_DESCUENTO_PCT), 4) AS TASA_PROMEDIO
FROM CB_SILVER.ADQUIRENCIA.COMERCIOS;

-- un stream sobre la tabla de CDC: marca que se ha consumido y que no.
-- Sin esto habria que llevar a mano una marca de agua, que es el patron que
-- falla cuando un proceso se cae a mitad de camino.
CREATE OR REPLACE STREAM CB_RAW.LANDING.STR_COMERCIOS_CDC
    ON TABLE CB_RAW.LANDING.COMERCIOS_CDC
    SHOW_INITIAL_ROWS = TRUE;

SELECT COUNT(*) AS PENDIENTES_EN_EL_STREAM FROM CB_RAW.LANDING.STR_COMERCIOS_CDC;

-- aplicar: una sola sentencia resuelve alta, cambio y retiro.
-- QUALIFY se queda con la ultima operacion por comercio segun el LSN, que es lo
-- que evita aplicar un cambio viejo encima de uno nuevo.
MERGE INTO CB_SILVER.ADQUIRENCIA.COMERCIOS t
USING (
    SELECT * FROM CB_RAW.LANDING.STR_COMERCIOS_CDC
    QUALIFY ROW_NUMBER() OVER (PARTITION BY COMERCIO_ID ORDER BY CDC_LSN DESC) = 1
) s
ON t.COMERCIO_ID = s.COMERCIO_ID
WHEN MATCHED AND s.CDC_OPERACION = 'DELETE' THEN
    UPDATE SET t.ESTADO = 'RETIRADO'
WHEN MATCHED AND s.CDC_OPERACION = 'UPDATE' THEN
    UPDATE SET t.RAZON_SOCIAL       = s.RAZON_SOCIAL,
               t.MCC                = s.MCC,
               t.CIUDAD             = s.CIUDAD,
               t.SEGMENTO           = s.SEGMENTO,
               t.ESTADO             = s.ESTADO,
               t.TASA_DESCUENTO_PCT = s.TASA_DESCUENTO_PCT,
               t.EMAIL_CONTACTO     = s.EMAIL_CONTACTO,
               t.TELEFONO_CONTACTO  = s.TELEFONO_CONTACTO
WHEN NOT MATCHED AND s.CDC_OPERACION <> 'DELETE' THEN
    INSERT (COMERCIO_ID, NIT, RAZON_SOCIAL, MCC, CIUDAD, SEGMENTO, ESTADO,
            TASA_DESCUENTO_PCT, EMAIL_CONTACTO, TELEFONO_CONTACTO)
    VALUES (s.COMERCIO_ID, s.NIT, s.RAZON_SOCIAL, s.MCC, s.CIUDAD, s.SEGMENTO,
            s.ESTADO, s.TASA_DESCUENTO_PCT, s.EMAIL_CONTACTO, s.TELEFONO_CONTACTO);

-- el stream queda vacio: lo consumido no se vuelve a consumir
SELECT COUNT(*) AS PENDIENTES_DESPUES FROM CB_RAW.LANDING.STR_COMERCIOS_CDC;

-- estado del maestro despues
SELECT COUNT(*) AS COMERCIOS,
       COUNT_IF(ESTADO = 'ACTIVO')   AS ACTIVOS,
       COUNT_IF(ESTADO = 'RETIRADO') AS RETIRADOS,
       ROUND(AVG(TASA_DESCUENTO_PCT), 4) AS TASA_PROMEDIO
FROM CB_SILVER.ADQUIRENCIA.COMERCIOS;

-- si el CDC se aplico mal, el dato anterior sigue disponible sin backup
SELECT COUNT(*) AS COMERCIOS_HACE_UN_MINUTO
FROM CB_SILVER.ADQUIRENCIA.COMERCIOS AT(OFFSET => -60);

CALL CB_PLATAFORMA.EVIDENCIA.LOG_EVIDENCIA('T2',
    'CDC aplicado al maestro de comercios con stream y MERGE',
    'STR_COMERCIOS_CDC sobre COMERCIOS_CDC hacia CB_SILVER.ADQUIRENCIA.COMERCIOS',
    '45.000 operaciones de alta, cambio y retiro aplicadas en una sentencia, con deduplicacion por LSN y consumo transaccional del stream',
    'Anexo 10 - 1.1 ingesta CDC bajo el mismo pipeline');


-- ==========================================================================
-- Paso 4. Conformar el mes con una tabla dinamica
-- Declarar la transformacion y dejar que la plataforma la mantenga.
-- ==========================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_ETL_BATCH;

-- se declara QUE se quiere, no COMO ni CUANDO refrescarlo
CREATE OR REPLACE DYNAMIC TABLE CB_SILVER.ADQUIRENCIA.AUTORIZACIONES_DIC2025
    TARGET_LAG = '1 minute'
    WAREHOUSE = WH_ETL_BATCH
AS
SELECT b.AUTORIZACION_ID,
       TRY_TO_TIMESTAMP_NTZ(b.FECHA_HORA)          AS FECHA_HORA,
       TRY_TO_DATE(LEFT(b.FECHA_HORA, 10))         AS FECHA,
       b.TERMINAL_ID,
       TRY_TO_NUMBER(b.COMERCIO_ID)                AS COMERCIO_ID,
       c.MCC,
       c.SECTOR,
       c.CIUDAD                                    AS CIUDAD_COMERCIO,
       c.DEPARTAMENTO,
       c.SEGMENTO                                  AS SEGMENTO_COMERCIO,
       TRY_TO_NUMBER(b.TARJETAHABIENTE_ID)         AS TARJETAHABIENTE_ID,
       b.PAN,
       b.FRANQUICIA,
       b.MODO_ENTRADA,
       TRY_TO_NUMBER(b.MONTO_COP, 18, 2)           AS MONTO_COP,
       b.CODIGO_RESPUESTA,
       b.CODIGO_RESPUESTA = '00'                   AS APROBADA,
       c.DEPARTAMENTO = 'EXTERIOR'                 AS ES_INTERNACIONAL,
       TRY_TO_NUMBER(b.NUMERO_CUOTAS)              AS NUMERO_CUOTAS,
       b.ARCHIVO_ORIGEN
FROM CB_RAW.LANDING.AUTORIZACIONES_BRONZE b
JOIN CB_SILVER.ADQUIRENCIA.COMERCIOS c
  ON c.COMERCIO_ID = TRY_TO_NUMBER(b.COMERCIO_ID)
WHERE TRY_TO_NUMBER(b.MONTO_COP, 18, 2) > 0
  AND b.AUTORIZACION_ID IS NOT NULL;

-- el refresco lo hace la plataforma; aca solo se consulta
SELECT COUNT(*) AS FILAS_CONFORMADAS,
       MIN(FECHA) AS DESDE,
       MAX(FECHA) AS HASTA,
       COUNT_IF(MONTO_COP IS NULL) AS MONTOS_ILEGIBLES
FROM CB_SILVER.ADQUIRENCIA.AUTORIZACIONES_DIC2025;

-- que descarto la conformacion y por que
SELECT (SELECT COUNT(*) FROM CB_RAW.LANDING.AUTORIZACIONES_BRONZE) AS EN_CRUDO,
       (SELECT COUNT(*) FROM CB_SILVER.ADQUIRENCIA.AUTORIZACIONES_DIC2025) AS CONFORMADAS,
       (SELECT COUNT(*) FROM CB_RAW.LANDING.AUTORIZACIONES_BRONZE)
         - (SELECT COUNT(*) FROM CB_SILVER.ADQUIRENCIA.AUTORIZACIONES_DIC2025) AS DESCARTADAS;

-- estado del refresco: la plataforma reporta si va incremental
SELECT NAME, SCHEDULING_STATE:state::STRING AS ESTADO,
       TARGET_LAG_SEC, MEAN_LAG_SEC, MAXIMUM_LAG_SEC,
       LAST_COMPLETED_REFRESH_STATE
FROM TABLE(CB_SILVER.INFORMATION_SCHEMA.DYNAMIC_TABLES(
           NAME => 'AUTORIZACIONES_DIC2025'));

-- promocion a la tabla historica: el mes queda integrado
INSERT INTO CB_SILVER.ADQUIRENCIA.AUTORIZACIONES
    (AUTORIZACION_ID, FECHA_HORA, FECHA, TERMINAL_ID, COMERCIO_ID, MCC, SECTOR,
     CIUDAD_COMERCIO, DEPARTAMENTO, SEGMENTO_COMERCIO, TARJETAHABIENTE_ID, PAN,
     FRANQUICIA, MODO_ENTRADA, MONTO_COP, CODIGO_RESPUESTA, DESCRIPCION_RESPUESTA,
     APROBADA, ES_INTERNACIONAL, MARCA_FRAUDE, NUMERO_CUOTAS)
SELECT AUTORIZACION_ID, FECHA_HORA, FECHA, TERMINAL_ID, COMERCIO_ID, MCC, SECTOR,
       CIUDAD_COMERCIO, DEPARTAMENTO, SEGMENTO_COMERCIO, TARJETAHABIENTE_ID, PAN,
       FRANQUICIA, MODO_ENTRADA, MONTO_COP, CODIGO_RESPUESTA,
       IFF(APROBADA, 'Aprobada', 'Declinada'), APROBADA, ES_INTERNACIONAL,
       FALSE, NUMERO_CUOTAS
FROM CB_SILVER.ADQUIRENCIA.AUTORIZACIONES_DIC2025;

-- el hueco de diciembre quedo cerrado
SELECT DATE_TRUNC('month', FECHA) AS MES, COUNT(*) AS FILAS
FROM CB_SILVER.ADQUIRENCIA.AUTORIZACIONES
WHERE FECHA >= '2025-10-01'
GROUP BY MES
ORDER BY MES;

CALL CB_PLATAFORMA.EVIDENCIA.LOG_EVIDENCIA('T2',
    'Conformacion declarativa de la capa silver con tabla dinamica',
    'CB_SILVER.ADQUIRENCIA.AUTORIZACIONES_DIC2025 con TARGET_LAG de 1 minuto',
    'Transformacion declarada una vez y mantenida por la plataforma, con conteo de filas descartadas y promocion del mes a la tabla historica',
    'Anexo 10 - 1.2 pipelines declarativos y 1.4 medallion');


-- ==========================================================================
-- Paso 5. Calidad embebida que corre sola
-- Adjuntar reglas de calidad al dato, no a un job aparte.
-- ==========================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_ETL_BATCH;

-- frecuencia de evaluacion de las reglas sobre esta tabla
ALTER TABLE CB_SILVER.ADQUIRENCIA.AUTORIZACIONES
    SET DATA_METRIC_SCHEDULE = '5 MINUTE';

-- reglas de sistema: nulos en la llave y duplicados
ALTER TABLE CB_SILVER.ADQUIRENCIA.AUTORIZACIONES
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (AUTORIZACION_ID);
ALTER TABLE CB_SILVER.ADQUIRENCIA.AUTORIZACIONES
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.DUPLICATE_COUNT ON (AUTORIZACION_ID);
ALTER TABLE CB_SILVER.ADQUIRENCIA.AUTORIZACIONES
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (MONTO_COP);

-- regla propia del negocio: una autorizacion aprobada con codigo
-- distinto de 00 es una inconsistencia que ningun chequeo generico detecta
CREATE OR REPLACE DATA METRIC FUNCTION CB_PLATAFORMA.GOBIERNO.DMF_APROBACION_COHERENTE(
    ARG_T TABLE(ARG_APROBADA BOOLEAN, ARG_CODIGO VARCHAR))
RETURNS NUMBER
COMMENT = 'Cuenta autorizaciones donde la marca de aprobacion no concuerda con el codigo de respuesta ISO 8583'
AS
$$
    SELECT COUNT(*)
    FROM ARG_T
    WHERE (ARG_APROBADA = TRUE  AND ARG_CODIGO <> '00')
       OR (ARG_APROBADA = FALSE AND ARG_CODIGO =  '00')
$$;

ALTER TABLE CB_SILVER.ADQUIRENCIA.AUTORIZACIONES
    ADD DATA METRIC FUNCTION CB_PLATAFORMA.GOBIERNO.DMF_APROBACION_COHERENTE
    ON (APROBADA, CODIGO_RESPUESTA);

-- que reglas quedaron adjuntas a la tabla
SELECT METRIC_NAME, REF_ARGUMENTS, SCHEDULE, SCHEDULE_STATUS
FROM TABLE(INFORMATION_SCHEMA.DATA_METRIC_FUNCTION_REFERENCES(
           REF_ENTITY_NAME => 'CB_SILVER.ADQUIRENCIA.AUTORIZACIONES',
           REF_ENTITY_DOMAIN => 'TABLE'));

-- ejecutar una regla ahora mismo, sin esperar la programacion
SELECT SNOWFLAKE.CORE.NULL_COUNT(
           SELECT AUTORIZACION_ID FROM CB_SILVER.ADQUIRENCIA.AUTORIZACIONES)
       AS NULOS_EN_LA_LLAVE;

SELECT SNOWFLAKE.CORE.DUPLICATE_COUNT(
           SELECT AUTORIZACION_ID FROM CB_SILVER.ADQUIRENCIA.AUTORIZACIONES)
       AS DUPLICADOS;

SELECT CB_PLATAFORMA.GOBIERNO.DMF_APROBACION_COHERENTE(
           SELECT APROBADA, CODIGO_RESPUESTA FROM CB_SILVER.ADQUIRENCIA.AUTORIZACIONES)
       AS INCOHERENCIAS_DE_APROBACION;

CALL CB_PLATAFORMA.EVIDENCIA.LOG_EVIDENCIA('T2',
    'Calidad embebida con reglas de sistema y una regla propia del negocio',
    'Cuatro metricas adjuntas a CB_SILVER.ADQUIRENCIA.AUTORIZACIONES cada 5 minutos',
    'Nulos, duplicados y coherencia entre marca de aprobacion y codigo ISO 8583 evaluados por la plataforma sin proceso externo',
    'Anexo 10 - 1.3 calidad embebida con reglas y validacion');


-- ==========================================================================
-- Paso 6. Linaje que nadie declaro
-- Ver el recorrido del dato de punta a punta sin haberlo documentado.
-- ==========================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_ETL_BATCH;

-- aguas abajo: que se construyo a partir de la tabla cruda
SELECT SOURCE_OBJECT_NAME, SOURCE_OBJECT_DOMAIN,
       TARGET_OBJECT_NAME, TARGET_OBJECT_DOMAIN, DISTANCE
FROM TABLE(SNOWFLAKE.CORE.GET_LINEAGE(
           'CB_RAW.LANDING.AUTORIZACIONES_BRONZE', 'TABLE', 'DOWNSTREAM', 3))
ORDER BY DISTANCE, TARGET_OBJECT_NAME;

-- aguas arriba: de donde sale el producto de datos que consume BI
SELECT SOURCE_OBJECT_NAME, SOURCE_OBJECT_DOMAIN,
       TARGET_OBJECT_NAME, DISTANCE
FROM TABLE(SNOWFLAKE.CORE.GET_LINEAGE(
           'CB_GOLD.PRODUCTOS.VW_AUTORIZACIONES_360', 'VIEW', 'UPSTREAM', 3))
ORDER BY DISTANCE, SOURCE_OBJECT_NAME;

CALL CB_PLATAFORMA.EVIDENCIA.LOG_EVIDENCIA('T2',
    'Linaje automatico end-to-end sin declaracion manual',
    'GET_LINEAGE desde AUTORIZACIONES_BRONZE y hacia VW_AUTORIZACIONES_360',
    'Recorrido completo del dato desde el archivo crudo hasta la vista de consumo, derivado de la definicion de los objetos',
    'Anexo 10 - 1.3 linaje automatico y 2.2 linaje de tabla y columna');


-- ==========================================================================
-- Cierre: evidencia del track
-- ==========================================================================

-- Resumen de lo ejecutado en este track. Es el artefacto que se entrega al
-- cierre, como exige el numeral 3.2 del Anexo 11.
SELECT PASO, OBJETO, RESULTADO, REQUISITO, EJECUTADO_POR, ROL, MOMENTO
FROM CB_PLATAFORMA.EVIDENCIA.ARTEFACTOS
WHERE TRACK = 'T2'
ORDER BY MOMENTO;

SELECT * FROM CB_PLATAFORMA.EVIDENCIA.VW_EVIDENCIA_POR_TRACK
WHERE TRACK = 'T2';
