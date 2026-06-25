/* ********************************************************************************************
                   HANDS ON LAB - SET-ICAP | Mercado de Divisas SET-FX
                   "De S3 a Snowflake Intelligence"
********************************************************************************************
 SET-ICAP es la compañía líder en negociación y registro de divisas y valores OTC en Colombia.
 Filial de la Bolsa de Valores de Colombia (BVC) y de TP ICAP Group. Opera el sistema
 electrónico SET-FX, principal fuente de información del dólar en Colombia.

 Este HOL recorre 12 partes. Copia todo el contenido en un Worksheet de Snowflake y ejecuta
 cada parte en orden. Comentarios y notas en español.

 Recorrido: cargas 400M filas desde S3 a velocidad de warehouse, construyes una capa de
 consumo viva con Dynamic Tables, analizas el mercado con Cortex AI y expones todo a un
 agente de Snowflake Intelligence.

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
   - operation_set_fx: 30 archivos × ~150 MB (120M filas) → ideal para XLARGE (16 nodos)
   - operation_set_fx_contraparte: 8 archivos × ~130 MB (240M filas)
   - operation_set_fx_contrap_comitente: 2 archivos × ~130 MB (40M filas)
   Todos en el rango óptimo 100-250 MB que recomienda Snowflake.
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

-- 🧪 DEMO DE SCALING: cargamos 120 MILLONES de operaciones (30 archivos) con SMALL
ALTER WAREHOUSE WH_HOL_SETICAP SET WAREHOUSE_SIZE = 'SMALL';
COPY INTO OPERATION_SET_FX FROM @STG_SETICAP/hist/operation_set_fx/;
-- ⏱ Medido REAL: 53 segundos con SMALL (2 nodos) para 120M filas. Ya es rápido... pero observa:

-- Vaciamos y recargamos lo mismo con XLARGE para comparar
TRUNCATE TABLE OPERATION_SET_FX;
ALTER WAREHOUSE WH_HOL_SETICAP SET WAREHOUSE_SIZE = 'XLARGE';
COPY INTO OPERATION_SET_FX FROM @STG_SETICAP/hist/operation_set_fx/;
-- ⏱ Medido REAL: 23 segundos con XLARGE (16 nodos). Mismo dato, mismo S3.
--    2.3x más rápido porque los 30 archivos se distribuyen entre 16 nodos.
--    LECCIÓN: el paralelismo depende del NÚMERO DE ARCHIVOS, no solo del warehouse.
--    Con 30 archivos de 150 MB, XLARGE aprovecha todos sus nodos. ¡Pagas por segundo!

/* 🧪 EXPERIMENTO OPCIONAL — "¿y si uso un 2XLARGE?" (la trampa del sobre-dimensionamiento)
   Intuición común: "más grande = más rápido". Probémoslo y midamos de verdad:
     TRUNCATE TABLE OPERATION_SET_FX;
     ALTER WAREHOUSE WH_HOL_SETICAP SET WAREHOUSE_SIZE = '2XLARGE';   -- 32 nodos
     COPY INTO OPERATION_SET_FX FROM @STG_SETICAP/hist/operation_set_fx/;
     ALTER WAREHOUSE WH_HOL_SETICAP SET WAREHOUSE_SIZE = 'XLARGE';    -- vuelve a XLARGE

   ⏱ Medido REAL: 2XLARGE = ~63s  vs  XLARGE = ~23s  → ¡el 2XLARGE es MÁS LENTO!
   ¿Por qué? Solo hay 30 archivos: un XLARGE (16 nodos) ya los reparte casi 2:1.
   Un 2XLARGE (32 nodos) deja nodos OCIOSOS y suma overhead de coordinación,
   mientras cuesta el DOBLE de créditos/segundo.
   LECCIÓN para el cliente: dimensiona por el NÚMERO DE ARCHIVOS, no por instinto.
   Para 30 archivos de 150 MB, XLARGE es el punto óptimo costo/rendimiento. */

-- Cargamos las otras 2 tablas grandes con XLARGE (seguimos en XLARGE)
COPY INTO OPERATION_SET_FX_CONTRAPARTE          FROM @STG_SETICAP/hist/operation_set_fx_contraparte/;          -- 240M, 8 archivos: ~30s medido
COPY INTO OPERATION_SET_FX_CONTRAP_COMITENTE    FROM @STG_SETICAP/hist/operation_set_fx_contrap_comitente/;    -- 40M, 2 archivos: ~18s medido

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

