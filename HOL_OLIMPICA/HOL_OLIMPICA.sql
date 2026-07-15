/* ============================================================================
   HOL OLÍMPICA — "De S3 a Snowflake CoWork"
   Script SQL completo. Cópialo en un Worksheet de Snowflake y ejecútalo
   parte por parte. Datos sintéticos generados para fines demostrativos.
   ============================================================================ */


/* ================= PARTE 1 — Setup del ambiente ================= */
USE ROLE ACCOUNTADMIN;
-- Habilita el uso de modelos Cortex desde cualquier región
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';
-- Base de datos y warehouse del laboratorio
CREATE OR REPLACE DATABASE DB_HOL_OLIMPICA COMMENT='HOL Olímpica - retail Colombia (datos sintéticos)';
CREATE OR REPLACE WAREHOUSE WH_HOL_OLIMPICA
  WITH WAREHOUSE_SIZE='SMALL' AUTO_SUSPEND=60 AUTO_RESUME=TRUE
       MIN_CLUSTER_COUNT=1 MAX_CLUSTER_COUNT=2 SCALING_POLICY='STANDARD';
USE WAREHOUSE WH_HOL_OLIMPICA;
USE DATABASE DB_HOL_OLIMPICA;
USE SCHEMA PUBLIC;


/* ================= PARTE 2 — Stage S3 + carga COPY INTO (~347M filas) ================= */
-- Formato CSV (delimitador ';', gzip) y stage externo al bucket S3
CREATE OR REPLACE FILE FORMAT FF_CSV_GZ
  TYPE=CSV FIELD_DELIMITER=';' FIELD_OPTIONALLY_ENCLOSED_BY='"' COMPRESSION=GZIP
  NULL_IF=('NULL','') EMPTY_FIELD_AS_NULL=TRUE SKIP_HEADER=1
  TIMESTAMP_FORMAT='YYYY-MM-DD HH24:MI:SS.FF3';

CREATE OR REPLACE STAGE STG_OLIMPICA
  URL='s3://demosjparrado/olimpica_hol/'
  STORAGE_INTEGRATION=SI_FCV_S3
  FILE_FORMAT=FF_CSV_GZ;

-- Verifica el acceso al stage
LIST @STG_OLIMPICA/fact_venta_linea/;

-- Dimensiones compartidas
CREATE OR REPLACE TABLE DIM_TIENDA (
  IdTienda NUMBER, TipoSucursal VARCHAR, Formato VARCHAR, Zona VARCHAR,
  Departamento VARCHAR, Ciudad VARCHAR, Gerencia VARCHAR,
  EncargadoZona VARCHAR, DirectorGeneral VARCHAR);

CREATE OR REPLACE TABLE DIM_PRODUCTO (
  PLU_SAP NUMBER, GTIN VARCHAR, NomProducto VARCHAR, Categoria NUMBER,
  NomCategoria VARCHAR, GrupoComercial NUMBER, Marca VARCHAR);

CREATE OR REPLACE TABLE DIM_PROVEEDOR (
  GLN_Proveedor VARCHAR, NomProveedor VARCHAR, Categoria VARCHAR);

CREATE OR REPLACE TABLE DIM_PROMO (
  OFERTA_ID NUMBER, NomPromo VARCHAR, TipoDescuento VARCHAR, PctDescuento NUMBER(5,2));

-- Hechos
CREATE OR REPLACE TABLE FACT_TICKET (
  FACTURA NUMBER, IdTienda NUMBER, FECHA DATE, Estrato NUMBER,
  MontoTotal NUMBER(14,2), NumLineas NUMBER);

CREATE OR REPLACE TABLE FACT_VENTA_LINEA (
  NroReg NUMBER, FACTURA NUMBER, FECHA DATE, IdTienda NUMBER, Estrato NUMBER,
  OFERTA_ID NUMBER, PLU_SAP NUMBER, Categoria NUMBER, GrupoComercial NUMBER,
  Cantidad NUMBER(12,3), Venta NUMBER(14,2), Descuento NUMBER(14,2));

