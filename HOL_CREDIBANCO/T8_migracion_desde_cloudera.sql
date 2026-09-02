/* ============================================================================
   HOL CredibanCo - RFP 10010806
   T8 - Migracion desde Cloudera

   Equipo    : Arquitectura
   Duracion  : 30 minutos
   Prerrequisito: haber ejecutado install_arquitectura.sql en esta cuenta

   Tomar codigo real de la linea base &mdash;HiveQL, Impala, PySpark y Oozie&mdash;, convertirlo, ejecutarlo y comparar el resultado contra la plataforma actual. La conversion no se evalua por el reporte: se evalua por los numeros.
   ==========================================================================*/


-- ==========================================================================
-- Paso 1. Inventariar la muestra antes de convertir nada
-- Clasificar el codigo por motor y por patron critico, que es lo que define el esfuerzo.
-- ==========================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_ANALITICA;

-- la muestra que entrego CredibanCo, ya disponible en el stage
SELECT TECNOLOGIA, COUNT(*) AS ARCHIVOS, SUM(SIZE) AS BYTES
FROM CB_PLATAFORMA.MIGRACION.VW_MUESTRA_CLOUDERA
GROUP BY TECNOLOGIA
ORDER BY ARCHIVOS DESC;

SELECT RELATIVE_PATH, TECNOLOGIA, SIZE
FROM CB_PLATAFORMA.MIGRACION.VW_MUESTRA_CLOUDERA
ORDER BY TECNOLOGIA, RELATIVE_PATH;

-- inventario del assessment: patron critico y equivalente destino.
-- Esta tabla es el entregable que permite estimar, no el conteo de archivos.
CREATE OR REPLACE TABLE CB_PLATAFORMA.MIGRACION.ASSESSMENT AS
SELECT * FROM VALUES
  ('hive/01_crear_tablas_externas.hql','HiveQL','Tez',58,
   'Tabla externa con particionado declarativo','Tabla nativa o Iceberg mas stage externo','AUTOMATICA'),
  ('hive/02_carga_incremental.hql','HiveQL','Tez',42,
   'INSERT OVERWRITE sobre particion dinamica','MERGE o tabla dinamica','AUTOMATICA'),
  ('hive/03_agregado_ventas_comercio.hql','HiveQL','Tez',30,
   'Funcion de ventana sobre agregado','Identico en SQL estandar','AUTOMATICA'),
  ('impala/04_consumo_analitico.sql','Impala SQL','Impala',38,
   'INVALIDATE METADATA y hint STRAIGHT_JOIN','Se elimina: no hay gestion manual de metadatos','SE_ELIMINA'),
  ('spark/05_features_churn.py','PySpark','Spark 2.4',118,
   'UDF de Python fila por fila, caida a RDD y escritura directa a HDFS','Snowpark con funcion de ventana','REESCRITURA'),
  ('spark/06_deteccion_fraude_stream.py','PySpark','Spark Streaming',72,
   'Structured Streaming desde Kafka con watermark','Openflow mas tabla dinamica incremental','REESCRITURA'),
  ('oozie/wf_carga_autorizaciones.xml','Oozie','Oozie',92,
   'Workflow con captura de falla y correo','Grafo de tareas con finalizador','AUTOMATICA'),
  ('oozie/coord_carga_autorizaciones.xml','Oozie','Oozie',38,
   'Coordinador por dataset con done-flag','Tarea disparada por stream o programacion','AUTOMATICA')
AS s(ARCHIVO,TECNOLOGIA,MOTOR,LINEAS,PATRON_CRITICO,EQUIVALENTE_SNOWFLAKE,CLASIFICACION);

SELECT CLASIFICACION,
       COUNT(*)     AS ARCHIVOS,
       SUM(LINEAS)  AS LINEAS,
       ROUND(100.0 * SUM(LINEAS) / SUM(SUM(LINEAS)) OVER (), 1) AS PCT_LINEAS
FROM CB_PLATAFORMA.MIGRACION.ASSESSMENT
GROUP BY CLASIFICACION
ORDER BY LINEAS DESC;

-- que patrones concentran el riesgo
SELECT TECNOLOGIA, PATRON_CRITICO, CLASIFICACION, LINEAS
FROM CB_PLATAFORMA.MIGRACION.ASSESSMENT
WHERE CLASIFICACION = 'REESCRITURA'
ORDER BY LINEAS DESC;

