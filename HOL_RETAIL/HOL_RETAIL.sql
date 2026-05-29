/* ********************************************************************************************
                   HANDS ON LAB - SuperPlus Retail FMCG
                   "From S3 to Intelligence" - basado en Zero2Snowflake
********************************************************************************************
 Este archivo SQL es la guía del HOL. Copia todo el contenido en un Worksheet de Snowflake.
 Recorre las 12 partes en orden. Comentarios y notas en español.
 Datos sintéticos en s3://demosjparrado/retail_hol/ (4 tablas, gzip)
******************************************************************************************** */
-- AWS_KEY_ID     = '<SOLICITAR_AL_INSTRUCTOR>'
-- AWS_SECRET_KEY = '<SOLICITAR_AL_INSTRUCTOR>'

/* ************************************ PARTE 1 ************************************************
   Definimos el ambiente: base de datos, warehouse y esquema.
******************************************************************************************** */
USE ROLE ACCOUNTADMIN;
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';

CREATE OR REPLACE DATABASE DB_HOL_RETAIL
  COMMENT = 'Base de datos del HOL Retail SuperPlus (Supermercado FMCG)';

CREATE OR REPLACE WAREHOUSE WH_HOL_RETAIL
WITH
  WAREHOUSE_SIZE = 'SMALL'
  WAREHOUSE_TYPE = 'STANDARD'
  AUTO_SUSPEND   = 60
  AUTO_RESUME    = TRUE
  MIN_CLUSTER_COUNT = 1
  MAX_CLUSTER_COUNT = 2
  SCALING_POLICY = 'STANDARD';

USE WAREHOUSE WH_HOL_RETAIL;
USE DATABASE  DB_HOL_RETAIL;
USE SCHEMA    PUBLIC;


/* ************************************ PARTE 2 ************************************************
   Stage externo a AWS S3 + File Format.
   El bucket s3://demosjparrado/retail_hol/ contiene archivos .csv.gz
******************************************************************************************** */

-- File format CSV gzip
CREATE OR REPLACE FILE FORMAT FF_CSV_GZ
  TYPE = CSV
  FIELD_DELIMITER = ';'
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  COMPRESSION = GZIP
  NULL_IF = ('NULL','')
  EMPTY_FIELD_AS_NULL = TRUE
  TIMESTAMP_FORMAT = 'YYYY-MM-DD HH24:MI:SS.FF3'
  SKIP_HEADER = 1
  COMMENT = 'CSV ; gzip para datasets HOL Retail';

-- Stage externo (credenciales embebidas, read-only)
CREATE OR REPLACE STAGE STG_RETAIL
  URL = 's3://demosjparrado/retail_hol/'
  CREDENTIALS = (AWS_KEY_ID='<SOLICITAR_AL_INSTRUCTOR>' AWS_SECRET_KEY='<SOLICITAR_AL_INSTRUCTOR>')
  FILE_FORMAT = FF_CSV_GZ
  COMMENT = 'Stage externo HOL Retail - lectura del dataset sintético';

-- Listar lo que hay en el stage
LIST @STG_RETAIL/cliente/;
LIST @STG_RETAIL/ticket/;
LIST @STG_RETAIL/linea_ticket/;
LIST @STG_RETAIL/promo_aplicada/;

-- Validar formato leyendo unas filas crudas sin cargarlas
SELECT $1, $2, $3, $4, $5, $6, $7, $8
FROM @STG_RETAIL/cliente/ (FILE_FORMAT => FF_CSV_GZ)
LIMIT 5;


/* ************************************ PARTE 3 ************************************************
   DDL de las 4 tablas con comentarios + COPY INTO.
   Jerarquía: CLIENTE 1:N TICKET 1:N LINEA_TICKET 1:N PROMO_APLICADA
******************************************************************************************** */

CREATE OR REPLACE TABLE CLIENTE (
  IdCliente     NUMBER         COMMENT 'Identificador único del cliente (comprador) en el ecosistema',
  NomCliente    VARCHAR        COMMENT 'Nombre(s) del cliente',
  ApeCliente    VARCHAR        COMMENT 'Apellido(s) del cliente',
  FecNacimiento TIMESTAMP_NTZ  COMMENT 'Fecha de nacimiento del cliente',
  Genero        VARCHAR        COMMENT 'Género: Femenino, Masculino o Indeterminado',
  Email         VARCHAR        COMMENT 'Correo electrónico del cliente',
  Ciudad        VARCHAR        COMMENT 'Ciudad de residencia del cliente',
  NivelLealtad  VARCHAR        COMMENT 'Nivel del programa de fidelidad: Bronce, Plata, Oro, Platino, Diamante'
) COMMENT='Clientes (compradores) fidelizados de la cadena SuperPlus';

