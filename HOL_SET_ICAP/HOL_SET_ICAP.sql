/* ********************************************************************************************
                   HANDS ON LAB - SET-ICAP | Mercado de Divisas SET-FX
                   "De S3 a Snowflake CoWork"
********************************************************************************************
 SET-ICAP es la compañía líder en negociación y registro de divisas y valores OTC en Colombia.
 Filial de la Bolsa de Valores de Colombia (BVC) y de TP ICAP Group. Opera el sistema
 electrónico SET-FX, principal fuente de información del dólar en Colombia.

 Este HOL recorre 12 partes. Copia todo el contenido en un Worksheet de Snowflake y ejecuta
 cada parte en orden. Comentarios y notas en español.

 Recorrido: cargas 400M filas desde S3 a velocidad de warehouse, construyes una capa de
 consumo viva con Dynamic Tables, analizas el mercado con Cortex AI y expones todo a un
 agente de Snowflake CoWork.

 Datos 100% SINTÉTICOS para fines demostrativos en s3://demosjparrado/set_icap_hol/
 (12 tablas, csv.gz, delimitador ';', ~400M filas totales — 5 años de historia).
 No representan operaciones reales de SET-ICAP ni de
 las entidades mencionadas.
********************************************************************************************
 -- Credenciales del stage (las entrega el instructor):
 -- AWS_KEY_ID     = '<SOLICITAR_AL_INSTRUCTOR>'
 -- AWS_SECRET_KEY = '<SOLICITAR_AL_INSTRUCTOR>'
******************************************************************************************** */


/* ************************************ PARTE 1 ************************************************
   Definimos el ambiente: base de datos, warehouse y esquema.
   Habilitamos Cortex cross-region para usar los modelos de IA generativa.
******************************************************************************************** */
USE ROLE ACCOUNTADMIN;
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';

CREATE OR REPLACE DATABASE DB_HOL_SETICAP
  COMMENT = 'HOL SET-ICAP - Mercado de divisas SET-FX (datos sintéticos)';

CREATE OR REPLACE WAREHOUSE WH_HOL_SETICAP
WITH
  WAREHOUSE_SIZE    = 'SMALL'
  WAREHOUSE_TYPE    = 'STANDARD'
  AUTO_SUSPEND      = 60
  AUTO_RESUME       = TRUE
  MIN_CLUSTER_COUNT = 1
  MAX_CLUSTER_COUNT = 2
  SCALING_POLICY    = 'STANDARD'
  COMMENT = 'Warehouse del HOL SET-ICAP';

USE WAREHOUSE WH_HOL_SETICAP;
USE DATABASE  DB_HOL_SETICAP;
USE SCHEMA    PUBLIC;


/* ************************************ PARTE 2 ************************************************
   Stage externo a AWS S3 + File Format.
   El bucket s3://demosjparrado/set_icap_hol/ contiene los datos del HOL en .csv.gz
******************************************************************************************** */

-- File format: CSV gzip, delimitado por ';', NULL como 'NULL'
CREATE OR REPLACE FILE FORMAT FF_CSV_GZ
  TYPE = CSV
  FIELD_DELIMITER = ';'
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  COMPRESSION = GZIP
  NULL_IF = ('NULL','')
  EMPTY_FIELD_AS_NULL = TRUE
  TRIM_SPACE = TRUE
  SKIP_HEADER = 1
  COMMENT = 'CSV ; gzip para datasets del HOL SET-ICAP';

-- Stage externo (credenciales read-only embebidas; las entrega el instructor)
CREATE OR REPLACE STAGE STG_SETICAP
  URL = 's3://demosjparrado/set_icap_hol/'
  CREDENTIALS = (AWS_KEY_ID='<SOLICITAR_AL_INSTRUCTOR>' AWS_SECRET_KEY='<SOLICITAR_AL_INSTRUCTOR>')
  FILE_FORMAT = FF_CSV_GZ
  COMMENT = 'Stage externo HOL SET-ICAP (lectura del dataset sintético)';

-- ¿Qué hay en el stage?
LIST @STG_SETICAP/hist/entidad/;
LIST @STG_SETICAP/hist/operation_set_fx/;

-- Validar el formato leyendo unas filas crudas SIN cargarlas
SELECT $1 AS id, $2 AS fecha, $5 AS mercado, $13 AS monto_usd, $16 AS precio, $19 AS plazo
FROM @STG_SETICAP/hist/operation_set_fx/ (FILE_FORMAT => FF_CSV_GZ)
LIMIT 5;


/* ************************************ PARTE 3 ************************************************
   DDL de las 12 tablas con comentarios + COPY INTO del histórico (~400M filas).
   Modelo: operation_set_fx (transaccional, 120M) se relaciona con catálogos y maestros.
   Nuevas tablas: OPERATION_SET_FX_CONTRAP_COMITENTE (40M) para comitentes por operación.
******************************************************************************************** */

-- ---------- CATÁLOGOS ----------
CREATE OR REPLACE TABLE CURRENCY (
  CURR_ID            NUMBER       COMMENT 'Identificador de la moneda',
  CURR_CURRENCY      VARCHAR      COMMENT 'Nombre de la moneda',
  CURR_ALIAS         VARCHAR      COMMENT 'Código ISO de la moneda (USD, COP, EUR...)',
  CURR_SIGNO         VARCHAR      COMMENT 'Símbolo de la moneda',
  CURR_ALIAS_DECEVAL VARCHAR      COMMENT 'Alias en Deceval',
  CURR_CODDECEVAL    VARCHAR      COMMENT 'Código numérico ISO 4217'
) COMMENT='Catálogo de monedas negociadas en SET-FX';

CREATE OR REPLACE TABLE MERCADO (
  MERCADO_ID      NUMBER    COMMENT 'Identificador del mercado (76 = Contado USD/COP)',
  PROD_ID         NUMBER    COMMENT 'Identificador del producto',
  ACTIVO          BOOLEAN   COMMENT 'Mercado activo (TRUE/FALSE)',
  MERCADO_NOMBRE  VARCHAR   COMMENT 'Nombre del mercado'
) COMMENT='Catálogo de mercados de negociación';

CREATE OR REPLACE TABLE PARIDAD_MONEDA (
  PARIDAD_ID      NUMBER    COMMENT 'Identificador del par de monedas',
  NOMBRE          VARCHAR   COMMENT 'Nombre del par (ej: USD/COP)',
  MONEDA_UNO      NUMBER    COMMENT 'FK a CURRENCY (moneda base)',
  MONEDA_DOS      NUMBER    COMMENT 'FK a CURRENCY (moneda cotizada)',
  PARIDAD_TO_UDS  FLOAT     COMMENT 'Factor de conversión a USD',
  PARIDAD_ACTIVA  BOOLEAN   COMMENT 'Par activo'
) COMMENT='Catálogo de pares de monedas (paridades)';

