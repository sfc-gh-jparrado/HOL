/* ============================================================================
   HOL CredibanCo - RFP 10010806
   T3 - Arquitectura y Data Fabric

   Equipo    : Arquitectura
   Duracion  : 30 minutos
   Prerrequisito: haber ejecutado install_arquitectura.sql en esta cuenta

   Comprobar que el dato queda en formato abierto y legible por otros motores, y que los dominios pueden publicar y gobernar sus propios productos de datos sin pasar por un equipo central.
   ==========================================================================*/


-- ==========================================================================
-- Paso 1. El dato en formato abierto, sobre su propio almacenamiento
-- Verificar que la tabla vive en Parquet e Iceberg en el bucket de CredibanCo.
-- ==========================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_ANALITICA;

-- el volumen externo apunta al bucket de CredibanCo: el dato no queda en un
-- almacenamiento opaco del proveedor
SHOW EXTERNAL VOLUMES LIKE 'EV_HOL_CB';
DESC EXTERNAL VOLUME EV_HOL_CB;

-- tabla Iceberg gestionada por Snowflake sobre el bucket propio.
-- Gestionada significa que Snowflake mantiene los metadatos y las
-- optimizaciones, pero los archivos son Parquet y el catalogo es Iceberg.
CREATE OR REPLACE ICEBERG TABLE CB_GOLD.PRODUCTOS.VENTAS_ICEBERG (
    COMERCIO_ID           NUMBER(12,0),
    RAZON_SOCIAL          STRING,
    SECTOR                STRING,
    CIUDAD_COMERCIO       STRING,
    DEPARTAMENTO          STRING,
    MES                   DATE,
    TRX_TOTAL             NUMBER(18,0),
    TRX_APROBADAS         NUMBER(18,0),
    MONTO_APROBADO_COP    NUMBER(24,2),
    TICKET_PROMEDIO_COP   NUMBER(18,2),
    CLIENTES_UNICOS       NUMBER(18,0)
)
    CATALOG = 'SNOWFLAKE'
    EXTERNAL_VOLUME = 'EV_HOL_CB'
    BASE_LOCATION = 'iceberg/ventas_mensuales/'
    COMMENT = 'Producto de datos de ventas en formato abierto Apache Iceberg';

INSERT INTO CB_GOLD.PRODUCTOS.VENTAS_ICEBERG
SELECT COMERCIO_ID, RAZON_SOCIAL, SECTOR, CIUDAD_COMERCIO, DEPARTAMENTO, MES,
       TRX_TOTAL, TRX_APROBADAS, MONTO_APROBADO_COP, TICKET_PROMEDIO_COP,
       CLIENTES_UNICOS
FROM CB_GOLD.PRODUCTOS.VENTAS_MENSUALES_COMERCIO;

SELECT COUNT(*) AS FILAS_EN_ICEBERG FROM CB_GOLD.PRODUCTOS.VENTAS_ICEBERG;

-- donde quedaron los archivos y cual es el metadato Iceberg vigente.
-- Esta ruta se le puede entregar a Spark, Trino, Flink o Athena tal cual.
SELECT SYSTEM$GET_ICEBERG_TABLE_INFORMATION('CB_GOLD.PRODUCTOS.VENTAS_ICEBERG') AS UBICACION_Y_METADATO;

-- se consulta igual que cualquier tabla, con el mismo SQL y las
-- mismas politicas de gobierno
SELECT SECTOR,
       COUNT(DISTINCT COMERCIO_ID)            AS COMERCIOS,
       ROUND(SUM(MONTO_APROBADO_COP)/1e9, 2)  AS MILES_MILLONES_COP
FROM CB_GOLD.PRODUCTOS.VENTAS_ICEBERG
GROUP BY SECTOR
ORDER BY MILES_MILLONES_COP DESC
LIMIT 10;