CREATE OR REPLACE TABLE TICKET (
  IdTicket       NUMBER         COMMENT 'Identificador único del ticket / transacción de compra',
  IdCliente      NUMBER         COMMENT 'FK al cliente (CLIENTE.IdCliente)',
  FecCompra      TIMESTAMP_NTZ  COMMENT 'Fecha y hora en la que el cliente realiza la compra',
  FecEntrega     TIMESTAMP_NTZ  COMMENT 'Fecha de entrega (igual a la compra si fue retiro en tienda)',
  CanalVenta     VARCHAR        COMMENT 'Canal de venta: Tienda Física, App Móvil, Web, Domicilio, Marketplace',
  EstadoTicket   VARCHAR        COMMENT 'Estado del ticket: Pagado, Entregado, En Camino, Devuelto, Cancelado',
  MontoTotal     NUMBER(12,2)   COMMENT 'Monto total del ticket en COP',
  NomTienda      VARCHAR        COMMENT 'Nombre de la tienda física o centro logístico que atiende el ticket'
) COMMENT='Tickets / transacciones de compra de los clientes';

CREATE OR REPLACE TABLE LINEA_TICKET (
  IdLinea       NUMBER                  COMMENT 'Identificador único del ítem del ticket (línea / SKU comprado)',
  IdTicket      NUMBER                  COMMENT 'FK al ticket (TICKET.IdTicket)',
  NomProducto   VARCHAR                 COMMENT 'Nombre del producto comprado en la línea',
  Categoria     VARCHAR                 COMMENT 'Categoría del producto: Lácteos, Panadería, Despensa, Bebidas, Aseo, Higiene, Carnes, Frutas y Verduras',
  Cantidad      NUMBER                  COMMENT 'Cantidad de unidades compradas en la línea',
  DesResena     VARCHAR(16777216)       COMMENT 'Reseña del cliente sobre el producto (texto libre - opinión / experiencia de uso)',
  FechaResena   TIMESTAMP_NTZ           COMMENT 'Fecha y hora en la que el cliente publicó la reseña',
  Esquema       VARCHAR                 COMMENT 'Categoría del registro: OPINION, RECOMENDACION o DESCRIPCION'
) COMMENT='Ítems (líneas SKU) del ticket de compra con reseña del cliente';

CREATE OR REPLACE TABLE PROMO_APLICADA (
  IdLinea         NUMBER         COMMENT 'FK a la línea del ticket (LINEA_TICKET.IdLinea)',
  IdPromo         NUMBER         COMMENT 'Identificador de la promoción aplicada',
  NomPromo        VARCHAR        COMMENT 'Nombre comercial de la promoción (descriptivo)',
  CodPromo        VARCHAR        COMMENT 'Código interno de la promoción',
  IndPrincipal    NUMBER(1,0)    COMMENT '1 = promoción principal de la línea, 0 = secundaria',
  SecPrioridad    NUMBER         COMMENT 'Orden de prioridad de aplicación de la promoción'
) COMMENT='Promociones aplicadas a las líneas del ticket';

-- COPY INTO desde S3

-- Antes prueba de performance
COPY INTO PROMO_APLICADA FROM @STG_RETAIL/promo_aplicada/ ;

SELECT 'PROMO_APLICADA',  COUNT(*) registros FROM PROMO_APLICADA;

TRUNCATE table PROMO_APLICADA;

ALTER WAREHOUSE WH_HOL_RETAIL SET WAREHOUSE_SIZE = 'LARGE';

COPY INTO PROMO_APLICADA FROM @STG_RETAIL/promo_aplicada/ ;

SELECT 'PROMO_APLICADA',  COUNT(*) registros FROM PROMO_APLICADA;

-- Continuemos con la carga
COPY INTO CLIENTE        FROM @STG_RETAIL/cliente/        ;
COPY INTO TICKET         FROM @STG_RETAIL/ticket/         ;
COPY INTO LINEA_TICKET   FROM @STG_RETAIL/linea_ticket/   ;

ALTER WAREHOUSE WH_HOL_RETAIL SET WAREHOUSE_SIZE = 'XSMALL';

-- Conteos
SELECT 'CLIENTE'         tabla, COUNT(*) registros FROM CLIENTE          UNION ALL
SELECT 'TICKET',                COUNT(*)            FROM TICKET           UNION ALL
SELECT 'LINEA_TICKET',          COUNT(*)            FROM LINEA_TICKET     UNION ALL
SELECT 'PROMO_APLICADA',        COUNT(*)            FROM PROMO_APLICADA;


/* ************************************ PARTE 4 ************************************************
   Performance & Warehouse Scaling - comparemos tiempos.
******************************************************************************************** */

-- Top 10 productos más vendidos
SELECT NomProducto, Categoria, COUNT(*) total_lineas, SUM(Cantidad) unidades
FROM LINEA_TICKET -- 120 millones de registros
GROUP BY 1, 2
ORDER BY unidades DESC
LIMIT 10;

