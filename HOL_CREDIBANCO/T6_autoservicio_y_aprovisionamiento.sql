/* ============================================================================
   HOL CredibanCo - RFP 10010806
   T6 - Autoservicio y aprovisionamiento

   Equipo    : Infraestructura y Experiencia
   Duracion  : 30 minutos
   Prerrequisito: haber ejecutado install_infra.sql en esta cuenta

   Que un usuario de negocio descubra un producto de datos, lo solicite y lo consulte en espanol; y que un sandbox se aprovisione sin que ninguna persona intervenga.
   ==========================================================================*/


-- ==========================================================================
-- Paso 1. Descubrir y solicitar, siendo un usuario de negocio
-- Que alguien sin SQL encuentre el dato que necesita y lo pida.
-- ==========================================================================

USE ROLE ACCOUNTADMIN;

-- GRANT no acepta IDENTIFIER(CURRENT_USER()) directo: pasa por variable de sesion
SET MI_USUARIO = CURRENT_USER();
GRANT ROLE RL_NEGOCIO TO USER IDENTIFIER($MI_USUARIO);

-- el usuario de negocio entra con su rol
USE ROLE RL_NEGOCIO;
USE WAREHOUSE WH_NEGOCIO;

-- que productos de datos existen, en lenguaje de negocio
SELECT PRODUCTO_ID, NOMBRE, DOMINIO, DESCRIPCION, SLA_FRESCURA,
       CLASIFICACION, REQUIERE_APROBACION
FROM CB_PLATAFORMA.GOBIERNO.CATALOGO_PRODUCTOS
ORDER BY DOMINIO, PRODUCTO_ID;

-- lo que ya puede consultar sin pedir nada
SELECT SECTOR,
       COUNT(DISTINCT COMERCIO_ID)             AS COMERCIOS,
       ROUND(SUM(MONTO_APROBADO_COP) / 1e9, 2) AS MILES_MILLONES_COP
FROM CB_GOLD.PRODUCTOS.VENTAS_MENSUALES_COMERCIO
GROUP BY SECTOR
ORDER BY MILES_MILLONES_COP DESC
LIMIT 5;

-- y lo que NO: el producto DP-002 requiere aprobacion
SELECT COUNT(*) FROM CB_GOLD.PRODUCTOS.CUSTOMER_360;

-- solicitar el acceso: el usuario de negocio deja su solicitud
INSERT INTO CB_PLATAFORMA.GOBIERNO.SOLICITUDES
    (PRODUCTO_ID, ROL_DESTINO, JUSTIFICACION)
VALUES ('DP-002', 'RL_NEGOCIO',
        'Analisis de comportamiento de compra por segmento para la campana de fin de ano');

SELECT SOLICITUD_ID, PRODUCTO_ID, SOLICITANTE, ROL_DESTINO, ESTADO, MOMENTO
FROM CB_PLATAFORMA.GOBIERNO.SOLICITUDES
ORDER BY MOMENTO DESC;

USE ROLE ACCOUNTADMIN;
CALL CB_PLATAFORMA.EVIDENCIA.LOG_EVIDENCIA('T6',
    'Flujo descubrir y solicitar operado por un usuario de negocio',
    'CB_PLATAFORMA.GOBIERNO.CATALOGO_PRODUCTOS y SOLICITUDES',
    'El rol de negocio recorrio el catalogo, consulto lo permitido, fue bloqueado en lo que requiere aprobacion y registro su solicitud con justificacion',
    'Anexo 10 - 8.1 marketplace interno descubrir solicitar consumir');


-- ==========================================================================
-- Paso 2. Aprovisionar sin que intervenga una persona
-- Atender la solicitud con codigo, no con un administrador.
-- ==========================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_GOBIERNO;

-- el aprovisionamiento como codigo: crea el sandbox, concede el acceso al
-- producto solicitado, aplica la cuota y cierra la solicitud. Todo en una
-- transaccion logica y con su registro.
CREATE OR REPLACE PROCEDURE CB_PLATAFORMA.GOBIERNO.ATENDER_SOLICITUDES()
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'Atiende las solicitudes pendientes del catalogo: crea sandbox, concede acceso y cierra la solicitud'
EXECUTE AS OWNER
AS
$$
DECLARE
    c CURSOR FOR
        SELECT s.SOLICITUD_ID, s.PRODUCTO_ID, s.ROL_DESTINO, p.OBJETO, p.NOMBRE
        FROM CB_PLATAFORMA.GOBIERNO.SOLICITUDES s
        JOIN CB_PLATAFORMA.GOBIERNO.CATALOGO_PRODUCTOS p
          ON p.PRODUCTO_ID = s.PRODUCTO_ID
        WHERE s.ESTADO = 'PENDIENTE';
    atendidas NUMBER DEFAULT 0;
    esquema   VARCHAR;
