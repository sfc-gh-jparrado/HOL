/* ****************************************************************************************************
  __               _   _           _       
 / _|             | | | |         | |      
| |_ _ __ ___  ___| |_| |__  _   _| |_ ___ 
|  _| '__/ _ \/ __| __| '_ \| | | | __/ _ \
| | | | | (_) \__ \ |_| |_) | |_| | ||  __/
|_| |_|  \___/|___/\__|_.__/ \__, |\__\___|
                              __/ |        
                             |___/         
Descripción: 
  Script para configurar nuestro ambiente de trabajo. Se creara la base de datos, warehouse, 
  tablas y se cargaran los datos con los que trabajaremos durante la sesión.
*******************************************************************************************************

IMPORTANTE: Este script debe descargarse y ejecutarse en un workbook de Snowflake.

***************************************************************************************************** */

USE ROLE accountadmin;
drop database IF EXISTS frostbyte_tasty_bytes_dev;
drop warehouse IF EXISTS tasty_dsci_wh;
DROP ROLE IF EXISTS tasty_bytes_admin;
DROP ROLE IF EXISTS tasty_bytes_ds_role;


-- create base de datos y esquemas:
CREATE OR REPLACE DATABASE frostbyte_tasty_bytes_dev;

-- raw zone para data ingestion
CREATE OR REPLACE SCHEMA frostbyte_tasty_bytes_dev.raw;

-- harmonized zone para data processing
CREATE OR REPLACE SCHEMA frostbyte_tasty_bytes_dev.harmonized;

-- analytics zone para development
CREATE OR REPLACE SCHEMA frostbyte_tasty_bytes_dev.analytics;

-- crear un file format para CSV
CREATE OR REPLACE FILE FORMAT frostbyte_tasty_bytes_dev.raw.csv_ff 
type = 'csv';

-- crear un external stage que apunta a S3
CREATE OR REPLACE STAGE frostbyte_tasty_bytes_dev.raw.s3load
COMMENT = 'Quickstarts S3 Stage Connection'
url = 's3://sfquickstarts/frostbyte_tastybytes/'
file_format = frostbyte_tasty_bytes_dev.raw.csv_ff;


-- crear y usuar el compute warehouse 
CREATE OR REPLACE WAREHOUSE tasty_dsci_wh AUTO_SUSPEND = 60;
USE WAREHOUSE tasty_dsci_wh;
show warehouses;

---------------------------------------------------------------
---------------------------------------------------------------
-------- CREATE TABLES/VIEWS PARA SNOWPARK 101  ----------------
---------------------------------------------------------------
---------------------------------------------------------------

-- definir tabla de ventas por turno
CREATE OR REPLACE TABLE frostbyte_tasty_bytes_dev.raw.shift_sales(
	location_id NUMBER(19,0),
	city VARCHAR(16777216),
	date DATE,
	shift_sales FLOAT,
	shift VARCHAR(2),
	month NUMBER(2,0),
	day_of_week NUMBER(2,0),
	city_population NUMBER(38,0)
);

-- Cargar desde S3 en la tabla de ventas por turno
COPY INTO frostbyte_tasty_bytes_dev.raw.shift_sales
FROM @frostbyte_tasty_bytes_dev.raw.s3load/analytics/shift_sales/;


-- Complementemos esta información con datos externos y disponibles en el MARKETPLACE!
-- Vamos al marketplace y buscamos: frostbyte
-- Selecciona el dataset llamado "SafeGraph: frostbyte"
-- Coloca al dataset el nombre FROSTBYTE_SAFEGRAPH (en mayusculas)
-- selecciona adicional el rol public para visualizar el dataset y dale GET.
-- Ahora, ya tienes acceso a una nueva BD sin necesidad de realizar copias de información!



-- Hagamos un join de nuestra tabla, con el dataset que acabamos de integrar desde el marketplace
CREATE OR REPLACE TABLE frostbyte_tasty_bytes_dev.harmonized.shift_sales
  AS
SELECT
    a.location_id,
    a.city,
    a.date,
    a.shift_sales,
    a.shift,
    a.month,
    a.day_of_week,
    a.city_population,
    b.latitude,
    b.longitude,
    b.location_name
FROM frostbyte_tasty_bytes_dev.raw.shift_sales a
JOIN frostbyte_safegraph.public.frostbyte_tb_safegraph_s b
ON a.location_id = b.location_id;

-- Promover la tabla armonizada a la capa de analítica para el desarrollo de ciencia de datos.
CREATE OR REPLACE VIEW frostbyte_tasty_bytes_dev.analytics.shift_sales_v
  AS
SELECT * FROM frostbyte_tasty_bytes_dev.harmonized.shift_sales;

-- Visualizar datos de ventas por turno
SELECT * FROM frostbyte_tasty_bytes_dev.analytics.shift_sales_v;

--
-- Ya que tenemos los datos, podemos pasar a CARGAR el NOTEBOOK en la base de datos frostbyte_tasty_bytes_dev.analytics