-- Análisis cruzado de las 4 tablas: top combinaciones
-- nivel de lealtad x canal x categoría x promoción principal en los últimos 6 meses
SELECT
  c.NivelLealtad,
  t.CanalVenta,
  l.Categoria,
  p.NomPromo,
  COUNT(DISTINCT t.IdTicket) AS tickets,
  SUM(l.Cantidad)            AS unidades,
  SUM(t.MontoTotal)          AS ventas
FROM CLIENTE c                 -- 30 millones
JOIN TICKET t          ON t.IdCliente = c.IdCliente   -- 80 millones
JOIN LINEA_TICKET l    ON l.IdTicket  = t.IdTicket    -- 120 millones
JOIN PROMO_APLICADA p  ON p.IdLinea   = l.IdLinea     -- 150 millones
WHERE t.FecCompra >= DATEADD(month, -6, CURRENT_DATE())
  AND p.IndPrincipal = 1
GROUP BY 1, 2, 3, 4
ORDER BY ventas DESC
LIMIT 10;



/* ************************************ PARTE 5 ************************************************
   Time Travel y Zero-Copy Cloning - recuperación instantánea sin duplicar almacenamiento.
******************************************************************************************** */

-- Clonemos una tabla
CREATE OR REPLACE TABLE CLIENTE_DEV CLONE CLIENTE;

-- Clonemos toda la base de datos (dev environment instantáneo)
CREATE OR REPLACE DATABASE DB_HOL_RETAIL_DEV CLONE DB_HOL_RETAIL;

-- Error intencional: borremos producción
DROP DATABASE DB_HOL_RETAIL;

-- Restauración con UNDROP (no necesitamos llamar al DBA)
UNDROP DATABASE DB_HOL_RETAIL;

-- Verifica que sigue todo
USE DATABASE DB_HOL_RETAIL;
USE SCHEMA PUBLIC;
SELECT COUNT(*) FROM CLIENTE;


-- ----------------------------------------------------------------------------
-- Time Travel: rollback de un UPDATE "por error" usando AT(OFFSET => -60*10)
-- ----------------------------------------------------------------------------

-- Snapshot original: distribución de niveles de lealtad de clientes en Bogota
SELECT 'antes_update' AS estado, NivelLealtad, COUNT(*) AS clientes
FROM CLIENTE WHERE Ciudad='Bogota' GROUP BY 1, 2 ORDER BY 2;

-- UPDATE masivo "por error": ascendemos a Diamante a TODOS los clientes de Bogota
UPDATE CLIENTE SET NivelLealtad='Diamante' WHERE Ciudad='Bogota';

-- Confirmamos el daño
SELECT 'despues_update' AS estado, NivelLealtad, COUNT(*) AS clientes
FROM CLIENTE WHERE Ciudad='Bogota' GROUP BY 1, 2 ORDER BY 2 DESC;

-- Time Travel: consultar la tabla 10 minutos atrás (sin restaurar todavía)
SELECT 'time_travel_10min' AS estado, NivelLealtad, COUNT(*) AS clientes
FROM CLIENTE AT(OFFSET => -60*10)
WHERE Ciudad='Bogota' GROUP BY 1, 2 ORDER BY 2 DESC;

-- Restauración instantánea: reemplazar la tabla con el snapshot de hace 10 minutos
CREATE OR REPLACE TABLE CLIENTE AS
SELECT * FROM CLIENTE AT(OFFSET => -60*10);

-- Verificamos que la distribución original quedó restaurada
SELECT 'restaurado' AS estado, NivelLealtad, COUNT(*) AS clientes
FROM CLIENTE WHERE Ciudad='Bogota' GROUP BY 1, 2 ORDER BY 2 DESC;


/* ************************************ PARTE 6 ************************************************
   Masking dinámico condicional por rol - clave para Snowflake Intelligence.
   ACCOUNTADMIN ve todo. ANALISTA_COMERCIAL ve datos enmascarados.
******************************************************************************************** */
USE ROLE ACCOUNTADMIN;
USE DATABASE DB_HOL_RETAIL;
USE SCHEMA PUBLIC;

-- Rol restringido
CREATE OR REPLACE ROLE ANALISTA_COMERCIAL;
GRANT USAGE  ON DATABASE  DB_HOL_RETAIL                     TO ROLE ANALISTA_COMERCIAL;
GRANT USAGE  ON SCHEMA    DB_HOL_RETAIL.PUBLIC              TO ROLE ANALISTA_COMERCIAL;
GRANT SELECT ON ALL TABLES IN SCHEMA DB_HOL_RETAIL.PUBLIC   TO ROLE ANALISTA_COMERCIAL;
GRANT USAGE  ON WAREHOUSE WH_HOL_RETAIL                     TO ROLE ANALISTA_COMERCIAL;