BEGIN
    FOR r IN c DO
        -- las columnas del cursor se ligan a variables locales: dentro de un
        -- statement SQL no se pueden referenciar como r.COLUMNA
        LET v_id  NUMBER  := r.SOLICITUD_ID;
        LET v_rol VARCHAR := r.ROL_DESTINO;
        LET v_obj VARCHAR := r.OBJETO;
        esquema := 'SBX_' || :v_id;

        -- sandbox propio del solicitante, aislado del resto
        EXECUTE IMMEDIATE 'CREATE SCHEMA IF NOT EXISTS CB_GOLD.' || :esquema
            || ' COMMENT = ''Sandbox aprovisionado automaticamente para la solicitud '
            || :v_id || '''';
        EXECUTE IMMEDIATE 'GRANT USAGE ON SCHEMA CB_GOLD.' || :esquema
            || ' TO ROLE ' || :v_rol;
        EXECUTE IMMEDIATE 'GRANT CREATE TABLE, CREATE VIEW ON SCHEMA CB_GOLD.'
            || :esquema || ' TO ROLE ' || :v_rol;

        -- acceso al producto solicitado
        EXECUTE IMMEDIATE 'GRANT SELECT ON ' || :v_obj || ' TO ROLE ' || :v_rol;

        -- computo del sandbox, con su cuota ya asociada
        EXECUTE IMMEDIATE 'GRANT USAGE ON WAREHOUSE WH_SANDBOX TO ROLE ' || :v_rol;

        UPDATE CB_PLATAFORMA.GOBIERNO.SOLICITUDES
        SET ESTADO = 'APROVISIONADA', ATENDIDA_EN = CURRENT_TIMESTAMP()
        WHERE SOLICITUD_ID = :v_id;

        CALL CB_PLATAFORMA.EVIDENCIA.LOG_EVIDENCIA('T6',
            'Aprovisionamiento automatico de la solicitud ' || :v_id,
            'CB_GOLD.' || :esquema || ' y acceso a ' || :v_obj,
            'Sandbox, permisos y computo entregados sin intervencion humana',
            'Anexo 10 - 1.7 IaC y 8.1 aprovisionamiento automatico');

        atendidas := atendidas + 1;
    END FOR;
    RETURN 'Solicitudes atendidas: ' || :atendidas;
END;
$$;

-- ejecutarlo una vez, para verificar que hace lo que dice
CALL CB_PLATAFORMA.GOBIERNO.ATENDER_SOLICITUDES();

SELECT SOLICITUD_ID, PRODUCTO_ID, ROL_DESTINO, ESTADO, MOMENTO, ATENDIDA_EN,
       DATEDIFF('second', MOMENTO, ATENDIDA_EN) AS SEGUNDOS_DE_ESPERA
FROM CB_PLATAFORMA.GOBIERNO.SOLICITUDES
ORDER BY SOLICITUD_ID;

-- y ahora el usuario de negocio SI puede consultar lo que pidio
USE ROLE RL_NEGOCIO;
USE WAREHOUSE WH_NEGOCIO;

SELECT SEGMENTO_CLIENTE,
       COUNT(*)                          AS CLIENTES,
       ROUND(AVG(TICKET_PROMEDIO), 0)    AS TICKET_PROMEDIO_COP,
       ROUND(SUM(MONTO_TOTAL) / 1e9, 2)  AS MILES_MILLONES_COP
FROM CB_GOLD.PRODUCTOS.CUSTOMER_360
GROUP BY SEGMENTO_CLIENTE
ORDER BY MILES_MILLONES_COP DESC;

-- y tiene su sandbox para trabajar.
-- El nombre se deriva del id de la solicitud: las columnas IDENTITY reservan
-- rangos, asi que la primera solicitud no es necesariamente la numero 1.
USE ROLE RL_NEGOCIO;
USE WAREHOUSE WH_NEGOCIO;

SET MI_SANDBOX = (
    SELECT 'CB_GOLD.SBX_' || MAX(SOLICITUD_ID) || '.MI_ANALISIS'
    FROM CB_PLATAFORMA.GOBIERNO.SOLICITUDES
    WHERE ESTADO = 'APROVISIONADA');

SELECT $MI_SANDBOX AS DONDE_VOY_A_TRABAJAR;

CREATE OR REPLACE TABLE IDENTIFIER($MI_SANDBOX) AS
SELECT SEGMENTO_CLIENTE, CIUDAD_RESIDENCIA, COUNT(*) AS CLIENTES
FROM CB_GOLD.PRODUCTOS.CUSTOMER_360
GROUP BY SEGMENTO_CLIENTE, CIUDAD_RESIDENCIA;

SELECT COUNT(*) AS FILAS_EN_MI_SANDBOX FROM IDENTIFIER($MI_SANDBOX);

-- para dejarlo desatendido: una tarea que lo corre sola cada 5 minutos
USE ROLE ACCOUNTADMIN;
CREATE OR REPLACE TASK CB_PLATAFORMA.GOBIERNO.TSK_ATENDER_SOLICITUDES
    WAREHOUSE = WH_GOBIERNO
    SCHEDULE = '5 MINUTE'
    COMMENT = 'Atiende las solicitudes pendientes del catalogo sin intervencion humana'
AS
    CALL CB_PLATAFORMA.GOBIERNO.ATENDER_SOLICITUDES();

ALTER TASK CB_PLATAFORMA.GOBIERNO.TSK_ATENDER_SOLICITUDES RESUME;

SHOW TASKS LIKE 'TSK_ATENDER%' IN SCHEMA CB_PLATAFORMA.GOBIERNO;
SELECT "name" AS TAREA, "state" AS ESTADO, "schedule" AS FRECUENCIA
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

CALL CB_PLATAFORMA.EVIDENCIA.LOG_EVIDENCIA('T6',
    'Aprovisionamiento automatico con procedimiento y tarea desatendida',
    'CB_PLATAFORMA.GOBIERNO.ATENDER_SOLICITUDES y TSK_ATENDER_SOLICITUDES cada 5 minutos',
    'Sandbox, permisos sobre el producto y computo con cuota entregados sin intervencion humana, con el tiempo de espera medido en segundos',
    'Anexo 10 - 1.7 IaC y criterio 10 aprovisionamiento sin intervencion humana');


-- ==========================================================================
-- Paso 3. Preguntar en espanol, sobre datos gobernados
-- Que un usuario de negocio obtenga la respuesta sin escribir SQL.
-- ==========================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_NEGOCIO;

-- la capa semantica disponible en esta cuenta
SHOW SEMANTIC VIEWS LIKE 'SV_ADQUIRENCIA' IN SCHEMA CB_GOLD.PRODUCTOS;

-- las metricas y dimensiones que el agente puede usar: nada mas
SELECT * FROM SEMANTIC_VIEW(
    CB_GOLD.PRODUCTOS.SV_ADQUIRENCIA
    DIMENSIONS SECTOR
    METRICS MONTO_APROBADO, TRANSACCIONES, TICKET_PROMEDIO, TASA_APROBACION
)
ORDER BY MONTO_APROBADO DESC
LIMIT 10;

-- el agente: se le dice de que responde y con que herramienta
CREATE OR REPLACE AGENT CB_GOLD.PRODUCTOS.AGT_ADQUIRENCIA
WITH PROFILE = '{"display_name": "Analista de Adquirencia"}'
COMMENT = 'Agente de consulta en lenguaje natural sobre el modelo semantico de adquirencia'
FROM SPECIFICATION
$$
models:
  orchestration: auto
instructions:
  orchestration: >
    Responde unicamente con la informacion del modelo semantico de adquirencia.
    Si la pregunta pide un dato que no esta en el modelo, dilo de forma explicita
    en vez de aproximar. Los montos estan en pesos colombianos.
  response: >
    Responde en espanol, de forma breve y con cifras. Cuando el resultado tenga
    mas de tres filas, presentalo como tabla. Cierra con una observacion util
    para el negocio, no con un resumen de lo que ya dijiste.
tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: adquirencia
tool_resources:
  adquirencia:
    semantic_view: CB_GOLD.PRODUCTOS.SV_ADQUIRENCIA
    execution_environment:
      type: warehouse
      warehouse: WH_NEGOCIO
$$;

SHOW AGENTS LIKE 'AGT_ADQUIRENCIA' IN SCHEMA CB_GOLD.PRODUCTOS;

-- permisos: el negocio usa el agente, no la tabla
GRANT USAGE ON AGENT CB_GOLD.PRODUCTOS.AGT_ADQUIRENCIA TO ROLE RL_NEGOCIO;
GRANT USAGE ON AGENT CB_GOLD.PRODUCTOS.AGT_ADQUIRENCIA TO ROLE RL_ANALISTA;

-- verificacion del limite de gobierno: la capa semantica no expone
-- el PAN, asi que el agente no tiene camino hacia el
SELECT COUNT(*) AS COLUMNAS_SENSIBLES_EN_EL_MODELO
FROM CB_GOLD.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME IN ('VENTAS_MENSUALES_COMERCIO')
  AND UPPER(COLUMN_NAME) IN ('PAN', 'DOCUMENTO', 'EMAIL', 'CELULAR', 'NOMBRE_COMPLETO');

CALL CB_PLATAFORMA.EVIDENCIA.LOG_EVIDENCIA('T6',
    'Agente de consulta en lenguaje natural sobre la capa semantica gobernada',
    'CB_GOLD.PRODUCTOS.AGT_ADQUIRENCIA sobre SV_ADQUIRENCIA',
    'Agente creado sobre el modelo semantico con permisos por rol; el producto que lo alimenta no contiene columnas sensibles, verificado por consulta al catalogo',
    'Anexo 10 - 8.2 consulta en lenguaje natural y 10.4 agentes gobernados por el catalogo');


-- ==========================================================================
-- Cierre: evidencia del track
-- ==========================================================================

-- Resumen de lo ejecutado en este track. Es el artefacto que se entrega al
-- cierre, como exige el numeral 3.2 del Anexo 11.
SELECT PASO, OBJETO, RESULTADO, REQUISITO, EJECUTADO_POR, ROL, MOMENTO
FROM CB_PLATAFORMA.EVIDENCIA.ARTEFACTOS
WHERE TRACK = 'T6'
ORDER BY MOMENTO;

SELECT * FROM CB_PLATAFORMA.EVIDENCIA.VW_EVIDENCIA_POR_TRACK
WHERE TRACK = 'T6';