-- y admite Time Travel como una tabla nativa: se borra algo y se recupera.
-- No se usa AT(OFFSET => -60) porque la tabla acaba de crearse y hace un
-- minuto no existia.
DELETE FROM CB_GOLD.PRODUCTOS.VENTAS_ICEBERG WHERE SECTOR = 'Joyerías';

-- se guarda el identificador del borrado: solo un statement de DML sirve como
-- punto de referencia para Time Travel
SET QID_BORRADO = LAST_QUERY_ID();

SELECT COUNT(*) AS DESPUES_DEL_BORRADO FROM CB_GOLD.PRODUCTOS.VENTAS_ICEBERG;

SELECT COUNT(*) AS ANTES_DEL_BORRADO
FROM CB_GOLD.PRODUCTOS.VENTAS_ICEBERG BEFORE(STATEMENT => $QID_BORRADO);

-- recuperar lo borrado desde la version anterior de la propia tabla
INSERT INTO CB_GOLD.PRODUCTOS.VENTAS_ICEBERG
SELECT * FROM CB_GOLD.PRODUCTOS.VENTAS_ICEBERG BEFORE(STATEMENT => $QID_BORRADO)
WHERE SECTOR = 'Joyerías';

SELECT COUNT(*) AS RECUPERADO FROM CB_GOLD.PRODUCTOS.VENTAS_ICEBERG;

CALL CB_PLATAFORMA.EVIDENCIA.LOG_EVIDENCIA('T3',
    'Producto de datos en formato abierto Iceberg sobre almacenamiento propio',
    'CB_GOLD.PRODUCTOS.VENTAS_ICEBERG en el volumen externo EV_HOL_CB',
    'Tabla Iceberg gestionada con archivos Parquet en el bucket de CredibanCo, ruta de metadata.json entregable a otros motores y Time Travel disponible',
    'Anexo 10 - 5.3 formatos abiertos y portabilidad multi-engine');


-- ==========================================================================
-- Paso 2. Dominios con dueno propio
-- Que cada dominio administre y publique lo suyo sin el equipo central.
-- ==========================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_ANALITICA;

-- los tres dominios y sus roles ya existen desde la instalacion
SHOW SCHEMAS LIKE 'DOM_%' IN DATABASE CB_GOLD;

GRANT USAGE ON WAREHOUSE WH_ANALITICA TO ROLE RL_DOM_RIESGO;
GRANT USAGE ON WAREHOUSE WH_ANALITICA TO ROLE RL_DOM_ADQUIRENCIA;
GRANT USAGE ON DATABASE CB_SILVER TO ROLE RL_DOM_RIESGO;
GRANT USAGE ON SCHEMA CB_SILVER.ADQUIRENCIA TO ROLE RL_DOM_RIESGO;
GRANT SELECT ON ALL TABLES IN SCHEMA CB_SILVER.ADQUIRENCIA TO ROLE RL_DOM_RIESGO;

-- GRANT no acepta IDENTIFIER(CURRENT_USER()) directo: hay que pasar por una
-- variable de sesion
SET MI_USUARIO = CURRENT_USER();
GRANT ROLE RL_DOM_RIESGO TO USER IDENTIFIER($MI_USUARIO);
GRANT ROLE RL_DOM_ADQUIRENCIA TO USER IDENTIFIER($MI_USUARIO);

-- el dominio Riesgo publica su propio producto de datos.
-- Lo hace con SU rol, en SU esquema, sin intervencion del equipo de plataforma.
USE ROLE RL_DOM_RIESGO;
USE WAREHOUSE WH_ANALITICA;

CREATE OR REPLACE TABLE CB_GOLD.DOM_RIESGO.SENALES_FRAUDE_COMERCIO
    COMMENT = 'Producto de datos del dominio Riesgo. Senales de fraude agregadas por comercio. SLA de frescura: diaria 06:00. Dueno: Vicepresidencia de Riesgo'