CREATE OR REPLACE TABLE SUB_MERCADO (
  SUB_MERCADO_ID         NUMBER   COMMENT 'Identificador del sub-mercado',
  MERCADO_ID             NUMBER   COMMENT 'FK al mercado',
  SUB_MERCADO            NUMBER   COMMENT 'Código del sub-mercado',
  ACTIVO                 BOOLEAN  COMMENT 'Sub-mercado activo',
  SUBMERCADO_NOMBRE      VARCHAR  COMMENT 'Nombre del sub-mercado',
  SUMERCADO_INTERBANCARIO BOOLEAN COMMENT 'Indica si es interbancario'
) COMMENT='Catálogo de sub-mercados (interbancario, cliente, IMC-IMC)';

CREATE OR REPLACE TABLE CIIU (
  CODIGO      VARCHAR  COMMENT 'Código CIIU de actividad económica',
  SECCION     VARCHAR  COMMENT 'Sección CIIU',
  DIVISION    VARCHAR  COMMENT 'División CIIU',
  GRUPO       VARCHAR  COMMENT 'Grupo CIIU',
  CLASE       VARCHAR  COMMENT 'Clase CIIU',
  DESCRIPCION VARCHAR  COMMENT 'Descripción de la actividad económica'
) COMMENT='Clasificación Industrial Internacional Uniforme (Colombia)';

-- ---------- MAESTROS ----------
CREATE OR REPLACE TABLE ENTIDAD (
  ENTIDAD_ID                 NUMBER   COMMENT 'Identificador único de la entidad (IMC)',
  ENTIDAD_CODIGO             VARCHAR  COMMENT 'Código interno de la entidad',
  ENTIDAD_SIGLA              VARCHAR  COMMENT 'Sigla de la entidad',
  ENTIDAD_NOMBRE             VARCHAR  COMMENT 'Razón social del Intermediario del Mercado Cambiario',
  ENTIDAD_NIT                VARCHAR  COMMENT 'NIT de la entidad',
  ENTIDAD_CIUDAD             VARCHAR  COMMENT 'Ciudad principal',
  ENTIDAD_PAIS               VARCHAR  COMMENT 'País',
  ENTIDAD_COD_SUPERFIN       VARCHAR  COMMENT 'Código en la Superintendencia Financiera',
  ENTIDAD_CLASE              VARCHAR  COMMENT 'Clase: Banco, Comisionista, Corp. Financiera, Banco Central...',
  ENTIDAD_TIPO               VARCHAR  COMMENT 'Tipo: Privado, Oficial, Extranjero, Cooperativo',
  ENTIDAD_ACTIVA             BOOLEAN  COMMENT 'Entidad activa',
  ENTIDAD_FORMADOR_LIQUIDEZ  BOOLEAN  COMMENT 'Formador de liquidez del mercado',
  ENTIDAD_CREADOR_MERCADO    BOOLEAN  COMMENT 'Creador de mercado (market maker)',
  ENTIDAD_FECHA_VINCULACION  DATE     COMMENT 'Fecha de vinculación a SET-FX'
) COMMENT='Entidades participantes: Intermediarios del Mercado Cambiario (IMC)';

CREATE OR REPLACE TABLE SUCURSAL (
  SUCURSAL_ID        NUMBER   COMMENT 'Identificador de la sucursal / mesa de dinero',
  SUCURSAL_SIGLA     VARCHAR  COMMENT 'Sigla de la sucursal',
  SUCURSAL_DIRECCION VARCHAR  COMMENT 'Dirección',
  SUCURSAL_TELEFONO  VARCHAR  COMMENT 'Teléfono',
  SUCURSAL_CIUDAD    VARCHAR  COMMENT 'Ciudad',
  SUCURSAL_PAIS      VARCHAR  COMMENT 'País',
  ENTIDAD_ID         NUMBER   COMMENT 'FK a ENTIDAD',
  SUCURSAL_NOMBRE    VARCHAR  COMMENT 'Nombre de la mesa de dinero'
) COMMENT='Sucursales / mesas de dinero de cada entidad';

CREATE OR REPLACE TABLE USUARIO (
  USUARIO_ID          NUMBER   COMMENT 'Identificador del usuario (trader/broker)',
  USUARIO_USER_CODE   VARCHAR  COMMENT 'Código de usuario en SET-FX (ej: O597)',
  USUARIO_PRIMARY_USER BOOLEAN COMMENT 'Usuario principal de la mesa',
  USUARIO_DOCUMENTO   VARCHAR  COMMENT 'Documento de identidad',
  USUARIO_TIPO_DOC    VARCHAR  COMMENT 'Tipo de documento',
  USUARIO_NOMBRE      VARCHAR  COMMENT 'Nombre del trader',
  USUARIO_SIGLAS      VARCHAR  COMMENT 'Iniciales del trader',
  SUCURSAL_ID         NUMBER   COMMENT 'FK a SUCURSAL'
) COMMENT='Traders y brokers que operan en las mesas de dinero';

CREATE OR REPLACE TABLE COMITENTE (
  OFFSHORE_ID             NUMBER   COMMENT 'Identificador del comitente (cliente final)',
  TIPO_IDENTIFICACION     VARCHAR  COMMENT 'Tipo de identificación (NIT, PAS)',
  IDENTIFICACION          VARCHAR  COMMENT 'Número de identificación',
  NOMBRE                  VARCHAR  COMMENT 'Razón social del comitente',
  SECTOR                  VARCHAR  COMMENT 'Código CIIU del sector económico',
  CODIGO_IMC              NUMBER   COMMENT 'FK a ENTIDAD (IMC que lo representa)',
  TIPO_INVERSIONISTA      VARCHAR  COMMENT 'Tipo de inversionista',
  PAIS                    VARCHAR  COMMENT 'País del comitente',
  AUTORETENEDOR           BOOLEAN  COMMENT 'Es autorretenedor',
  ENVIAR_INFORME_OFFSHORE BOOLEAN  COMMENT 'Comitente offshore (reporte cambiario)'
) COMMENT='Comitentes: clientes finales (domésticos y offshore) de los IMC';

