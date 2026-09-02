/* ============================================================================
   HOL CredibanCo - RFP 10010806
   T5 - Monetizacion y exposicion

   Equipo    : Arquitectura y Data & Analytics
   Duracion  : 30 minutos
   Prerrequisito: haber ejecutado install_arquitectura.sql en esta cuenta

   Entregar dato a un tercero sin copiarlo ni moverlo, cruzar informacion con un socio sin que ninguno vea la del otro, y publicar un producto en un catalogo interno.
   ==========================================================================*/


-- ==========================================================================
-- Paso 1. Entregar el dato sin entregar el dato
-- Publicar un producto a otra cuenta sin copiar ni exportar nada.
-- ==========================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_ANALITICA;

-- lo que el tercero puede ver: agregados por sector y ciudad, con un umbral
-- minimo de comercios para que ningun agregado identifique a uno solo
CREATE OR REPLACE SECURE VIEW CB_GOLD.PRODUCTOS.VW_INDICADOR_SECTORIAL
    COMMENT = 'Producto monetizable. Agregados por sector, ciudad y mes con k-anonimato de 5 comercios'
AS
SELECT SECTOR,
       CIUDAD_COMERCIO,
       DEPARTAMENTO,
       MES,
       COUNT(DISTINCT COMERCIO_ID)                  AS COMERCIOS,
       SUM(TRX_TOTAL)                               AS TRANSACCIONES,
       ROUND(SUM(MONTO_APROBADO_COP) / 1e6, 2)      AS MONTO_MILLONES_COP,
       ROUND(AVG(TICKET_PROMEDIO_COP), 0)           AS TICKET_PROMEDIO_COP,
       ROUND(100.0 * SUM(TRX_APROBADAS) / NULLIF(SUM(TRX_TOTAL), 0), 2) AS TASA_APROBACION_PCT
FROM CB_GOLD.PRODUCTOS.VENTAS_MENSUALES_COMERCIO
GROUP BY SECTOR, CIUDAD_COMERCIO, DEPARTAMENTO, MES
HAVING COUNT(DISTINCT COMERCIO_ID) >= 5;

SELECT COUNT(*) AS FILAS_PUBLICABLES FROM CB_GOLD.PRODUCTOS.VW_INDICADOR_SECTORIAL;

-- el share: se declara que se comparte, no se mueve nada
CREATE SHARE IF NOT EXISTS SH_INDICADOR_SECTORIAL
    COMMENT = 'Indicador sectorial de adquirencia para bancos emisores';

GRANT USAGE ON DATABASE CB_GOLD TO SHARE SH_INDICADOR_SECTORIAL;
GRANT USAGE ON SCHEMA CB_GOLD.PRODUCTOS TO SHARE SH_INDICADOR_SECTORIAL;
GRANT SELECT ON VIEW CB_GOLD.PRODUCTOS.VW_INDICADOR_SECTORIAL
    TO SHARE SH_INDICADOR_SECTORIAL;

SHOW SHARES LIKE 'SH_INDICADOR_SECTORIAL';

-- que quedo expuesto exactamente: la lista es auditable
SHOW GRANTS TO SHARE SH_INDICADOR_SECTORIAL;

-- se agrega la cuenta del consumidor. En el workshop es la cuenta
-- del equipo de Seguridad, haciendo de banco emisor.
-- ALTER SHARE SH_INDICADOR_SECTORIAL ADD ACCOUNTS = <cuenta_consumidora>;

-- del lado del consumidor, montar el dato compartido es una sentencia y no
-- consume almacenamiento:
-- CREATE DATABASE DATOS_CREDIBANCO FROM SHARE <proveedor>.SH_INDICADOR_SECTORIAL;
-- SELECT * FROM DATOS_CREDIBANCO.PRODUCTOS.VW_INDICADOR_SECTORIAL LIMIT 10;

SELECT 'El consumidor monta el share sin copiar datos ni pagar almacenamiento' AS NOTA;