AS
SELECT COMERCIO_ID,
       SECTOR,
       CIUDAD_COMERCIO,
       DEPARTAMENTO,
       COUNT(*)                                             AS TRX_TOTAL,
       COUNT_IF(MARCA_FRAUDE)                               AS TRX_FRAUDE,
       ROUND(100.0 * COUNT_IF(MARCA_FRAUDE) / COUNT(*), 4)  AS TASA_FRAUDE_PCT,
       COUNT_IF(ES_INTERNACIONAL)                           AS TRX_INTERNACIONALES,
       COUNT_IF(MODO_ENTRADA = 'ECOMMERCE')                 AS TRX_ECOMMERCE,
       ROUND(SUM(IFF(MARCA_FRAUDE, MONTO_COP, 0)) / 1e6, 2) AS MONTO_FRAUDE_MILLONES
FROM CB_SILVER.ADQUIRENCIA.AUTORIZACIONES
GROUP BY COMERCIO_ID, SECTOR, CIUDAD_COMERCIO, DEPARTAMENTO
HAVING COUNT(*) >= 50;

SELECT COUNT(*) AS COMERCIOS_EN_EL_PRODUCTO FROM CB_GOLD.DOM_RIESGO.SENALES_FRAUDE_COMERCIO;

-- el contrato del producto: quien es dueno, que frescura garantiza,
-- que clasificacion tiene. Sin contrato, un producto de datos es una tabla mas.
ALTER TABLE CB_GOLD.DOM_RIESGO.SENALES_FRAUDE_COMERCIO
    SET TAG CB_PLATAFORMA.GOBIERNO.DOMINIO = 'RIESGO',
            CB_PLATAFORMA.GOBIERNO.CLASIFICACION = 'FINANCIERO',
            CB_PLATAFORMA.GOBIERNO.CONFIDENCIALIDAD = 'CONFIDENCIAL',
            CB_PLATAFORMA.GOBIERNO.PCI_CDE = 'FUERA';

-- y el dominio Riesgo decide, por su cuenta, quien lo consume
GRANT USAGE ON SCHEMA CB_GOLD.DOM_RIESGO TO ROLE RL_DOM_ADQUIRENCIA;
GRANT SELECT ON TABLE CB_GOLD.DOM_RIESGO.SENALES_FRAUDE_COMERCIO TO ROLE RL_DOM_ADQUIRENCIA;

-- el dominio Adquirencia consume el producto del dominio Riesgo
USE ROLE RL_DOM_ADQUIRENCIA;
USE WAREHOUSE WH_ANALITICA;

SELECT SECTOR,
       COUNT(*)                       AS COMERCIOS,
       ROUND(AVG(TASA_FRAUDE_PCT), 4) AS TASA_FRAUDE_PROMEDIO,
       ROUND(SUM(MONTO_FRAUDE_MILLONES), 1) AS MONTO_FRAUDE_MILLONES
FROM CB_GOLD.DOM_RIESGO.SENALES_FRAUDE_COMERCIO
GROUP BY SECTOR
ORDER BY TASA_FRAUDE_PROMEDIO DESC
LIMIT 10;

-- y NO puede escribir en el dominio ajeno
USE ROLE RL_DOM_ADQUIRENCIA;
CREATE TABLE CB_GOLD.DOM_RIESGO.INTRUSION (X NUMBER(1,0));

USE ROLE ACCOUNTADMIN;
CALL CB_PLATAFORMA.EVIDENCIA.LOG_EVIDENCIA('T3',
    'Dominio publica su producto de datos y otorga acceso por su cuenta',
    'CB_GOLD.DOM_RIESGO.SENALES_FRAUDE_COMERCIO con contrato en etiquetas',
    'El rol del dominio Riesgo creo el producto, le puso contrato y dueno, y concedio acceso al dominio Adquirencia sin intervencion del equipo central',
    'Anexo 10 - 5.2 data mesh con gobierno federado y 2.9 contratos de datos');