CREATE OR REPLACE TABLE FACT_SELLOUT_INV (
  FecMovimiento DATE, GLN_Proveedor VARCHAR, GLN_Localizacion VARCHAR, IdTienda NUMBER,
  GTIN_Producto VARCHAR, PLU_SAP NUMBER, InventarioUnidades NUMBER,
  CostoProducto NUMBER(14,2), VentasUnidades NUMBER, PrecioVenta NUMBER(14,2),
  EstadoProducto VARCHAR);

CREATE OR REPLACE TABLE FACT_CHECKLIST (
  ANO NUMBER, MES NUMBER, DIA NUMBER, IdTienda NUMBER, TipoSucursal VARCHAR,
  CheckId NUMBER, Checklist VARCHAR, EstadoChecklist VARCHAR, NotaChecklist NUMBER(5,2),
  FechaRealizacion TIMESTAMP_NTZ, Gerencia VARCHAR, Zona VARCHAR, Departamento VARCHAR,
  EncargadoZona VARCHAR, DirectorGeneral VARCHAR, JefeOperacionesVisita VARCHAR,
  Almacen NUMBER(5,2), Auditoria NUMBER(5,2), Bodegas NUMBER(5,2), Cafeteria NUMBER(5,2),
  Carnes NUMBER(5,2), Clientes NUMBER(5,2), DatosPersonales NUMBER(5,2), Deli NUMBER(5,2),
  DocumentacionLegal NUMBER(5,2), Droguerias NUMBER(5,2), Fruver NUMBER(5,2),
  Indicadores NUMBER(5,2), IngresoAlmacen NUMBER(5,2), Panaderia NUMBER(5,2),
  PuestosDePago NUMBER(5,2), Recibo NUMBER(5,2), Supermercado NUMBER(5,2),
  Tesoreria NUMBER(5,2), Observaciones VARCHAR);

-- Carga masiva desde S3 (escala el warehouse para acelerar y luego reduce)
ALTER WAREHOUSE WH_HOL_OLIMPICA SET WAREHOUSE_SIZE='LARGE';
COPY INTO DIM_TIENDA        FROM @STG_OLIMPICA/dim_tienda/;
COPY INTO DIM_PRODUCTO      FROM @STG_OLIMPICA/dim_producto/;
COPY INTO DIM_PROVEEDOR     FROM @STG_OLIMPICA/dim_proveedor/;
COPY INTO DIM_PROMO         FROM @STG_OLIMPICA/dim_promo/;
COPY INTO FACT_TICKET       FROM @STG_OLIMPICA/fact_ticket/;
COPY INTO FACT_VENTA_LINEA  FROM @STG_OLIMPICA/fact_venta_linea/;
COPY INTO FACT_SELLOUT_INV  FROM @STG_OLIMPICA/fact_sellout_inv/;
COPY INTO FACT_CHECKLIST    FROM @STG_OLIMPICA/fact_checklist/;
ALTER WAREHOUSE WH_HOL_OLIMPICA SET WAREHOUSE_SIZE='XSMALL';

-- Conteos por tabla
SELECT 'DIM_TIENDA' tabla, COUNT(*) registros FROM DIM_TIENDA
UNION ALL SELECT 'DIM_PRODUCTO', COUNT(*) FROM DIM_PRODUCTO
UNION ALL SELECT 'DIM_PROVEEDOR', COUNT(*) FROM DIM_PROVEEDOR
UNION ALL SELECT 'DIM_PROMO', COUNT(*) FROM DIM_PROMO
UNION ALL SELECT 'FACT_TICKET', COUNT(*) FROM FACT_TICKET
UNION ALL SELECT 'FACT_VENTA_LINEA', COUNT(*) FROM FACT_VENTA_LINEA
UNION ALL SELECT 'FACT_SELLOUT_INV', COUNT(*) FROM FACT_SELLOUT_INV
UNION ALL SELECT 'FACT_CHECKLIST', COUNT(*) FROM FACT_CHECKLIST
ORDER BY registros DESC;


