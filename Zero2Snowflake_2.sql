/* ********************************** HANDS ON LAB ********************************************* /
Este archivo SQL es un guía para el Hands on Lab (HoL) sobre la cuenta
de prueba en Snowflake.
Por favor copia todo el contenido de este archivo en un worksheet de Snowflake
************************************************************************************************/


/* ************************************ PARTE 1 ***************************************************
 Definiremos nuestro ambiente: Base de datos y warehouse (capacidad de cómputo)
 Nota: Estas tareas las puedes hacer vía línea de comandos o interfaz gráfica.
*************************************************************************************************/
use role accountadmin;

-- Crear base de datos
----------------------
CREATE OR REPLACE DATABASE DB_EMPRESA COMMENT = 'Base de datos de prueba para HOL EMPRESA';

-- Crear warehouse
CREATE OR REPLACE WAREHOUSE COMPUTE_HOL_WH
WITH WAREHOUSE_SIZE = 'SMALL'
   WAREHOUSE_TYPE = 'STANDARD'
   AUTO_SUSPEND = 15
   AUTO_RESUME = TRUE
   MIN_CLUSTER_COUNT = 1
   MAX_CLUSTER_COUNT = 2
   SCALING_POLICY = 'STANDARD';

-- definir el warehouse, database y schema que utilizaremos.
------------------------------------------------------------
use warehouse COMPUTE_HOL_WH;
use database DB_EMPRESA;
use schema public;


/* ************************************ PARTE 2 **********************************************
 Crearemos  una tabla y un stage externo que apunta a AWS S3.
 Nota: Existen dos tipos de Stage: Interno y externo. El Interno es dentro de Snowflake
       y muy útil cuando no contamos con un data lake o queremos obtener un mejor desempeño.
       Externo puede ser hacia AWS S3, GCP Cloud Storage o Azure Data Lake Storage y Blob Storage
*********************************************************************************************/

-- Creemos nuestra TABLE T_CLIENTES
------------------------------
create or replace table T_CLIENTES
(tripduration integer,
starttime timestamp,
stoptime timestamp,
start_station_id integer,
start_station_name string,
start_station_latitude float,
start_station_longitude float,
end_station_id integer,
end_station_name string,
end_station_latitude float,
end_station_longitude float,
bikeid integer,
membership_type string,
usertype string,
birth_year integer,
gender integer);


-- Creemos nuestro STAGE que apunta a un S3
-------------------------------------------
CREATE STAGE "DB_EMPRESA"."PUBLIC".STG_CLIENTES
URL = 's3://snowflake-workshop-lab/japan/citibike-trips/' -- bucket en S3 a donde está apuntando nuestro Stage
COMMENT = 'Stage Externo para el cargado de datos de Clientes';


-- Listemos los archivos qué tenemos en nuestro Stage
-----------------------------------------------------
list @STG_CLIENTES;


-- Creemos un file format para describir datos que utilizaremos
---------------------------------------------------------------
CREATE OR REPLACE FILE FORMAT DB_EMPRESA.PUBLIC.CSV
TYPE = 'CSV'
COMPRESSION = 'AUTO'
FIELD_DELIMITER = ','
RECORD_DELIMITER = '\n'
SKIP_HEADER = 0
FIELD_OPTIONALLY_ENCLOSED_BY = '\042'
TRIM_SPACE = FALSE
ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
ESCAPE = 'NONE'
ESCAPE_UNENCLOSED_FIELD = '\134'
DATE_FORMAT = 'AUTO'
TIMESTAMP_FORMAT = 'AUTO'
NULL_IF = ('')
COMMENT = 'Formato de archivo para el cargado de los datos de Clientes';


-- Validemos que datos en el Stage, estén en el formato que previamente creamos
select $1, $2, $3, $4, $5
from @stg_clientes/trips_2013_0_0_0.csv.gz
(file_format => CSV)
limit 10;


/* ************************************ PARTE 3 *****************************************
 Copiaremos los datos de S3 a nuestra tabla trips. Para esto se utilizará nuestro
 warehouse previamente creado.
****************************************************************************************/


-- Copiemos los datos y anotemos el tiempo de ejecución (lo utilizaremos en un momento)
---------------------------------------------------------------------------------------
copy into T_CLIENTES
from @stg_clientes/trips
file_format=CSV;


-- ¿Cuántos registros cargamos a la tabla?
-----------------------------------------
select count(*) from T_CLIENTES;


-- Hagamos una prueba rápida de performance.
--------------------------------------------
truncate table T_CLIENTES;




-- Cambiemos el tamaño del warehouse
------------------------------------
ALTER WAREHOUSE "COMPUTE_HOL_WH"
SET WAREHOUSE_SIZE = 'XLARGE'
    AUTO_SUSPEND = 15
    AUTO_RESUME = TRUE;


-- Copiamos los datos a la tabla y comparemos con el tiempo de ejecución anterior.
----------------------------------------------------------------------------------
copy into T_CLIENTES
from @stg_clientes/trips
file_format=CSV;


-- ¿Cuántos registros tenemos en la tabla?
-----------------------------------------
select count(*) from T_CLIENTES;


-- Ahora, reduzcamos el tamaño del warehouse
--------------------------------------------
alter warehouse COMPUTE_HOL_WH set warehouse_size = 'SMALL';




/* ************************************ PARTE 4 *****************************************
 Utilizaremos el cache y el zero copy cloning. Estas funcionalidades son óptimas para
 ahorrar tiempos de procesamiento y almacenamiento.
 Vamos adelante!
****************************************************************************************/


-- Demos un vistazo rápido a nuestros datos (solo 20 registros)
---------------------------------------------------------------
select * from T_CLIENTES limit 20;


-- Analicemos y ejecutemos la siguiente consulta:
-------------------------------------------------
select
date_trunc('hour', starttime) as "date",
count(*) as "num trips",
avg(tripduration)/60 as "avg duration (mins)",
avg(haversine(start_station_latitude, start_station_longitude, end_station_latitude, end_station_longitude)) as "avg distance (km)",
60*("avg distance (km)"/"avg duration (mins)") "Speed km/h"
from T_CLIENTES
group by 1 order by 1;


-- Volvamos a ejecutar el query anterior para ver el uso del caché
------------------------------------------------------------------
-- Ahora utilicemos el Zero Copy Cloning!
-- Esta funcionalidad puede aplicarse sobre una tabla, esquema o incluso una base de datos completa!
----------------------------------------------------------------------------------------------------


-- Clonemos nuestra tabla trips
-------------------------------
create table t_clientes_dev CLONE t_clientes;