-- Asigna el rol a tu usuario (REEMPLAZA POR TU USUARIO)
GRANT ROLE ANALISTA_COMERCIAL TO USER JPARRADO;

-- Política para nombres y apellidos
CREATE OR REPLACE MASKING POLICY mp_nombre AS (val STRING) RETURNS STRING ->
  CASE
    WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN') THEN val
    ELSE '****'
  END;

-- Política para email (preserva dominio, oculta usuario)
CREATE OR REPLACE MASKING POLICY mp_email AS (val STRING) RETURNS STRING ->
  CASE
    WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN') THEN val
    ELSE CONCAT('****@', SPLIT_PART(val, '@', 2))
  END;

-- Política para fecha de nacimiento (solo año visible al rol restringido)
CREATE OR REPLACE MASKING POLICY mp_fecnac AS (val TIMESTAMP_NTZ) RETURNS TIMESTAMP_NTZ ->
  CASE
    WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN') THEN val
    ELSE DATE_TRUNC('year', val)::TIMESTAMP_NTZ
  END;

-- Política para texto de reseña (preserva un breve preview, oculta el resto)
CREATE OR REPLACE MASKING POLICY mp_texto_resena AS (val STRING) RETURNS STRING ->
  CASE
    WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN') THEN val
    ELSE LEFT(val, 50) || ' ... [INFORMACIÓN COMERCIAL RESTRINGIDA POR POLÍTICA DE PRIVACIDAD]'
  END;

-- Asociación a las columnas
ALTER TABLE CLIENTE      MODIFY COLUMN NomCliente    SET MASKING POLICY mp_nombre;
ALTER TABLE CLIENTE      MODIFY COLUMN ApeCliente    SET MASKING POLICY mp_nombre;
ALTER TABLE CLIENTE      MODIFY COLUMN FecNacimiento SET MASKING POLICY mp_fecnac;
ALTER TABLE CLIENTE      MODIFY COLUMN Email         SET MASKING POLICY mp_email;
ALTER TABLE LINEA_TICKET MODIFY COLUMN DesResena     SET MASKING POLICY mp_texto_resena;


-- Consulta como ACCOUNTADMIN (ve todo)
SELECT c.IdCliente, c.NomCliente, c.ApeCliente, c.FecNacimiento, c.Email, c.Genero, c.NivelLealtad,
       l.IdLinea, l.NomProducto, LEFT(l.DesResena, 200) AS DesResena_Preview
FROM CLIENTE c -- 30 millones
JOIN TICKET t        ON c.IdCliente = t.IdCliente   -- 80 millones
JOIN LINEA_TICKET l  ON t.IdTicket = l.IdTicket     -- 120 millones
LIMIT 10;

-- Cambiamos de rol
USE ROLE ANALISTA_COMERCIAL;

-- Misma query: ahora los datos están enmascarados
SELECT c.IdCliente, c.NomCliente, c.ApeCliente, c.FecNacimiento, c.Email, c.Genero, c.NivelLealtad,
       l.IdLinea, l.NomProducto, LEFT(l.DesResena, 200) AS DesResena_Preview
FROM CLIENTE c
JOIN TICKET t        ON c.IdCliente = t.IdCliente
JOIN LINEA_TICKET l  ON t.IdTicket = l.IdTicket
LIMIT 10;

-- Volvemos al rol admin
USE ROLE ACCOUNTADMIN;


/* ************************************ PARTE 7 ************************************************
   Cortex AI Functions sobre datos comerciales - sin extraer datos del entorno.
******************************************************************************************** */

-- 1. Resolver preguntas con LLMs sin APIs
SELECT SNOWFLAKE.CORTEX.COMPLETE(
  'claude-sonnet-4-5',
  'Resume en 5 puntos las ventajas de usar Snowflake Cortex AI para una cadena de retail FMCG como SuperPlus. (entrega el resultado con salto de línea)'
) AS respuesta;

-- 2. Resumir reseñas con COMPLETE
SELECT
  IdLinea,
  NomProducto,
  LEFT(DesResena, 100) AS preview,
  SNOWFLAKE.CORTEX.COMPLETE(
    'openai-gpt-5.1',
    CONCAT('Resume en máximo 5 palabras la siguiente reseña de cliente: ', DesResena)
  ) AS resumen_resena
FROM LINEA_TICKET
LIMIT 10;

-- 3. Valoración comercial multi-aspecto con LLM
SELECT
  IdLinea,
  NomProducto,
  DesResena,
  SNOWFLAKE.CORTEX.COMPLETE(
    'openai-gpt-4.1',
    CONCAT(
      'Evalúa la siguiente reseña en escala 1-5 para: satisfaccion, calidad_percibida, intencion_recompra y servicio. Responde solo en JSON con el formato {satisfaccion:N,calidad_percibida:N,intencion_recompra:N,servicio:N}. Texto: ',
      LEFT(DesResena, 1500)
    )
  ) AS valoracion
