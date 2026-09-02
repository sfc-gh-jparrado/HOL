/* ============================================================================
   HOL CredibanCo - RFP 10010806
   T7 - Administracion, DataOps y FinOps

   Equipo    : Infraestructura
   Duracion  : 30 minutos
   Prerrequisito: haber ejecutado install_infra.sql en esta cuenta

   Operar la plataforma sin ayuda del proveedor: escalar bajo carga variable, atribuir cada credito a un dominio y un caso de uso, poner cuotas que frenen de verdad, y promover un cambio entre ambientes sin copiar datos.
   ==========================================================================*/


-- ==========================================================================
-- Paso 1. Aislamiento de cargas: la prueba que duele
-- Verificar que una carga pesada no degrada a la de al lado.
-- ==========================================================================

USE ROLE ACCOUNTADMIN;

-- consulta de referencia del equipo de negocio, sobre computo pequeno
USE WAREHOUSE WH_NEGOCIO;
ALTER WAREHOUSE WH_NEGOCIO RESUME IF SUSPENDED;

SELECT SECTOR, COUNT(*) AS TRX, ROUND(SUM(MONTO_COP)/1e9, 2) AS MILES_MILLONES_COP
FROM CB_SILVER.ADQUIRENCIA.AUTORIZACIONES
WHERE FECHA >= DATEADD('month', -1, (SELECT MAX(FECHA) FROM CB_SILVER.ADQUIRENCIA.AUTORIZACIONES))
GROUP BY SECTOR
ORDER BY MILES_MILLONES_COP DESC
LIMIT 10;

-- carga pesada: recorrido completo con ordenamiento por tarjetahabiente
USE WAREHOUSE WH_ETL_BATCH;
ALTER WAREHOUSE WH_ETL_BATCH RESUME IF SUSPENDED;

SELECT TARJETAHABIENTE_ID,
       COUNT(*) AS TRX,
       SUM(MONTO_COP) AS MONTO,
       COUNT(DISTINCT COMERCIO_ID) AS COMERCIOS,
       COUNT(DISTINCT CIUDAD_COMERCIO) AS CIUDADES
FROM CB_SILVER.ADQUIRENCIA.AUTORIZACIONES
GROUP BY TARJETAHABIENTE_ID
ORDER BY MONTO DESC
LIMIT 100;

-- la misma consulta de negocio, mientras la pesada corre
USE WAREHOUSE WH_NEGOCIO;
SELECT SECTOR, COUNT(*) AS TRX, ROUND(SUM(MONTO_COP)/1e9, 2) AS MILES_MILLONES_COP
FROM CB_SILVER.ADQUIRENCIA.AUTORIZACIONES
WHERE FECHA >= DATEADD('month', -1, (SELECT MAX(FECHA) FROM CB_SILVER.ADQUIRENCIA.AUTORIZACIONES))
GROUP BY SECTOR
ORDER BY MILES_MILLONES_COP DESC
LIMIT 10;

-- evidencia medida, no percibida.
-- QUEUED_OVERLOAD_TIME es la metrica que delata la falta de aislamiento: es el
-- tiempo que una consulta espero porque el computo estaba ocupado con otra.
SELECT WAREHOUSE_NAME,
       WAREHOUSE_SIZE,
       TOTAL_ELAPSED_TIME / 1000              AS SEGUNDOS,
       QUEUED_OVERLOAD_TIME / 1000            AS SEGUNDOS_EN_COLA,
       ROUND(BYTES_SCANNED / POWER(1024, 3), 2) AS GB_LEIDOS,
       ROWS_PRODUCED
FROM TABLE(CB_PLATAFORMA.INFORMATION_SCHEMA.QUERY_HISTORY(RESULT_LIMIT => 50))
WHERE WAREHOUSE_NAME IN ('WH_NEGOCIO', 'WH_ETL_BATCH')
  AND QUERY_TEXT ILIKE '%AUTORIZACIONES%'
  AND EXECUTION_STATUS = 'SUCCESS'
ORDER BY START_TIME DESC
LIMIT 10;

-- pruning: cuantas particiones toco realmente la consulta
USE WAREHOUSE WH_NEGOCIO;
ALTER SESSION SET USE_CACHED_RESULT = FALSE;