-- Clonemos nuestra BD
----------------------
create or replace database DB_EMPRESA_DEV CLONE DB_EMPRESA;


-- Un error intencional. Borremos la base de datos de producción.
------------------------------------------
drop database DB_EMPRESA;


-- No hay que llamar un DBA para reestablecer un buckup.
undrop database DB_EMPRESA;


-- actualicemos una columna para simular un error
-------------------------------------------------
update t_clientes set start_station_name = 'UUPS! Un error de actualizacion.';


select
start_station_name as "station",
count(*) as "rides"
from t_clientes
group by 1
order by 2 desc
limit 20;


-- Todo es auditable en Snowflake.
-- Recuperemos el id de la última transacción
------------------------------------------------------------------------------
set query_id =
(select query_id from
table(information_schema.query_history_by_session (result_limit=>5))
where query_text like 'update%' order by start_time limit 1);


select $query_id;


-- Recreamos la tabla antes de la última ejecución
--------------------------------------------------------
create or replace table t_clientes as
(select * from t_clientes before (statement => $query_id));


-- Verifiquemos que nuestros datos esten bien.
select
start_station_name as "station",
count(*) as "rides"
from t_clientes
group by 1
order by 2 desc
limit 20;




/* ************************************ PARTE 5 *****************************************
 Archivos JSON no son un problema en Snowflake.
 Vamos adelante!
****************************************************************************************/
-- Creemos una nueva base de datos
----------------------------------
create or replace database db_clima;


-- Creemos una tabla
--------------------
create or replace table t_json_datos_clima (v variant);


-- Creemos un nuevo Stage
-------------------------
create stage stg_clima
url = 's3://snowflake-workshop-lab/weather-nyc';


-- ¿Qué archivos tenemos en el nuevo Stage?
------------------------------------------
list @stg_clima;


-- Copiemos datos del stage a la tabla
--------------------------------------
copy into t_json_datos_clima
from @stg_clima
file_format = (type=json);


-- ¿Qué datos tiene la tabla?
----------------------------
select * from t_json_datos_clima limit 10;


-- Creemos una vista con el json aplanado
-----------------------------------------
create or replace view vw_json_datos_clima as
  select
        v:time::timestamp as observation_time,
        v:city.id::int as city_id,
        v:city.name::string as city_name,
        v:city.country::string as country,
        v:city.coord.lat::float as city_lat,
        v:city.coord.lon::float as city_lon,
        v:clouds.all::int as clouds,
        (v:main.temp::float)-273.15 as temp_avg,
        (v:main.temp_min::float)-273.15 as temp_min,
        (v:main.temp_max::float)-273.15 as temp_max,
        v:weather[0].main::string as weather,
        v:weather[0].description::string as weather_desc,
        v:weather[0].icon::string as weather_icon,
        v:wind.deg::float as wind_dir,
        v:wind.speed::float as wind_speed
  from t_json_datos_clima
  where city_id = 5128638;


-- Consultemos la información del clima para un mes
---------------------------------------------------
select *
from vw_json_datos_clima
where date_trunc('month',observation_time) = '2018-01-01'
limit 20;


-- Crucemos y analicemos la información de viajes y clima
---------------------------------------------------------
select weather as conditions
  ,count(*) as num_trips
from DB_EMPRESA.public.t_clientes
left outer join vw_json_datos_clima
  on date_trunc('hour', observation_time) = date_trunc('hour', starttime)
where conditions is not null
group by 1 order by 2 desc;




/* ************************************ PARTE 6 *****************************************
 Enmascaramiento dinámico para gobernar los datos evaluando el rol que desea consumir los datos
 Fácil y rápido!
****************************************************************************************/
use role accountadmin;
use database DB_EMPRESA;


-- Creemos un nuevo rol
-----------------------
create or replace role OPERADOR_JUNIOR;


-- Agrega tu nombre de usuario
------------------------------
grant role OPERADOR_JUNIOR to user TU_USUARIO; ------ REEMPLAZA POR TU USUARIO


-- Permisos para nuestro Operador Junior
-----------------------------------
grant usage on database DB_EMPRESA to role OPERADOR_JUNIOR;
grant usage on schema public to role OPERADOR_JUNIOR;
grant select on all tables in schema DB_EMPRESA.public to role OPERADOR_JUNIOR;
grant usage on database db_clima to role OPERADOR_JUNIOR;
grant usage on warehouse COMPUTE_HOL_WH to role OPERADOR_JUNIOR;


-- Creemos una política de enmascaramiento dinámico
---------------------------------------------------
create or replace masking policy membership_mask as (val string)
returns string ->
case
  when current_role() in ('OPERADOR_JUNIOR') then '*******'
  else val
end;


-- Asociemos la política de enmascaramiento a una tabla y columna
-----------------------------------------------------------------
alter table t_clientes modify column membership_type set masking policy membership_mask;


-- Consultemos la tabla con el rol del administrador
----------------------------------------------------
select membership_type, count(1)
from t_clientes
group by membership_type;


-- Consultemos la tabla con el rol del Operador junior
-----------------------------------------------------------------
use role OPERADOR_JUNIOR;


-- Confirmemos que los datos no serán expuestos al Operador junior
-------------------------------------------------------------
select membership_type, count(1)
from t_clientes
group by membership_type;


select membership_type, * from t_clientes
limit 100;




/* ********************* PARTE 7 - usar Gen AI ahora es muy fácil! *******************************
******************************************************************************************/
use role accountadmin;


CREATE or REPLACE file format csvformat
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  type = 'CSV';


CREATE or REPLACE stage call_transcripts_data_stage
  file_format = csvformat
  url = 's3://sfquickstarts/misc/call_transcripts/';


CREATE or REPLACE table CALL_TRANSCRIPTS ( 
  date_created date,
  language varchar(60),
  country varchar(60),
  product varchar(60),
  category varchar(60),
  damage_type varchar(90),
  transcript varchar
);


COPY into CALL_TRANSCRIPTS
  from @call_transcripts_data_stage;


-- Exploremos la tabla CALL_TRANSCRIPTS
select * from CALL_TRANSCRIPTS limit 20;


-- Traducir sin necesidad de herramientas externas
update CALL_TRANSCRIPTS
set damage_type = snowflake.cortex.translate(damage_type,'en','es'),
    transcript = snowflake.cortex.translate(transcript,'en','es'),
    language = 'Español'
where language='English';


-- Análisis de sentimientos con Cortex
select transcript, snowflake.cortex.sentiment(transcript) 
from call_transcripts 
where language = 'Español';


