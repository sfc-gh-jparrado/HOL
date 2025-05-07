-- El uso de AccountAdmin a menudo se sugiere para laboratorios, pero cualquier role con privilegios suficientes puede funcionar
USE ROLE ACCOUNTADMIN;

-- Crear base de datos de desarrollo y esquema
CREATE OR REPLACE DATABASE quickstart;
CREATE OR REPLACE SCHEMA ml_functions;

-- Usar los recursos apropiados
USE DATABASE quickstart;
USE SCHEMA ml_functions;

-- Crear warehouse 
CREATE OR REPLACE WAREHOUSE quickstart_wh;
USE WAREHOUSE quickstart_wh;

-- Crear un file format para ingestar archivos CSV al stage
CREATE OR REPLACE FILE FORMAT quickstart.ml_functions.csv_ff
    TYPE = 'csv'
    SKIP_HEADER = 1,
    COMPRESSION = AUTO;

-- Crear un external stage que apunte a AWS S3 para cargar datos
CREATE OR REPLACE STAGE s3load 
    COMMENT = 'Quickstart S3 Stage Connection'
    URL = 's3://sfquickstarts/hol_snowflake_cortex_ml_for_sql/'
    FILE_FORMAT = quickstart.ml_functions.csv_ff;

-- Definir el esquema de nuestra tabla
CREATE OR REPLACE TABLE quickstart.ml_functions.bank_marketing(
    CUSTOMER_ID TEXT,
    AGE NUMBER,
    JOB TEXT, 
    MARITAL TEXT, 
    EDUCATION TEXT, 
    DEFAULT TEXT, 
    HOUSING TEXT, 
    LOAN TEXT, 
    CONTACT TEXT, 
    MONTH TEXT, 
    DAY_OF_WEEK TEXT, 
    DURATION NUMBER(4, 0), 
    CAMPAIGN NUMBER(2, 0), 
    PDAYS NUMBER(3, 0), 
    PREVIOUS NUMBER(1, 0), 
    POUTCOME TEXT, 
    EMPLOYEE_VARIATION_RATE NUMBER(2, 1), 
    CONSUMER_PRICE_INDEX NUMBER(5, 3), 
    CONSUMER_CONFIDENCE_INDEX NUMBER(3,1), 
    EURIBOR_3_MONTH_RATE NUMBER(4, 3),
    NUMBER_EMPLOYEES NUMBER(5, 1),
    CLIENT_SUBSCRIBED BOOLEAN,
    TIMESTAMP TIMESTAMP_NTZ(9)
);

-- Ingestar los datos desde S3 en la tabla creada
COPY INTO quickstart.ml_functions.bank_marketing
FROM @s3load/customers.csv;

-- Analicemos los datos cargados
SELECT * FROM quickstart.ml_functions.bank_marketing LIMIT 100;



--  Empecemos con la preparación de los datos para entrenar nuestro primer modelo
-- Total de registros
SELECT COUNT(1) as num_rows
FROM bank_marketing;

-- Conteo de subscritos vs sin subscrirse: 
SELECT client_subscribed, COUNT(1) as num_rows
FROM bank_marketing
GROUP BY 1;


-- Crear una vista con una columba que clasifique entre entrenamiento e inferencia los datos
CREATE OR REPLACE TABLE partitioned_data as (
  SELECT *, 
        CASE WHEN UNIFORM(0::float, 1::float, RANDOM()) < .95 THEN 'training' ELSE 'inference' END AS split_group
  FROM bank_marketing
);

-- Vista para entrenamiento
CREATE OR REPLACE VIEW training_view AS (
  SELECT * EXCLUDE split_group
  FROM partitioned_data 
  WHERE split_group LIKE 'training');

-- Vista para inferencia
CREATE OR REPLACE VIEW inference_view AS (
  SELECT * EXCLUDE split_group
  FROM partitioned_data 
  WHERE split_group LIKE 'inference');



-- Creemos nuestro primer modelo!
-- 01. Vamos ahora para AI & ML -> Studio -> Classification y luego create.
-- 02. Nombra el modelo como bank_classifier.
-- Ahora, Vamos a seleccionar nuestros datos de entrenamiento:
-- 03. Elije para datos de entrenamiento la vista training_view.
-- 04. Elije client_subscribed como columna target para la clasificación.
-- Ahora, vamos a elegir los datos que queremos clasificacar.
-- 05. Seleccina la vista inference_view.
-- 06. Dale un nombre a la tabla donde se guardarán los resultados y luego obtendras todo el código SQL necesario para crear tu modelo.
-- Vamos a ejecutar paso a paso y para interiorizar lo que vamos haciendo.

Quieres ahora probarlo con un modelo de forecasting?
Puedes continuar con el paso de Forecasting en este link:
https://quickstarts.snowflake.com/guide/getting-started-with-snowflake-cortex-ml-forecasting-and-classification/index.html#4