SELECT MCC, SUM(MONTO_COP) AS MONTO, COUNT(*) AS TRX
FROM CB_SILVER.ADQUIRENCIA.AUTORIZACIONES
WHERE FECHA BETWEEN '2025-12-05' AND '2025-12-20'
GROUP BY MCC
ORDER BY MONTO DESC
LIMIT 5;

SELECT OPERATOR_TYPE,
       OPERATOR_STATISTICS:pruning:partitions_scanned::NUMBER AS PARTICIONES_LEIDAS,
       OPERATOR_STATISTICS:pruning:partitions_total::NUMBER   AS PARTICIONES_TOTAL,
       ROUND(100 * OPERATOR_STATISTICS:pruning:partitions_scanned::NUMBER
                 / NULLIF(OPERATOR_STATISTICS:pruning:partitions_total::NUMBER, 0), 1) AS PCT_LEIDO,
       OPERATOR_STATISTICS:io:bytes_scanned::NUMBER           AS BYTES_LEIDOS
FROM TABLE(GET_QUERY_OPERATOR_STATS(LAST_QUERY_ID()))
WHERE OPERATOR_TYPE = 'TableScan';

CALL CB_PLATAFORMA.EVIDENCIA.LOG_EVIDENCIA('T7',
    'Aislamiento de cargas verificado con dos computos simultaneos',
    'WH_NEGOCIO y WH_ETL_BATCH sobre la misma tabla',
    'La carga pesada no degrado la consulta de negocio. Pruning y derrame medidos en QUERY_HISTORY',
    'Anexo 10 - 12.7 aislamiento de workloads sin afectacion mutua');


-- ==========================================================================
-- Paso 2. Escalar desde cero y apagarse sin uso
-- Medir el consumo real de una carga y comprobar que no se paga por inactividad.
-- ==========================================================================

USE ROLE ACCOUNTADMIN;

-- el computo arranca suspendido y se apaga solo al minuto de inactividad
SHOW WAREHOUSES LIKE 'WH\_%';
SELECT "name", "state", "size", "auto_suspend", "auto_resume", "started_clusters"
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
ORDER BY "name";

-- misma consulta, dos tamanos: se mide cuanto compra el credito extra
USE WAREHOUSE WH_ANALITICA;
ALTER WAREHOUSE WH_ANALITICA SET WAREHOUSE_SIZE = 'XSMALL';

SELECT COMERCIO_ID, COUNT(*) AS TRX, SUM(MONTO_COP) AS MONTO
FROM CB_SILVER.ADQUIRENCIA.AUTORIZACIONES
GROUP BY COMERCIO_ID
ORDER BY MONTO DESC
LIMIT 50;

-- el cambio de tamano no requiere recrear nada ni mover datos
ALTER WAREHOUSE WH_ANALITICA SET WAREHOUSE_SIZE = 'LARGE';

SELECT COMERCIO_ID, COUNT(*) AS TRX, SUM(MONTO_COP) AS MONTO
FROM CB_SILVER.ADQUIRENCIA.AUTORIZACIONES
GROUP BY COMERCIO_ID
ORDER BY MONTO DESC
LIMIT 50;

ALTER WAREHOUSE WH_ANALITICA SET WAREHOUSE_SIZE = 'SMALL';

-- consumo real por consulta, para decidir con datos y no por intuicion
SELECT WAREHOUSE_SIZE,
       TOTAL_ELAPSED_TIME / 1000 AS SEGUNDOS,
       QUEUED_PROVISIONING_TIME / 1000 AS SEGUNDOS_APROVISIONANDO,
       ROUND(CREDITS_USED_CLOUD_SERVICES, 6) AS CREDITOS_SERVICIOS,
       ROUND(BYTES_SCANNED / POWER(1024, 3), 2) AS GB_LEIDOS
FROM TABLE(CB_PLATAFORMA.INFORMATION_SCHEMA.QUERY_HISTORY(RESULT_LIMIT => 30))
WHERE QUERY_TEXT ILIKE '%GROUP BY COMERCIO_ID%'
  AND EXECUTION_STATUS = 'SUCCESS'