-- ---------------------------------------------------------------------------
-- CAPA DE CONSUMO: la tabla denormalizada OPERACIONES (la que usa Cortex Analyst)
-- no se construye aquí con un CTAS estático. En la PARTE 8 la creamos como
-- DYNAMIC TABLE: se refresca de forma incremental sobre el histórico, sin tener
-- que reconstruirla a mano. Continúa con la Parte 5 (Time Travel).


/* ************************************ PARTE 5 ************************************************
   Time Travel y Zero-Copy Cloning.
******************************************************************************************** */

-- TRM promedio de hace 7 días vs hoy (Time Travel sobre el histórico)
SELECT 'hoy'  AS momento, ROUND(AVG(PRECIO),2) AS trm FROM OPERATION_SET_FX
WHERE FECHA = (SELECT MAX(FECHA) FROM OPERATION_SET_FX)
UNION ALL
SELECT 'inicio', ROUND(AVG(PRECIO),2) FROM OPERATION_SET_FX
WHERE FECHA = (SELECT MIN(FECHA) FROM OPERATION_SET_FX);

-- Clonado instantáneo de toda la base para un ambiente de análisis (sin duplicar storage)
CREATE OR REPLACE DATABASE DB_HOL_SETICAP_DEV CLONE DB_HOL_SETICAP;

-- Simular un borrado accidental y recuperarlo
DROP TABLE OPERATION_SET_FX;
UNDROP TABLE OPERATION_SET_FX;
SELECT COUNT(*) AS sigue_disponible FROM OPERATION_SET_FX;


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

-- 7.3 Sentimiento de las notas de los traders (SENTIMENT retorna FLOAT -1..1)
SELECT ID, TEXTO_TERM,
  ROUND(SNOWFLAKE.CORTEX.SENTIMENT(TEXTO_TERM), 2) AS score,
  CASE
    WHEN SNOWFLAKE.CORTEX.SENTIMENT(TEXTO_TERM) > 0.3 THEN 'Alcista'
    WHEN SNOWFLAKE.CORTEX.SENTIMENT(TEXTO_TERM) < -0.3 THEN 'Bajista'
    ELSE 'Neutral'
  END AS sentimiento_mercado
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


/* ************************************ PARTE 8 ⭐ *********************************************
   Dynamic Tables: la capa analítica que se refresca SOLA (sin ETL, sin tareas).
   OPERACIONES deja de ser un CTAS manual y se vuelve una Dynamic Table: se mantiene
   al día de forma INCREMENTAL sobre el histórico (solo procesa filas nuevas o cambiadas,
   no reconstruye los 120M). Cuando el cliente conecte su ingesta real, la capa de consumo
   y sus métricas se actualizan solas. Sobre ella encadenamos las métricas de mercado,
   que la siguen automáticamente (TARGET_LAG=DOWNSTREAM).
   Cadena: OPERATION_SET_FX -> OPERACIONES (DT) -> DT_VWAP_DIARIO / DT_RANKING_ENTIDADES
******************************************************************************************** */

-- 8.1 CAPA DE CONSUMO como Dynamic Table denormalizada (la que usa Cortex Analyst).
-- Resuelve nombres de entidad (compradora/vendedora), mercado y paridad en UNA sola tabla
-- plana. Todos los joins son N:1 (cada operación tiene exactamente un comprador, un vendedor,
-- un mercado) => refresh INCREMENTAL + CERO fan-out => agregaciones siempre correctas en
-- Cortex Analyst y Snowflake CoWork. Es la ÚNICA tabla del semantic view.
-- TARGET_LAG = DOWNSTREAM: se refresca tan seguido como lo necesiten sus DT derivadas (5 min).
CREATE OR REPLACE DYNAMIC TABLE OPERACIONES
  TARGET_LAG   = DOWNSTREAM
  WAREHOUSE    = WH_HOL_SETICAP
  REFRESH_MODE = INCREMENTAL