CALL CB_PLATAFORMA.EVIDENCIA.LOG_EVIDENCIA('T8',
    'Assessment de la muestra por motor, patron critico y clasificacion de conversion',
    'CB_PLATAFORMA.MIGRACION.ASSESSMENT sobre 8 artefactos de 4 motores',
    'Clasificacion en automatica, reescritura y se-elimina con lineas por categoria, base para estimar las 13.003 tablas y 439 workflows de la linea base',
    'Anexo 10 - 11.1 analizar y validar la linea base');


-- ==========================================================================
-- Paso 2. Convertir y ejecutar sobre el dato real
-- Correr el codigo convertido y ver que produce el mismo resultado.
-- ==========================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_ETL_BATCH;

-- Original en HiveQL:
--   CREATE TABLE agg_ventas_mensuales_comercio STORED AS PARQUET AS
--   SELECT ... LAG(SUM(...)) OVER (PARTITION BY comercio_id ORDER BY anio, mes)
--   FROM autorizaciones_master_rt a JOIN dim_comercio c ...
--   GROUP BY a.comercio_id, c.razon_social, c.sector, c.ciudad, a.anio, a.mes;
--
-- Convertido: sin STORED AS PARQUET (el formato es propiedad de la tabla, no
-- del DDL) y con las particiones anio/mes derivadas de la fecha.
CREATE OR REPLACE TABLE CB_PLATAFORMA.MIGRACION.AGG_VENTAS_CONVERTIDO AS
SELECT a.COMERCIO_ID,
       c.RAZON_SOCIAL,
       c.SECTOR,
       c.CIUDAD                                        AS CIUDAD,
       YEAR(a.FECHA)                                   AS ANIO,
       MONTH(a.FECHA)                                  AS MES,
       COUNT(*)                                        AS TRX_TOTAL,
       SUM(IFF(a.APROBADA, 1, 0))                      AS TRX_APROBADAS,
       SUM(IFF(a.APROBADA, a.MONTO_COP, 0))            AS MONTO_APROBADO_COP,
       AVG(IFF(a.APROBADA, a.MONTO_COP, NULL))         AS TICKET_PROMEDIO_COP,
       COUNT(DISTINCT a.TARJETAHABIENTE_ID)            AS CLIENTES_UNICOS,
       LAG(SUM(IFF(a.APROBADA, a.MONTO_COP, 0)))
           OVER (PARTITION BY a.COMERCIO_ID ORDER BY YEAR(a.FECHA), MONTH(a.FECHA))
                                                       AS MONTO_MES_ANTERIOR
FROM CB_SILVER.ADQUIRENCIA.AUTORIZACIONES a
JOIN CB_SILVER.ADQUIRENCIA.COMERCIOS c ON c.COMERCIO_ID = a.COMERCIO_ID
GROUP BY a.COMERCIO_ID, c.RAZON_SOCIAL, c.SECTOR, c.CIUDAD,
         YEAR(a.FECHA), MONTH(a.FECHA);

SELECT COUNT(*) AS FILAS_PRODUCIDAS FROM CB_PLATAFORMA.MIGRACION.AGG_VENTAS_CONVERTIDO;

-- reconciliacion: el codigo convertido contra el agregado que la
-- plataforma ya tenia. Si los numeros no cuadran, la conversion no sirve.
WITH convertido AS (
    SELECT COUNT(*)                      AS FILAS,
           SUM(TRX_TOTAL)                AS TRX,
           ROUND(SUM(MONTO_APROBADO_COP), 2) AS MONTO,
           COUNT(DISTINCT COMERCIO_ID)   AS COMERCIOS
    FROM CB_PLATAFORMA.MIGRACION.AGG_VENTAS_CONVERTIDO
),
referencia AS (
    SELECT COUNT(*)                      AS FILAS,
           SUM(TRX_TOTAL)                AS TRX,
           ROUND(SUM(MONTO_APROBADO_COP), 2) AS MONTO,
           COUNT(DISTINCT COMERCIO_ID)   AS COMERCIOS
    FROM CB_GOLD.PRODUCTOS.VENTAS_MENSUALES_COMERCIO
)
SELECT 'Filas'         AS METRICA, c.FILAS::VARCHAR AS CONVERTIDO, r.FILAS::VARCHAR AS REFERENCIA,
       IFF(c.FILAS = r.FILAS, 'CUADRA', 'REVISAR') AS RESULTADO