/* ================= PARTE 3 — Performance & análisis cruzado ================= */
-- Top 10 productos más vendidos (150M líneas + join a la dimensión)
SELECT p.NomProducto, p.NomCategoria, p.Marca,
       SUM(v.Cantidad) AS unidades_vendidas, SUM(v.Venta) AS venta_total_cop, COUNT(*) AS lineas
FROM FACT_VENTA_LINEA v JOIN DIM_PRODUCTO p ON p.PLU_SAP = v.PLU_SAP
GROUP BY 1,2,3 ORDER BY unidades_vendidas DESC LIMIT 10;

-- Cruce tienda -> ticket -> línea -> promo (últimos 6 meses)
SELECT t.Gerencia, t.Zona, pr.NomCategoria, pm.NomPromo,
       COUNT(DISTINCT ft.FACTURA) AS tickets, SUM(vl.Cantidad) AS unidades,
       SUM(vl.Venta) AS ventas_cop, SUM(vl.Descuento) AS descuento_cop
FROM DIM_TIENDA t
JOIN FACT_TICKET ft      ON ft.IdTienda  = t.IdTienda
JOIN FACT_VENTA_LINEA vl ON vl.FACTURA   = ft.FACTURA
JOIN DIM_PROMO pm        ON pm.OFERTA_ID = vl.OFERTA_ID
JOIN DIM_PRODUCTO pr     ON pr.PLU_SAP   = vl.PLU_SAP
WHERE ft.FECHA >= DATEADD(month, -6, CURRENT_DATE())
GROUP BY 1,2,3,4 ORDER BY ventas_cop DESC LIMIT 20;


/* ================= PARTE 4 — Time Travel & Zero-Copy Cloning ================= */
-- Clone instantáneo de una tabla y de toda la base de datos (ambiente DEV)
CREATE OR REPLACE TABLE DIM_TIENDA_DEV CLONE DIM_TIENDA;
CREATE OR REPLACE DATABASE DB_HOL_OLIMPICA_DEV CLONE DB_HOL_OLIMPICA;

-- Simular un error y recuperar con UNDROP
DROP DATABASE DB_HOL_OLIMPICA;
UNDROP DATABASE DB_HOL_OLIMPICA;
USE DATABASE DB_HOL_OLIMPICA; USE SCHEMA PUBLIC;

-- Rollback de un UPDATE por error usando Time Travel
UPDATE FACT_CHECKLIST SET NotaChecklist = 0 WHERE Zona = 'Bolivar';
SET q = LAST_QUERY_ID();
-- Consultar el estado ANTES del update (sin restaurar todavía)
SELECT Zona, AVG(NotaChecklist) FROM FACT_CHECKLIST BEFORE(STATEMENT => $q)
WHERE Zona='Bolivar' GROUP BY 1;
-- Restaurar la tabla al snapshot previo
CREATE OR REPLACE TABLE FACT_CHECKLIST AS SELECT * FROM FACT_CHECKLIST BEFORE(STATEMENT => $q);


/* ================= PARTE 5 — Masking dinámico por rol (con AI_REDACT) ================= */
USE ROLE ACCOUNTADMIN; USE DATABASE DB_HOL_OLIMPICA; USE SCHEMA PUBLIC;
-- Rol restringido con acceso de lectura
CREATE OR REPLACE ROLE ANALISTA_OPERACIONES;
GRANT USAGE ON DATABASE DB_HOL_OLIMPICA TO ROLE ANALISTA_OPERACIONES;
GRANT USAGE ON SCHEMA DB_HOL_OLIMPICA.PUBLIC TO ROLE ANALISTA_OPERACIONES;
GRANT SELECT ON ALL TABLES IN SCHEMA DB_HOL_OLIMPICA.PUBLIC TO ROLE ANALISTA_OPERACIONES;
GRANT USAGE ON WAREHOUSE WH_HOL_OLIMPICA TO ROLE ANALISTA_OPERACIONES;
GRANT ROLE ANALISTA_OPERACIONES TO USER JPARRADO;  -- reemplaza por tu usuario