FROM LINEA_TICKET
LIMIT 10;


-- 4. AI_AGG: insight agregado sobre múltiples reseñas
SELECT
  AI_AGG(
    DesResena,
    'Resume en 3 bullets los temas más frecuentes que mencionan los clientes: qué les gusta, qué critican y oportunidades de mejora'
  ) AS insight
FROM (
  SELECT DesResena
  FROM LINEA_TICKET
  WHERE FechaResena >= '2026-01-01'
  LIMIT 100
);

-- 5. AI_TRANSLATE
SELECT
  IdLinea,
  SNOWFLAKE.CORTEX.AI_TRANSLATE(LEFT(DesResena, 400), 'es', 'en') AS translation
FROM LINEA_TICKET
LIMIT 3;


/* ************************************ PARTE 7B ***********************************************
   Datos no estructurados - PDFs, imágenes y audio procesados con Cortex AI.
   Bucket: s3://demosjparrado/retail_hol/archivos/  (archivos sintéticos)
******************************************************************************************** */
USE ROLE ACCOUNTADMIN;
USE DATABASE DB_HOL_RETAIL; USE SCHEMA PUBLIC; USE WAREHOUSE WH_HOL_RETAIL;

-- Stage externo dedicado al subprefijo archivos (DIRECTORY ENABLE para list y TO_FILE)
CREATE OR REPLACE STAGE STG_ARCHIVOS_RETAIL
  URL = 's3://demosjparrado/retail_hol/archivos/'
  CREDENTIALS = (AWS_KEY_ID='<SOLICITAR_AL_INSTRUCTOR>' AWS_SECRET_KEY='<SOLICITAR_AL_INSTRUCTOR>')
  DIRECTORY = (ENABLE = TRUE);

LIST @STG_ARCHIVOS_RETAIL;

-- ----------------------------------------------------------------------------
-- A) DOCUMENTOS (PDF) — texto + extracción estructurada
-- ----------------------------------------------------------------------------

-- 1. AI_PARSE_DOCUMENT: OCR simple sobre la factura PDF (texto plano)
SELECT AI_PARSE_DOCUMENT(
  TO_FILE('@STG_ARCHIVOS_RETAIL','factura_001.pdf'),
  {'mode':'OCR'}
) AS contenido_pdf;

-- 2. AI_EXTRACT: extracción estructurada de campos del recibo POS
WITH extraccion AS (
  SELECT AI_EXTRACT(
    file => TO_FILE('@STG_ARCHIVOS_RETAIL','recibo_pos_001.pdf'),
    responseFormat => [
      ['transaccion_id', 'ID de la transacción'],
      ['cajero',         'Nombre o código del cajero'],
      ['subtotal',       'Subtotal antes de impuestos'],
      ['iva',            'Valor del IVA'],
      ['total',          'Valor total'],
      ['items_count',    'Cantidad total de ítems'],
      ['descuento',      'Descuento aplicado']
    ]
  ) AS resultado
)
SELECT
  resultado:response:transaccion_id::STRING AS transaccion_id,
  resultado:response:cajero::STRING         AS cajero,
  resultado:response:subtotal::STRING       AS subtotal,
  resultado:response:iva::STRING            AS iva,
  resultado:response:total::STRING          AS total,
  resultado:response:items_count::STRING    AS items_count,
  resultado:response:descuento::STRING      AS descuento
FROM extraccion;


-- ----------------------------------------------------------------------------
-- B) IMÁGENES — multimodal (visión)
-- ----------------------------------------------------------------------------

-- 3. AI_COMPLETE multimodal con pixtral-large: lectura simple de etiqueta de producto
SELECT SNOWFLAKE.CORTEX.COMPLETE(
  'pixtral-large',
  PROMPT('Extrae la información nutricional y de marca de esta etiqueta de producto: marca, nombre del producto, peso/volumen, calorías por porción, fecha de vencimiento. {0}',
         TO_FILE('@STG_ARCHIVOS_RETAIL','etiqueta_producto_001.png'))
) AS etiqueta_datos;

-- 4. AI_COMPLETE con claude-opus: lectura de cupón con extracción estructurada en JSON
SELECT SNOWFLAKE.CORTEX.COMPLETE(
  'claude-opus-4-5',
  PROMPT('Lee este cupón de descuento y devuelve en JSON: codigo_cupon, porcentaje_descuento, fecha_vigencia, condiciones, productos_aplicables. {0}',
         TO_FILE('@STG_ARCHIVOS_RETAIL','cupon_descuento_001.png'))
) AS cupon_datos;