-- Utilizar LLMs de vanguardia y de múltiples fabricantes sin sacar los datos de nuestro entorno de seguridad
select transcript,
       snowflake.cortex.complete('mistral-large',concat('resume en max. 30 palabras:',transcript)) as summary,
       snowflake.cortex.count_tokens('mistral-large',concat('resume en max. 30 palabras:',transcript)) as number_of_tokens 
from call_transcripts 
where language = 'Español' 
limit 10;


-- Resolver preguntas con LLMs sin necesidad de APIs!
select snowflake.cortex.complete('claude-3-5-sonnet','Que es Lulo Bank en Colombia?');


-- Resolver tareas complejas con GenAI LLMs muy fácil!
select 
snowflake.cortex.complete('claude-3-5-sonnet',
           concat('Arma un XML, con los siguientes atributos: 
           resumen del problema en no más de 100 palabras, 
           sentimiento del cliente (negativo, neutro, positivo),
           producto,
           tiempo de resolución,
           Solución otorgada (máximo 10 palabras).
           Todo esto utilizando la transcripción de siguiente llamada: ',transcript) 
)
from call_transcripts 
where language = 'Español'
limit 2;




/* ************** PARTE 8 - Marketplace & Cortex Playground  **********
************************************************************************/
/*
1. Vamos al MARKERPLACE y sincronicemos un dataset llamado: YOUTUBE_PROFILES__POSTS__COMMENTS


2. Vamos a "AI & ML" -> "Studio" -> "Cortex Playground" 
3. Selecciona la base de datos recien creada, el esquema PUBLIC y la tabla YOUTUBE_PROFILES_NEW
4. Columna DESCRIPTION y filtro SUBSCRIBERS. 
5. Selecciona 2 LLMs a comparar
6. Selecciona un registro con múltiples suscriptores y ordenale la siguiente tarea:


7. 
Genérame la traducción del texto y luego créame un json y un XML con los siguientes atributos: tipo del perfil, sentimiento (positivo, negativo, neutro), resumen (no más de 5 palabras), tipo de contenido, posible nombre para el canal, contacto y solicita suscribirse.


*/


/* ***************** PARTE 9 - Trabajar con NOTEBOOKS ahora es muy fácil!  *******************
****************************************************************************************/


1. Descarguemos el archivo 02 - Recorrido_por_Notebooks.ipynb
2. Carguemos el Notebook a Snowflake
3. Continuemos con el paso a paso del Notebook


/* ******************************* PARTE 10 - Cortex Analyst  **********************************
 Hablar con datos es realmente fácil!
****************************************************************************************/


-- Descarguemos el contenido de la carpeta-> Cortex Analyst
-- Creemos un nuevo Worksheet
-- Carguemos en nuestro Worksheet el contenido del archivo-> Script - SQL
-- Continuemos con el paso a paso del Script del paso anterior.




/* ************************************************************************************
 ************************************************************************************
 ***************** SECCIONES ADICIONALES DEL QUICKSTART OFICIAL *********************
 ************************************************************************************
 
 Las siguientes secciones están basadas en el repositorio oficial de Snowflake:
 https://github.com/Snowflake-Labs/sfguide-getting-started-from-zero-to-snowflake
 
 Fuente: Zero to Snowflake Quickstart v2
 Copyright(c): 2025 Snowflake Inc. All rights reserved.
 
 ************************************************************************************/




/* ************************************ PARTE 12 ***********************************************
 PIPELINES DE DATOS SIMPLES - Dynamic Tables (Tablas Dinámicas)
 
 Basado en: vignette-2.sql - Simple Data Pipeline
 
 En esta sección aprenderás:
 1. Ingesta de datos desde stages externos
 2. Datos Semi-Estructurados y el tipo VARIANT
 3. Dynamic Tables (Tablas Dinámicas)
 4. Pipelines simples con Dynamic Tables
 5. Visualización del Pipeline con DAG (Directed Acyclic Graph)
 
 Fuente: https://github.com/Snowflake-Labs/sfguide-getting-started-from-zero-to-snowflake
*************************************************************************************************/

-- Configuremos el ambiente necesario para esta sección
-- Nota: Este ejercicio usa la base de datos tb_101 del Quickstart oficial

/*  1. Ingesta desde Stage Externo
    ***************************************************************
    Los datos actualmente están en un bucket de Amazon S3 en formato CSV. 
    Necesitamos cargar estos datos CSV crudos en un stage para luego 
    copiarlos a una tabla de staging.
    
    En Snowflake, un stage es un objeto de base de datos que especifica 
    una ubicación donde se almacenan archivos de datos, permitiéndote 
    cargar o descargar datos hacia y desde tablas.
*/

-- Crear el stage del menú
CREATE OR REPLACE STAGE raw_pos.menu_stage
COMMENT = 'Stage para datos del menú'
URL = 's3://sfquickstarts/frostbyte_tastybytes/raw_pos/menu/'
FILE_FORMAT = public.csv_ff;

CREATE OR REPLACE TABLE raw_pos.menu_staging
(
    menu_id NUMBER(19,0),
    menu_type_id NUMBER(38,0),
    menu_type VARCHAR(16777216),
    truck_brand_name VARCHAR(16777216),
    menu_item_id NUMBER(38,0),
    menu_item_name VARCHAR(16777216),
    item_category VARCHAR(16777216),
    item_subcategory VARCHAR(16777216),
    cost_of_goods_usd NUMBER(38,4),
    sale_price_usd NUMBER(38,4),
    menu_item_health_metrics_obj VARIANT
);

-- Con el stage y la tabla en su lugar, carguemos los datos del stage a la nueva tabla menu_staging
COPY INTO raw_pos.menu_staging
FROM @raw_pos.menu_stage;

-- Opcional: Verificar carga exitosa
SELECT * FROM raw_pos.menu_staging;

/*  2. Datos Semi-Estructurados en Snowflake
    *********************************************************************
    Snowflake excels at handling semi-structured data like JSON using its VARIANT data type. 
    Snowflake sobresale manejando datos semi-estructurados como JSON usando su tipo de dato VARIANT. 
    Automáticamente analiza, optimiza e indexa estos datos, permitiendo a los usuarios consultarlos 
    con SQL estándar y funciones especializadas para extracción y análisis fáciles.
    
    El objeto VARIANT en la columna menu_item_health_metrics_obj contiene:
        - menu_item_id: Un número que representa el identificador único del ítem
        - menu_item_health_metrics: Un array que contiene objetos con información de salud
        
    Cada objeto dentro del array menu_item_health_metrics tiene:
        - Un array de ingredientes (strings)
        - Varias banderas dietéticas con valores 'Y' y 'N'
*/
SELECT menu_item_health_metrics_obj FROM raw_pos.menu_staging;

/*
    Esta consulta usa sintaxis especial para navegar la estructura interna tipo JSON. 
    El operador dos puntos (:) accede a datos por su nombre de clave y los corchetes ([]) 
    seleccionan un elemento de un array por su posición numérica.
    
    Los elementos recuperados de objetos VARIANT permanecen con tipo VARIANT. 
    Convertir estos elementos a sus tipos de datos conocidos mejora el rendimiento de las 
    consultas y la calidad de los datos. Hay dos formas de lograr el casting:
        - la función CAST
        - usando la sintaxis abreviada: <source_expr> :: <target_data_type>
*/
SELECT
    menu_item_name,
    CAST(menu_item_health_metrics_obj:menu_item_id AS INTEGER) AS menu_item_id,
    menu_item_health_metrics_obj:menu_item_health_metrics[0]:ingredients::ARRAY AS ingredients
FROM raw_pos.menu_staging;

/*
    Otra función poderosa que podemos aprovechar al trabajar con datos semi-estructurados es FLATTEN.
    FLATTEN nos permite desenvolver datos semi-estructurados como JSON y Arrays y producir
    una fila por cada elemento dentro del objeto especificado.
*/
SELECT
    i.value::STRING AS ingredient_name,
    m.menu_item_health_metrics_obj:menu_item_id::INTEGER AS menu_item_id
FROM
    raw_pos.menu_staging m,
    LATERAL FLATTEN(INPUT => m.menu_item_health_metrics_obj:menu_item_health_metrics[0]:ingredients::ARRAY) i;




/* ************************************ PARTE 13 ***********************************************
 DYNAMIC TABLES - Tablas Dinámicas
 
 Las Dynamic Tables son una herramienta poderosa diseñada para simplificar pipelines de 
 transformación de datos. Son perfectas para nuestro caso de uso por varias razones:
 - Se crean usando sintaxis declarativa, donde sus datos se definen por una consulta especificada
 - El refresco automático de datos significa que los datos permanecen frescos sin requerir 
   actualizaciones manuales o programación personalizada
 - La frescura de datos gestionada por Snowflake Dynamic Tables se extiende no solo a la tabla 
   dinámica en sí, sino también a cualquier objeto de datos downstream que dependa de ella
*************************************************************************************************/

CREATE OR REPLACE DYNAMIC TABLE harmonized.ingredient
    LAG = '1 minute'
    WAREHOUSE = 'TB_DE_WH'
AS
    SELECT
    ingredient_name,
    menu_ids
FROM (
    SELECT DISTINCT
        i.value::STRING AS ingredient_name,
        ARRAY_AGG(m.menu_item_id) AS menu_ids
    FROM
        raw_pos.menu_staging m,
        LATERAL FLATTEN(INPUT => menu_item_health_metrics_obj:menu_item_health_metrics[0]:ingredients::ARRAY) i
    GROUP BY i.value::STRING
);

-- Verifiquemos que la tabla dinámica de ingredientes se creó exitosamente
SELECT * FROM harmonized.ingredient;

/*
    Uno de nuestros trucks de sándwiches Better Off Bread ha introducido un nuevo ítem del menú, 
    un sándwich Banh Mi. Este ítem introduce algunos ingredientes nuevos: French Baguette, 
    Mayonnaise y Pickled Daikon.
    
    El refresco automático de las Dynamic Tables significa que actualizar nuestra tabla menu_staging 
    con este nuevo ítem del menú se reflejará automáticamente en la tabla ingredient.
*/
INSERT INTO raw_pos.menu_staging 
SELECT 
    10101,
    15,
    'Sandwiches',
    'Better Off Bread',
    157,
    'Banh Mi',
    'Main',
    'Cold Option',
    9.0,
    12.0,
    PARSE_JSON('{
      "menu_item_health_metrics": [
        {
          "ingredients": [
            "French Baguette",
            "Mayonnaise",
            "Pickled Daikon",
            "Cucumber",
            "Pork Belly"
          ],
          "is_dairy_free_flag": "N",
          "is_gluten_free_flag": "N",
          "is_healthy_flag": "Y",
          "is_nut_free_flag": "Y"
        }
      ],
      "menu_item_id": 157
    }'
);