-- ==========================================================================
-- Paso 3. Catalogo de negocio y de casos de uso
-- Que un no tecnico encuentre el dato y sepa si puede confiar en el.
-- ==========================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_ANALITICA;

-- catalogo de casos de uso de analitica: lo que el criterio 6 pide de forma
-- explicita y casi nadie tiene. Vincula caso de uso, dominio, producto y modelo.
CREATE TABLE IF NOT EXISTS CB_PLATAFORMA.GOBIERNO.CATALOGO_CASOS_USO (
    CASO_USO_ID    VARCHAR(20) NOT NULL,
    NOMBRE         VARCHAR(200),
    DOMINIO        VARCHAR(40),
    ESTADO         VARCHAR(30),
    DESCRIPCION    VARCHAR(1000),
    PRODUCTOS      VARCHAR(500) COMMENT 'Productos de datos que consume',
    MODELO         VARCHAR(200) COMMENT 'Modelo o agente asociado, si aplica',
    DUENO_NEGOCIO  VARCHAR(120),
    CONSTRAINT PK_CASOS_USO PRIMARY KEY (CASO_USO_ID)
) COMMENT = 'Catalogo de casos de uso de analitica de CredibanCo';

MERGE INTO CB_PLATAFORMA.GOBIERNO.CATALOGO_CASOS_USO t
USING (
    SELECT * FROM VALUES
      ('UC-01','DaInsight','MONETIZACION','EN PRODUCCION',
       'Analitica de comportamiento de compra comercializada a terceros.',
       'VENTAS_MENSUALES_COMERCIO, VENTAS_ICEBERG', NULL, 'Gerencia de Datos'),
      ('UC-02','Open Data / DataConnect','MONETIZACION','EN PRODUCCION',
       'Exposicion controlada de indicadores agregados a bancos y pasarelas.',
       'VENTAS_MENSUALES_COMERCIO', NULL, 'Gerencia de Datos'),
      ('UC-03','Customer 360','CLIENTE','EN PRODUCCION',
       'Vision unica del tarjetahabiente para campanas y servicio.',
       'CUSTOMER_360', NULL, 'Vicepresidencia Comercial'),
      ('UC-04','Churn de comercio','ADQUIRENCIA','EN PRODUCCION',
       'Prediccion de abandono de comercio afiliado para retencion proactiva.',
       'COMERCIO_FEATURES_CHURN', 'MODELO_CHURN_COMERCIO', 'Vicepresidencia Comercial'),
      ('UC-05','Senales de fraude','RIESGO','EN PRODUCCION',
       'Deteccion de patrones de fraude por comercio y canal.',
       'SENALES_FRAUDE_COMERCIO', NULL, 'Vicepresidencia de Riesgo'),
      ('UC-06','Vinculacion inteligente','ADQUIRENCIA','EN DESARROLLO',
       'Priorizacion de prospectos de afiliacion por potencial transaccional.',
       'VENTAS_MENSUALES_COMERCIO, CUSTOMER_360', NULL, 'Vicepresidencia Comercial')
    AS s(CASO_USO_ID,NOMBRE,DOMINIO,ESTADO,DESCRIPCION,PRODUCTOS,MODELO,DUENO_NEGOCIO)
) s ON t.CASO_USO_ID = s.CASO_USO_ID
WHEN NOT MATCHED THEN INSERT
    (CASO_USO_ID,NOMBRE,DOMINIO,ESTADO,DESCRIPCION,PRODUCTOS,MODELO,DUENO_NEGOCIO)
    VALUES (s.CASO_USO_ID,s.NOMBRE,s.DOMINIO,s.ESTADO,s.DESCRIPCION,s.PRODUCTOS,
            s.MODELO,s.DUENO_NEGOCIO);