CALL CB_PLATAFORMA.EVIDENCIA.LOG_EVIDENCIA('T5',
    'Producto de datos compartido a otra cuenta sin copia ni transferencia',
    'SH_INDICADOR_SECTORIAL sobre la vista segura VW_INDICADOR_SECTORIAL',
    'Share con una sola vista segura expuesta y k-anonimato de 5 comercios. Las tablas base con PAN y detalle por comercio quedan fuera, verificable con SHOW GRANTS TO SHARE',
    'Anexo 10 - 7.1 data sharing zero-copy sin transferencia fisica');


-- ==========================================================================
-- Paso 2. Cruzar con un socio sin ver lo del socio
-- Medir el traslape de clientes con un banco sin que ninguno exponga su base.
-- ==========================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_ANALITICA;

CREATE SCHEMA IF NOT EXISTS CB_GOLD.CLEAN_ROOM
    COMMENT = 'Superficie de cruce con terceros. Solo salen agregados';

-- la llave de cruce es un hash con sal compartida. El PAN nunca sale, y el
-- hash sin la sal no sirve para nada fuera de este contexto.
CREATE OR REPLACE SECURE VIEW CB_GOLD.CLEAN_ROOM.VW_IDENTIDADES_HASH
    COMMENT = 'Identificadores hasheados con sal compartida para cruce con terceros'
AS
SELECT SHA2(CONCAT(h.DOCUMENTO, 'sal-acordada-con-el-socio-2026'), 256) AS ID_HASH,
       c.SECTOR,
       c.DEPARTAMENTO,
       COUNT(*)                        AS TRANSACCIONES,
       ROUND(SUM(a.MONTO_COP) / 1e3, 0) AS MONTO_MILES_COP
FROM CB_SILVER.ADQUIRENCIA.AUTORIZACIONES a
JOIN CB_SILVER.ADQUIRENCIA.TARJETAHABIENTES h
  ON h.TARJETAHABIENTE_ID = a.TARJETAHABIENTE_ID
JOIN CB_SILVER.ADQUIRENCIA.COMERCIOS c
  ON c.COMERCIO_ID = a.COMERCIO_ID
WHERE a.APROBADA
GROUP BY ID_HASH, c.SECTOR, c.DEPARTAMENTO;

SELECT COUNT(*) AS FILAS, COUNT(DISTINCT ID_HASH) AS IDENTIDADES
FROM CB_GOLD.CLEAN_ROOM.VW_IDENTIDADES_HASH;

-- la base del socio: en el workshop llega por su propio share.
-- Aqui se simula con una muestra para poder ejecutar el cruce.
CREATE OR REPLACE TABLE CB_GOLD.CLEAN_ROOM.SOCIO_BANCO_HASH AS
SELECT SHA2(CONCAT(DOCUMENTO, 'sal-acordada-con-el-socio-2026'), 256) AS ID_HASH,
       CASE WHEN MOD(ABS(HASH(DOCUMENTO)), 3) = 0 THEN 'NOMINA'
            WHEN MOD(ABS(HASH(DOCUMENTO)), 3) = 1 THEN 'TARJETA_CREDITO'
            ELSE 'AHORROS' END AS PRODUCTO_DEL_BANCO
FROM CB_SILVER.ADQUIRENCIA.TARJETAHABIENTES
SAMPLE (35);

SELECT COUNT(*) AS CLIENTES_DEL_SOCIO FROM CB_GOLD.CLEAN_ROOM.SOCIO_BANCO_HASH;

-- la funcion de cruce: SOLO devuelve agregados y exige un minimo de
-- 100 identidades por celda. Ninguna de las dos partes puede pedir una fila.
CREATE OR REPLACE SECURE FUNCTION CB_GOLD.CLEAN_ROOM.TRASLAPE_POR_SECTOR()
RETURNS TABLE (
    SECTOR VARCHAR, PRODUCTO_DEL_BANCO VARCHAR,
    CLIENTES_EN_COMUN NUMBER, TRANSACCIONES NUMBER, MONTO_MILLONES_COP NUMBER)