/*
    Verifica que French Baguette y Pickled Daikon aparecen en la tabla de ingredientes.
    Puede que veas 'Query produced no results'. Esto significa que la tabla dinámica aún no se ha refrescado.
    Permite como máximo 1 minuto para que la configuración de LAG de la Dynamic Table se actualice
*/
SELECT * FROM harmonized.ingredient 
WHERE ingredient_name IN ('French Baguette', 'Pickled Daikon');




/* ************************************ PARTE 14 ***********************************************
 CONSTRUIR EL PIPELINE - Pipeline Completo con Dynamic Tables
 
 Ahora crearemos una tabla dinámica de búsqueda de ingrediente a menú. Esto nos permitirá 
 ver qué ítems del menú usan ingredientes específicos. Luego podemos determinar qué trucks 
 necesitan qué ingredientes y cuántos.
 
 Dado que esta tabla también es una tabla dinámica, se refrescará automáticamente si se 
 usan nuevos ingredientes en cualquier ítem del menú que se añada a la tabla menu staging.
*************************************************************************************************/

CREATE OR REPLACE DYNAMIC TABLE harmonized.ingredient_to_menu_lookup
    LAG = '1 minute'
    WAREHOUSE = 'TB_DE_WH'    
AS
SELECT
    i.ingredient_name,
    m.menu_item_health_metrics_obj:menu_item_id::INTEGER AS menu_item_id
FROM
    raw_pos.menu_staging m,
    LATERAL FLATTEN(INPUT => m.menu_item_health_metrics_obj:menu_item_health_metrics[0]:ingredients) f
JOIN harmonized.ingredient i ON f.value::STRING = i.ingredient_name;

-- Verificar que ingredient to menu lookup se creó exitosamente
SELECT * 
FROM harmonized.ingredient_to_menu_lookup
ORDER BY menu_item_id;

/*
    Ejecuta las siguientes dos consultas INSERT para simular un pedido de 2 sándwiches Banh Mi 
    en el truck #15 el 27 de enero de 2022. Después crearemos otra tabla dinámica downstream 
    que nos muestra el uso de ingredientes por truck.
*/
INSERT INTO raw_pos.order_header
SELECT 
    459520441,
    15,
    1030,
    101565,
    null,
    200322900,
    TO_TIMESTAMP_NTZ('08:00:00', 'hh:mi:ss'),
    TO_TIMESTAMP_NTZ('14:00:00', 'hh:mi:ss'),
    null,
    TO_TIMESTAMP_NTZ('2022-01-27 08:21:08.000'),
    null,
    'USD',
    14.00,
    null,
    null,
    14.00;
    