AS
SELECT
  o.ID, o.FECHA, o.HORA, o.ANULADA,
  o.MERCADO, m.MERCADO_NOMBRE,
  o.SUB_MERCADO,
  o.PLAZO_CURVA, o.DIAS, o.FECHA_VALOR,
  o.MONTO_USD, o.MONTO_MONEDA_DOS AS MONTO_COP,
  o.PRECIO, o.PRECIO_SPOT, o.POINTS_FORWARD,
  o.PARIDAD_ID, p.NOMBRE AS PARIDAD_NOMBRE,
  o.ENTIDAD_COMPRADORA, ec.ENTIDAD_SIGLA AS COMPRADOR_SIGLA, ec.ENTIDAD_NOMBRE AS COMPRADOR_NOMBRE, ec.ENTIDAD_CLASE AS COMPRADOR_CLASE, ec.ENTIDAD_CIUDAD AS COMPRADOR_CIUDAD,
  o.ENTIDAD_VENDEDORA,  ev.ENTIDAD_SIGLA AS VENDEDOR_SIGLA,  ev.ENTIDAD_NOMBRE AS VENDEDOR_NOMBRE,  ev.ENTIDAD_CLASE AS VENDEDOR_CLASE,  ev.ENTIDAD_CIUDAD AS VENDEDOR_CIUDAD,
  o.REGISTRO, o.ENVIADA_CAMARA, o.BANDERA_FISICO_COMPENSACION,
  o.TEXTO_TERM
FROM OPERATION_SET_FX o
JOIN MERCADO m         ON o.MERCADO = m.MERCADO_ID
JOIN PARIDAD_MONEDA p  ON o.PARIDAD_ID = p.PARIDAD_ID
JOIN ENTIDAD ec        ON o.ENTIDAD_COMPRADORA = ec.ENTIDAD_ID
JOIN ENTIDAD ev        ON o.ENTIDAD_VENDEDORA  = ev.ENTIDAD_ID;

-- Verifica el refresh y que sea INCREMENTAL (no FULL):
SHOW DYNAMIC TABLES LIKE 'OPERACIONES';
SELECT COUNT(*) AS filas_operaciones, COUNT(DISTINCT COMPRADOR_SIGLA) AS entidades FROM OPERACIONES;

-- 8.2 VWAP diario (Volume-Weighted Average Price) del USD/COP
CREATE OR REPLACE DYNAMIC TABLE DT_VWAP_DIARIO
  TARGET_LAG = '5 minutes'
  WAREHOUSE  = WH_HOL_SETICAP
AS
  SELECT
    FECHA,
    ROUND(SUM(PRECIO * MONTO_USD) / NULLIF(SUM(MONTO_USD),0), 2) AS VWAP,
    ROUND(SUM(MONTO_USD)/1e6, 2) AS VOLUMEN_MUSD,
    COUNT(*) AS NUM_OPERACIONES,
    MIN(PRECIO) AS PRECIO_MIN,
    MAX(PRECIO) AS PRECIO_MAX,
    ROUND(MAX(PRECIO) - MIN(PRECIO), 2) AS RANGO
  FROM OPERACIONES
  WHERE ANULADA = FALSE AND MERCADO = 76
  GROUP BY FECHA;

SELECT * FROM DT_VWAP_DIARIO ORDER BY FECHA DESC LIMIT 15;

-- 8.3 Ranking de entidades más activas (volumen comprado)
-- OPERACIONES ya tiene el nombre/clase resuelto (sin fan-out): agregación directa.
CREATE OR REPLACE DYNAMIC TABLE DT_RANKING_ENTIDADES
  TARGET_LAG = '5 minutes'
  WAREHOUSE  = WH_HOL_SETICAP
AS
  SELECT
    COMPRADOR_SIGLA AS ENTIDAD_SIGLA,
    COMPRADOR_NOMBRE AS ENTIDAD_NOMBRE,
    COMPRADOR_CLASE AS ENTIDAD_CLASE,
    COUNT(*) AS NUM_OPERACIONES,
    ROUND(SUM(MONTO_USD)/1e6, 1) AS VOLUMEN_COMPRA_MUSD
  FROM OPERACIONES
  WHERE ANULADA = FALSE
  GROUP BY COMPRADOR_SIGLA, COMPRADOR_NOMBRE, COMPRADOR_CLASE
  ORDER BY VOLUMEN_COMPRA_MUSD DESC;

SELECT * FROM DT_RANKING_ENTIDADES LIMIT 15;