-- Enmascara nombres de empleados excepto para ACCOUNTADMIN
CREATE OR REPLACE MASKING POLICY mp_nombre_empleado AS (val STRING) RETURNS STRING ->
  CASE WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN') THEN val ELSE '****' END;

-- Redacta la PII del texto de observaciones con IA (conserva el hallazgo operativo)
CREATE OR REPLACE MASKING POLICY mp_texto_observacion AS (val STRING) RETURNS STRING ->
  CASE WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN') THEN val ELSE AI_REDACT(val) END;

-- Asocia las políticas a las columnas
ALTER TABLE DIM_TIENDA MODIFY COLUMN EncargadoZona   SET MASKING POLICY mp_nombre_empleado;
ALTER TABLE DIM_TIENDA MODIFY COLUMN DirectorGeneral SET MASKING POLICY mp_nombre_empleado;
ALTER TABLE FACT_CHECKLIST MODIFY COLUMN Observaciones SET MASKING POLICY mp_texto_observacion;

-- Demo: misma consulta, distinto resultado por rol
SELECT t.IdTienda, t.Zona, t.EncargadoZona, t.DirectorGeneral, LEFT(c.Observaciones,120) AS obs
FROM DIM_TIENDA t JOIN FACT_CHECKLIST c ON c.IdTienda=t.IdTienda WHERE t.Zona='Bolivar' LIMIT 5;
-- Cambia de rol y repite la consulta anterior para ver el enmascaramiento
-- USE ROLE ANALISTA_OPERACIONES;  (luego vuelve con USE ROLE ACCOUNTADMIN;)


/* ================= PARTE 6 — Cortex AI Functions (sobre observaciones) ================= */
USE ROLE ACCOUNTADMIN; USE WAREHOUSE WH_HOL_OLIMPICA; USE DATABASE DB_HOL_OLIMPICA; USE SCHEMA PUBLIC;

-- 6.1 Pregunta de negocio directa a un LLM
SELECT AI_COMPLETE('claude-sonnet-4-5',
  'Resume en 5 puntos los beneficios de Snowflake Cortex para auditoría operativa de un retail como Olímpica. Responde en español con saltos de línea.') AS respuesta;

-- 6.2 Resumen corto + evaluación estructurada en JSON
SELECT IdTienda, LEFT(Observaciones,80) AS preview,
  AI_COMPLETE('openai-gpt-4.1', CONCAT('Resume en máximo 5 palabras la siguiente observación de auditoría de tienda: ', Observaciones)) AS resumen_corto,
  AI_COMPLETE('openai-gpt-4.1', CONCAT('Evalúa la siguiente observación de auditoría de tienda. Responde SOLO en JSON con el formato {"severidad":"alta|media|baja","area_afectada":"<área>","requiere_accion":true|false}. Texto: ', Observaciones)) AS evaluacion_json
FROM FACT_CHECKLIST WHERE Observaciones IS NOT NULL LIMIT 10;

-- 6.3 Sentimiento (AI_SENTIMENT devuelve OBJECT; extraemos el label)
SELECT IdTienda, LEFT(Observaciones,100) AS preview,
  AI_SENTIMENT(Observaciones):categories[0]:sentiment::VARCHAR AS sentimiento
FROM FACT_CHECKLIST WHERE Observaciones IS NOT NULL LIMIT 10;

-- 6.4 Insight agregado sobre múltiples observaciones
SELECT AI_AGG(Observaciones,
  'Resume los principales hallazgos de estas auditorías de tienda. Indica: 1) Top 3 problemas más frecuentes, 2) Riesgos operativos, 3) Oportunidades de mejora. Responde en español con bullets.') AS insight