INSERT INTO raw_pos.order_detail
SELECT
    904745311,
    459520441,
    157,
    null,
    0,
    2,
    14.00,
    28.00,
    null;

/*
    A continuación, crearemos otra tabla dinámica que resume el uso mensual de cada ingrediente 
    por trucks de comida individuales en Estados Unidos. Esto permite a nuestro negocio rastrear 
    el consumo de ingredientes, crucial para optimizar inventario, controlar costos y tomar 
    decisiones informadas sobre planificación de menú y relaciones con proveedores.
    
    Nota los dos métodos diferentes usados para extraer partes de la fecha de nuestro timestamp de orden:
      -> EXTRACT(<date part> FROM <datetime>) aislará la parte de fecha especificada del timestamp dado
      -> MONTH(<datetime>) retorna el índice del mes del 1-12. YEAR(<datetime>) y DAY(<datetime>) 
         harán lo mismo pero para el año y día respectivamente.
*/

CREATE OR REPLACE DYNAMIC TABLE harmonized.ingredient_usage_by_truck 
    LAG = '2 minute'
    WAREHOUSE = 'TB_DE_WH'  
    AS 
    SELECT
        oh.truck_id,
        EXTRACT(YEAR FROM oh.order_ts) AS order_year,
        MONTH(oh.order_ts) AS order_month,
        i.ingredient_name,
        SUM(od.quantity) AS total_ingredients_used
    FROM
        raw_pos.order_detail od
        JOIN raw_pos.order_header oh ON od.order_id = oh.order_id
        JOIN harmonized.ingredient_to_menu_lookup iml ON od.menu_item_id = iml.menu_item_id
        JOIN harmonized.ingredient i ON iml.ingredient_name = i.ingredient_name
        JOIN raw_pos.location l ON l.location_id = oh.location_id
    WHERE l.country = 'United States'
    GROUP BY
        oh.truck_id,
        order_year,
        order_month,
        i.ingredient_name
    ORDER BY
        oh.truck_id,
        total_ingredients_used DESC;

/*
    Ahora, veamos el uso de ingredientes para el truck #15 en enero de 2022 usando nuestra 
    vista ingredient_usage_by_truck recién creada.
*/
SELECT
    truck_id,
    ingredient_name,
    SUM(total_ingredients_used) AS total_ingredients_used,
FROM
    harmonized.ingredient_usage_by_truck
WHERE
    order_month = 1
    AND truck_id = 15
GROUP BY truck_id, ingredient_name
ORDER BY total_ingredients_used DESC;

/*  5. Visualización del Pipeline con el Directed Acyclic Graph (DAG)
    
    Finalmente, entendamos el Directed Acyclic Graph, o DAG de nuestro pipeline. 
    El DAG sirve como visualización de nuestro pipeline de datos. Puedes usarlo para orquestar 
    visualmente flujos de trabajo de datos complejos, asegurando que las tareas se ejecuten en 
    el orden correcto. Puedes usarlo para ver métricas de lag y configuración para cada tabla 
    dinámica en el pipeline y también refrescar tablas manualmente si es necesario.
    
    Para acceder al DAG:
    - Haz clic en el botón 'Data' en el Menú de Navegación para abrir la pantalla de base de datos
    - Haz clic en la flecha '>' junto a 'TB_101' para expandir la base de datos
    - Expande 'HARMONIZED' luego expande 'Dynamic Tables'
    - Haz clic en la tabla 'INGREDIENT'
*/




/* ************************************ PARTE 18 ***********************************************
 FUNCIONES AISQL - Funciones de IA en SQL con Snowflake Cortex
 
 Basado en: vignette-3-aisql.sql - AISQL Functions
 
 En esta sección aprenderás a usar funciones de IA directamente en SQL:
 1. SENTIMENT() para analizar sentimiento de reviews de clientes
 2. AI_CLASSIFY() para categorizar reviews por temas
 3. EXTRACT_ANSWER() para extraer quejas o elogios específicos
 4. AI_SUMMARIZE_AGG() para generar resúmenes rápidos de sentimiento
 
 Fuente: https://github.com/Snowflake-Labs/sfguide-getting-started-from-zero-to-snowflake
*************************************************************************************************/

/* 1. Análisis de Sentimiento a Escala
    ***************************************************************
    Analiza el sentimiento de clientes en todas las marcas de food trucks para identificar 
    qué trucks están teniendo mejor desempeño y crear métricas de satisfacción del cliente.
    
    Usaremos la función SENTIMENT() para puntuar automáticamente reviews de clientes de 
    -1 (negativo) a +1 (positivo), siguiendo los rangos de sentimiento oficiales de Snowflake.
    ***************************************************************/

-- Pregunta de Negocio: "¿Cómo se sienten los clientes sobre cada una de nuestras marcas de trucks en general?"
SELECT
    truck_brand_name,
    COUNT(*) AS total_reviews,
    AVG(CASE WHEN sentiment >= 0.5 THEN sentiment END) AS avg_positive_score,
    AVG(CASE WHEN sentiment BETWEEN -0.5 AND 0.5 THEN sentiment END) AS avg_neutral_score,
    AVG(CASE WHEN sentiment <= -0.5 THEN sentiment END) AS avg_negative_score
FROM (
    SELECT
        truck_brand_name,
        SNOWFLAKE.CORTEX.SENTIMENT (review) AS sentiment
    FROM harmonized.truck_reviews_v
    WHERE
        language ILIKE '%en%'
        AND review IS NOT NULL
    LIMIT 10000
)
GROUP BY
    truck_brand_name
ORDER BY total_reviews DESC;

/*
    Insight Clave:
        Observa cómo hicimos la transición de analizar reviews una a la vez en Cortex Playground 
        a procesar sistemáticamente miles. La función SENTIMENT() puntuó automáticamente cada 
        review y las categorizó en Positivo, Negativo y Neutral - dándonos métricas instantáneas 
        de satisfacción del cliente en toda la flota.
        
    Rangos de Puntuación de Sentimiento:
        Positivo:   0.5 a 1
        Neutral:   -0.5 a 0.5
        Negativo:  -0.5 a -1
*/

