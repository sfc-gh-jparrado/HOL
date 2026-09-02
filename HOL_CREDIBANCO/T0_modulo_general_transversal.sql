/* ============================================================================
   HOL CredibanCo - RFP 10010806
   T0 - Modulo general transversal

   Equipo    : Todos los equipos
   Duracion  : 25 minutos
   Prerrequisito: haber ejecutado install_seguridad.sql en esta cuenta

   Arquitectura objetivo, navegacion, modelo de dominios y el recorrido completo de una autorizacion desde el archivo hasta la respuesta del agente. Es el mapa que hace falta para que los ocho tracks siguientes se entiendan.
   ==========================================================================*/


-- ==========================================================================
-- Paso 1. Donde esta el dato y como esta organizado
-- Recorrer las cuatro capas y entender por que estan separadas.
-- ==========================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_ANALITICA;

-- las cuatro capas
SHOW DATABASES LIKE 'CB\_%';
SELECT "name" AS BASE, "comment" AS PARA_QUE_SIRVE
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
ORDER BY "name";

-- que hay en cada una y con que volumen
SELECT TABLE_CATALOG AS CAPA,
       TABLE_SCHEMA  AS DOMINIO,
       TABLE_NAME    AS OBJETO,
       TABLE_TYPE    AS TIPO,
       ROW_COUNT     AS FILAS,
       ROUND(BYTES / POWER(1024, 3), 2) AS GB
FROM CB_SILVER.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA <> 'INFORMATION_SCHEMA'
UNION ALL
SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, TABLE_TYPE, ROW_COUNT,
       ROUND(BYTES / POWER(1024, 3), 2)
FROM CB_GOLD.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA <> 'INFORMATION_SCHEMA'
ORDER BY FILAS DESC NULLS LAST;

-- el computo esta separado del dato: se apaga y el dato sigue ahi
SHOW WAREHOUSES LIKE 'WH\_%';
SELECT "name" AS COMPUTO, "size" AS TALLA, "state" AS ESTADO,
       "auto_suspend" AS SEGUNDOS_PARA_APAGARSE, "comment" AS PARA_QUE_SIRVE
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
ORDER BY "name";


-- ==========================================================================
-- Paso 2. El recorrido completo de una autorizacion
-- Seguir un mismo registro desde el archivo crudo hasta la respuesta al negocio.
-- ==========================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_ANALITICA;

-- 1. el dato conformado: una autorizacion cualquiera
SELECT AUTORIZACION_ID, FECHA_HORA, MONTO_COP, MODO_ENTRADA,
       CODIGO_RESPUESTA, DESCRIPCION_RESPUESTA, APROBADA,
       COMERCIO_ID, CIUDAD_COMERCIO, SECTOR
FROM CB_SILVER.ADQUIRENCIA.AUTORIZACIONES
WHERE APROBADA = FALSE
LIMIT 1;

-- 2. enriquecido: comercio, terminal y tarjetahabiente en una vista
SELECT AUTORIZACION_ID, FECHA, MONTO_COP, PAN, RAZON_SOCIAL, SECTOR,
       CIUDAD_COMERCIO, TIPO_TERMINAL, SEGMENTO_CLIENTE, BANCO_EMISOR
FROM CB_GOLD.PRODUCTOS.VW_AUTORIZACIONES_360
LIMIT 3;

-- 3. agregado al nivel del negocio
SELECT SECTOR,
       COUNT(DISTINCT COMERCIO_ID)                  AS COMERCIOS,
       SUM(TRX_TOTAL)                               AS TRANSACCIONES,
       ROUND(SUM(MONTO_APROBADO_COP) / 1e9, 2)      AS MILES_MILLONES_COP,
       ROUND(100.0 * SUM(TRX_APROBADAS) / SUM(TRX_TOTAL), 2) AS TASA_APROBACION_PCT
FROM CB_GOLD.PRODUCTOS.VENTAS_MENSUALES_COMERCIO
GROUP BY SECTOR
ORDER BY MILES_MILLONES_COP DESC
LIMIT 10;

-- 4. la pregunta de negocio que motiva todo el workshop:
-- donde se estan cayendo las transacciones y cuanto cuesta
SELECT DESCRIPCION_RESPUESTA                              AS MOTIVO,
       COUNT(*)                                           AS DECLINACIONES,
       ROUND(SUM(MONTO_COP) / 1e9, 2)                     AS MILES_MILLONES_NO_VENDIDOS,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS PCT
FROM CB_SILVER.ADQUIRENCIA.AUTORIZACIONES
WHERE APROBADA = FALSE
GROUP BY DESCRIPCION_RESPUESTA
ORDER BY DECLINACIONES DESC;

-- 5. la ventana de recuperacion viene configurada en cada capa:
-- cualquier estado anterior se consulta sin restaurar un respaldo
SHOW PARAMETERS LIKE 'DATA_RETENTION_TIME_IN_DAYS' IN DATABASE CB_SILVER;
SELECT "key" AS PARAMETRO, "value" AS DIAS_DE_RECUPERACION, "description" AS QUE_SIGNIFICA
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

CALL CB_PLATAFORMA.EVIDENCIA.LOG_EVIDENCIA('T0',
    'Recorrido end-to-end de una autorizacion y flujo de las cuatro capas',
    'CB_SILVER.ADQUIRENCIA.AUTORIZACIONES hasta CB_GOLD.PRODUCTOS',
    'Recorrido de una autorizacion desde la capa conformada hasta el agregado de negocio, con el costo de las declinaciones cuantificado y Time Travel disponible',
    'Anexo 11 - modulo general: flujo end-to-end del dato');


-- ==========================================================================
-- Paso 3. Con que rol entra cada equipo
-- Ver el modelo de roles y comprobar que cada uno ve lo suyo.
-- ==========================================================================

USE ROLE ACCOUNTADMIN;

-- los roles del workshop, uno por equipo del pliego
SHOW ROLES LIKE 'RL\_%';
SELECT "name" AS ROL, "comment" AS EQUIPO
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
ORDER BY "name";

-- que puede hacer un rol concreto: es auditable sin abrir otra consola
SHOW GRANTS TO ROLE RL_ANALISTA;

-- las etiquetas de gobierno que van a usar todos los tracks
SHOW TAGS IN SCHEMA CB_PLATAFORMA.GOBIERNO;
SELECT "name" AS ETIQUETA, "allowed_values" AS VALORES_PERMITIDOS, "comment" AS PARA_QUE_SIRVE
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
ORDER BY "name";

-- la bitacora de evidencia: cada paso de cada track queda registrado
SELECT TRACK, PASOS_EJECUTADOS, REQUISITOS_ACREDITADOS, PARTICIPANTES, DURACION_MIN
FROM CB_PLATAFORMA.EVIDENCIA.VW_EVIDENCIA_POR_TRACK
ORDER BY INICIO;


-- ==========================================================================
-- Cierre: evidencia del track
-- ==========================================================================

-- Resumen de lo ejecutado en este track. Es el artefacto que se entrega al
-- cierre, como exige el numeral 3.2 del Anexo 11.
SELECT PASO, OBJETO, RESULTADO, REQUISITO, EJECUTADO_POR, ROL, MOMENTO
FROM CB_PLATAFORMA.EVIDENCIA.ARTEFACTOS
WHERE TRACK = 'T0'
ORDER BY MOMENTO;

SELECT * FROM CB_PLATAFORMA.EVIDENCIA.VW_EVIDENCIA_POR_TRACK
WHERE TRACK = 'T0';