-- ---------- TRANSACCIONALES ----------
CREATE OR REPLACE TABLE OPERATION_SET_FX (
  ID                          NUMBER         COMMENT 'Identificador único de la operación',
  FECHA                       DATE           COMMENT 'Fecha de la operación',
  HORA                        TIME           COMMENT 'Hora de calce de la operación',
  ANULADA                     BOOLEAN        COMMENT 'Operación anulada (TRUE/FALSE)',
  MERCADO                     NUMBER         COMMENT 'FK a MERCADO (76 = Contado USD/COP)',
  SUB_MERCADO                 NUMBER         COMMENT 'FK a SUB_MERCADO',
  REGISTRO                    BOOLEAN        COMMENT 'Operación de registro (TRUE) vs negociación (FALSE)',
  MCOD_TRANSACCION            VARCHAR        COMMENT 'Código de transacción',
  USUARIO_POSTURA             VARCHAR        COMMENT 'Código del usuario que originó la postura',
  DIAS                        NUMBER         COMMENT 'Días al vencimiento',
  FECHA_VALOR                 DATE           COMMENT 'Fecha de liquidación',
  HORA_POSTURA                TIME           COMMENT 'Hora de la postura inicial',
  MONTO_MONEDA_UNO            NUMBER(18,2)   COMMENT 'Monto en moneda uno (USD)',
  MONTO_MONEDA_DOS            NUMBER(20,2)   COMMENT 'Monto en moneda dos (COP)',
  MONTO_USD                   NUMBER(18,2)   COMMENT 'Monto normalizado en USD',
  PRECIO                      NUMBER(12,4)   COMMENT 'Tipo de cambio negociado (COP por USD)',
  POINTS_FORWARD              NUMBER(12,4)   COMMENT 'Puntos forward (0 en contado)',
  PRECIO_SPOT                 NUMBER(12,4)   COMMENT 'Precio spot de referencia',
  PLAZO_CURVA                 VARCHAR        COMMENT 'Plazo: T+0, T+1, T+2, 1W, 1M, 3M, 6M, 1Y',
  ENTIDAD_PUBLICA_3C_1        BOOLEAN        COMMENT 'Operación con entidad pública',
  BANDERA_FISICO_COMPENSACION BOOLEAN        COMMENT 'Compensación física (TRUE) o neta (FALSE)',
  PARIDAD_ID                  NUMBER         COMMENT 'FK a PARIDAD_MONEDA',
  PARIDAD_NOMBRE              VARCHAR        COMMENT 'Nombre del par (ej: USD/COP)',
  MONEDA_UNO                  NUMBER         COMMENT 'FK a CURRENCY (moneda uno)',
  MONEDA_DOS                  NUMBER         COMMENT 'FK a CURRENCY (moneda dos)',
  ENTIDAD_COMPRADORA          NUMBER         COMMENT 'FK a ENTIDAD (compra divisas)',
  ENTIDAD_VENDEDORA           NUMBER         COMMENT 'FK a ENTIDAD (vende divisas)',
  PLAZO_DIAS                  NUMBER         COMMENT 'Plazo en días calendario',
  ENVIADA_CAMARA              BOOLEAN        COMMENT 'Enviada a cámara de compensación',
  TEXTO_TERM                  VARCHAR(16777216) COMMENT 'Nota libre del trader sobre condiciones de mercado'
) COMMENT='Operaciones de divisas negociadas/registradas en SET-FX (histórico)';

CREATE OR REPLACE TABLE OPERATION_SET_FX_CONTRAPARTE (
  OPER_ID      NUMBER   COMMENT 'FK a OPERATION_SET_FX.ID',
  OPER_LADO    VARCHAR  COMMENT 'Lado de la operación: C (compra) o V (venta)',
  ENTIDAD_ID   NUMBER   COMMENT 'FK a ENTIDAD (contraparte)',
  SUCURSAL_ID  NUMBER   COMMENT 'FK a SUCURSAL',
  TRADER_ID    NUMBER   COMMENT 'FK a USUARIO (trader)',
  BROKER_ID    NUMBER   COMMENT 'FK a USUARIO (broker, si aplica)',
  COMITENTE_ID NUMBER   COMMENT 'FK a COMITENTE (cliente final, si aplica)'
) COMMENT='Contrapartes por operación (un registro por lado comprador/vendedor)';

CREATE OR REPLACE TABLE OPERATION_SET_FX_CONTRAP_COMITENTE (
  OPER_ID      NUMBER   COMMENT 'FK a OPERATION_SET_FX.ID',
  ENTIDAD_ID   NUMBER   COMMENT 'FK a ENTIDAD (entidad que opera para el comitente)',
  SUCURSAL_ID  NUMBER   COMMENT 'FK a SUCURSAL',
  TRADER_ID    NUMBER   COMMENT 'FK a USUARIO (trader)',
  COMITENTE_ID NUMBER   COMMENT 'FK a COMITENTE (cliente final)'
) COMMENT='Comitentes involucrados en operaciones (~33% de operaciones tienen cliente final)';


/* ************************************ PARTE 4 ************************************************
   Carga de datos históricos: COPY INTO + demostración de Warehouse Scaling.
   Objetivo: IMPRESIONAR con la velocidad. Snowflake escala al vuelo — mismo dato,
   mismo S3, cambias el tamaño del warehouse y la carga se acelera. Pagas por segundo.

   Dimensionamiento de archivos (clave para el paralelismo):
   - operation_set_fx: ~37 MB c/u (120M filas) — particionado fino para saturar un XLARGE
   - operation_set_fx_contraparte: ~130 MB (240M filas)
   - operation_set_fx_contrap_comitente: ~130 MB (40M filas)
   COPY INTO paraleliza 1 archivo por hilo; con más archivos el warehouse grande ocupa todos sus hilos.
******************************************************************************************** */

-- Catálogos y maestros (con SMALL, son pocas filas — instantáneo)
COPY INTO CURRENCY        FROM @STG_SETICAP/hist/currency/;
COPY INTO MERCADO         FROM @STG_SETICAP/hist/mercado/;
COPY INTO PARIDAD_MONEDA  FROM @STG_SETICAP/hist/paridad_moneda/;
COPY INTO SUB_MERCADO     FROM @STG_SETICAP/hist/sub_mercado/;
COPY INTO CIIU            FROM @STG_SETICAP/hist/ciiu/;
COPY INTO ENTIDAD         FROM @STG_SETICAP/hist/entidad/;
COPY INTO SUCURSAL        FROM @STG_SETICAP/hist/sucursal/;
COPY INTO USUARIO         FROM @STG_SETICAP/hist/usuario/;
COPY INTO COMITENTE       FROM @STG_SETICAP/hist/comitente/;

-- DEMO DE SCALING:
COPY INTO OPERATION_SET_FX FROM @STG_SETICAP/hist/operation_set_fx/;