/* 2. Categorizar Retroalimentación de Clientes
    ***************************************************************
    Ahora, categoricemos todas las reviews para entender de qué aspectos de nuestro servicio 
    están hablando más los clientes. Usaremos la función AI_CLASSIFY(), que automáticamente 
    categoriza reviews en categorías definidas por el usuario basándose en comprensión de IA, 
    en lugar de simple coincidencia de palabras clave.
    ***************************************************************/

-- Pregunta de Negocio: "¿En qué están comentando principalmente los clientes: calidad de comida, servicio o experiencia de entrega?"
WITH classified_reviews AS (
  SELECT
    truck_brand_name,
    AI_CLASSIFY(
      review,
      ['Food Quality', 'Pricing', 'Service Experience', 'Staff Behavior']
    ):labels[0] AS feedback_category
  FROM
    harmonized.truck_reviews_v
  WHERE
    language ILIKE '%en%'
    AND review IS NOT NULL
    AND LENGTH(review) > 30
  LIMIT
    10000
)
SELECT
  truck_brand_name,
  feedback_category,
  COUNT(*) AS number_of_reviews
FROM
  classified_reviews
GROUP BY
  truck_brand_name,
  feedback_category
ORDER BY
  truck_brand_name,
  number_of_reviews DESC;
                
/*
    Insight Clave:
        Observa cómo AI_CLASSIFY() categorizó automáticamente miles de reviews en temas 
        relevantes para el negocio como Calidad de Comida, Experiencia de Servicio y más. 
        Podemos ver instantáneamente que la Calidad de Comida es el tema más discutido en 
        nuestras marcas de trucks, proporcionando al equipo de operaciones insight claro y 
        accionable sobre las prioridades de los clientes.
*/

/* 3. Extraer Insights Operacionales Específicos
    ***************************************************************
    Para obtener respuestas precisas de texto no estructurado, utilizaremos la función 
    EXTRACT_ANSWER(). Esta poderosa función nos permite hacer preguntas específicas de 
    negocio sobre retroalimentación de clientes y recibir respuestas directas.
    ***************************************************************/

-- Pregunta de negocio: "¿Qué problemas operacionales específicos o menciones positivas se encuentran en cada review de cliente?"
SELECT
    truck_brand_name,
    primary_city,
    LEFT(review, 100) || '...' AS review_preview,
    SNOWFLAKE.CORTEX.EXTRACT_ANSWER(
        review,
        'What specific improvement or complaint is mentioned in this review?'
    ) AS specific_feedback
FROM 
    harmonized.truck_reviews_v
WHERE 
    language = 'en'
    AND review IS NOT NULL
    AND LENGTH(review) > 50
ORDER BY truck_brand_name, primary_city ASC
LIMIT 10000;

/*
    Insight Clave:
        Nota cómo EXTRACT_ANSWER() destila insights específicos y accionables de reviews 
        largas de clientes. En lugar de revisión manual, esta función identifica automáticamente 
        retroalimentación concreta como "friendly staff was saving grace" y "hot dogs are cooked 
        to perfection". El resultado es una transformación de texto denso en retroalimentación 
        específica y citable que el equipo de operaciones puede aprovechar instantáneamente.
*/

/* 4. Generar Resúmenes Ejecutivos
    ***************************************************************
    Finalmente, para crear resúmenes concisos de retroalimentación de clientes, usaremos la 
    función SUMMARIZE(). Esta poderosa función genera resúmenes cortos y coherentes de texto 
    no estructurado largo.
    ***************************************************************/

-- Pregunta de Negocio: "¿Cuáles son los temas clave y el sentimiento general para cada marca de truck?"
SELECT
  truck_brand_name,
  AI_SUMMARIZE_AGG (review) AS review_summary
FROM
  (
    SELECT
      truck_brand_name,
      review
    FROM
      harmonized.truck_reviews_v
    LIMIT
      100
  )
GROUP BY
  truck_brand_name;

/*
  Insight Clave:
      La función AI_SUMMARIZE_AGG() condensa reviews largas en resúmenes claros a nivel de marca.
      Estos resúmenes destacan temas recurrentes y tendencias de sentimiento, proporcionando a 
      los tomadores de decisiones vistas rápidas del desempeño de cada food truck y permitiendo 
      una comprensión más rápida de la percepción del cliente sin leer reviews individuales.
*/




/* ************************************ PARTE 24 ***********************************************
 CLASIFICACIÓN Y AUTO-ETIQUETADO - Clasificación Automática de Datos Sensibles
 
 Basado en: vignette-4.sql - Governance with Horizon
 Sección 2: Tag-Based Classification with Auto Tagging
 
 En esta sección aprenderás:
 - Cómo Snowflake puede detectar automáticamente datos sensibles (PII)
 - Crear perfiles de clasificación para etiquetar datos automáticamente
 - Usar tags para organizar y gobernar datos sensibles
 
 Fuente: https://github.com/Snowflake-Labs/sfguide-getting-started-from-zero-to-snowflake
*************************************************************************************************/

/*  Clasificación Basada en Tags con Auto Tagging
    ******************************************************
    
    Snowflake puede clasificar automáticamente información sensible monitoreando continuamente 
    las columnas en tus esquemas de base de datos. Después de que un ingeniero de datos asigne 
    un perfil de clasificación a un esquema, todos los datos sensibles dentro de las tablas de 
    ese esquema se clasifican automáticamente basándose en el cronograma del perfil.
    
    Crearemos un perfil de clasificación y designaremos un tag para ser asignado automáticamente 
    a columnas basándose en la categoría semántica de la columna.
*/

USE ROLE accountadmin;

-- Crear un tag para PII dentro del esquema governance
CREATE OR REPLACE TAG governance.pii;
GRANT APPLY TAG ON ACCOUNT TO ROLE tb_data_steward;

/*
    Primero necesitamos otorgar a nuestro rol tb_data_steward los privilegios apropiados para 
    ejecutar clasificaciones de datos y crear perfiles de clasificación en nuestro esquema raw_customer.
*/
GRANT EXECUTE AUTO CLASSIFICATION ON SCHEMA raw_customer TO ROLE tb_data_steward;
GRANT DATABASE ROLE SNOWFLAKE.CLASSIFICATION_ADMIN TO ROLE tb_data_steward;
GRANT CREATE SNOWFLAKE.DATA_PRIVACY.CLASSIFICATION_PROFILE ON SCHEMA governance TO ROLE tb_data_steward;

-- Cambiar de vuelta al rol data steward
USE ROLE tb_data_steward;

/*
    Crear el perfil de clasificación. Los objetos añadidos al esquema se clasifican inmediatamente, 
    son válidos por 30 días y se etiquetan automáticamente.
*/
CREATE OR REPLACE SNOWFLAKE.DATA_PRIVACY.CLASSIFICATION_PROFILE
  governance.tb_classification_profile(
    {
      'minimum_object_age_for_classification_days': 0,
      'maximum_classification_validity_days': 30,
      'auto_tag': true
    });

