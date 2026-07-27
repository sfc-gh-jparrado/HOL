USE SCHEMA HOL_SEC.INCIDENTE;
ALTER WAREHOUSE HOL_WH SET WAREHOUSE_SIZE = LARGE;
USE WAREHOUSE HOL_WH;

-- limpiar modelo generico anterior
DROP TABLE IF EXISTS AUTH_LOGINS;
DROP TABLE IF EXISTS EXPORT_EVENTS;
DROP TABLE IF EXISTS CUSTOMERS;

-- ===================== DIMENSIONES =====================
CREATE OR REPLACE TABLE BANCOS (banco STRING, tipo STRING);
INSERT INTO BANCOS VALUES
 ('Bancolombia','Establecimiento'),('Davivienda','Establecimiento'),
 ('BBVA Colombia','Establecimiento'),('Banco de Bogota','Establecimiento'),
 ('Nequi','SEDPE'),('Daviplata','SEDPE'),
 ('Banco de Occidente','Establecimiento'),('Scotiabank Colpatria','Establecimiento'),
 ('Itau','Establecimiento'),('Banco Popular','Establecimiento'),
 ('Banco Caja Social','Establecimiento'),('Banco AV Villas','Establecimiento'),
 ('Banco Agrario','Establecimiento'),('Bancoomeva','Cooperativo'),
 ('Banco Falabella','Establecimiento'),('Banco Pichincha','Establecimiento'),
 ('GNB Sudameris','Establecimiento'),('Banco Serfinanza','Establecimiento'),
 ('Lulo Bank','Neobanco'),('Nu Colombia','Neobanco');

CREATE OR REPLACE TABLE COMERCIOS AS
SELECT (SEQ8()+1)::NUMBER AS comercio_id,
       'Comercio '||(SEQ8()+1) AS nombre,
       ARRAY_CONSTRUCT('Retail','Servicios publicos','Educacion','Salud','Gobierno','Telco','Seguros','Viajes')[UNIFORM(0,7,RANDOM())]::STRING AS categoria
FROM TABLE(GENERATOR(ROWCOUNT=>500));
INSERT INTO COMERCIOS VALUES (9001,'MegaTiendaOnline','Retail');

-- ===================== FACT: PSE_TRANSACTIONS 30M =====================
CREATE OR REPLACE TABLE PSE_TRANSACTIONS (
  txn_id NUMBER, ts TIMESTAMP_NTZ, banco STRING, comercio_id NUMBER,
  monto NUMBER, canal STRING, estado STRING, tipo_persona STRING,
  documento_hash STRING, ciudad STRING);

INSERT INTO PSE_TRANSACTIONS
WITH base AS (
  SELECT SEQ8() AS txn_id,
         DATEADD('second', -UNIFORM(0, 3888000, RANDOM()), CURRENT_TIMESTAMP()) AS ts,
         UNIFORM(0,19,RANDOM())  AS bidx,
         UNIFORM(1,500,RANDOM()) AS comercio_id,
         UNIFORM(1,2000000,RANDOM()) AS didx,
         UNIFORM(0,6,RANDOM())   AS cidx,
         UNIFORM(1,100,RANDOM())  AS er,
         UNIFORM(1,100,RANDOM())  AS mr,
         UNIFORM(0,1,RANDOM())    AS ch,
         UNIFORM(1,100,RANDOM())  AS pr
  FROM TABLE(GENERATOR(ROWCOUNT=>30000000))
)
SELECT txn_id,
       ts,
       ARRAY_CONSTRUCT('Bancolombia','Davivienda','BBVA Colombia','Banco de Bogota','Nequi','Daviplata','Banco de Occidente','Scotiabank Colpatria','Itau','Banco Popular','Banco Caja Social','Banco AV Villas','Banco Agrario','Bancoomeva','Banco Falabella','Banco Pichincha','GNB Sudameris','Banco Serfinanza','Lulo Bank','Nu Colombia')[bidx]::STRING AS banco,
       comercio_id::NUMBER AS comercio_id,
       (CASE WHEN mr<=70 THEN UNIFORM(10000,500000,RANDOM())
             WHEN mr<=95 THEN UNIFORM(500000,3000000,RANDOM())
             ELSE UNIFORM(3000000,20000000,RANDOM()) END)::NUMBER AS monto,
       IFF(ch=0,'WEB','APP') AS canal,
       (CASE WHEN er<=85 THEN 'APROBADA' WHEN er<=93 THEN 'RECHAZADA'
             WHEN er<=96 THEN 'PENDIENTE' WHEN er<=98 THEN 'TIMEOUT' ELSE 'REVERSADA' END) AS estado,
       IFF(pr<=80,'NATURAL','JURIDICA') AS tipo_persona,
       'DOC'||LPAD(didx,8,'0') AS documento_hash,
       ARRAY_CONSTRUCT('Bogota','Medellin','Cali','Barranquilla','Bucaramanga','Cartagena','Pereira')[cidx]::STRING AS ciudad