-- 5. AI_COMPLETE multimodal: análisis de góndola / visual merchandising
--    Caso de uso avanzado: pasamos una foto de la tienda a un modelo de visión
--    y pedimos un diagnóstico estructurado con recomendaciones priorizadas.
SELECT SNOWFLAKE.CORTEX.COMPLETE(
  'pixtral-large',
  PROMPT('Eres un experto en visual merchandising y trade marketing para retail FMCG. Analiza esta foto de una góndola / exhibición de tienda y devuelve un JSON con: 1) estado_general (ordenado/desordenado), 2) categorias_detectadas, 3) problemas_visuales (lista: producto fuera de lugar, sobre-stock, faltantes, falta de etiquetado, mezcla de categorías, etc.), 4) impacto_estimado_ventas (alto/medio/bajo con justificación), 5) recomendaciones_priorizadas (3 acciones concretas para mejorar la visualización y la experiencia del comprador). Responde solo en JSON y en español. {0}',
         TO_FILE('@STG_ARCHIVOS_RETAIL','producto_foto_001.jpg'))
) AS analisis_gondola;


-- ----------------------------------------------------------------------------
-- C) AUDIO — transcripción + extracción + sentimiento
-- ----------------------------------------------------------------------------

-- 6. AI_TRANSCRIBE: transcripción simple de una llamada de venta consultiva
--    Audio: asesor ofreciendo un producto / servicio complementario a un cliente
SELECT TO_VARCHAR(AI_TRANSCRIBE(
  TO_FILE('@STG_ARCHIVOS_RETAIL','ofreciendo-producto.mp3')
)) AS transcripcion;

-- 7. CASO END-TO-END sobre 2 audios reales del call center (oferta y queja):
--    AI_TRANSCRIBE  → texto
--    AI_SENTIMENT   → sentimiento por aspecto
--    AI_EXTRACT     → cliente, agente, motivo, monto, decisión
--    AI_COMPLETE    → coach de Customer Experience (clasificación, prioridad,
--                     siguiente_accion y riesgo_churn 0-100) en JSON
WITH llamadas AS (
  SELECT 'oferta'         AS tipo_llamada,
         AI_TRANSCRIBE(TO_FILE('@STG_ARCHIVOS_RETAIL','ofreciendo-producto.mp3')):text::STRING AS texto
  UNION ALL
  SELECT 'queja_servicio',
         AI_TRANSCRIBE(TO_FILE('@STG_ARCHIVOS_RETAIL','problema-servicio.mp3')):text::STRING
)
SELECT
  tipo_llamada,
  LEFT(texto, 120) AS preview,
  AI_SENTIMENT(texto, ['producto','servicio','precio','retencion_cliente']) AS sentimiento_aspectos,
  AI_EXTRACT(text => texto, responseFormat => [
    ['cliente',          '¿Nombre del cliente?'],
    ['agente',           '¿Nombre del agente / asesor?'],
    ['motivo',           '¿Cuál es el motivo principal de la llamada?'],
    ['monto_o_precio',   '¿Se menciona algún monto, tarifa o precio?'],
    ['decision_cliente', '¿Cuál es la decisión, requerimiento o siguiente paso pedido por el cliente?']
  ]) AS extraccion,
  SNOWFLAKE.CORTEX.COMPLETE('claude-opus-4-5',
    PROMPT('Eres un coach de Customer Experience para una cadena de retail FMCG. Lee esta llamada y devuelve un JSON con: clasificacion (oferta_proactiva | reclamo | consulta), prioridad (alta | media | baja), siguiente_accion (1 sola frase concreta), riesgo_churn (0-100). Responde solo en JSON y en español. Texto: {0}', texto)) AS coach_cx
FROM llamadas
ORDER BY tipo_llamada;




/* ************************************ PARTE 8 ************************************************
   Cortex Search - búsqueda semántica sobre las reseñas.
   Construimos una vista enriquecida con contexto (ticket + promos) y la indexamos.
******************************************************************************************** */

ALTER WAREHOUSE WH_HOL_RETAIL SET WAREHOUSE_SIZE = 'MEDIUM';

-- Vista enriquecida (limitamos para que la indexación del HOL sea ágil)
CREATE OR REPLACE TABLE T_RESENAS_ENRIQUECIDAS AS
SELECT
  l.IdLinea,
  l.IdTicket,
  t.IdCliente,
  l.FechaResena,
  l.Esquema,
  l.NomProducto,
  l.Categoria,
  l.DesResena                                                  AS Texto,
  t.CanalVenta,
  t.NomTienda,
  LISTAGG(p.NomPromo, '; ') WITHIN GROUP (ORDER BY p.SecPrioridad) AS Promociones
FROM LINEA_TICKET l
JOIN TICKET t ON t.IdTicket = l.IdTicket
LEFT JOIN PROMO_APLICADA p ON p.IdLinea = l.IdLinea
WHERE l.FechaResena >= DATEADD(year, -1, CURRENT_DATE())
GROUP BY ALL
LIMIT 50000;

