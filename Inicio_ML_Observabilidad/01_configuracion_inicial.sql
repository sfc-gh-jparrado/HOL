-- https://quickstarts.snowflake.com/guide/getting-started-with-ml-observability-in-snowflake/index.html#0



-- Definamos el ambiente de trabajo
USE ROLE SYSADMIN;
create database customer_db;


CREATE OR REPLACE WAREHOUSE ml_wh WITH 
WAREHOUSE_TYPE = standard WAREHOUSE_SIZE = Medium
AUTO_SUSPEND = 5 AUTO_RESUME = True;