/*
    Crear un mapa de tags para etiquetar automáticamente columnas dadas las categorías semánticas 
    especificadas. Esto significa que cualquier columna clasificada con cualquiera de los valores 
    en el array semantic_categories será etiquetada automáticamente con el tag PII.
*/
CALL governance.tb_classification_profile!SET_TAG_MAP(
  {'column_tag_map':[
    {
      'tag_name':'tb_101.governance.pii',
      'tag_value':'pii',
      'semantic_categories':['NAME', 'PHONE_NUMBER', 'POSTAL_CODE', 'DATE_OF_BIRTH', 'CITY', 'EMAIL']
    }]});

-- Ahora llamar SYSTEM$CLASSIFY para clasificar automáticamente la tabla customer_loyalty con nuestro perfil de clasificación
CALL SYSTEM$CLASSIFY('tb_101.raw_customer.customer_loyalty', 'tb_101.governance.tb_classification_profile');

/*
    Ejecuta la siguiente consulta para ver los resultados de la clasificación y etiquetado automáticos. 
    Extraeremos metadatos del INFORMATION_SCHEMA generado automáticamente, disponible en cada cuenta 
    de Snowflake. Tómate un minuto para revisar cómo se etiquetó cada columna y cómo se relaciona 
    con el perfil de clasificación que creamos en pasos anteriores.
    
    Verás que todas las columnas están etiquetadas con tags PRIVACY_CATEGORY y SEMANTIC_CATEGORY, 
    cada uno con su propio propósito. PRIVACY_CATEGORY denota el nivel de sensibilidad de los datos 
    personales en la columna, mientras que SEMANTIC_CATEGORY describe el concepto del mundo real 
    que los datos representan.
    
    Finalmente, nota que las columnas etiquetadas con la categoría semántica que especificamos en 
    el array de mapeo de clasificación están etiquetadas con nuestro tag 'PII' personalizado.
*/
SELECT 
    column_name,
    tag_database,
    tag_schema,
    tag_name,
    tag_value,
    apply_method
FROM TABLE(INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('raw_customer.customer_loyalty', 'table'));




/* ************************************ PARTE 26 ***********************************************
 ROW ACCESS POLICIES - Seguridad a Nivel de Fila
 
 Basado en: vignette-4.sql - Governance with Horizon
 Sección 4: Row Level Security with Row Access Policies
 
 En esta sección aprenderás:
 - Cómo crear Row Access Policies para controlar qué filas ve cada usuario
 - Usar tablas de mapeo para definir permisos de acceso granular
 - Aplicar políticas basadas en roles y valores de columna
 
 Fuente: https://github.com/Snowflake-Labs/sfguide-getting-started-from-zero-to-snowflake
*************************************************************************************************/

/*  Seguridad a Nivel de Fila con Row Access Policies
    ***********************************************************
    
    Snowflake soporta seguridad a nivel de fila usando row access policies para determinar 
    qué filas se devuelven en los resultados de consulta. La política se adjunta a una tabla 
    y funciona evaluando cada fila contra reglas que defines. Estas reglas a menudo usan 
    atributos del usuario que ejecuta la consulta, como su rol actual.
    
    Por ejemplo, podemos usar una row access policy para asegurar que los usuarios en Estados 
    Unidos solo vean datos de clientes dentro de Estados Unidos.
*/

USE ROLE tb_data_steward;

-- Antes de crear la row access policy, crearemos un mapa de políticas de fila
CREATE OR REPLACE TABLE governance.row_policy_map
    (role STRING, country_permission STRING);

/*
    El mapa de políticas de fila asocia roles con el valor de fila de acceso permitido.
    Por ejemplo, si asociamos nuestro rol tb_data_engineer con el valor de país 'United States', 
    tb_data_engineer solo verá filas donde el valor de país sea 'United States'.
*/
INSERT INTO governance.row_policy_map
    VALUES('tb_data_engineer', 'United States');

/*
    Con el mapa de políticas de fila en su lugar, crearemos la Row Access Policy.
    
    Esta política establece que los administradores tienen acceso sin restricciones a las filas, 
    mientras que otros roles en el mapa de políticas solo pueden ver filas que coincidan con su 
    país asociado.
*/
CREATE OR REPLACE ROW ACCESS POLICY governance.customer_loyalty_policy
    AS (country STRING) RETURNS BOOLEAN ->
        CURRENT_ROLE() IN ('ACCOUNTADMIN', 'SYSADMIN') 
        OR EXISTS 
            (
            SELECT 1
                FROM governance.row_policy_map rp
            WHERE
                UPPER(rp.role) = CURRENT_ROLE()
                AND rp.country_permission = country
            );

-- Aplicar la row access policy a la tabla customer loyalty en la columna 'country'
ALTER TABLE raw_customer.customer_loyalty
    ADD ROW ACCESS POLICY governance.customer_loyalty_policy ON (country);

/*
    Ahora, cambia al rol que asociamos con 'United States' en el mapa de políticas de fila y 
    observa el resultado de consultar una tabla con nuestra row access policy.
*/
USE ROLE tb_data_engineer;

-- Solo deberíamos ver clientes de Estados Unidos
SELECT TOP 100 * FROM raw_customer.customer_loyalty;

/*
    ¡Bien hecho! Ahora deberías tener una mejor comprensión de cómo gobernar y asegurar tus 
    datos con las estrategias de seguridad a nivel de columna y fila de Snowflake.
*/




/* ************************************ PARTE 27 ***********************************************
 DATA METRIC FUNCTIONS - Monitoreo de Calidad de Datos
 
 Basado en: vignette-4.sql - Governance with Horizon
 Sección 5: Data Quality Monitoring with Data Metric Functions
 
 En esta sección aprenderás:
 - Usar Data Metric Functions (DMFs) del sistema para monitorear calidad de datos
 - Crear funciones de métricas de datos personalizadas
 - Programar métricas de calidad para ejecución automática
 
 Fuente: https://github.com/Snowflake-Labs/sfguide-getting-started-from-zero-to-snowflake
*************************************************************************************************/