-- Podemos crear el Cortex Search por código o por la UI.
--
-- ============================================================================
-- OPCIÓN A) Crear el servicio CSS_RESENAS desde la UI (Snowsight)
-- ============================================================================
-- Estos pasos producen un servicio EQUIVALENTE al CREATE de la OPCIÓN B.
--
--  1. Snowsight → menú lateral → AI & ML → Cortex Search.
--  2. Botón "+ Create" (esquina superior derecha) → "Cortex Search Service".
--  3. Wizard "Create Cortex Search Service":
--
--     Step 1 — Select source data:
--       - Database:    DB_HOL_RETAIL
--       - Schema:      PUBLIC
--       - Table/View:  T_RESENAS_ENRIQUECIDAS
--       - Click "Next".
--
--     Step 2 — Select search column:
--       - Search column: Texto                (única columna que se indexa para búsqueda semántica)
--       - Embedding model: snowflake-arctic-embed-m-v1.5  (default; mismo que usa el SQL)
--       - Click "Next".
--
--     Step 3 — Select attribute columns (filtros):
--       Marcar EXACTAMENTE estas 9 columnas:
--           Esquema, CanalVenta, NomTienda, NomProducto, Categoria,
--           FechaResena, Promociones, IdLinea, IdCliente
--       - Click "Next".
--
--     Step 4 — Select columns to include in results:
--       Dejar las 10 columnas por defecto (todas las de la tabla):
--           IdLinea, IdCliente, FechaResena, Esquema, CanalVenta, NomTienda,
--           NomProducto, Categoria, Texto, Promociones
--       - Click "Next".
--
--     Step 5 — Configure service:
--       - Service name:   CSS_RESENAS
--       - Database:       DB_HOL_RETAIL
--       - Schema:         PUBLIC
--       - Warehouse:      WH_HOL_RETAIL
--       - Target lag:     1 hour
--       - Click "Create".
--
--  4. Snowsight muestra el detalle del servicio. Esperar 5-10 min hasta que
--     "Indexing state" pase a ACTIVE y "Source data num rows" muestre 50000.
--
--  5. En el mismo detalle, pestaña "Search Playground":
--       Query:  quejas mala experiencia
--       → Devuelve los mismos resultados que el SEARCH_PREVIEW del final de
--         esta parte (mismo embedding, mismos atributos, misma data).
--
-- ============================================================================
-- OPCIÓN B) Crear el servicio CSS_RESENAS vía SQL (equivalente a la UI)
-- ============================================================================

CREATE OR REPLACE CORTEX SEARCH SERVICE CSS_RESENAS
  ON Texto -- campo para hacer la búsqueda
  ATTRIBUTES Esquema, CanalVenta, NomTienda, NomProducto, Categoria, FechaResena, Promociones, IdLinea, IdCliente
  WAREHOUSE = WH_HOL_RETAIL
  TARGET_LAG = '1 hour'
  AS
  SELECT IdLinea, IdCliente, FechaResena, Esquema, CanalVenta, NomTienda,
         NomProducto, Categoria, Texto, Promociones
  FROM T_RESENAS_ENRIQUECIDAS;


-- Verifica el estado
SHOW CORTEX SEARCH SERVICES LIKE 'CSS_RESENAS';

-- Demo de búsqueda semántica
SELECT PARSE_JSON(SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
  'DB_HOL_RETAIL.PUBLIC.CSS_RESENAS',
  '{
     "query": "quejas mala experiencia",
     "columns": ["IdLinea","FechaResena","NomProducto","Categoria","CanalVenta","NomTienda","Texto"],
     "limit": 5
   }'
))['results'] AS resultados;



/* ************************************ PARTE 9 ************************************************
   Cortex Analyst - Semantic View sobre las 4 tablas para text-to-SQL.
******************************************************************************************** */

-- Vamos a AI Studio

/* ************************************ PARTE 10 ***********************************************
   Dynamic Tables - pipeline incremental para KPIs.
******************************************************************************************** */

CREATE OR REPLACE DYNAMIC TABLE DT_KPI_VENTAS_MENSUAL
  TARGET_LAG = '1 hour'
  WAREHOUSE  = WH_HOL_RETAIL
  AS
SELECT
  DATE_TRUNC('month', t.FecCompra)                                          AS mes,
  t.CanalVenta                                                              AS canal,
  t.NomTienda                                                               AS tienda,
  c.Genero                                                                  AS genero,
  c.NivelLealtad                                                            AS nivel_lealtad,
  CASE
    WHEN DATEDIFF(year, c.FecNacimiento, CURRENT_DATE()) < 18 THEN 'menor'
    WHEN DATEDIFF(year, c.FecNacimiento, CURRENT_DATE()) < 30 THEN 'joven'
    WHEN DATEDIFF(year, c.FecNacimiento, CURRENT_DATE()) < 45 THEN 'adulto joven'
    WHEN DATEDIFF(year, c.FecNacimiento, CURRENT_DATE()) < 65 THEN 'adulto'
    ELSE 'adulto mayor'
  END                                                                       AS bucket_edad,
  COUNT(*)                                                                  AS tickets,
  COUNT(DISTINCT t.IdCliente)                                               AS clientes_unicos,
  SUM(t.MontoTotal)                                                         AS ventas_total,
  AVG(t.MontoTotal)                                                         AS ticket_promedio