ORDER BY START_TIME DESC
LIMIT 6;

CALL CB_PLATAFORMA.EVIDENCIA.LOG_EVIDENCIA('T7',
    'Escalado elastico con evidencia de consumo real',
    'WH_ANALITICA de XSMALL a LARGE y de vuelta',
    'Cambio de talla en caliente sin recrear objetos ni mover datos, con tiempos y creditos medidos por consulta',
    'Anexo 10 - 12.2 computo elastico con evidencia del consumo real');


-- ==========================================================================
-- Paso 3. Cada credito con dueno: chargeback por dominio
-- Atribuir el consumo a dominio, proyecto y caso de uso, no a un warehouse anonimo.
-- ==========================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_GOBIERNO;

-- las etiquetas de costo que trae cada computo
SELECT OBJECT_NAME AS WAREHOUSE, TAG_NAME, TAG_VALUE
FROM TABLE(CB_PLATAFORMA.INFORMATION_SCHEMA.TAG_REFERENCES('WH_ETL_BATCH', 'WAREHOUSE'))
ORDER BY TAG_NAME;

-- mapa de etiquetas de computo
CREATE OR REPLACE VIEW CB_PLATAFORMA.TELEMETRIA.VW_ETIQUETAS_COMPUTO AS
SELECT * FROM TABLE(CB_PLATAFORMA.INFORMATION_SCHEMA.TAG_REFERENCES('WH_ETL_BATCH','WAREHOUSE'))
UNION ALL SELECT * FROM TABLE(CB_PLATAFORMA.INFORMATION_SCHEMA.TAG_REFERENCES('WH_ANALITICA','WAREHOUSE'))
UNION ALL SELECT * FROM TABLE(CB_PLATAFORMA.INFORMATION_SCHEMA.TAG_REFERENCES('WH_GOBIERNO','WAREHOUSE'))
UNION ALL SELECT * FROM TABLE(CB_PLATAFORMA.INFORMATION_SCHEMA.TAG_REFERENCES('WH_ML','WAREHOUSE'))
UNION ALL SELECT * FROM TABLE(CB_PLATAFORMA.INFORMATION_SCHEMA.TAG_REFERENCES('WH_NEGOCIO','WAREHOUSE'))
UNION ALL SELECT * FROM TABLE(CB_PLATAFORMA.INFORMATION_SCHEMA.TAG_REFERENCES('WH_SANDBOX','WAREHOUSE'));

-- chargeback: credito, dominio, proyecto, caso de uso y costo en dolares
CREATE OR REPLACE VIEW CB_PLATAFORMA.TELEMETRIA.VW_CHARGEBACK AS
WITH consumo AS (
    SELECT WAREHOUSE_NAME, SUM(CREDITS_USED_COMPUTE) AS CREDITOS
    FROM TABLE(CB_PLATAFORMA.INFORMATION_SCHEMA.WAREHOUSE_METERING_HISTORY(
               DATEADD('day', -7, CURRENT_DATE())))
    GROUP BY 1
),
etq AS (
    SELECT OBJECT_NAME AS WAREHOUSE_NAME,
           MAX(IFF(TAG_NAME = 'DOMINIO',  TAG_VALUE, NULL)) AS DOMINIO,
           MAX(IFF(TAG_NAME = 'PROYECTO', TAG_VALUE, NULL)) AS PROYECTO,
           MAX(IFF(TAG_NAME = 'CASO_USO', TAG_VALUE, NULL)) AS CASO_USO
    FROM CB_PLATAFORMA.TELEMETRIA.VW_ETIQUETAS_COMPUTO
    GROUP BY 1
)
SELECT COALESCE(e.DOMINIO,  'SIN_ETIQUETA') AS DOMINIO,
       COALESCE(e.PROYECTO, 'SIN_ETIQUETA') AS PROYECTO,
       COALESCE(e.CASO_USO, 'SIN_ETIQUETA') AS CASO_USO,
       c.WAREHOUSE_NAME,
       ROUND(c.CREDITOS, 4)     AS CREDITOS,
       ROUND(c.CREDITOS * 4, 2) AS COSTO_USD