/* ************************************ PARTE 9 ************************************************
   Streamlit in Snowflake: tablero interactivo del mercado SET-FX.
   Snowsight -> Projects -> Streamlit -> + Streamlit App (warehouse WH_HOL_SETICAP,
   database DB_HOL_SETICAP, schema PUBLIC). Pega el siguiente código.
******************************************************************************************** */
/*
import streamlit as st
import pandas as pd
import altair as alt
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="SET-FX | Mercado de Divisas", layout="wide")
session = get_active_session()

st.title("SET-FX · Tablero del Mercado de Divisas")
st.caption("SET-ICAP · Datos sintéticos demostrativos")

@st.cache_data(ttl=300)
def q(sql):
    return session.sql(sql).to_pandas()

vwap = q("SELECT * FROM DT_VWAP_DIARIO ORDER BY FECHA")
rank = q("SELECT * FROM DT_RANKING_ENTIDADES LIMIT 10")

c1, c2, c3 = st.columns(3)
c1.metric("TRM más reciente (VWAP)", f"{vwap['VWAP'].iloc[-1]:,.2f}")
c2.metric("Volumen último día (M USD)", f"{vwap['VOLUMEN_MUSD'].iloc[-1]:,.1f}")
c3.metric("Operaciones último día", f"{int(vwap['NUM_OPERACIONES'].iloc[-1]):,}")

st.subheader("Evolución de la TRM (VWAP diario)")
st.altair_chart(
    alt.Chart(vwap).mark_line(point=True).encode(
        x="FECHA:T", y=alt.Y("VWAP:Q", scale=alt.Scale(zero=False)),
        tooltip=["FECHA","VWAP","VOLUMEN_MUSD"]
    ).properties(height=320), use_container_width=True)

st.subheader("Top 10 entidades por volumen comprado")
st.altair_chart(
    alt.Chart(rank).mark_bar().encode(
        x="VOLUMEN_COMPRA_MUSD:Q", y=alt.Y("ENTIDAD_SIGLA:N", sort="-x"),
        tooltip=["ENTIDAD_NOMBRE","VOLUMEN_COMPRA_MUSD","NUM_OPERACIONES"]
    ).properties(height=320), use_container_width=True)
*/

/* --- OPCIÓN B: genera un dashboard visualmente potente con Cortex Code (CoCo) ---
   En lugar del código base de arriba, abre Cortex Code en tu cuenta y pega este
   prompt. CoCo genera el app.py completo conectado a los objetos del HOL.

   ----------------------------- PROMPT PARA CORTEX CODE -----------------------------
   Crea una app de Streamlit-in-Snowflake visualmente potente para el mercado de
   divisas SET-FX de SET-ICAP (Colombia). Úsala con get_active_session() y SIN
   dependencias de red externas (solo altair/plotly nativos).

   Base de datos: DB_HOL_SETICAP, schema PUBLIC. Objetos disponibles:
   - DT_VWAP_DIARIO (FECHA, VWAP, VOLUMEN_MUSD, NUM_OPERACIONES, PRECIO_MIN, PRECIO_MAX, RANGO)
   - DT_RANKING_ENTIDADES (ENTIDAD_SIGLA, ENTIDAD_NOMBRE, ENTIDAD_CLASE, NUM_OPERACIONES, VOLUMEN_COMPRA_MUSD)
   - OPERATION_SET_FX (ID, FECHA, HORA, ANULADA, MERCADO, MONTO_USD, MONTO_MONEDA_DOS, PRECIO, PLAZO_CURVA, ENTIDAD_COMPRADORA, ENTIDAD_VENDEDORA, TEXTO_TERM)
   - OPERACIONES (Dynamic Table denormalizada: + COMPRADOR_NOMBRE/CLASE, VENDEDOR_NOMBRE/CLASE, MERCADO_NOMBRE, PARIDAD_NOMBRE)
   - ENTIDAD (ENTIDAD_ID, ENTIDAD_SIGLA, ENTIDAD_NOMBRE, ENTIDAD_CLASE)
   - MERCADO (MERCADO_ID, MERCADO_NOMBRE)

   Requisitos visuales (estilo fintech profesional, branding Snowflake #29B5E8 / #11567F):
   1. Encabezado con título "SET-FX - Mercado de Divisas" y selector de rango de fechas.
   2. Fila de KPI cards: TRM más reciente (VWAP), variación % vs día anterior,
      volumen del día (M USD), núm operaciones, % anuladas. Con flechas de tendencia y color.
   3. Gráfico principal: evolución de la TRM (VWAP diario) tipo línea con banda min-max
      (área sombreada PRECIO_MIN-PRECIO_MAX) y tooltip rico.
   4. Barras horizontales: Top 10 entidades por volumen comprado, coloreadas por ENTIDAD_CLASE.
   5. Profundidad de mercado: comparativo compra vs venta por entidad (barras divergentes).
   6. Mapa de calor de actividad por hora del día vs día de la semana (núm operaciones).
   7. Donut: distribución de volumen por PLAZO_CURVA (T+1, 3M, etc.).
   8. Tabla de operaciones más recientes (OPERACIONES ordenado por FECHA y HORA desc, top 50)
      con formato de moneda y badges por ENTIDAD_CLASE.
   9. Layout responsive con st.columns, st.container(border=True), métricas grandes,
      tema oscuro elegante y tipografía clara. Usa @st.cache_data(ttl=300) en las consultas.

   Genera el app.py completo, listo para pegar en Snowsight -> Streamlit. No uses
   librerías que requieran instalación externa más allá de las disponibles en SiS.
   ----------------------------------------------------------------------------------- */