COMMENT = 'Traslape de clientes por sector y producto. Suprime celdas con menos de 100 identidades'
AS
$$
    SELECT i.SECTOR,
           s.PRODUCTO_DEL_BANCO,
           COUNT(DISTINCT i.ID_HASH)                     AS CLIENTES_EN_COMUN,
           SUM(i.TRANSACCIONES)                          AS TRANSACCIONES,
           ROUND(SUM(i.MONTO_MILES_COP) / 1000.0, 1)     AS MONTO_MILLONES_COP
    FROM CB_GOLD.CLEAN_ROOM.VW_IDENTIDADES_HASH i
    JOIN CB_GOLD.CLEAN_ROOM.SOCIO_BANCO_HASH s ON s.ID_HASH = i.ID_HASH
    GROUP BY i.SECTOR, s.PRODUCTO_DEL_BANCO
    HAVING COUNT(DISTINCT i.ID_HASH) >= 100
$$;

SELECT * FROM TABLE(CB_GOLD.CLEAN_ROOM.TRASLAPE_POR_SECTOR())
ORDER BY CLIENTES_EN_COMUN DESC
LIMIT 15;

-- verificacion de la restriccion: cuanto se suprimio
WITH todo AS (
    SELECT i.SECTOR, s.PRODUCTO_DEL_BANCO, COUNT(DISTINCT i.ID_HASH) AS N
    FROM CB_GOLD.CLEAN_ROOM.VW_IDENTIDADES_HASH i
    JOIN CB_GOLD.CLEAN_ROOM.SOCIO_BANCO_HASH s ON s.ID_HASH = i.ID_HASH
    GROUP BY 1, 2
)
SELECT COUNT(*)                    AS CELDAS_TOTALES,
       COUNT_IF(N >= 100)          AS CELDAS_PUBLICADAS,
       COUNT_IF(N < 100)           AS CELDAS_SUPRIMIDAS,
       MIN(N)                      AS MINIMO_OBSERVADO
FROM todo;

CALL CB_PLATAFORMA.EVIDENCIA.LOG_EVIDENCIA('T5',
    'Cruce con un socio sin exponer identidades ni bases',
    'CB_GOLD.CLEAN_ROOM: vista de identidades hasheadas y funcion segura con umbral de 100',
    'Traslape de clientes por sector y producto bancario calculado sobre identificadores hasheados con sal compartida, con supresion de celdas pequenas verificada',
    'Anexo 10 - 7.2 data clean rooms con joins hasheados');


-- ==========================================================================
-- Paso 3. Publicar en el catalogo y exponer por API
-- Dejar el producto disponible para descubrir, solicitar y consumir.
-- ==========================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_ANALITICA;

-- el producto se publica en el catalogo interno con su contrato comercial
MERGE INTO CB_PLATAFORMA.GOBIERNO.CATALOGO_PRODUCTOS t
USING (
    SELECT 'DP-005' AS PRODUCTO_ID,
           'Indicador sectorial de adquirencia' AS NOMBRE,
           'MONETIZACION' AS DOMINIO,
           'Agregados de transaccionalidad por sector, ciudad y mes con k-anonimato de 5 comercios. Producto monetizable para bancos emisores y pasarelas.' AS DESCRIPCION,
           'CB_GOLD.PRODUCTOS.VW_INDICADOR_SECTORIAL' AS OBJETO,
           'Gerencia de Datos' AS DUENO,
           'Mensual, quinto dia habil' AS SLA_FRESCURA,
           'USO_INTERNO' AS CLASIFICACION,
           TRUE AS REQUIERE_APROBACION
) s ON t.PRODUCTO_ID = s.PRODUCTO_ID
WHEN NOT MATCHED THEN INSERT
    (PRODUCTO_ID,NOMBRE,DOMINIO,DESCRIPCION,OBJETO,DUENO,SLA_FRESCURA,CLASIFICACION,REQUIERE_APROBACION)
    VALUES (s.PRODUCTO_ID,s.NOMBRE,s.DOMINIO,s.DESCRIPCION,s.OBJETO,s.DUENO,
            s.SLA_FRESCURA,s.CLASIFICACION,s.REQUIERE_APROBACION);