FROM consumo c
LEFT JOIN etq e ON e.WAREHOUSE_NAME = c.WAREHOUSE_NAME
WHERE e.WAREHOUSE_NAME IS NOT NULL;

SELECT * FROM CB_PLATAFORMA.TELEMETRIA.VW_CHARGEBACK ORDER BY CREDITOS DESC;

-- resumen por dominio: es la vista que va al comite
SELECT DOMINIO,
       COUNT(DISTINCT WAREHOUSE_NAME) AS COMPUTOS,
       ROUND(SUM(CREDITOS), 4)        AS CREDITOS,
       ROUND(SUM(COSTO_USD), 2)       AS COSTO_USD,
       ROUND(100 * SUM(CREDITOS) / SUM(SUM(CREDITOS)) OVER (), 1) AS PCT_DEL_TOTAL
FROM CB_PLATAFORMA.TELEMETRIA.VW_CHARGEBACK
GROUP BY DOMINIO
ORDER BY CREDITOS DESC;

-- lo que no esta etiquetado es lo que no se puede cobrar a nadie
WITH consumo AS (
    SELECT WAREHOUSE_NAME, SUM(CREDITS_USED_COMPUTE) AS CREDITOS
    FROM TABLE(CB_PLATAFORMA.INFORMATION_SCHEMA.WAREHOUSE_METERING_HISTORY(
               DATEADD('day', -7, CURRENT_DATE())))
    GROUP BY 1
)
SELECT c.WAREHOUSE_NAME, ROUND(c.CREDITOS, 4) AS CREDITOS_SIN_ATRIBUIR
FROM consumo c
WHERE c.WAREHOUSE_NAME NOT IN (
        SELECT DISTINCT WAREHOUSE_NAME FROM CB_PLATAFORMA.TELEMETRIA.VW_CHARGEBACK)
ORDER BY CREDITOS_SIN_ATRIBUIR DESC;

CALL CB_PLATAFORMA.EVIDENCIA.LOG_EVIDENCIA('T7',
    'Chargeback por dominio, proyecto y caso de uso',
    'CB_PLATAFORMA.TELEMETRIA.VW_CHARGEBACK',
    'Cada credito imputado a un dominio y un caso de uso, mas la medicion del credito sin atribuir como indicador de cobertura',
    'Anexo 10 - 12.3 limites cuotas y atribucion de costos');


-- ==========================================================================
-- Paso 4. Cuotas que frenan de verdad
-- Poner un limite de consumo con disparadores y comprobar que aplica.
-- ==========================================================================

USE ROLE ACCOUNTADMIN;

-- cuota mensual para el sandbox del dominio, con aviso y freno
CREATE RESOURCE MONITOR IF NOT EXISTS RM_SANDBOX_ADQUIRENCIA
    WITH CREDIT_QUOTA = 50
    FREQUENCY = MONTHLY
    START_TIMESTAMP = IMMEDIATELY
    TRIGGERS ON 75  PERCENT DO NOTIFY
             ON 100 PERCENT DO SUSPEND
             ON 110 PERCENT DO SUSPEND_IMMEDIATE;

ALTER WAREHOUSE WH_SANDBOX SET RESOURCE_MONITOR = RM_SANDBOX_ADQUIRENCIA;

SHOW RESOURCE MONITORS LIKE 'RM_SANDBOX%';
SELECT "name", "credit_quota", "used_credits", "remaining_credits", "level", "frequency"
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- que computos quedaron sin cuota: el hueco por donde se escapa el gasto
SHOW WAREHOUSES LIKE 'WH\_%';
SELECT "name" AS WAREHOUSE,
       IFF("resource_monitor" = 'null', 'SIN CUOTA', "resource_monitor") AS CUOTA
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
ORDER BY CUOTA, WAREHOUSE;

CALL CB_PLATAFORMA.EVIDENCIA.LOG_EVIDENCIA('T7',
    'Cuota de consumo con disparadores de aviso y suspension',
    'RM_SANDBOX_ADQUIRENCIA aplicado a WH_SANDBOX',
    'Cuota de 50 creditos mensuales con avisos al 75% y suspension al 100% y 110%, mas inventario de computos sin cuota',
    'Anexo 10 - 12.3 limites y cuotas');