FROM (SELECT Observaciones FROM FACT_CHECKLIST
      WHERE FechaRealizacion = (SELECT MAX(FechaRealizacion) FROM FACT_CHECKLIST)
        AND Observaciones IS NOT NULL LIMIT 100);

-- 6.5 Traducción es -> en
SELECT IdTienda, AI_TRANSLATE(LEFT(Observaciones,400), 'es', 'en') AS observacion_en
FROM FACT_CHECKLIST WHERE Observaciones IS NOT NULL LIMIT 3;

-- 6.6 Clasificación automática en categorías operativas
SELECT IdTienda, LEFT(Observaciones,100) AS preview,
  AI_CLASSIFY(Observaciones, ['Limpieza','Inventario','Cadena de frío','Atención al cliente','Documentación legal','Seguridad']):labels[0]::VARCHAR AS categoria
FROM FACT_CHECKLIST WHERE Observaciones IS NOT NULL LIMIT 10;


/* ================= PARTE 7 — Cortex AI Multimodal (PDF / imagen / audio) ================= */
-- Reutiliza el stage STG_OLIMPICA; los archivos están en la subcarpeta archivos/
LIST @STG_OLIMPICA/archivos/;

-- 7.1 Extracción estructurada de un recibo POS (PDF)
WITH e AS (
  SELECT AI_EXTRACT(file => TO_FILE('@STG_OLIMPICA','archivos/recibo_pos_001.pdf'),
    responseFormat => [['transaccion_id','ID de la transacción'],['cajero','Nombre o código del cajero'],
      ['subtotal','Subtotal antes de impuestos'],['iva','Valor del IVA'],['total','Valor total pagado'],
      ['items_count','Cantidad total de ítems'],['descuento','Descuento aplicado']]) AS r)
SELECT r:response:transaccion_id::STRING, r:response:total::STRING, r:response:iva::STRING FROM e;

-- 7.2 Lectura de etiqueta de producto (visión, pixtral-large)
SELECT AI_COMPLETE('pixtral-large',
  PROMPT('Extrae la información nutricional y de marca de esta etiqueta: marca, nombre, peso/volumen, calorías, fecha de vencimiento. Responde en español. {0}',
         TO_FILE('@STG_OLIMPICA','archivos/etiqueta_producto_001.png'))) AS etiqueta;

-- 7.3 Análisis de góndola / visual merchandising (claude-sonnet-4-5)
SELECT AI_COMPLETE('claude-sonnet-4-5',
  PROMPT('Eres experto en visual merchandising para retail FMCG. Analiza esta góndola y devuelve JSON con estado_general, categorias_detectadas, problemas_visuales, impacto_estimado_ventas y recomendaciones_priorizadas. Responde solo en JSON y en español. {0}',
         TO_FILE('@STG_OLIMPICA','archivos/producto_foto_001.jpg'))) AS analisis_gondola;

-- 7.4 Lectura de cupón de descuento (claude-opus-4-5)
SELECT AI_COMPLETE('claude-opus-4-5',
  PROMPT('Lee este cupón de Olímpica y devuelve en JSON: codigo_cupon, porcentaje_descuento, fecha_vigencia, condiciones, productos_aplicables. Responde solo en JSON y en español. {0}',
         TO_FILE('@STG_OLIMPICA','archivos/cupon_descuento_001.png'))) AS cupon;

-- 7.5 Transcripción de audio (llamada de call center)
SELECT TO_VARCHAR(AI_TRANSCRIBE(TO_FILE('@STG_OLIMPICA','archivos/ofreciendo-producto.mp3'))) AS transcripcion;