SELECT COUNT(1) FROM OPERATION_SET_FX;

-- Vaciamos y recargamos lo mismo con XLARGE para comparar
TRUNCATE TABLE OPERATION_SET_FX;
ALTER WAREHOUSE WH_HOL_SETICAP SET WAREHOUSE_SIZE = 'XLARGE';
COPY INTO OPERATION_SET_FX FROM @STG_SETICAP/hist/operation_set_fx/;

-- Cargamos las otras 2 tablas grandes (seguimos en XLARGE)
COPY INTO OPERATION_SET_FX_CONTRAPARTE          FROM @STG_SETICAP/hist/operation_set_fx_contraparte/;          -- 240M
COPY INTO OPERATION_SET_FX_CONTRAP_COMITENTE    FROM @STG_SETICAP/hist/operation_set_fx_contrap_comitente/;    -- 40M

-- Volvemos a SMALL para el resto del HOL (consultas, AI, DT). ¡SMALL es suficiente!
ALTER WAREHOUSE WH_HOL_SETICAP SET WAREHOUSE_SIZE = 'SMALL';

-- Conteos (debe dar ~400M en total)
SELECT 'CURRENCY' tabla, COUNT(*) registros FROM CURRENCY
UNION ALL SELECT 'MERCADO', COUNT(*) FROM MERCADO
UNION ALL SELECT 'PARIDAD_MONEDA', COUNT(*) FROM PARIDAD_MONEDA
UNION ALL SELECT 'SUB_MERCADO', COUNT(*) FROM SUB_MERCADO
UNION ALL SELECT 'CIIU', COUNT(*) FROM CIIU
UNION ALL SELECT 'ENTIDAD', COUNT(*) FROM ENTIDAD
UNION ALL SELECT 'SUCURSAL', COUNT(*) FROM SUCURSAL
UNION ALL SELECT 'USUARIO', COUNT(*) FROM USUARIO
UNION ALL SELECT 'COMITENTE', COUNT(*) FROM COMITENTE
UNION ALL SELECT 'OPERATION_SET_FX', COUNT(*) FROM OPERATION_SET_FX
UNION ALL SELECT 'OPERATION_SET_FX_CONTRAPARTE', COUNT(*) FROM OPERATION_SET_FX_CONTRAPARTE
UNION ALL SELECT 'OPERATION_SET_FX_CONTRAP_COMITENTE', COUNT(*) FROM OPERATION_SET_FX_CONTRAP_COMITENTE
ORDER BY 1;


/* ************************************ PARTE 5 ************************************************
   Time Travel & UNDROP: recupérate de errores sin backups ni restauraciones.
   Snowflake conserva el historial de cada tabla, así que puedes deshacer un DROP o un
   cambio destructivo (p. ej. un UPDATE sin WHERE) "viajando en el tiempo".
   (Ejecuta en el mismo worksheet para que la variable de sesión persista.)
******************************************************************************************** */

-- Tabla de demostración pequeña (clon del catálogo MERCADO), para no tocar las tablas grandes.
CREATE OR REPLACE TABLE T_DEMO_TT AS SELECT * FROM MERCADO;
SELECT COUNT(*) AS filas FROM T_DEMO_TT;

-- 5.1 DROP y UNDROP: recuperar una tabla borrada por error, al instante.
DROP TABLE T_DEMO_TT;                   -- borrada por accidente
UNDROP TABLE T_DEMO_TT;                 -- recuperada al instante (sin restaurar backups)
SELECT COUNT(*) AS filas_tras_undrop FROM T_DEMO_TT;

-- 5.2 UPDATE SIN WHERE (daño masivo) y recuperación con Time Travel.
-- Estado bueno (los nombres reales de cada mercado):
SELECT MERCADO_ID, MERCADO_NOMBRE FROM T_DEMO_TT ORDER BY MERCADO_ID;

-- El clásico accidente: un UPDATE SIN WHERE sobrescribe TODAS las filas.
UPDATE T_DEMO_TT SET MERCADO_NOMBRE = 'CORRUPTO';
SET bad_qid = LAST_QUERY_ID();          -- id del UPDATE dañino (para el BEFORE)
SELECT MERCADO_ID, MERCADO_NOMBRE FROM T_DEMO_TT ORDER BY MERCADO_ID;   -- todo 'CORRUPTO'

-- Recuperación con un BEFORE de ~3 minutos (estado previo al UPDATE):
--   Forma por tiempo — "hace 3 minutos" (requiere que la tabla tenga ≥3 min de historia):
SELECT MERCADO_ID, MERCADO_NOMBRE
FROM T_DEMO_TT AT(OFFSET => -180)       -- 180 s = 3 minutos atrás
ORDER BY MERCADO_ID;
--   Forma a prueba de tiempo — justo ANTES del UPDATE por su query_id (siempre funciona):
SELECT MERCADO_ID, MERCADO_NOMBRE
FROM T_DEMO_TT BEFORE(STATEMENT => $bad_qid)
ORDER BY MERCADO_ID;

-- Restauramos la tabla al estado bueno (antes del UPDATE):
CREATE OR REPLACE TABLE T_DEMO_TT AS
  SELECT * FROM T_DEMO_TT BEFORE(STATEMENT => $bad_qid);
SELECT MERCADO_ID, MERCADO_NOMBRE FROM T_DEMO_TT ORDER BY MERCADO_ID;   -- recuperado


/* ************************************ PARTE 6 ************************************************
   Enmascaramiento dinámico de datos (Dynamic Data Masking).
   Un analista de mercado NO debe ver la identidad de las contrapartes de cada operación
   (información sensible bajo supervisión de la SFC).
******************************************************************************************** */

CREATE ROLE IF NOT EXISTS ANALISTA_MERCADO;
GRANT USAGE ON DATABASE DB_HOL_SETICAP TO ROLE ANALISTA_MERCADO;
GRANT USAGE ON SCHEMA DB_HOL_SETICAP.PUBLIC TO ROLE ANALISTA_MERCADO;
GRANT SELECT ON ALL TABLES IN SCHEMA DB_HOL_SETICAP.PUBLIC TO ROLE ANALISTA_MERCADO;
GRANT USAGE ON WAREHOUSE WH_HOL_SETICAP TO ROLE ANALISTA_MERCADO;

-- Política: solo ADMIN ve la entidad real; el analista ve 999999 (anónimo)
CREATE OR REPLACE MASKING POLICY MP_ENTIDAD AS (val NUMBER) RETURNS NUMBER ->
  CASE
    WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN','SYSADMIN') THEN val
    ELSE 999999
  END;