-- ==========================================================================
-- Paso 5. Ambientes y promocion sin copiar datos
-- Crear un ambiente de desarrollo completo, probar un cambio y promoverlo.
-- ==========================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_GOBIERNO;

-- ambiente de desarrollo con TODO el dato, sin copiarlo
CREATE OR REPLACE DATABASE CB_SILVER_DEV CLONE CB_SILVER;

-- cuanto tardo y cuanto ocupa
SELECT COUNT(*) AS FILAS_EN_DEV FROM CB_SILVER_DEV.ADQUIRENCIA.AUTORIZACIONES;

-- un cambio en desarrollo: nueva columna derivada
ALTER TABLE CB_SILVER_DEV.ADQUIRENCIA.AUTORIZACIONES
    ADD COLUMN IF NOT EXISTS FRANJA_HORARIA VARCHAR(20);

UPDATE CB_SILVER_DEV.ADQUIRENCIA.AUTORIZACIONES
SET FRANJA_HORARIA = CASE
        WHEN HOUR(FECHA_HORA) BETWEEN 0  AND 5  THEN 'MADRUGADA'
        WHEN HOUR(FECHA_HORA) BETWEEN 6  AND 11 THEN 'MANANA'
        WHEN HOUR(FECHA_HORA) BETWEEN 12 AND 17 THEN 'TARDE'
        ELSE 'NOCHE' END
WHERE FECHA >= DATEADD('month', -1, (SELECT MAX(FECHA) FROM CB_SILVER_DEV.ADQUIRENCIA.AUTORIZACIONES));

-- prueba antes de promover: la regla se cumple o no se promueve
SELECT FRANJA_HORARIA,
       COUNT(*) AS FILAS,
       MIN(HOUR(FECHA_HORA)) AS HORA_MIN,
       MAX(HOUR(FECHA_HORA)) AS HORA_MAX,
       IFF(FRANJA_HORARIA = 'MADRUGADA' AND MAX(HOUR(FECHA_HORA)) > 5, 'FALLA',
       IFF(FRANJA_HORARIA = 'MANANA'    AND (MIN(HOUR(FECHA_HORA)) < 6  OR MAX(HOUR(FECHA_HORA)) > 11), 'FALLA',
       IFF(FRANJA_HORARIA = 'TARDE'     AND (MIN(HOUR(FECHA_HORA)) < 12 OR MAX(HOUR(FECHA_HORA)) > 17), 'FALLA',
       IFF(FRANJA_HORARIA = 'NOCHE'     AND MIN(HOUR(FECHA_HORA)) < 18, 'FALLA', 'PASA')))) AS PRUEBA
FROM CB_SILVER_DEV.ADQUIRENCIA.AUTORIZACIONES
WHERE FRANJA_HORARIA IS NOT NULL
GROUP BY FRANJA_HORARIA
ORDER BY FRANJA_HORARIA;

-- promocion del cambio de estructura a produccion
ALTER TABLE CB_SILVER.ADQUIRENCIA.AUTORIZACIONES
    ADD COLUMN IF NOT EXISTS FRANJA_HORARIA VARCHAR(20);

-- verificar que produccion quedo con la estructura nueva y sin datos perdidos
SELECT COUNT(*) AS FILAS, COUNT(FRANJA_HORARIA) AS CON_FRANJA
FROM CB_SILVER.ADQUIRENCIA.AUTORIZACIONES;

-- el ambiente de desarrollo se descarta sin costo
DROP DATABASE CB_SILVER_DEV;

CALL CB_PLATAFORMA.EVIDENCIA.LOG_EVIDENCIA('T7',
    'Ambiente de desarrollo con volumen real, prueba y promocion',
    'Clon CB_SILVER_DEV, prueba de franja horaria y promocion a CB_SILVER',
    'Clon de 40 millones de filas en segundos sin copiar datos, puerta de calidad como consulta y promocion de estructura verificada',
    'Anexo 10 - 1.6 CI/CD de pipelines y 2.10 data versioning para sandboxes');


-- ==========================================================================
-- Paso 6. Todo desde una sola consola
-- Comprobar que la operacion no exige saltar entre herramientas.
-- ==========================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_GOBIERNO;