SELECT PRODUCTO_ID, NOMBRE, DOMINIO, SLA_FRESCURA, REQUIERE_APROBACION
FROM CB_PLATAFORMA.GOBIERNO.CATALOGO_PRODUCTOS
ORDER BY PRODUCTO_ID;

-- exposicion por API: la logica de negocio queda del lado del dato,
-- parametrizada, y el gateway corporativo la invoca. No se expone SQL libre.
CREATE OR REPLACE SECURE FUNCTION CB_GOLD.PRODUCTOS.API_INDICADOR_SECTOR(
    P_SECTOR VARCHAR, P_DESDE DATE, P_HASTA DATE)
RETURNS TABLE (
    SECTOR VARCHAR, MES DATE, COMERCIOS NUMBER,
    TRANSACCIONES NUMBER, MONTO_MILLONES_COP NUMBER, TASA_APROBACION_PCT NUMBER)
COMMENT = 'Endpoint del producto DP-005. Recibe sector y rango de fechas y devuelve la serie agregada'
AS
$$
    SELECT SECTOR, MES,
           SUM(COMERCIOS)            AS COMERCIOS,
           SUM(TRANSACCIONES)        AS TRANSACCIONES,
           ROUND(SUM(MONTO_MILLONES_COP), 2) AS MONTO_MILLONES_COP,
           ROUND(AVG(TASA_APROBACION_PCT), 2) AS TASA_APROBACION_PCT
    FROM CB_GOLD.PRODUCTOS.VW_INDICADOR_SECTORIAL
    WHERE SECTOR = P_SECTOR
      AND MES BETWEEN P_DESDE AND P_HASTA
    GROUP BY SECTOR, MES
$$;

-- la misma llamada que haria el gateway
SELECT * FROM TABLE(CB_GOLD.PRODUCTOS.API_INDICADOR_SECTOR(
    'Supermercados', '2025-01-01'::DATE, '2025-12-31'::DATE))
ORDER BY MES;

-- control de acceso al endpoint: se concede la funcion, no la tabla
GRANT USAGE ON SCHEMA CB_GOLD.PRODUCTOS TO ROLE RL_NEGOCIO;
GRANT USAGE ON FUNCTION CB_GOLD.PRODUCTOS.API_INDICADOR_SECTOR(VARCHAR, DATE, DATE)
    TO ROLE RL_NEGOCIO;

CALL CB_PLATAFORMA.EVIDENCIA.LOG_EVIDENCIA('T5',
    'Producto publicado en el catalogo interno y expuesto como endpoint parametrizado',
    'DP-005 en CATALOGO_PRODUCTOS y funcion segura API_INDICADOR_SECTOR',
    'Producto monetizable publicado con SLA y aprobacion requerida, mas endpoint parametrizado que encapsula la regla de negocio y se concede sin exponer las tablas',
    'Anexo 10 - 7.3 marketplace de productos y 7.4 productos de datos como API');


-- ==========================================================================
-- Cierre: evidencia del track
-- ==========================================================================

-- Resumen de lo ejecutado en este track. Es el artefacto que se entrega al
-- cierre, como exige el numeral 3.2 del Anexo 11.
SELECT PASO, OBJETO, RESULTADO, REQUISITO, EJECUTADO_POR, ROL, MOMENTO
FROM CB_PLATAFORMA.EVIDENCIA.ARTEFACTOS
WHERE TRACK = 'T5'
ORDER BY MOMENTO;

SELECT * FROM CB_PLATAFORMA.EVIDENCIA.VW_EVIDENCIA_POR_TRACK
WHERE TRACK = 'T5';