FROM TICKET t
JOIN CLIENTE c ON c.IdCliente = t.IdCliente
GROUP BY 1,2,3,4,5,6;

CREATE OR REPLACE DYNAMIC TABLE DT_TOP_PRODUCTOS
  TARGET_LAG = '1 hour'
  WAREHOUSE  = WH_HOL_RETAIL
  AS
SELECT
  DATE_TRUNC('month', t.FecCompra)  AS mes,
  l.NomProducto,
  l.Categoria,
  COUNT(*)         AS lineas,
  SUM(l.Cantidad)  AS unidades_vendidas
FROM LINEA_TICKET l
JOIN TICKET t ON t.IdTicket = l.IdTicket
GROUP BY 1,2,3;

-- Vamos a ver las tablas dinámicas en el catálogo.
-- Una automatización fácil y muy potente sin necesidad de ETLs/ELTs


/* ************************************ PARTE 11 ***********************************************
   Snowflake Intelligence - Agente con Cortex Search + Cortex Analyst.
--------------------------------------------------------------------------------------------
   Pasos en la UI (no se hacen vía SQL, sigue las instrucciones):

   1. AI & ML  ->  Snowflake Intelligence  ->  + Crear agente
      Nombre: AGT_RETAIL
      DB/Schema: DB_HOL_RETAIL.PUBLIC
   2. Tools  ->  Add tool
        - Cortex Search  -> CSS_RESENAS  (busca en reseñas de clientes)
        - Cortex Analyst -> SV_RETAIL    (responde con métricas / SQL)
   3. Orchestrator instructions (ejemplo):
        "Eres asistente comercial de SuperPlus. Cuando preguntan métricas de ventas,
         tickets, clientes o productos, usa Cortex Analyst.
         Cuando preguntan por experiencia del cliente, opiniones o búsquedas en
         reseñas, usa Cortex Search.
         Cita siempre los IdLinea, NomProducto o las dimensiones usadas. Responde en español."
   4. Response instructions (ejemplo):
        "Genera sugerencias de preguntas para permitirle al usuario continuar
         profundizando el análisis. Todo el contenido generado, incluyendo el
         razonamiento paso a paso, debe ser en español."
   5. En Access, agrega el rol "ANALISTA_COMERCIAL"
   6. Pruebas con rol ACCOUNTADMIN (ve todo el detalle):
        - ¿Cuántos tickets por canal de venta tuvimos en 2026?
        - Top 5 promociones aplicadas del año
        - Muéstrame reseñas con queja de cadena de frío o producto vencido
        - ¿Qué producto tiene mejor sentimiento de cliente este mes?
        - Dame el nombre de los 10 clientes con mayor monto comprado en 2026
   7. **Cambia de rol y repite la última pregunta**:
        Vuelve al agente y repite "Dame el nombre de los 10 clientes con mayor monto comprado en 2026".
        La respuesta no incluirá los datos sensibles que están bajo el gobierno definido.

******************************************************************************************** */


/* ************************************ PARTE 12 ***********************************************
   Con CoCo todo es aún más FÁCIL y RÁPIDO!!
--------------------------------------------------------------------------------------------

   Ejercicio: Creación de un modelo de ML en segundos usando las Dynamic Tables
   creadas en la PARTE 10 como feature store (KPIs pre-agregados, siempre frescos).

   PROMPT:
   Crea un notebook que utilice DB_HOL_RETAIL.PUBLIC.DT_KPI_VENTAS_MENSUAL
   (mes, canal, tienda, género, nivel_lealtad, bucket_edad, tickets,
   clientes_unicos, ventas_total, ticket_promedio) como feature store y
   DB_HOL_RETAIL.PUBLIC.DT_TOP_PRODUCTOS (mes, NomProducto, Categoria,
   lineas, unidades_vendidas) para forecasting de demanda.

   Construye dos modelos de ML:
     1) Predicción del ticket_promedio mensual por canal y tienda (regresión).
     2) Forecast de unidades_vendidas por categoría a 3 meses (time series con
        SNOWFLAKE.ML.FORECAST).

   Realiza análisis EDA con gráficos (estacionalidad, top categorías,
   distribución de ticket por canal y nivel de lealtad), descripción de los
   resultados y genera 3 experimentos para elegir el mejor modelo.
   Crea un feature store sobre las dynamic tables y registra 2 versiones del
   modelo en el Snowflake Model Registry.

******************************************************************************************** */