ALTER TABLE OPERATION_SET_FX MODIFY COLUMN ENTIDAD_COMPRADORA SET MASKING POLICY MP_ENTIDAD;
ALTER TABLE OPERATION_SET_FX MODIFY COLUMN ENTIDAD_VENDEDORA  SET MASKING POLICY MP_ENTIDAD;

-- Como ACCOUNTADMIN vemos las entidades reales
SELECT ID, ENTIDAD_COMPRADORA, ENTIDAD_VENDEDORA, MONTO_USD, PRECIO
FROM OPERATION_SET_FX LIMIT 5;

-- Como ANALISTA_MERCADO se ven enmascaradas
USE ROLE ANALISTA_MERCADO;
USE WAREHOUSE WH_HOL_SETICAP;
SELECT ID, ENTIDAD_COMPRADORA, ENTIDAD_VENDEDORA, MONTO_USD, PRECIO
FROM DB_HOL_SETICAP.PUBLIC.OPERATION_SET_FX LIMIT 5;

USE ROLE ACCOUNTADMIN;


/* ************************************ PARTE 7 ************************************************
   Cortex AI Functions: análisis de mercado con IA generativa.
   Usamos SNOWFLAKE.CORTEX.COMPLETE (texto), SENTIMENT (sentimiento) y SUMMARIZE.
******************************************************************************************** */

-- 7.1 Clasificar el tipo de operación según contexto de mercado
SELECT ID, PRECIO, MONTO_USD, PLAZO_CURVA,
  SNOWFLAKE.CORTEX.COMPLETE('claude-sonnet-4-5',
    'Eres analista del mercado cambiario colombiano. Clasifica esta operación FX en UNA sola palabra ' ||
    'sin formato markdown [Cobertura, Especulacion, Liquidez, Regulatorio]. ' ||
    'USD/COP a ' || PRECIO::VARCHAR || ', monto ' || ROUND(MONTO_USD/1000,0)::VARCHAR ||
    'K USD, plazo ' || COALESCE(PLAZO_CURVA,'T+1') || '. Responde solo la categoría.'
  ) AS tipo_operacion
FROM OPERATION_SET_FX
WHERE ANULADA = FALSE
LIMIT 15;

-- 7.2 Análisis diario de las condiciones del mercado (agregado por día)
SELECT FECHA,
  ROUND(AVG(PRECIO),2) AS trm_prom,
  ROUND(SUM(MONTO_USD)/1e6,1) AS volumen_musd,
  COUNT(*) AS num_ops,
  SNOWFLAKE.CORTEX.COMPLETE('claude-sonnet-4-5',
    'Analiza en UNA sola frase sin formato markdown las condiciones del mercado FX colombiano: TRM promedio ' ||
    ROUND(AVG(PRECIO),2)::VARCHAR || ' COP/USD, volumen ' ||
    ROUND(SUM(MONTO_USD)/1e6,1)::VARCHAR || 'M USD en ' || COUNT(*)::VARCHAR || ' operaciones.'
  ) AS analisis_ia
FROM OPERATION_SET_FX
WHERE ANULADA = FALSE
GROUP BY FECHA
ORDER BY FECHA DESC
LIMIT 7;

-- 7.3 Perspectiva de mercado a partir de las notas de los traders.
--     IMPORTANTE: SENTIMENT mide el TONO emocional del texto, NO la dirección del mercado
--     (una nota "alcista" puede tener tono negativo). Para clasificar la dirección usamos
--     COMPLETE (semánticamente correcto) y mostramos SENTIMENT aparte solo como tono.
SELECT ID, TEXTO_TERM,
  TRIM(SNOWFLAKE.CORTEX.COMPLETE('claude-sonnet-4-5',
    'Eres analista FX. Según esta nota de un trader del mercado USD/COP colombiano, clasifica la ' ||
    'PERSPECTIVA del peso en UNA palabra sin markdown: Alcista (TRM sube / peso se deprecia), ' ||
    'Bajista (TRM baja / peso se aprecia) o Neutral. Nota: ' || TEXTO_TERM || '. Responde solo la palabra.'
  )) AS perspectiva_mercado,
  ROUND(SNOWFLAKE.CORTEX.SENTIMENT(TEXTO_TERM), 2) AS tono_nota
FROM OPERATION_SET_FX
WHERE TEXTO_TERM IS NOT NULL AND TEXTO_TERM <> ''
LIMIT 25;

-- 7.4 Resumen ejecutivo del mercado del último mes con datos
SELECT SNOWFLAKE.CORTEX.SUMMARIZE(
  LISTAGG(DISTINCT TEXTO_TERM, ' ') WITHIN GROUP (ORDER BY TEXTO_TERM)
) AS resumen_mercado
FROM OPERATION_SET_FX
WHERE TEXTO_TERM IS NOT NULL AND TEXTO_TERM <> ''
  AND FECHA >= DATEADD(MONTH, -1, (SELECT MAX(FECHA) FROM OPERATION_SET_FX));


/* ************************************ PARTE 7B **********************************************
   Datos NO estructurados con Cortex AI: imágenes y audio del mercado FX.
   Bucket: s3://demosjparrado/set_icap_hol/archivos/  (assets sintéticos demostrativos)
   - grafico_trm.png   : gráfico de la TRM USD/COP (análisis de imagen / visión)
   - llamada_mesa.mp3  : llamada de una mesa de dinero cerrando una operación (audio)
******************************************************************************************** */

-- Stage dedicado a los archivos no estructurados (DIRECTORY ENABLE para LIST y TO_FILE)
CREATE OR REPLACE STAGE STG_ARCHIVOS_SETICAP
  URL = 's3://demosjparrado/set_icap_hol/archivos/'
  CREDENTIALS = (AWS_KEY_ID='<SOLICITAR_AL_INSTRUCTOR>' AWS_SECRET_KEY='<SOLICITAR_AL_INSTRUCTOR>')
  DIRECTORY = (ENABLE = TRUE);

LIST @STG_ARCHIVOS_SETICAP;

-- 7B.1 Análisis de IMAGEN (visión): leer un gráfico de la TRM e interpretarlo.
SELECT SNOWFLAKE.CORTEX.COMPLETE(
  'pixtral-large',
  PROMPT('Eres analista del mercado cambiario colombiano. Analiza este gráfico de la TRM USD/COP: ' ||
         'describe la tendencia, identifica niveles de soporte y resistencia aproximados y resume ' ||
         'en 3 frases qué le dirías a un trader. {0}',
         TO_FILE('@STG_ARCHIVOS_SETICAP', 'grafico_trm.png'))
) AS lectura_grafico;