-- 7.6 Pipeline end-to-end: transcribir -> sentimiento -> extraer -> coach CX
WITH llamadas AS (
  SELECT 'oferta' AS tipo, AI_TRANSCRIBE(TO_FILE('@STG_OLIMPICA','archivos/ofreciendo-producto.mp3')):text::STRING AS texto
  UNION ALL
  SELECT 'queja', AI_TRANSCRIBE(TO_FILE('@STG_OLIMPICA','archivos/problema-servicio.mp3')):text::STRING)
SELECT tipo, LEFT(texto,120) AS preview,
  AI_SENTIMENT(texto, ['producto','servicio','precio','retencion_cliente']) AS sentimiento,
  AI_COMPLETE('claude-opus-4-5', PROMPT('Eres coach de Customer Experience para Olímpica. Devuelve JSON con clasificacion, prioridad, siguiente_accion, riesgo_churn (0-100). Solo JSON, en español. Texto: {0}', texto)) AS coach_cx
FROM llamadas ORDER BY tipo;


/* ================= PARTE 8 — Cortex Search (búsqueda semántica) ================= */
ALTER WAREHOUSE WH_HOL_OLIMPICA SET WAREHOUSE_SIZE='MEDIUM';
-- Tabla enriquecida con contexto de tienda (últimos 12 meses)
CREATE OR REPLACE TABLE T_OBSERVACIONES_ENRIQUECIDAS AS
SELECT c.IdTienda, t.Ciudad, t.Zona, t.Gerencia, c.TipoSucursal, c.FechaRealizacion,
       c.NotaChecklist, c.EstadoChecklist, c.Observaciones AS Texto
FROM FACT_CHECKLIST c JOIN DIM_TIENDA t ON t.IdTienda = c.IdTienda
WHERE c.FechaRealizacion >= DATEADD(year,-1,CURRENT_DATE()) AND c.Observaciones IS NOT NULL
LIMIT 50000;

-- Servicio de búsqueda semántica sobre las observaciones
CREATE OR REPLACE CORTEX SEARCH SERVICE CSS_AUDITORIAS
  ON Texto
  ATTRIBUTES IdTienda, Ciudad, Zona, Gerencia, TipoSucursal, FechaRealizacion, NotaChecklist, EstadoChecklist
  WAREHOUSE = WH_HOL_OLIMPICA TARGET_LAG='1 hour'
  AS SELECT IdTienda, Ciudad, Zona, Gerencia, TipoSucursal, FechaRealizacion, NotaChecklist, EstadoChecklist, Texto
     FROM T_OBSERVACIONES_ENRIQUECIDAS;

SHOW CORTEX SEARCH SERVICES LIKE 'CSS_AUDITORIAS';

-- Demo: búsqueda por concepto, aplanando el JSON a columnas legibles
WITH busqueda AS (
  SELECT PARSE_JSON(SNOWFLAKE.CORTEX.SEARCH_PREVIEW('DB_HOL_OLIMPICA.PUBLIC.CSS_AUDITORIAS',
    '{ "query": "cadena de frío producto vencido", "columns": ["Ciudad","Zona","Gerencia","NotaChecklist","Texto"], "limit": 5 }'))['results'] AS resultados)
SELECT r.value:Ciudad::STRING AS ciudad, r.value:Zona::STRING AS zona, r.value:Gerencia::STRING AS gerencia,
       ROUND(r.value:NotaChecklist::FLOAT,1) AS nota_auditoria, r.value:Texto::STRING AS hallazgo
FROM busqueda, LATERAL FLATTEN(input => busqueda.resultados) r;
ALTER WAREHOUSE WH_HOL_OLIMPICA SET WAREHOUSE_SIZE='SMALL';


/* ================= PARTE 9 — Dynamic Table incremental ================= */
-- KPI de ventas por tienda y mes; refresco incremental (COUNT(*)/SUM/AVG, sin COUNT DISTINCT)
CREATE OR REPLACE DYNAMIC TABLE DT_VENTAS_TIENDA_MES
  TARGET_LAG='1 hour' WAREHOUSE=WH_HOL_OLIMPICA REFRESH_MODE=INCREMENTAL