/* ************************************ PARTE 10 ***********************************************
   Semantic View para Cortex Analyst (creación asistida en Snowsight UI).
   Snowsight -> AI & ML -> Cortex Analyst -> Create -> Semantic View. Selecciona:
     Tabla ÚNICA: OPERACIONES (Dynamic Table plana denormalizada de la Parte 8)
       → Una sola tabla, SIN relaciones que definir, SIN riesgo de fan-out.
         Esto garantiza agregaciones correctas en Cortex Analyst y Snowflake CoWork.
         Al ser Dynamic Table, el modelo semántico se mantiene al día automáticamente.
     Métricas: total_volumen_usd = SUM(MONTO_USD), num_operaciones = COUNT(ID),
               vwap = SUM(PRECIO*MONTO_USD)/SUM(MONTO_USD), trm_promedio = AVG(PRECIO)
     Dimensiones: FECHA, PLAZO_CURVA, MERCADO_NOMBRE, PARIDAD_NOMBRE,
                  COMPRADOR_SIGLA, COMPRADOR_NOMBRE, COMPRADOR_CLASE,
                  VENDEDOR_SIGLA, VENDEDOR_CLASE
   (También puedes importar el archivo HOL_SET_ICAP_semantic_model.yaml de este repositorio.)
   NOTA: las tablas de detalle (CONTRAPARTE 240M, COMITENTE 40M) NO se incluyen en el
   modelo semántico — tienen múltiples filas por operación y causarían doble conteo.
   Quedan disponibles para drill-down con SQL directo cuando se requiera.
******************************************************************************************** */


/* ************************************ PARTE 11 **********************************************
   Snowflake Intelligence: un Agente Cortex que responde en lenguaje natural.
   Snowsight -> AI & ML -> Agents (Snowflake Intelligence) -> Create agent.
     Nombre: AGT_SETICAP
     Herramientas:
       - Cortex Analyst -> Semantic View SV_SET_FX (creada en la Parte 10)
       - Cortex Search (opcional) sobre TEXTO_TERM para notas de mercado
     Instrucciones (system prompt):
       "Eres un analista experto del mercado cambiario colombiano SET-FX de SET-ICAP.
        Respondes en español, con cifras claras (TRM, volumen en millones de USD) y
        contexto del mercado OTC. Usa la Semantic View para todas las consultas de datos."
     Preguntas demo:
       - ¿Cuál fue el VWAP del USD/COP la última semana?
       - ¿Qué entidad negoció el mayor volumen el último mes?
       - ¿Cuántas operaciones forward se hicieron a plazo 3M?
       - Compara el volumen de bancos vs comisionistas.
******************************************************************************************** */


/* ************************************ PARTE 12 **********************************************
   Limpieza: eliminamos los objetos del HOL.
******************************************************************************************** */
DROP DATABASE IF EXISTS DB_HOL_SETICAP_DEV;
DROP DATABASE IF EXISTS DB_HOL_SETICAP;
DROP WAREHOUSE IF EXISTS WH_HOL_SETICAP;
DROP ROLE IF EXISTS ANALISTA_MERCADO;

-- ¡Felicitaciones! Completaste el HOL de SET-ICAP: carga masiva desde S3, Cortex AI,
-- Dynamic Tables y Snowflake Intelligence sobre el mercado de divisas SET-FX.