/*  Monitoreo de Calidad de Datos con Data Metric Functions
    ***********************************************************
    
    Snowflake mantiene consistencia y confiabilidad de datos usando Data Metric Functions (DMFs), 
    una característica poderosa para automatizar verificaciones de calidad directamente dentro 
    de la plataforma. Al programar estas verificaciones en cualquier tabla o vista, los usuarios 
    obtienen una comprensión clara de la integridad de sus datos, lo que conduce a decisiones 
    más confiables e informadas por datos.
    
    Snowflake ofrece tanto DMFs del sistema pre-construidas para uso inmediato como la flexibilidad 
    de crear personalizadas para lógica de negocio única, asegurando monitoreo de calidad integral.
*/

-- Cambiar de vuelta al rol TastyBytes data steward para comenzar a usar DMFs
USE ROLE tb_data_steward;

-- Esto retornará el porcentaje de customer IDs nulos de la tabla order header
SELECT SNOWFLAKE.CORE.NULL_PERCENT(SELECT customer_id FROM raw_pos.order_header);

-- Podemos usar DUPLICATE_COUNT para verificar IDs de órdenes duplicados
SELECT SNOWFLAKE.CORE.DUPLICATE_COUNT(SELECT order_id FROM raw_pos.order_header); 

-- Monto total promedio de orden para todas las órdenes
SELECT SNOWFLAKE.CORE.AVG(SELECT order_total FROM raw_pos.order_header);

/*
    También podemos crear nuestras propias Data Metric Functions personalizadas para monitorear 
    calidad de datos según reglas de negocio específicas. Crearemos una DMF personalizada que 
    verifica totales de órdenes que no son iguales al precio unitario multiplicado por la cantidad.
*/

-- Crear Data Metric Function personalizada
CREATE OR REPLACE DATA METRIC FUNCTION governance.invalid_order_total_count(
    order_prices_t table(
        order_total NUMBER,
        unit_price NUMBER,
        quantity INTEGER
    )
)
RETURNS NUMBER
AS
'SELECT COUNT(*)
 FROM order_prices_t
 WHERE order_total != unit_price * quantity';

-- Simula una nueva orden donde el total no es igual al precio unitario * cantidad
INSERT INTO raw_pos.order_detail
SELECT
    904745311,
    459520442,
    52,
    null,
    0,
    2,
    5.0,
    5.0,
    null;

-- Llamar la DMF personalizada en la tabla order detail
SELECT governance.invalid_order_total_count(
    SELECT 
        price, 
        unit_price, 
        quantity 
    FROM raw_pos.order_detail
) AS num_orders_with_incorrect_price;

-- Establecer Data Metric Schedule en la tabla order detail para que se dispare en cambios
ALTER TABLE raw_pos.order_detail
    SET DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES';

-- Asignar DMF personalizada a la tabla
ALTER TABLE raw_pos.order_detail
    ADD DATA METRIC FUNCTION governance.invalid_order_total_count
    ON (price, unit_price, quantity);




/* ******************************* PARTE 11 - Opcional **********************************
 LIMPIEZA - Eliminemos los elementos creados en este laboratorio
****************************************************************************************/
use role accountadmin;

-- Elementos del script original
show shares;
drop share if exists clientes_share;
drop database if exists DB_EMPRESA;
drop database if exists DB_EMPRESA_DEV;
drop database if exists db_clima;
drop warehouse if exists COMPUTE_HOL_WH;
drop role if exists OPERADOR_JUNIOR;

-- Elementos de las secciones adicionales (si fueron creadas)
-- Nota: Solo ejecuta estas líneas si creaste la base de datos tb_101 y sus objetos

-- Limpiar Dynamic Tables
DROP TABLE IF EXISTS raw_pos.menu_staging;
DROP TABLE IF EXISTS harmonized.ingredient;
DROP TABLE IF EXISTS harmonized.ingredient_to_menu_lookup;
DROP TABLE IF EXISTS harmonized.ingredient_usage_by_truck;

-- Eliminar inserts de prueba
DELETE FROM raw_pos.order_detail WHERE order_detail_id = 904745311;
DELETE FROM raw_pos.order_header WHERE order_id = 459520441;

-- Limpiar Masking Policies
ALTER TAG IF EXISTS governance.pii UNSET
    MASKING POLICY governance.mask_string_pii,
    MASKING POLICY governance.mask_date_pii;
DROP MASKING POLICY IF EXISTS governance.mask_string_pii;
DROP MASKING POLICY IF EXISTS governance.mask_date_pii;

-- Limpiar Auto classification
ALTER SCHEMA raw_customer UNSET CLASSIFICATION_PROFILE;
DROP SNOWFLAKE.DATA_PRIVACY.CLASSIFICATION_PROFILE IF EXISTS tb_classification_profile;

-- Limpiar Row access policies
ALTER TABLE raw_customer.customer_loyalty 
    DROP ROW ACCESS POLICY governance.customer_loyalty_policy;
DROP ROW ACCESS POLICY IF EXISTS governance.customer_loyalty_policy;

-- Limpiar Data metric functions
DELETE FROM raw_pos.order_detail WHERE order_detail_id = 904745311;
ALTER TABLE raw_pos.order_detail
    DROP DATA METRIC FUNCTION governance.invalid_order_total_count ON (price, unit_price, quantity);
DROP FUNCTION governance.invalid_order_total_count(TABLE(NUMBER, NUMBER, INTEGER));
ALTER TABLE raw_pos.order_detail UNSET DATA_METRIC_SCHEDULE;

-- Limpiar Tags
DROP TAG IF EXISTS governance.pii;

-- Links recomendados:
-- Explore múltiples labs y arquitecturas para implementar en minutos
-- https://developers.snowflake.com/solutions/

-- Lab - RAG sobre documentos PDF
-- https://developers.snowflake.com/solution/rag-based-ai-app-for-equipment-maintenance-using-snowflake-cortex/

-- Lab - Getting Started with Cortex Analyst: Augment BI with AI
-- https://quickstarts.snowflake.com/guide/getting_started_with_cortex_analyst

-- Lab - Extracting Insights from Unstructured Data with Document AI
-- https://quickstarts.snowflake.com/guide/tasty_bytes_extracting_insights_with_docai

-- Lab - Run 3 useful LLM inference jobs in minutes with Snowflake Cortex
-- https://medium.com/snowflake/run-3-useful-llm-inference-jobs-in-minutes-with-snowflake-cortex-743a6096fff8

-- Lab - Build A Document Search Assistant using Vector Embeddings in Cortex AI
-- https://quickstarts.snowflake.com/guide/asking_questions_to_your_own_documents_with_snowflake_cortex

-- Lab - Quickstart oficial Zero to Snowflake
-- https://quickstarts.snowflake.com/guide/zero_to_snowflake/index.html

-- Repositorio GitHub oficial
-- https://github.com/Snowflake-Labs/sfguide-getting-started-from-zero-to-snowflake