AS
SELECT DATE_TRUNC('month', ft.FECHA) AS mes, t.IdTienda, t.Ciudad, t.Gerencia,
       COUNT(*) AS tickets, SUM(ft.MontoTotal) AS ventas, AVG(ft.MontoTotal) AS ticket_promedio,
       SUM(ft.NumLineas) AS lineas
FROM FACT_TICKET ft JOIN DIM_TIENDA t ON t.IdTienda = ft.IdTienda
GROUP BY 1,2,3,4;

-- Verificar la Dynamic Table
SHOW DYNAMIC TABLES IN SCHEMA DB_HOL_OLIMPICA.PUBLIC;
SELECT * FROM DT_VENTAS_TIENDA_MES ORDER BY mes DESC LIMIT 10;


/* ================= PARTE 10 — Semantic View + Cortex Analyst ================= */
-- El Semantic View SV_OLIMPICA se crea por la UI:
--   Snowsight -> AI & ML -> Studio -> Cortex Analyst -> + Create -> Semantic View -> Create from scratch
--   Tablas: DIM_TIENDA (PK IdTienda), FACT_TICKET (PK FACTURA), FACT_VENTA_LINEA (PK NroReg),
--           DIM_PRODUCTO (PK PLU_SAP), DIM_PROMO (PK OFERTA_ID)
--   Relaciones N:1: FACT_TICKET.IdTienda->DIM_TIENDA; FACT_VENTA_LINEA.FACTURA->FACT_TICKET;
--                   FACT_VENTA_LINEA.PLU_SAP->DIM_PRODUCTO; FACT_VENTA_LINEA.OFERTA_ID->DIM_PROMO
-- Consultas verificadas de ejemplo:
SELECT t.Gerencia, COUNT(f.FACTURA) AS tickets
FROM FACT_TICKET f JOIN DIM_TIENDA t ON t.IdTienda=f.IdTienda
WHERE YEAR(f.FECHA)=2026 GROUP BY 1 ORDER BY 2 DESC;

SELECT p.NomPromo, COUNT(*) AS frecuencia
FROM FACT_VENTA_LINEA l JOIN DIM_PROMO p ON p.OFERTA_ID=l.OFERTA_ID
GROUP BY 1 ORDER BY 2 DESC LIMIT 10;

SELECT t.Ciudad, SUM(l.Venta) AS ventas_total
FROM FACT_VENTA_LINEA l JOIN DIM_TIENDA t ON t.IdTienda=l.IdTienda
GROUP BY 1 ORDER BY 2 DESC;

SELECT t.IdTienda, t.Ciudad, AVG(f.MontoTotal) AS ticket_promedio
FROM FACT_TICKET f JOIN DIM_TIENDA t ON t.IdTienda=f.IdTienda
GROUP BY 1,2 ORDER BY 3 DESC;


/* ================= PARTE 11 — Snowflake CoWork (agente) ================= */
-- Se configura por la UI (no requiere SQL):
--   Snowsight -> AI & ML -> Snowflake CoWork -> + Crear agente -> AGT_OLIMPICA
--   Tools:  Cortex Analyst -> SV_OLIMPICA   |   Cortex Search -> CSS_AUDITORIAS
--   Orquestador (español): usa Analyst para métricas de ventas/tickets/tiendas/productos
--   y Search para hallazgos de auditoría/observaciones. Cita IdTienda, Zona, NomProducto.
--   En Access agrega el rol ANALISTA_OPERACIONES para ver el gobierno automático (masking).


/* ================= PARTE 12 — Limpieza del ambiente ================= */
USE ROLE ACCOUNTADMIN;
DROP DATABASE IF EXISTS DB_HOL_OLIMPICA;
DROP DATABASE IF EXISTS DB_HOL_OLIMPICA_DEV;
DROP WAREHOUSE IF EXISTS WH_HOL_OLIMPICA;
DROP ROLE IF EXISTS ANALISTA_OPERACIONES;
