/*--
• Creación de objetos y warehouse
--*/

-- Creemos una nueva base de datos y un esquema
CREATE OR REPLACE DATABASE cortex_analyst_demo;

CREATE OR REPLACE SCHEMA revenue_timeseries;

-- Creemos un nuevo warehouse para administrar mejor los costos
CREATE OR REPLACE WAREHOUSE cortex_analyst_wh
   WAREHOUSE_SIZE = 'large'
   WAREHOUSE_TYPE = 'standard'
   AUTO_SUSPEND = 60
   AUTO_RESUME = TRUE
   INITIALLY_SUSPENDED = TRUE
COMMENT = 'Warehouse para Cortex Analyst';

-- Creemos un stage
CREATE STAGE raw_data DIRECTORY = (ENABLE = TRUE);

-- CARGUEMOS los 3 archivos CSV y el .yaml (modelo semántico) en el STAGE

-- Listemos los archivos
List @raw_data;






-- Creemos 3 tablas para cargar el contenido de los archivos CSV
CREATE OR REPLACE TABLE CORTEX_ANALYST_DEMO.REVENUE_TIMESERIES.DAILY_REVENUE (
   DATE DATE,
   REVENUE FLOAT,
   COGS FLOAT,
   FORECASTED_REVENUE FLOAT
);


CREATE OR REPLACE TABLE CORTEX_ANALYST_DEMO.REVENUE_TIMESERIES.DAILY_REVENUE_BY_PRODUCT (
   DATE DATE,
   PRODUCT_LINE VARCHAR(16777216),
   REVENUE FLOAT,
   COGS FLOAT,
   FORECASTED_REVENUE FLOAT
);


CREATE OR REPLACE TABLE CORTEX_ANALYST_DEMO.REVENUE_TIMESERIES.DAILY_REVENUE_BY_REGION (
   DATE DATE,
   SALES_REGION VARCHAR(16777216),
   REVENUE FLOAT,
   COGS FLOAT,
   FORECASTED_REVENUE FLOAT
);


/*--
 Carguemos los datos de los CSV a las tablas previamente creadas
--*/
COPY INTO CORTEX_ANALYST_DEMO.REVENUE_TIMESERIES.DAILY_REVENUE
FROM @raw_data
FILES = ('daily_revenue_combined.csv')
FILE_FORMAT = (
   TYPE=CSV,
   SKIP_HEADER=1,
   FIELD_DELIMITER=',',
   TRIM_SPACE=FALSE,
   FIELD_OPTIONALLY_ENCLOSED_BY=NONE,
   REPLACE_INVALID_CHARACTERS=TRUE,
   DATE_FORMAT=AUTO,
   TIME_FORMAT=AUTO,
   TIMESTAMP_FORMAT=AUTO
   EMPTY_FIELD_AS_NULL = FALSE
   error_on_column_count_mismatch=false
)
ON_ERROR=CONTINUE
FORCE = TRUE ;


COPY INTO CORTEX_ANALYST_DEMO.REVENUE_TIMESERIES.DAILY_REVENUE_BY_PRODUCT
FROM @raw_data
FILES = ('daily_revenue_by_product_combined.csv')
FILE_FORMAT = (
   TYPE=CSV,
   SKIP_HEADER=1,
   FIELD_DELIMITER=',',
   TRIM_SPACE=FALSE,
   FIELD_OPTIONALLY_ENCLOSED_BY=NONE,
   REPLACE_INVALID_CHARACTERS=TRUE,
   DATE_FORMAT=AUTO,
   TIME_FORMAT=AUTO,
   TIMESTAMP_FORMAT=AUTO
   EMPTY_FIELD_AS_NULL = FALSE
   error_on_column_count_mismatch=false
)
ON_ERROR=CONTINUE
FORCE = TRUE ;


COPY INTO CORTEX_ANALYST_DEMO.REVENUE_TIMESERIES.DAILY_REVENUE_BY_REGION
FROM @raw_data
FILES = ('daily_revenue_by_region_combined.csv')
FILE_FORMAT = (
   TYPE=CSV,
   SKIP_HEADER=1,
   FIELD_DELIMITER=',',
   TRIM_SPACE=FALSE,
   FIELD_OPTIONALLY_ENCLOSED_BY=NONE,
   REPLACE_INVALID_CHARACTERS=TRUE,
   DATE_FORMAT=AUTO,
   TIME_FORMAT=AUTO,
   TIMESTAMP_FORMAT=AUTO
   EMPTY_FIELD_AS_NULL = FALSE
   error_on_column_count_mismatch=false
)
ON_ERROR=CONTINUE
FORCE = TRUE ;


--------------------------------------------------------------
-- Creemos una App en Streamlit, para hablar con estos datos.
-- Copiemos el contenido del archivo “02_streamlit.py” y reemplazamos el código del Streamlit recién creado.


-----------------------------------------------------
-------------------- Preguntas  ---------------------
-----------------------------------------------------
-- ¿Qué puedo preguntar?
-- Ejecuta la pregunta sugerida
-- ¿Cuál es el ingreso total del último año?
-- ¿Cuáles son las líneas de productos más vendidas?