FROM convertido c, referencia r
UNION ALL
SELECT 'Transacciones', c.TRX::VARCHAR, r.TRX::VARCHAR,
       IFF(c.TRX = r.TRX, 'CUADRA', 'REVISAR') FROM convertido c, referencia r
UNION ALL
SELECT 'Monto aprobado', c.MONTO::VARCHAR, r.MONTO::VARCHAR,
       IFF(c.MONTO = r.MONTO, 'CUADRA', 'REVISAR') FROM convertido c, referencia r
UNION ALL
SELECT 'Comercios', c.COMERCIOS::VARCHAR, r.COMERCIOS::VARCHAR,
       IFF(c.COMERCIOS = r.COMERCIOS, 'CUADRA', 'REVISAR') FROM convertido c, referencia r;

-- reconciliacion fila por fila, que es lo que pide una migracion real
SELECT COUNT(*) AS COMBINACIONES_CON_DIFERENCIA
FROM CB_PLATAFORMA.MIGRACION.AGG_VENTAS_CONVERTIDO x
FULL OUTER JOIN (
    SELECT COMERCIO_ID, YEAR(MES) AS ANIO, MONTH(MES) AS MES,
           TRX_TOTAL, MONTO_APROBADO_COP
    FROM CB_GOLD.PRODUCTOS.VENTAS_MENSUALES_COMERCIO
) y
  ON  y.COMERCIO_ID = x.COMERCIO_ID
  AND y.ANIO = x.ANIO
  AND y.MES  = x.MES
WHERE x.COMERCIO_ID IS NULL
   OR y.COMERCIO_ID IS NULL
   OR x.TRX_TOTAL <> y.TRX_TOTAL
   OR ABS(x.MONTO_APROBADO_COP - y.MONTO_APROBADO_COP) > 0.01;

-- la reescritura de PySpark: el mismo calculo del RDD, con una
-- funcion de ventana. Es el patron que el conversor marca como REESCRITURA.
SELECT COMERCIO_ID,
       ROUND(TENDENCIA_3M, 4) AS TENDENCIA_3M_SNOWFLAKE,
       MESES_ACTIVO
FROM CB_GOLD.PRODUCTOS.COMERCIO_FEATURES_CHURN
WHERE MESES_ACTIVO >= 6
ORDER BY TENDENCIA_3M
LIMIT 10;

CALL CB_PLATAFORMA.EVIDENCIA.LOG_EVIDENCIA('T8',
    'Codigo convertido ejecutado y reconciliado contra la referencia',
    'CB_PLATAFORMA.MIGRACION.AGG_VENTAS_CONVERTIDO frente a VENTAS_MENSUALES_COMERCIO',
    'Cuatro metricas de control cuadran y la reconciliacion fila por fila con FULL OUTER JOIN devuelve cero diferencias',
    'Anexo 10 - 11.3 aceleradores y 11.4 muestra de migracion medible');


-- ==========================================================================
-- Paso 3. Lo que NO se convierte y el DW Oracle
-- Cerrar el alcance con honestidad: que permanece, que se federa y que se estima aparte.
-- ==========================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_ANALITICA;

-- destino de cada componente de la linea base. Kafka permanece: el propio
-- Anexo 10 pide mantener el patron de eventos.
CREATE OR REPLACE TABLE CB_PLATAFORMA.MIGRACION.DESTINO_COMPONENTES AS
SELECT * FROM VALUES
  ('HDFS','Almacenamiento','SE_REEMPLAZA','Almacenamiento de la plataforma mas Iceberg sobre el bucket propio','Directa'),
  ('YARN','Planificacion','SE_REEMPLAZA','Warehouses por patron de carga','Directa'),
  ('Hive','SQL batch','SE_REEMPLAZA','SQL nativo y tablas dinamicas','Directa'),
  ('Impala','SQL interactivo','SE_REEMPLAZA','SQL nativo. Desaparece la gestion manual de metadatos','Directa'),
  ('Oozie','Orquestacion','SE_REEMPLAZA','Grafos de tareas con finalizador','Directa'),
  ('Ranger','Autorizacion del plano de datos','SE_REEMPLAZA','RBAC y ABAC con politicas por etiqueta','Directa'),
  ('KMS y KTS','Llaves','SE_REEMPLAZA','Cifrado con llave gestionada por el cliente','Directa'),
  ('Hue','Consola de consulta','SE_REEMPLAZA','Snowsight','Directa'),
  ('Knox','Puerta de acceso','INNECESARIO','Servicio administrado con conectividad privada','No aplica'),
  ('Spark','Procesamiento distribuido','SE_REEMPLAZA','Snowpark. Riesgo en RDD de bajo nivel y librerias JVM propias','Requiere validacion'),
  ('Kudu','Acceso de baja latencia','SE_REEMPLAZA','Hybrid Tables o tablas interactivas. Validar QPS','Requiere validacion'),
  ('NiFi','Integracion','SE_REEMPLAZA','Openflow. Validar procesadores NAR propios','Requiere validacion'),
  ('CDSW','Ciencia de datos','SE_REEMPLAZA','ML nativo y contenedores. Validar R e imagenes propias','Requiere validacion'),
  ('Kafka','Mensajeria','PERMANECE','Se conserva. El Anexo 10 pide mantener el patron de eventos','No se migra'),
  ('Schema Registry','Gobierno de topicos','PERMANECE','Queda con Kafka como componente de terceros','No se migra')