-- 7B.2 Análisis de AUDIO: transcribir una llamada de mesa de dinero...
SELECT TO_VARCHAR(AI_TRANSCRIBE(
  TO_FILE('@STG_ARCHIVOS_SETICAP', 'llamada_mesa.mp3')
)) AS transcripcion_llamada;

-- 7B.3 ...y extraer la operación negociada (monto, precio, plazo, contrapartes) de la llamada.
WITH t AS (
  SELECT AI_TRANSCRIBE(TO_FILE('@STG_ARCHIVOS_SETICAP', 'llamada_mesa.mp3')) AS r
)
SELECT
  r:text::STRING AS transcripcion,
  SNOWFLAKE.CORTEX.COMPLETE('claude-sonnet-4-5',
    'De esta llamada de una mesa de dinero FX, extrae en JSON sin markdown los campos ' ||
    'monto_usd, precio_trm, plazo, entidad_compradora, entidad_vendedora. Llamada: ' || r:text::STRING
  ) AS operacion_extraida
FROM t;


/* ************************************ PARTE 8 ⭐ *********************************************
   Dynamic Table: UNA sola tabla de consumo que replica el query del cliente (la "vista plana"
   de Tableau) — uniendo TODAS las tablas del modelo, pero con grano 1 FILA POR OPERACIÓN.
   La contraparte se aplana POR LADO (comprador / vendedor) con LEFT JOIN filtrados por
   OPER_LADO ('C'/'V'), de modo que NO se genera fan-out (cada operación = 1 fila).
   Se refresca de forma AUTOMÁTICA (incremental cuando aplica) sin ETL ni tareas: cuando el
   cliente conecte su ingesta real, la capa de consumo y todas sus métricas se actualizan solas.
   Es la ÚNICA tabla del semantic view de Cortex Analyst => agregaciones siempre correctas.
   (La tabla OPERATION_SET_FX_CONTRAP_COMITENTE —varios comitentes por operación— queda para
    drill-down con SQL directo; NO entra a la tabla plana para no romper el grano.)
******************************************************************************************** */

-- 8.1 La tabla plana OPERACIONES (1 fila por operación, todas las tablas unidas)
CREATE OR REPLACE DYNAMIC TABLE OPERACIONES
  TARGET_LAG   = '1 hour'          -- se puede bajar (p. ej. '1 minute') para más frescura
  WAREHOUSE    = WH_HOL_SETICAP
  REFRESH_MODE = AUTO              -- Snowflake elige incremental cuando es posible (ver 8.2)
AS
SELECT
  o.ID, o.FECHA, o.HORA, o.ANULADA, o.REGISTRO,
  -- Mercado / sub-mercado / paridad / moneda
  o.MERCADO, m.MERCADO_NOMBRE,
  o.SUB_MERCADO, sm.SUBMERCADO_NOMBRE,
  o.PARIDAD_ID, p.NOMBRE AS PARIDAD_NOMBRE,
  cur.CURR_CURRENCY AS MONEDA_UNO_NOMBRE,
  -- Plazos y montos
  o.PLAZO_CURVA, o.DIAS, o.FECHA_VALOR,
  o.MONTO_USD, o.MONTO_MONEDA_DOS AS MONTO_COP,
  o.PRECIO, o.PRECIO_SPOT, o.POINTS_FORWARD,
  o.ENVIADA_CAMARA, o.BANDERA_FISICO_COMPENSACION,
  -- Entidad compradora / vendedora (N:1)
  o.ENTIDAD_COMPRADORA, ec.ENTIDAD_SIGLA AS COMPRADOR_SIGLA, ec.ENTIDAD_NOMBRE AS COMPRADOR_NOMBRE,
  ec.ENTIDAD_CLASE AS COMPRADOR_CLASE, ec.ENTIDAD_CIUDAD AS COMPRADOR_CIUDAD,
  o.ENTIDAD_VENDEDORA, ev.ENTIDAD_SIGLA AS VENDEDOR_SIGLA, ev.ENTIDAD_NOMBRE AS VENDEDOR_NOMBRE,
  ev.ENTIDAD_CLASE AS VENDEDOR_CLASE, ev.ENTIDAD_CIUDAD AS VENDEDOR_CIUDAD,
  -- Contraparte lado COMPRADOR (aplanada por OPER_LADO='C', sin fan-out)
  uc.USUARIO_NOMBRE AS COMPRADOR_TRADER, suc.SUCURSAL_NOMBRE AS COMPRADOR_SUCURSAL,
  cmc.NOMBRE AS COMPRADOR_COMITENTE, cmc.SECTOR AS COMPRADOR_COMITENTE_SECTOR,
  -- Contraparte lado VENDEDOR (aplanada por OPER_LADO='V', sin fan-out)
  uv.USUARIO_NOMBRE AS VENDEDOR_TRADER, suv.SUCURSAL_NOMBRE AS VENDEDOR_SUCURSAL,
  cmv.NOMBRE AS VENDEDOR_COMITENTE, cmv.SECTOR AS VENDEDOR_COMITENTE_SECTOR,
  o.TEXTO_TERM
FROM OPERATION_SET_FX o
JOIN MERCADO m              ON o.MERCADO = m.MERCADO_ID
LEFT JOIN SUB_MERCADO sm    ON o.SUB_MERCADO = sm.SUB_MERCADO_ID
JOIN PARIDAD_MONEDA p       ON o.PARIDAD_ID = p.PARIDAD_ID
LEFT JOIN CURRENCY cur      ON o.MONEDA_UNO = cur.CURR_ID
JOIN ENTIDAD ec             ON o.ENTIDAD_COMPRADORA = ec.ENTIDAD_ID
JOIN ENTIDAD ev             ON o.ENTIDAD_VENDEDORA  = ev.ENTIDAD_ID
LEFT JOIN OPERATION_SET_FX_CONTRAPARTE cpc ON cpc.OPER_ID = o.ID AND cpc.OPER_LADO = 'C'
LEFT JOIN USUARIO   uc      ON cpc.TRADER_ID   = uc.USUARIO_ID
LEFT JOIN SUCURSAL  suc     ON cpc.SUCURSAL_ID = suc.SUCURSAL_ID
LEFT JOIN COMITENTE cmc     ON cpc.COMITENTE_ID = cmc.OFFSHORE_ID
LEFT JOIN OPERATION_SET_FX_CONTRAPARTE cpv ON cpv.OPER_ID = o.ID AND cpv.OPER_LADO = 'V'
LEFT JOIN USUARIO   uv      ON cpv.TRADER_ID   = uv.USUARIO_ID
LEFT JOIN SUCURSAL  suv     ON cpv.SUCURSAL_ID = suv.SUCURSAL_ID
LEFT JOIN COMITENTE cmv     ON cpv.COMITENTE_ID = cmv.OFFSHORE_ID;