FROM base;

-- ===================== ANOMALIAS 03:00 de ayer =====================
-- A1: anillo de fraude -> comercio 9001, ~50 documentos x ~40 txns rapidas, 2 ciudades (velocity + salto imposible)
INSERT INTO PSE_TRANSACTIONS
SELECT 50000000+SEQ8(),
       DATEADD('second', UNIFORM(0,1800,RANDOM()), DATEADD('hour',3,DATEADD('day',-1,DATE_TRUNC('day',CURRENT_TIMESTAMP())))),
       ARRAY_CONSTRUCT('Bancolombia','Davivienda','Nequi','Daviplata','Lulo Bank','Nu Colombia')[UNIFORM(0,5,RANDOM())]::STRING,
       9001,
       UNIFORM(80000,120000,RANDOM()),
       'WEB',
       IFF(UNIFORM(1,100,RANDOM())<=90,'APROBADA','RECHAZADA'),
       'NATURAL',
       'DOC'||LPAD(UNIFORM(90000000,90000050,RANDOM()),8,'0'),
       IFF(UNIFORM(0,1,RANDOM())=0,'Bogota','Medellin')
FROM TABLE(GENERATOR(ROWCOUNT=>2000));

-- A2: pico de rechazos de un banco (posible caida/ataque)
INSERT INTO PSE_TRANSACTIONS
SELECT 51000000+SEQ8(),
       DATEADD('second', UNIFORM(0,3600,RANDOM()), DATEADD('hour',3,DATEADD('day',-1,DATE_TRUNC('day',CURRENT_TIMESTAMP())))),
       'Scotiabank Colpatria',
       UNIFORM(1,500,RANDOM()),
       UNIFORM(50000,2000000,RANDOM()),
       IFF(UNIFORM(0,1,RANDOM())=0,'WEB','APP'),
       'RECHAZADA','NATURAL',
       'DOC'||LPAD(UNIFORM(1,2000000,RANDOM()),8,'0'),'Bogota'
FROM TABLE(GENERATOR(ROWCOUNT=>1500));

-- A3: montos atipicos hacia comercio 9001 (>3 sigma)
INSERT INTO PSE_TRANSACTIONS
SELECT 52000000+SEQ8(),
       DATEADD('second', UNIFORM(0,1800,RANDOM()), DATEADD('hour',3,DATEADD('day',-1,DATE_TRUNC('day',CURRENT_TIMESTAMP())))),
       'Bancolombia', 9001,
       UNIFORM(80000000,200000000,RANDOM()),
       'WEB','APROBADA','JURIDICA',
       'DOC'||LPAD(UNIFORM(90000000,90000050,RANDOM()),8,'0'),'Bogota'
FROM TABLE(GENERATOR(ROWCOUNT=>15));

-- ===================== UNLOAD a S3 =====================
COPY INTO @stg_hol/pse_hist/data_ FROM PSE_TRANSACTIONS
  FILE_FORMAT=(TYPE=CSV FIELD_DELIMITER=';' COMPRESSION=GZIP) HEADER=TRUE MAX_FILE_SIZE=80000000 OVERWRITE=TRUE;
COPY INTO @stg_hol/comercios/data_ FROM COMERCIOS
  FILE_FORMAT=(TYPE=CSV FIELD_DELIMITER=';' COMPRESSION=GZIP) HEADER=TRUE MAX_FILE_SIZE=80000000 OVERWRITE=TRUE;

SELECT 'PSE_TRANSACTIONS' AS tabla, COUNT(*) AS filas FROM PSE_TRANSACTIONS
UNION ALL SELECT 'COMERCIOS', COUNT(*) FROM COMERCIOS
UNION ALL SELECT 'BANCOS', COUNT(*) FROM BANCOS;