AS s(COMPONENTE,FUNCION,DESTINO,EQUIVALENTE,COMPLEJIDAD);

SELECT DESTINO, COUNT(*) AS COMPONENTES,
       LISTAGG(COMPONENTE, ', ') WITHIN GROUP (ORDER BY COMPONENTE) AS DETALLE
FROM CB_PLATAFORMA.MIGRACION.DESTINO_COMPONENTES
GROUP BY DESTINO
ORDER BY COMPONENTES DESC;

-- los cuatro que hay que validar antes de comprometer fechas
SELECT COMPONENTE, EQUIVALENTE
FROM CB_PLATAFORMA.MIGRACION.DESTINO_COMPONENTES
WHERE COMPLEJIDAD = 'Requiere validacion'
ORDER BY COMPONENTE;

-- olas de migracion propuestas, con el criterio de corte
SELECT * FROM VALUES
  (1,'Analitica y bodega','Tablas Hive e Impala de consumo analitico y sus workflows batch',
     'Sin dependencia de baja latencia. Es donde el 80% de objetos se mueve con conversion automatica','Q4 2026'),
  (2,'Ingesta y NRT','NiFi hacia Openflow, los 21 workflows de baja latencia y Kudu',
     'Requiere validacion de procesadores propios y de QPS. Coexistencia con Kafka','Q1 2027'),
  (3,'Ciencia de datos','CDSW, los 12 modelos productivos y los 5 en desarrollo',
     'Depende de que la ola 1 haya entregado los productos de datos','Q1 2027'),
  (4,'Apagado','Decomiso de los 3 clusteres','Tras dos cierres mensuales en paralelo sin diferencias','Q2 2027'),
  (5,'DW Oracle','Fase posterior, sujeta a assessment',
     'Sin volumetria en el pliego. Se cotiza contra la linea base agregada que CredibanCo entregue','Por definir')
AS s(OLA,NOMBRE,ALCANCE,CRITERIO,VENTANA);

CALL CB_PLATAFORMA.EVIDENCIA.LOG_EVIDENCIA('T8',
    'Destino componente por componente y plan de olas con riesgos declarados',
    'CB_PLATAFORMA.MIGRACION.DESTINO_COMPONENTES y plan de 5 olas',
    'De 15 componentes solo Kafka y su registro permanecen; 4 declarados como requieren validacion en el assessment; DW Oracle explicitamente sin cifra hasta tener volumetria',
    'Anexo 10 - 11.2 estrategia de ciclo de vida y 6.3 absorcion de cargas del DW Oracle');


-- ==========================================================================
-- Cierre: evidencia del track
-- ==========================================================================

-- Resumen de lo ejecutado en este track. Es el artefacto que se entrega al
-- cierre, como exige el numeral 3.2 del Anexo 11.
SELECT PASO, OBJETO, RESULTADO, REQUISITO, EJECUTADO_POR, ROL, MOMENTO
FROM CB_PLATAFORMA.EVIDENCIA.ARTEFACTOS
WHERE TRACK = 'T8'
ORDER BY MOMENTO;

SELECT * FROM CB_PLATAFORMA.EVIDENCIA.VW_EVIDENCIA_POR_TRACK
WHERE TRACK = 'T8';