-- 8.2 Verifica el modo de refresh y que NO haya fan-out (1 fila por operación):
SHOW DYNAMIC TABLES LIKE 'OPERACIONES';   -- columna refresh_mode debe decir INCREMENTAL
SELECT
  (SELECT COUNT(*) FROM OPERACIONES)        AS filas_operaciones,
  (SELECT COUNT(*) FROM OPERATION_SET_FX)   AS filas_base,
  (SELECT COUNT(*) FROM OPERACIONES) = (SELECT COUNT(*) FROM OPERATION_SET_FX) AS sin_fan_out;

-- 8.3 Métricas de mercado directamente sobre la tabla plana (sin DTs adicionales).
--     VWAP diario (Volume-Weighted Average Price) del USD/COP:
SELECT FECHA,
  ROUND(SUM(PRECIO * MONTO_USD) / NULLIF(SUM(MONTO_USD),0), 2) AS VWAP,
  ROUND(SUM(MONTO_USD)/1e6, 2) AS VOLUMEN_MUSD,
  COUNT(*) AS NUM_OPERACIONES
FROM OPERACIONES
WHERE ANULADA = FALSE AND MERCADO = 76
GROUP BY FECHA
ORDER BY FECHA DESC
LIMIT 15;

--     Ranking de entidades compradoras por volumen (sin fan-out -> conteo correcto):
SELECT COMPRADOR_SIGLA, COMPRADOR_NOMBRE, COMPRADOR_CLASE,
  COUNT(*) AS NUM_OPERACIONES,
  ROUND(SUM(MONTO_USD)/1e6, 1) AS VOLUMEN_COMPRA_MUSD
FROM OPERACIONES
WHERE ANULADA = FALSE
GROUP BY COMPRADOR_SIGLA, COMPRADOR_NOMBRE, COMPRADOR_CLASE
ORDER BY VOLUMEN_COMPRA_MUSD DESC
LIMIT 15;


/* ************************************ PARTE 9 ************************************************
   Streamlit in Snowflake: tablero interactivo del mercado SET-FX.
   Snowsight -> Projects -> Streamlit -> + Streamlit App (warehouse WH_HOL_SETICAP,
   database DB_HOL_SETICAP, schema PUBLIC). Pega el siguiente código.
******************************************************************************************** */
/* Genera el dashboard con un PROMPT en Cortex Code (CoCo) — sin escribir código a mano.
   Abre Cortex Code en tu cuenta, pega el prompt de abajo y CoCo crea el app.py completo,
   conectado a los objetos del HOL, listo para desplegar como Streamlit-in-Snowflake.

   ----------------------------- PROMPT PARA CORTEX CODE -----------------------------
   Crea una app de Streamlit-in-Snowflake VISUALMENTE POTENTE para el mercado de divisas
   SET-FX de SET-ICAP (Colombia). Úsala con get_active_session() y SIN dependencias de red
   externas (solo Streamlit nativo + altair/plotly disponibles en SiS).

   Base de datos: DB_HOL_SETICAP, schema PUBLIC. Fuente principal: la Dynamic Table OPERACIONES
   (1 fila por operación, ya denormalizada). Columnas relevantes:
   - FECHA, HORA, ANULADA, MERCADO, MERCADO_NOMBRE, SUBMERCADO_NOMBRE, PARIDAD_NOMBRE, PLAZO_CURVA
   - MONTO_USD, MONTO_COP, PRECIO (TRM), PRECIO_SPOT, POINTS_FORWARD
   - COMPRADOR_SIGLA / COMPRADOR_NOMBRE / COMPRADOR_CLASE / COMPRADOR_CIUDAD
   - VENDEDOR_SIGLA / VENDEDOR_NOMBRE / VENDEDOR_CLASE / VENDEDOR_CIUDAD
   - COMPRADOR_TRADER, VENDEDOR_TRADER, COMPRADOR_COMITENTE, VENDEDOR_COMITENTE
   No hay tablas pre-agregadas: calcula todo con agregaciones SQL sobre OPERACIONES. Ejemplo:
   VWAP diario = SUM(PRECIO*MONTO_USD)/NULLIF(SUM(MONTO_USD),0) por FECHA, con ANULADA=FALSE y MERCADO=76.

   Diseño (estilo fintech profesional, TEMA OSCURO, branding Snowflake #29B5E8 / #11567F):
   1. Hero con título "SET-FX · Mercado de Divisas", subtítulo y selector de rango de fechas.
   2. Fila de KPI cards grandes con delta/flechas y color: TRM (VWAP) más reciente, variación %
      vs día anterior, volumen del día (M USD), número de operaciones, % anuladas.
   3. Gráfico principal: evolución de la TRM (VWAP diario) tipo línea, con banda min–max sombreada
      (MIN/MAX de PRECIO por día) y tooltip rico.
   4. Barras horizontales: Top 10 entidades compradoras por volumen, coloreadas por COMPRADOR_CLASE.
   5. Profundidad de mercado: compra vs venta por clase de entidad (barras divergentes).
   6. Mapa de calor de actividad por HORA del día vs día de la semana (número de operaciones).
   7. Donut: distribución de volumen por PLAZO_CURVA (T+0, T+1, 3M…).
   8. Tabla de las 50 operaciones más recientes (ORDER BY FECHA, HORA desc) con formato de moneda
      y badges por clase de entidad.
   9. Layout responsive con st.columns y st.container(border=True), tipografía clara, tema oscuro
      elegante con acentos en #29B5E8. Usa @st.cache_data(ttl=300) en todas las consultas y maneja
      el caso de DataFrame vacío.

   Hazlo realmente atractivo: paleta coherente, espaciado generoso, títulos de sección claros y que
   parezca un terminal de trading profesional. Genera el app.py COMPLETO, listo para pegar en
   Snowsight -> Streamlit.
   ----------------------------------------------------------------------------------- */


/* ************************************ PARTE 10 **********************************************
   Capa de IA conversacional: Cortex Analyst (datos estructurados) + Cortex Search (texto).
   - Cortex Analyst responde con cifras/SQL sobre la tabla plana OPERACIONES.
   - Cortex Search permite buscar en texto libre: notas de mercado y catálogo de entidades.
   Ambos alimentan al agente de la Parte 11.
******************************************************************************************** */