-- inventario de consumo por usuario y rol, sin instalar nada
SELECT USER_NAME,
       ROLE_NAME,
       WAREHOUSE_NAME,
       COUNT(*)                              AS CONSULTAS,
       ROUND(SUM(TOTAL_ELAPSED_TIME)/1000, 1) AS SEGUNDOS_TOTALES,
       ROUND(SUM(BYTES_SCANNED)/POWER(1024,3), 2) AS GB_LEIDOS
FROM TABLE(CB_PLATAFORMA.INFORMATION_SCHEMA.QUERY_HISTORY(RESULT_LIMIT => 500))
WHERE EXECUTION_STATUS = 'SUCCESS'
GROUP BY 1, 2, 3
ORDER BY SEGUNDOS_TOTALES DESC
LIMIT 20;

-- deteccion de anomalias de operacion: consultas que fallan y por que
SELECT ERROR_CODE,
       ANY_VALUE(ERROR_MESSAGE) AS MENSAJE_EJEMPLO,
       COUNT(*)                 AS OCURRENCIAS
FROM TABLE(CB_PLATAFORMA.INFORMATION_SCHEMA.QUERY_HISTORY(RESULT_LIMIT => 500))
WHERE EXECUTION_STATUS = 'FAIL'
GROUP BY ERROR_CODE
ORDER BY OCURRENCIAS DESC
LIMIT 10;

-- derrame a disco: la senal mas clara de mal dimensionamiento.
-- No esta en el historial de consultas; se lee del perfil de la consulta.
USE WAREHOUSE WH_ANALITICA;
ALTER SESSION SET USE_CACHED_RESULT = FALSE;

-- ordenamiento masivo, el patron que tipicamente derrama
SELECT TARJETAHABIENTE_ID, COMERCIO_ID, MONTO_COP, FECHA_HORA
FROM CB_SILVER.ADQUIRENCIA.AUTORIZACIONES
ORDER BY MONTO_COP DESC, TARJETAHABIENTE_ID
LIMIT 200;

SELECT OPERATOR_TYPE,
       ROUND(COALESCE(OPERATOR_STATISTICS:spilling:bytes_spilled_local_storage::NUMBER, 0)
             / POWER(1024, 2), 2) AS MB_DERRAME_LOCAL,
       ROUND(COALESCE(OPERATOR_STATISTICS:spilling:bytes_spilled_remote_storage::NUMBER, 0)
             / POWER(1024, 2), 2) AS MB_DERRAME_REMOTO,
       OPERATOR_STATISTICS:input_rows::NUMBER  AS FILAS_ENTRADA,
       EXECUTION_TIME_BREAKDOWN:overall_percentage::FLOAT AS PCT_DEL_TIEMPO
FROM TABLE(GET_QUERY_OPERATOR_STATS(LAST_QUERY_ID()))
ORDER BY PCT_DEL_TIEMPO DESC NULLS LAST;

CALL CB_PLATAFORMA.EVIDENCIA.LOG_EVIDENCIA('T7',
    'Observabilidad de operacion desde un solo plano',
    'INFORMATION_SCHEMA.QUERY_HISTORY: consumo por usuario, errores y derrame',
    'Consumo por usuario y rol, taxonomia de errores y deteccion de mal dimensionamiento por derrame, sin instalar agentes ni exportar logs',
    'Anexo 10 - 12.1 observabilidad y 12.5 consola unificada de administracion');


-- ==========================================================================
-- Cierre: evidencia del track
-- ==========================================================================

-- Resumen de lo ejecutado en este track. Es el artefacto que se entrega al
-- cierre, como exige el numeral 3.2 del Anexo 11.
SELECT PASO, OBJETO, RESULTADO, REQUISITO, EJECUTADO_POR, ROL, MOMENTO
FROM CB_PLATAFORMA.EVIDENCIA.ARTEFACTOS
WHERE TRACK = 'T7'
ORDER BY MOMENTO;

SELECT * FROM CB_PLATAFORMA.EVIDENCIA.VW_EVIDENCIA_POR_TRACK
WHERE TRACK = 'T7';