SELECT DOMINIO, ESTADO, COUNT(*) AS CASOS_USO
FROM CB_PLATAFORMA.GOBIERNO.CATALOGO_CASOS_USO
GROUP BY DOMINIO, ESTADO
ORDER BY DOMINIO;

-- inventario por dominio. SYSTEM$GET_TAG exige el nombre del objeto
-- como literal y ACCOUNT_USAGE.TAG_REFERENCES tiene latencia de horas, asi que
-- el inventario se materializa con TAG_REFERENCES, que es inmediato.
CREATE OR REPLACE VIEW CB_PLATAFORMA.GOBIERNO.VW_INVENTARIO_POR_DOMINIO AS
SELECT * FROM TABLE(CB_GOLD.INFORMATION_SCHEMA.TAG_REFERENCES('CB_GOLD.PRODUCTOS.VENTAS_MENSUALES_COMERCIO','TABLE'))
UNION ALL SELECT * FROM TABLE(CB_GOLD.INFORMATION_SCHEMA.TAG_REFERENCES('CB_GOLD.DOM_RIESGO.SENALES_FRAUDE_COMERCIO','TABLE'))
UNION ALL SELECT * FROM TABLE(CB_SILVER.INFORMATION_SCHEMA.TAG_REFERENCES('CB_SILVER.ADQUIRENCIA.AUTORIZACIONES','TABLE'))
UNION ALL SELECT * FROM TABLE(CB_SILVER.INFORMATION_SCHEMA.TAG_REFERENCES('CB_SILVER.ADQUIRENCIA.COMERCIOS','TABLE'))
UNION ALL SELECT * FROM TABLE(CB_SILVER.INFORMATION_SCHEMA.TAG_REFERENCES('CB_SILVER.ADQUIRENCIA.TARJETAHABIENTES','TABLE'));

SELECT TAG_VALUE AS DOMINIO,
       OBJECT_DATABASE || '.' || OBJECT_SCHEMA || '.' || OBJECT_NAME AS OBJETO
FROM CB_PLATAFORMA.GOBIERNO.VW_INVENTARIO_POR_DOMINIO
WHERE TAG_NAME = 'DOMINIO'
ORDER BY DOMINIO, OBJETO;

-- el comentario del objeto es parte del catalogo, no documentacion aparte
SELECT TABLE_SCHEMA AS DOMINIO,
       TABLE_NAME   AS PRODUCTO,
       ROW_COUNT    AS FILAS,
       COMMENT      AS CONTRATO
FROM CB_GOLD.INFORMATION_SCHEMA.TABLES
WHERE COMMENT IS NOT NULL
  AND TABLE_SCHEMA LIKE 'DOM%'
ORDER BY TABLE_SCHEMA;

CALL CB_PLATAFORMA.EVIDENCIA.LOG_EVIDENCIA('T3',
    'Catalogo de negocio y catalogo de casos de uso de analitica',
    'CB_PLATAFORMA.GOBIERNO.CATALOGO_CASOS_USO con los 6 casos de uso vigentes',
    'Casos de uso vinculados a dominio, producto de datos, modelo y dueno de negocio, mas inventario por dominio derivado de las etiquetas',
    'Anexo 10 - 5.2 catalogo de negocio y catalogo de casos de uso');


-- ==========================================================================
-- Cierre: evidencia del track
-- ==========================================================================

-- Resumen de lo ejecutado en este track. Es el artefacto que se entrega al
-- cierre, como exige el numeral 3.2 del Anexo 11.
SELECT PASO, OBJETO, RESULTADO, REQUISITO, EJECUTADO_POR, ROL, MOMENTO
FROM CB_PLATAFORMA.EVIDENCIA.ARTEFACTOS
WHERE TRACK = 'T3'
ORDER BY MOMENTO;

SELECT * FROM CB_PLATAFORMA.EVIDENCIA.VW_EVIDENCIA_POR_TRACK
WHERE TRACK = 'T3';