-- 10.1 CORTEX ANALYST — Semantic View sobre la tabla ÚNICA OPERACIONES (text-to-SQL).
--   Snowsight -> AI & ML -> Cortex Analyst -> Create -> Semantic View:
--     Tabla ÚNICA: OPERACIONES (Dynamic Table plana de la Parte 8) — SIN relaciones, SIN fan-out.
--     Métricas: volumen_usd=SUM(MONTO_USD), num_operaciones=COUNT(ID),
--               vwap=SUM(PRECIO*MONTO_USD)/SUM(MONTO_USD), trm_promedio=AVG(PRECIO)
--     Dimensiones: FECHA, PLAZO_CURVA, MERCADO_NOMBRE, PARIDAD_NOMBRE,
--                  COMPRADOR_SIGLA/NOMBRE/CLASE, VENDEDOR_SIGLA/CLASE
--   O simplemente importa HOL_SET_ICAP_semantic_model.yaml (nombre del modelo: SV_SET_FX).

-- 10.2 CORTEX SEARCH sobre las NOTAS de mercado (texto libre de los traders).
CREATE OR REPLACE CORTEX SEARCH SERVICE CS_NOTAS_MERCADO
  ON TEXTO_TERM                                            -- campo de búsqueda semántica
  ATTRIBUTES FECHA, MERCADO_NOMBRE, COMPRADOR_SIGLA, VENDEDOR_SIGLA, PLAZO_CURVA
  WAREHOUSE = WH_HOL_SETICAP
  TARGET_LAG = '1 hour'
  AS
  SELECT TEXTO_TERM, FECHA, MERCADO_NOMBRE, COMPRADOR_SIGLA, VENDEDOR_SIGLA, PLAZO_CURVA
  FROM OPERACIONES
  WHERE TEXTO_TERM IS NOT NULL AND TEXTO_TERM <> '';

-- 10.3 CORTEX SEARCH sobre el catálogo de ENTIDADES (descubrir/desambiguar contrapartes).
CREATE OR REPLACE CORTEX SEARCH SERVICE CS_ENTIDADES
  ON ENTIDAD_NOMBRE
  ATTRIBUTES ENTIDAD_SIGLA, ENTIDAD_CLASE, ENTIDAD_TIPO, ENTIDAD_CIUDAD
  WAREHOUSE = WH_HOL_SETICAP
  TARGET_LAG = '1 hour'
  AS
  SELECT ENTIDAD_NOMBRE, ENTIDAD_SIGLA, ENTIDAD_CLASE, ENTIDAD_TIPO, ENTIDAD_CIUDAD
  FROM ENTIDAD;

-- Verifica el estado de los servicios
SHOW CORTEX SEARCH SERVICES;

-- Demo de búsqueda semántica: notas que mencionen intervención del emisor
SELECT PARSE_JSON(SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
  'CS_NOTAS_MERCADO',
  '{ "query": "intervención del Banco de la República en el mercado", "columns": ["TEXTO_TERM","FECHA","MERCADO_NOMBRE"], "limit": 5 }'
))['results'] AS notas;

-- Demo: descubrir entidades por nombre/atributo en lenguaje natural
SELECT PARSE_JSON(SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
  'CS_ENTIDADES',
  '{ "query": "comisionistas de bolsa en Medellín", "columns": ["ENTIDAD_NOMBRE","ENTIDAD_SIGLA","ENTIDAD_CLASE","ENTIDAD_CIUDAD"], "limit": 5 }'
))['results'] AS entidades;


/* ************************************ PARTE 11 **********************************************
   Snowflake CoWork: un Agente Cortex que responde en lenguaje natural combinando las tres
   herramientas de la Parte 10. Se crea en la UI (no por SQL):
   Snowsight -> AI & ML -> Snowflake CoWork -> + Crear agente.
   --------------------------------------------------------------------------------------------
   1. Datos del agente
        Nombre: AGT_SETICAP
        DB/Schema: DB_HOL_SETICAP.PUBLIC
   2. Tools -> Add tool (las tres herramientas de la Parte 10):
        - Cortex Analyst -> Semantic View SV_SET_FX   (métricas / text-to-SQL sobre OPERACIONES)
        - Cortex Search   -> CS_NOTAS_MERCADO          (buscar en notas de los traders)
        - Cortex Search   -> CS_ENTIDADES              (descubrir / desambiguar contrapartes)
   3. Orchestration instructions (instrucciones de orquestación):
        "Eres un analista experto del mercado cambiario colombiano SET-FX de SET-ICAP.
         Decide la herramienta según la intención del usuario:
         - Si piden CIFRAS, métricas, rankings, volúmenes, TRM, VWAP, comparaciones o tendencias,
           usa Cortex Analyst (SV_SET_FX).
         - Si piden buscar, citar o resumir NOTAS de mercado / comentarios de traders,
           usa Cortex Search CS_NOTAS_MERCADO.
         - Si mencionan una ENTIDAD por nombre parcial, sigla o atributo (clase, ciudad, tipo) y
           hay que identificarla o listarla, usa Cortex Search CS_ENTIDADES; si luego piden cifras
           de esa entidad, encadena con Cortex Analyst usando la sigla/nombre encontrado.
         Cita siempre las dimensiones o los identificadores usados. Razona y responde SIEMPRE en español."
   4. Response instructions (instrucciones de respuesta):
        "Responde en español, con cifras claras (TRM en COP/USD, volumen en millones de USD) y
         contexto del mercado OTC. Al final, propón 2 o 3 preguntas de seguimiento para profundizar.
         TODO el contenido generado, INCLUIDO el razonamiento paso a paso, debe estar en español."
   5. Preguntas demo (cubren las tres herramientas):
        - (Analyst)  ¿Cuál fue el VWAP del USD/COP la última semana?
        - (Analyst)  Compara el volumen negociado entre bancos y comisionistas el último mes.
        - (Search notas) Busca notas que mencionen intervención del Banco de la República.
        - (Search entidades) ¿Qué comisionistas de bolsa hay en Medellín?
        - (Encadenado) ¿Cuánto volumen compró la entidad cuya sigla se parece a 'BBVA'?
******************************************************************************************** */


/* ************************************ PARTE 12 **********************************************
   Limpieza: eliminamos los objetos del HOL.
******************************************************************************************** */
DROP DATABASE IF EXISTS DB_HOL_SETICAP;
DROP WAREHOUSE IF EXISTS WH_HOL_SETICAP;
DROP ROLE IF EXISTS ANALISTA_MERCADO;

-- ¡Felicitaciones! Completaste el HOL de SET-ICAP: carga masiva desde S3, Cortex AI,
-- Dynamic Tables y Snowflake CoWork sobre el mercado de divisas SET-FX.
