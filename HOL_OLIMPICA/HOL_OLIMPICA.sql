/* ==========================================================================
   HOL OLIMPICA - "De S3 a Snowflake CoWork"
   Script SQL completo (identico al paso a paso del HOL).
   Copialo en un Worksheet de Snowflake y ejecutalo de arriba a abajo,
   o por secciones. Cada comentario explica que hace el bloque.
   Datos sinteticos para fines demostrativos.
   ========================================================================== */

-- AWS_KEY_ID     = '<SOLICITAR_AL_INSTRUCTOR>'
-- AWS_SECRET_KEY = '<SOLICITAR_AL_INSTRUCTOR>'

/* ----------------------------------------------------------------------
   Setup del ambiente
   ---------------------------------------------------------------------- */
USE ROLE ACCOUNTADMIN;
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';

CREATE OR REPLACE DATABASE DB_HOL_OLIMPICA
  COMMENT='HOL Olímpica - retail Colombia (datos sintéticos)';

CREATE OR REPLACE WAREHOUSE WH_HOL_OLIMPICA
WITH
  WAREHOUSE_SIZE='SMALL'
  AUTO_SUSPEND=60
  AUTO_RESUME=TRUE
  MIN_CLUSTER_COUNT=1
  MAX_CLUSTER_COUNT=2
  SCALING_POLICY='STANDARD';

USE WAREHOUSE WH_HOL_OLIMPICA;
USE DATABASE DB_HOL_OLIMPICA;
USE SCHEMA PUBLIC;

/* ----------------------------------------------------------------------
   Stage S3 + Carga COPY INTO (~347M filas)
   > 2.1 — File Format y Stage externo
   ---------------------------------------------------------------------- */
CREATE OR REPLACE FILE FORMAT FF_CSV_GZ
  TYPE=CSV
  FIELD_DELIMITER=';'
  FIELD_OPTIONALLY_ENCLOSED_BY='"'
  COMPRESSION=GZIP
  NULL_IF=('NULL','')
  EMPTY_FIELD_AS_NULL=TRUE
  SKIP_HEADER=1
  TIMESTAMP_FORMAT='YYYY-MM-DD HH24:MI:SS.FF3';

CREATE OR REPLACE STAGE STG_OLIMPICA
  URL='s3://demosjparrado/olimpica_hol/'
  CREDENTIALS=(AWS_KEY_ID='<SOLICITAR_AL_INSTRUCTOR>' AWS_SECRET_KEY='<SOLICITAR_AL_INSTRUCTOR>')
  FILE_FORMAT=FF_CSV_GZ;

-- Verificamos que los archivos son accesibles
LIST @STG_OLIMPICA/fact_venta_linea/;

-- > 2.2 — DDL de las 8 tablas
-- ========== DIMENSIONES ==========

CREATE OR REPLACE TABLE DIM_TIENDA (
    IdTienda        NUMBER          COMMENT 'Identificador único de la tienda/sucursal',
    TipoSucursal    VARCHAR         COMMENT 'Tipo de sucursal: SAO, Superalmacén, Droguerías, etc.',
    Formato         VARCHAR         COMMENT 'Formato comercial de la tienda',
    Zona            VARCHAR         COMMENT 'Zona geográfica asignada',
    Departamento    VARCHAR         COMMENT 'Departamento (división administrativa)',
    Ciudad          VARCHAR         COMMENT 'Ciudad donde se ubica la tienda',
    Gerencia        VARCHAR         COMMENT 'Gerencia regional responsable',
    EncargadoZona   VARCHAR         COMMENT 'Encargado de la zona',
    DirectorGeneral VARCHAR         COMMENT 'Director general asignado'
) COMMENT='Dimensión de tiendas Olímpica - 1,800 puntos de venta';

CREATE OR REPLACE TABLE DIM_PRODUCTO (
    PLU_SAP         NUMBER          COMMENT 'Código PLU interno SAP del producto',
    GTIN            VARCHAR         COMMENT 'Código de barras GTIN/EAN',
    NomProducto     VARCHAR         COMMENT 'Nombre comercial del producto',
    Categoria       NUMBER          COMMENT 'Código numérico de categoría',
    NomCategoria    VARCHAR         COMMENT 'Nombre de la categoría del producto',
    GrupoComercial  NUMBER          COMMENT 'Código del grupo comercial',
    Marca           VARCHAR         COMMENT 'Marca del producto'
) COMMENT='Dimensión de productos - 50,000 SKUs';

CREATE OR REPLACE TABLE DIM_PROVEEDOR (
    GLN_Proveedor   VARCHAR         COMMENT 'Código GLN único del proveedor',
    NomProveedor    VARCHAR         COMMENT 'Razón social del proveedor',
    Categoria       VARCHAR         COMMENT 'Categoría comercial del proveedor'
) COMMENT='Dimensión de proveedores - 2,000 proveedores';

CREATE OR REPLACE TABLE DIM_PROMO (
    OFERTA_ID       NUMBER          COMMENT 'Identificador de la oferta (0 = sin promoción)',
    NomPromo        VARCHAR         COMMENT 'Nombre de la promoción',
    TipoDescuento   VARCHAR         COMMENT 'Tipo de descuento aplicado',
    PctDescuento    VARCHAR         COMMENT 'Porcentaje o valor del descuento'
) COMMENT='Dimensión de promociones - 20,001 (incluye ID 0 = sin promo)';

-- ========== HECHOS ==========

CREATE OR REPLACE TABLE FACT_TICKET (
    FACTURA         NUMBER          COMMENT 'Número de factura / ticket',
    IdTienda        NUMBER          COMMENT 'FK a DIM_TIENDA.IdTienda',
    FECHA           DATE            COMMENT 'Fecha de la transacción',
    Estrato         VARCHAR         COMMENT 'Estrato socioeconómico del cliente',
    MontoTotal      NUMBER(14,2)    COMMENT 'Monto total de la factura en COP',
    NumLineas       NUMBER          COMMENT 'Cantidad de líneas/ítems en el ticket'
) COMMENT='Tickets de venta POS - 39M transacciones';

CREATE OR REPLACE TABLE FACT_VENTA_LINEA (
    NroReg          NUMBER          COMMENT 'Número de registro único de la línea',
    FACTURA         NUMBER          COMMENT 'FK a FACT_TICKET.FACTURA',
    FECHA           DATE            COMMENT 'Fecha de la venta',
    IdTienda        NUMBER          COMMENT 'FK a DIM_TIENDA.IdTienda',
    Estrato         VARCHAR         COMMENT 'Estrato socioeconómico',
    OFERTA_ID       NUMBER          COMMENT 'FK a DIM_PROMO.OFERTA_ID',
    PLU_SAP         NUMBER          COMMENT 'FK a DIM_PRODUCTO.PLU_SAP',
    Categoria       NUMBER          COMMENT 'Código de categoría del producto',
    GrupoComercial  NUMBER          COMMENT 'Grupo comercial del producto',
    Cantidad        NUMBER(12,3)    COMMENT 'Cantidad vendida (permite decimales para peso)',
    Venta           NUMBER(14,2)    COMMENT 'Valor de la venta en COP',
    Descuento       NUMBER(14,2)    COMMENT 'Valor del descuento aplicado en COP'
) COMMENT='Detalle de venta por línea - 150M registros';

CREATE OR REPLACE TABLE FACT_SELLOUT_INV (
    FecMovimiento       DATE            COMMENT 'Fecha del movimiento de inventario',
    GLN_Proveedor       VARCHAR         COMMENT 'FK a DIM_PROVEEDOR.GLN_Proveedor',
    GLN_Localizacion    VARCHAR         COMMENT 'GLN de la localización/bodega',
    IdTienda            NUMBER          COMMENT 'FK a DIM_TIENDA.IdTienda',
    GTIN_Producto       VARCHAR         COMMENT 'Código GTIN del producto',
    PLU_SAP             NUMBER          COMMENT 'FK a DIM_PRODUCTO.PLU_SAP',
    InventarioUnidades  NUMBER          COMMENT 'Unidades en inventario',
    CostoProducto       NUMBER(14,2)    COMMENT 'Costo unitario del producto',
    VentasUnidades      NUMBER          COMMENT 'Unidades vendidas en el período',
    PrecioVenta         NUMBER(14,2)    COMMENT 'Precio de venta unitario',
    EstadoProducto      VARCHAR         COMMENT 'Estado del producto: Activo, Descontinuado, etc.'
) COMMENT='Sell-out e inventario por proveedor - 150M registros';

CREATE OR REPLACE TABLE FACT_CHECKLIST (
    ANO                 NUMBER          COMMENT 'Año de la auditoría',
    MES                 NUMBER          COMMENT 'Mes de la auditoría',
    DIA                 NUMBER          COMMENT 'Día de la auditoría',
    IdTienda            NUMBER          COMMENT 'FK a DIM_TIENDA.IdTienda',
    TipoSucursal        VARCHAR         COMMENT 'Tipo de sucursal evaluada',
    CheckId             NUMBER          COMMENT 'Identificador del checklist',
    Checklist           VARCHAR         COMMENT 'Nombre del checklist aplicado',
    EstadoChecklist     VARCHAR         COMMENT 'Estado: Completo, Pendiente, etc.',
    NotaChecklist       NUMBER(5,2)     COMMENT 'Nota global del checklist (0-100)',
    FechaRealizacion    TIMESTAMP_NTZ   COMMENT 'Fecha y hora de realización',
    Gerencia            VARCHAR         COMMENT 'Gerencia responsable',
    Zona                VARCHAR         COMMENT 'Zona geográfica',
    Departamento        VARCHAR         COMMENT 'Departamento',
    EncargadoZona       VARCHAR         COMMENT 'Encargado de zona',
    DirectorGeneral     VARCHAR         COMMENT 'Director general',
    JefeOperacionesVisita VARCHAR      COMMENT 'Jefe de operaciones que realizó la visita',
    Almacen             NUMBER(5,2)     COMMENT 'Nota sección Almacén',
    Auditoria           NUMBER(5,2)     COMMENT 'Nota sección Auditoría',
    Bodegas             NUMBER(5,2)     COMMENT 'Nota sección Bodegas',
    Cafeteria           NUMBER(5,2)     COMMENT 'Nota sección Cafetería',
    Carnes              NUMBER(5,2)     COMMENT 'Nota sección Carnes',
    Clientes            NUMBER(5,2)     COMMENT 'Nota sección Clientes',
    DatosPersonales     NUMBER(5,2)     COMMENT 'Nota sección Datos Personales',
    Deli                NUMBER(5,2)     COMMENT 'Nota sección Deli',
    DocumentacionLegal  NUMBER(5,2)     COMMENT 'Nota sección Documentación Legal',
    Droguerias          NUMBER(5,2)     COMMENT 'Nota sección Droguerías',
    Fruver              NUMBER(5,2)     COMMENT 'Nota sección Fruver',
    Indicadores         NUMBER(5,2)     COMMENT 'Nota sección Indicadores',
    IngresoAlmacen      NUMBER(5,2)     COMMENT 'Nota sección Ingreso Almacén',
    Panaderia           NUMBER(5,2)     COMMENT 'Nota sección Panadería',
    PuestosDePago       NUMBER(5,2)     COMMENT 'Nota sección Puestos de Pago',
    Recibo              NUMBER(5,2)     COMMENT 'Nota sección Recibo',
    Supermercado        NUMBER(5,2)     COMMENT 'Nota sección Supermercado',
    Tesoreria           NUMBER(5,2)     COMMENT 'Nota sección Tesorería',
    Observaciones       VARCHAR         COMMENT 'Observaciones de texto libre del auditor'
) COMMENT='Checklists de auditoría operativa - 8M registros';

-- > 2.3 — Carga masiva con COPY INTO (demo de elasticidad)
-- === Experimento de performance sobre FACT_VENTA_LINEA (150M filas, 128 archivos) ===

-- 1) Carga con warehouse SMALL (1 nodo). Anota el tiempo en el historial de queries (Query History).
--    FORCE=TRUE fuerza la recarga aunque los archivos ya figuren como cargados (TRUNCATE no borra ese historial).
ALTER WAREHOUSE WH_HOL_OLIMPICA SET WAREHOUSE_SIZE='SMALL';
COPY INTO FACT_VENTA_LINEA FROM @STG_OLIMPICA/fact_venta_linea/ FORCE=TRUE;

-- 2) Truncamos para repetir exactamente la misma carga
TRUNCATE TABLE FACT_VENTA_LINEA;

-- 3) Recarga con warehouse XLARGE (16 nodos). Compara el tiempo: mucho más rápido.
ALTER WAREHOUSE WH_HOL_OLIMPICA SET WAREHOUSE_SIZE='XLARGE';
COPY INTO FACT_VENTA_LINEA FROM @STG_OLIMPICA/fact_venta_linea/ FORCE=TRUE;

-- Snowflake factura por SEGUNDO: el XLARGE termina en una fracción del tiempo
-- (en esta prueba: SMALL ~33s vs XLARGE ~8s para 150M filas) y no hay infraestructura que administrar.
-- Aprovechamos el XLARGE para cargar el resto de tablas rápidamente:
COPY INTO DIM_TIENDA        FROM @STG_OLIMPICA/dim_tienda/;
COPY INTO DIM_PRODUCTO      FROM @STG_OLIMPICA/dim_producto/;
COPY INTO DIM_PROVEEDOR     FROM @STG_OLIMPICA/dim_proveedor/;
COPY INTO DIM_PROMO         FROM @STG_OLIMPICA/dim_promo/;
COPY INTO FACT_TICKET       FROM @STG_OLIMPICA/fact_ticket/;
COPY INTO FACT_SELLOUT_INV  FROM @STG_OLIMPICA/fact_sellout_inv/;
COPY INTO FACT_CHECKLIST    FROM @STG_OLIMPICA/fact_checklist/;

-- Volvemos a un tamaño económico
ALTER WAREHOUSE WH_HOL_OLIMPICA SET WAREHOUSE_SIZE='XSMALL';

-- > 2.4 — Validación de conteos
SELECT 'DIM_TIENDA'       AS tabla, COUNT(*) AS registros FROM DIM_TIENDA       UNION ALL
SELECT 'DIM_PRODUCTO',            COUNT(*)            FROM DIM_PRODUCTO     UNION ALL
SELECT 'DIM_PROVEEDOR',           COUNT(*)            FROM DIM_PROVEEDOR    UNION ALL
SELECT 'DIM_PROMO',               COUNT(*)            FROM DIM_PROMO        UNION ALL
SELECT 'FACT_TICKET',             COUNT(*)            FROM FACT_TICKET      UNION ALL
SELECT 'FACT_VENTA_LINEA',        COUNT(*)            FROM FACT_VENTA_LINEA UNION ALL
SELECT 'FACT_SELLOUT_INV',        COUNT(*)            FROM FACT_SELLOUT_INV UNION ALL
SELECT 'FACT_CHECKLIST',          COUNT(*)            FROM FACT_CHECKLIST
ORDER BY registros DESC;

/* ----------------------------------------------------------------------
   Performance & Warehouse Scaling
   > 3.1 — Top 10 productos más vendidos
   ---------------------------------------------------------------------- */
-- Aseguramos warehouse SMALL para la primera ejecución
ALTER WAREHOUSE WH_HOL_OLIMPICA SET WAREHOUSE_SIZE='SMALL';

-- Top 10 productos más vendidos (150M filas + JOIN dimensión)
SELECT
    p.NomProducto,
    p.NomCategoria,
    p.Marca,
    SUM(v.Cantidad)     AS unidades_vendidas,
    SUM(v.Venta)        AS venta_total_cop,
    COUNT(*)            AS lineas_venta
FROM FACT_VENTA_LINEA v
JOIN DIM_PRODUCTO p ON p.PLU_SAP = v.PLU_SAP
GROUP BY 1, 2, 3
ORDER BY unidades_vendidas DESC
LIMIT 10;

-- > 3.2 — Análisis cruzado: Ventas por Gerencia/Zona x Categoría x Promoción
-- Análisis cruzado: Gerencia/Zona x Categoría x Promoción (últimos 6 meses)
SELECT
    t.Gerencia,
    t.Zona,
    pr.NomCategoria,
    pm.NomPromo,
    COUNT(DISTINCT ft.FACTURA)  AS tickets,
    SUM(vl.Cantidad)            AS unidades,
    SUM(vl.Venta)               AS ventas_cop,
    SUM(vl.Descuento)           AS descuento_cop
FROM DIM_TIENDA t
JOIN FACT_TICKET ft         ON ft.IdTienda  = t.IdTienda
JOIN FACT_VENTA_LINEA vl    ON vl.FACTURA   = ft.FACTURA
JOIN DIM_PROMO pm           ON pm.OFERTA_ID = vl.OFERTA_ID
JOIN DIM_PRODUCTO pr        ON pr.PLU_SAP   = vl.PLU_SAP
WHERE ft.FECHA >= DATEADD(month, -6, CURRENT_DATE())
GROUP BY 1, 2, 3, 4
ORDER BY ventas_cop DESC
LIMIT 20;

/* ----------------------------------------------------------------------
   Time Travel & Zero-Copy Cloning
   > 4.1 — Zero-Copy Clone de una tabla
   ---------------------------------------------------------------------- */
-- Clone instantáneo de la tabla DIM_TIENDA (1,800 registros)
CREATE OR REPLACE TABLE DIM_TIENDA_DEV CLONE DIM_TIENDA;

-- Verificamos que tiene los mismos datos
SELECT COUNT(*) AS registros_clone FROM DIM_TIENDA_DEV;

-- > 4.2 — Clone de toda la base de datos
-- Clone de toda la BD: ambiente DEV instantáneo
CREATE OR REPLACE DATABASE DB_HOL_OLIMPICA_DEV CLONE DB_HOL_OLIMPICA;

-- > 4.3 — DROP & UNDROP: recuperación sin DBA
-- Simulamos un error grave: eliminamos producción
DROP DATABASE DB_HOL_OLIMPICA;

-- Restauración instantánea con UNDROP
UNDROP DATABASE DB_HOL_OLIMPICA;

-- Verificamos que todo sigue intacto
USE DATABASE DB_HOL_OLIMPICA;
USE SCHEMA PUBLIC;
SELECT COUNT(*) AS registros FROM FACT_CHECKLIST;

-- > 4.4 — Time Travel: rollback de un UPDATE masivo por error
-- Snapshot ANTES del error: distribución de NotaChecklist por Zona
SELECT 'antes_update' AS estado, Zona, AVG(NotaChecklist) AS nota_promedio, COUNT(*) AS registros
FROM FACT_CHECKLIST
WHERE Zona IN ('Bolivar','Atlantico','Santander')
GROUP BY 1, 2
ORDER BY 2;
-- UPDATE masivo "por error": ponemos NotaChecklist = 0 en toda la zona Bolívar
UPDATE FACT_CHECKLIST SET NotaChecklist = 0 WHERE Zona = 'Bolivar';

-- Capturamos el QUERY_ID del UPDATE para el rollback
SET q = LAST_QUERY_ID();
-- Confirmamos el daño: la zona Bolívar ahora tiene nota promedio = 0
SELECT 'despues_update' AS estado, Zona, AVG(NotaChecklist) AS nota_promedio, COUNT(*) AS registros
FROM FACT_CHECKLIST
WHERE Zona IN ('Bolivar','Atlantico','Santander')
GROUP BY 1, 2
ORDER BY 2;
-- Time Travel: consultamos la tabla justo ANTES del UPDATE (sin restaurar todavía)
SELECT 'time_travel_before' AS estado, Zona, AVG(NotaChecklist) AS nota_promedio, COUNT(*) AS registros
FROM FACT_CHECKLIST BEFORE(STATEMENT => $q)
WHERE Zona IN ('Bolivar','Atlantico','Santander')
GROUP BY 1, 2
ORDER BY 2;
-- Restauración instantánea: reemplazamos la tabla con el snapshot anterior al UPDATE
CREATE OR REPLACE TABLE FACT_CHECKLIST AS
SELECT * FROM FACT_CHECKLIST BEFORE(STATEMENT => $q);

-- Verificamos que la distribución original quedó restaurada
SELECT 'restaurado' AS estado, Zona, AVG(NotaChecklist) AS nota_promedio, COUNT(*) AS registros
FROM FACT_CHECKLIST
WHERE Zona IN ('Bolivar','Atlantico','Santander')
GROUP BY 1, 2
ORDER BY 2;

/* ----------------------------------------------------------------------
   Masking Dinámico por Rol
   > 5.1 — Crear rol restringido ANALISTA_OPERACIONES
   ---------------------------------------------------------------------- */
USE ROLE ACCOUNTADMIN;
USE DATABASE DB_HOL_OLIMPICA;
USE SCHEMA PUBLIC;

-- Rol con acceso de lectura pero sin visibilidad de datos sensibles
CREATE OR REPLACE ROLE ANALISTA_OPERACIONES;

-- Grants de uso sobre BD, schema y warehouse
GRANT USAGE ON DATABASE DB_HOL_OLIMPICA              TO ROLE ANALISTA_OPERACIONES;
GRANT USAGE ON SCHEMA   DB_HOL_OLIMPICA.PUBLIC       TO ROLE ANALISTA_OPERACIONES;
GRANT SELECT ON ALL TABLES IN SCHEMA DB_HOL_OLIMPICA.PUBLIC TO ROLE ANALISTA_OPERACIONES;
GRANT USAGE ON WAREHOUSE WH_HOL_OLIMPICA             TO ROLE ANALISTA_OPERACIONES;

-- Asignar el rol a tu usuario
GRANT ROLE ANALISTA_OPERACIONES TO USER JPARRADO;

-- > 5.2 — Política de masking para nombres de empleados
-- Política: enmascara nombres de empleados para todos los roles excepto ACCOUNTADMIN
CREATE OR REPLACE MASKING POLICY mp_nombre_empleado AS (val STRING) RETURNS STRING ->
  CASE
    WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN') THEN val
    ELSE '****'
  END
  COMMENT = 'Oculta nombres de empleados (EncargadoZona, DirectorGeneral) a roles no privilegiados';

-- > 5.3 — Redacción inteligente de observaciones con AI_REDACT
-- Política: ACCOUNTADMIN ve la observación completa;
-- otros roles ven el texto con la PII redactada por IA (se preserva el hallazgo operativo)
CREATE OR REPLACE MASKING POLICY mp_texto_observacion AS (val STRING) RETURNS STRING ->
  CASE
    WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN') THEN val
    ELSE AI_REDACT(val)
  END
  COMMENT = 'Redacta datos sensibles (PII) de las observaciones de auditoría con AI_REDACT para roles no privilegiados';

-- > 5.4 — Aplicar las políticas a las columnas
-- Asociar mp_nombre_empleado a columnas de DIM_TIENDA
ALTER TABLE DIM_TIENDA MODIFY COLUMN EncargadoZona    SET MASKING POLICY mp_nombre_empleado;
ALTER TABLE DIM_TIENDA MODIFY COLUMN DirectorGeneral  SET MASKING POLICY mp_nombre_empleado;

-- Asociar mp_texto_observacion a FACT_CHECKLIST.Observaciones
ALTER TABLE FACT_CHECKLIST MODIFY COLUMN Observaciones SET MASKING POLICY mp_texto_observacion;

-- > 5.5 — Demostración: misma query, diferente resultado por rol
----------------------------------------------------------------------
-- A) Como ACCOUNTADMIN: ve nombres y observaciones en claro
----------------------------------------------------------------------
USE ROLE ACCOUNTADMIN;

SELECT
    t.IdTienda,
    t.Zona,
    t.Gerencia,
    t.EncargadoZona,
    t.DirectorGeneral,
    LEFT(c.Observaciones, 120) AS Observaciones_Preview
FROM DIM_TIENDA t
JOIN FACT_CHECKLIST c ON c.IdTienda = t.IdTienda
WHERE t.Zona = 'Bolivar'
LIMIT 5;
----------------------------------------------------------------------
-- B) Como ANALISTA_OPERACIONES: misma query, datos enmascarados
----------------------------------------------------------------------
USE ROLE ANALISTA_OPERACIONES;

SELECT
    t.IdTienda,
    t.Zona,
    t.Gerencia,
    t.EncargadoZona,        -- Verá '****'
    t.DirectorGeneral,      -- Verá '****'
    LEFT(c.Observaciones, 120) AS Observaciones_Preview  -- Verá el texto con la PII redactada por AI_REDACT
FROM DIM_TIENDA t
JOIN FACT_CHECKLIST c ON c.IdTienda = t.IdTienda
WHERE t.Zona = 'Bolivar'
LIMIT 5;
-- Volver al rol administrador para continuar el lab
USE ROLE ACCOUNTADMIN;

/* ----------------------------------------------------------------------
   Cortex AI Functions
   > 6.1 — AI_COMPLETE: Pregunta de negocio al LLM
   ---------------------------------------------------------------------- */
USE DATABASE DB_HOL_OLIMPICA;
USE SCHEMA PUBLIC;
USE WAREHOUSE WH_HOL_OLIMPICA;

-- Pregunta de negocio directa al LLM
SELECT AI_COMPLETE(
    'claude-sonnet-4-5',
    'Resume en 5 puntos los beneficios de Snowflake Cortex para auditoría operativa de un retail como Olímpica. Responde en español con saltos de línea.'
) AS respuesta;

-- > 6.2 — Resumen y evaluación multi-aspecto por observación
-- Resumen en <=5 palabras + evaluación JSON multi-aspecto
SELECT
    IdTienda,
    LEFT(Observaciones, 80) AS preview,

    AI_COMPLETE(
        'openai-gpt-4.1',
        CONCAT('Resume en máximo 5 palabras la siguiente observación de auditoría de tienda: ',
               Observaciones)
    ) AS resumen_corto,

    AI_COMPLETE(
        'openai-gpt-4.1',
        CONCAT(
            'Evalúa la siguiente observación de auditoría de tienda. ',
            'Responde SOLO en JSON con el formato {"severidad":"alta|media|baja","area_afectada":"<área>","requiere_accion":true|false}. ',
            'Texto: ', Observaciones
        )
    ) AS evaluacion_json

FROM FACT_CHECKLIST
WHERE Observaciones IS NOT NULL
LIMIT 10;

-- > 6.3 — AI_SENTIMENT: Clasificación de sentimiento
-- Análisis de sentimiento sobre las observaciones de auditoría
SELECT
    IdTienda,
    LEFT(Observaciones, 100) AS preview,
    AI_SENTIMENT(Observaciones):categories[0]:sentiment::VARCHAR AS sentimiento
FROM FACT_CHECKLIST
WHERE Observaciones IS NOT NULL
LIMIT 10;

-- > 6.4 — AI_AGG: Insight agregado sobre observaciones recientes
-- Insight agregado: top hallazgos, riesgos y oportunidades de mejora
SELECT
    AI_AGG(
        Observaciones,
        'Resume los principales hallazgos de estas auditorías de tienda. Indica: 1) Top 3 problemas más frecuentes, 2) Riesgos operativos detectados, 3) Oportunidades de mejora. Responde en español con bullets.'
    ) AS insight_agregado
FROM (
    SELECT Observaciones
    FROM FACT_CHECKLIST
    WHERE FechaRealizacion = (SELECT MAX(FechaRealizacion) FROM FACT_CHECKLIST)
      AND Observaciones IS NOT NULL
    LIMIT 100
);

-- > 6.5 — AI_TRANSLATE: Traducción es → en
-- Traducción de observaciones de español a inglés
SELECT
    IdTienda,
    LEFT(Observaciones, 120) AS observacion_es,
    AI_TRANSLATE(LEFT(Observaciones, 400), 'es', 'en') AS observacion_en
FROM FACT_CHECKLIST
WHERE Observaciones IS NOT NULL
LIMIT 3;

-- > 6.6 — AI_CLASSIFY: Clasificación por categoría operativa
-- Clasificación automática de observaciones en categorías operativas
SELECT
    IdTienda,
    LEFT(Observaciones, 100) AS preview,
    AI_CLASSIFY(
        Observaciones,
        ['Limpieza', 'Inventario', 'Cadena de frío', 'Atención al cliente', 'Documentación legal', 'Seguridad']
    ):labels[0]::VARCHAR AS categoria_detectada
FROM FACT_CHECKLIST
WHERE Observaciones IS NOT NULL
LIMIT 10;

/* ----------------------------------------------------------------------
   Cortex AI Multimodal
   > 7.1 — Reutilizar el stage y listar los archivos
   ---------------------------------------------------------------------- */
USE ROLE ACCOUNTADMIN;
USE DATABASE DB_HOL_OLIMPICA;
USE SCHEMA PUBLIC;
USE WAREHOUSE WH_HOL_OLIMPICA;

-- Reutilizamos el stage STG_OLIMPICA creado en el Paso 2 (mismas credenciales del Paso 2).
-- Solo apuntamos a la subcarpeta 'archivos/' del mismo bucket para leer los no estructurados.
LIST @STG_OLIMPICA/archivos/;

-- > 7.3 — AI_EXTRACT: Extracción estructurada del recibo POS
-- Extracción estructurada de campos del recibo POS
WITH extraccion AS (
    SELECT AI_EXTRACT(
        file => TO_FILE('@STG_OLIMPICA', 'archivos/recibo_pos_001.pdf'),
        responseFormat => [
            ['transaccion_id', 'ID de la transacción'],
            ['cajero',         'Nombre o código del cajero'],
            ['subtotal',       'Subtotal antes de impuestos'],
            ['iva',            'Valor del IVA'],
            ['total',          'Valor total pagado'],
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

-- > 7.4 — AI_COMPLETE Multimodal: Etiqueta de producto
-- Lectura de etiqueta de producto con modelo de visión
SELECT AI_COMPLETE(
    'pixtral-large',
    PROMPT('Extrae la información nutricional y de marca de esta etiqueta de producto: marca, nombre del producto, peso/volumen, calorías por porción, fecha de vencimiento. Responde en español. {0}',
           TO_FILE('@STG_OLIMPICA', 'archivos/etiqueta_producto_001.png'))
) AS etiqueta_datos;

-- > 7.5 — Análisis de góndola / Visual Merchandising
-- Análisis de góndola / visual merchandising con IA de visión
SELECT AI_COMPLETE(
    'claude-sonnet-4-5',
    PROMPT('Eres un experto en visual merchandising y trade marketing para retail FMCG. Analiza esta foto de una góndola / exhibición de tienda y devuelve un JSON con: 1) estado_general (ordenado/desordenado), 2) categorias_detectadas, 3) problemas_visuales (lista: producto fuera de lugar, sobre-stock, faltantes, falta de etiquetado, mezcla de categorías, etc.), 4) impacto_estimado_ventas (alto/medio/bajo con justificación), 5) recomendaciones_priorizadas (3 acciones concretas para mejorar la visualización y la experiencia del comprador). Responde solo en JSON y en español. {0}',
           TO_FILE('@STG_OLIMPICA', 'archivos/producto_foto_001.jpg'))
) AS analisis_gondola;

-- > 7.6 — Lectura de cupón de descuento (Claude Opus)
-- Extracción estructurada de cupón de descuento con Claude Opus
SELECT AI_COMPLETE(
    'claude-opus-4-5',
    PROMPT('Lee este cupón de descuento de Olímpica y devuelve en JSON: codigo_cupon, porcentaje_descuento, fecha_vigencia, condiciones, productos_aplicables. Responde solo en JSON y en español. {0}',
           TO_FILE('@STG_OLIMPICA', 'archivos/cupon_descuento_001.png'))
) AS cupon_datos;

-- > 7.7 — AI_TRANSCRIBE: Transcripción de audio
-- Transcripción simple de audio
SELECT TO_VARCHAR(AI_TRANSCRIBE(
    TO_FILE('@STG_OLIMPICA', 'archivos/ofreciendo-producto.mp3')
)) AS transcripcion;

-- > 7.8 — Caso End-to-End: Transcripción → Sentimiento → Extracción → Coach CX
-- Pipeline end-to-end: AI_TRANSCRIBE → AI_SENTIMENT → AI_EXTRACT → AI_COMPLETE (Coach CX)
WITH llamadas AS (
    SELECT 'oferta' AS tipo_llamada,
           AI_TRANSCRIBE(TO_FILE('@STG_OLIMPICA', 'archivos/ofreciendo-producto.mp3')):text::STRING AS texto
    UNION ALL
    SELECT 'queja_servicio',
           AI_TRANSCRIBE(TO_FILE('@STG_OLIMPICA', 'archivos/problema-servicio.mp3')):text::STRING
)
SELECT
    tipo_llamada,
    LEFT(texto, 120) AS preview,

    -- Sentimiento por aspectos
    AI_SENTIMENT(texto, ['producto', 'servicio', 'precio', 'retencion_cliente']) AS sentimiento_aspectos,

    -- Extracción de entidades
    AI_EXTRACT(
        text => texto,
        responseFormat => [
            ['cliente',          '¿Nombre del cliente?'],
            ['agente',           '¿Nombre del agente / asesor?'],
            ['motivo',           '¿Cuál es el motivo principal de la llamada?'],
            ['monto_o_precio',   '¿Se menciona algún monto, tarifa o precio?'],
            ['decision_cliente', '¿Cuál es la decisión o siguiente paso pedido por el cliente?']
        ]
    ) AS extraccion,

    -- Coach de Customer Experience
    AI_COMPLETE(
        'claude-opus-4-5',
        PROMPT('Eres un coach de Customer Experience para Olímpica (cadena retail colombiana). Lee esta llamada y devuelve un JSON con: clasificacion (oferta_proactiva | reclamo | consulta), prioridad (alta | media | baja), siguiente_accion (1 sola frase concreta), riesgo_churn (0-100). Responde solo en JSON y en español. Texto: {0}', texto)
    ) AS coach_cx

FROM llamadas
ORDER BY tipo_llamada;

/* ----------------------------------------------------------------------
   Cortex Search
   > 8.1 — Crear tabla enriquecida para indexación
   ---------------------------------------------------------------------- */
USE ROLE ACCOUNTADMIN;
USE DATABASE DB_HOL_OLIMPICA;
USE SCHEMA PUBLIC;

-- Escalar warehouse para la creación del índice
ALTER WAREHOUSE WH_HOL_OLIMPICA SET WAREHOUSE_SIZE = 'MEDIUM';

-- Tabla enriquecida con contexto de tienda (últimos 12 meses, máx. 50k registros)
CREATE OR REPLACE TABLE T_OBSERVACIONES_ENRIQUECIDAS AS
SELECT
    c.IdTienda,
    t.Ciudad,
    t.Zona,
    t.Gerencia,
    c.TipoSucursal,
    c.FechaRealizacion,
    c.NotaChecklist,
    c.EstadoChecklist,
    c.Observaciones AS Texto
FROM FACT_CHECKLIST c
JOIN DIM_TIENDA t ON t.IdTienda = c.IdTienda
WHERE c.FechaRealizacion >= DATEADD(year, -1, CURRENT_DATE())
  AND c.Observaciones IS NOT NULL
LIMIT 50000;

-- > 8.2 — Crear el servicio Cortex Search (SQL)
-- Crear servicio de búsqueda semántica sobre observaciones de auditoría
CREATE OR REPLACE CORTEX SEARCH SERVICE CSS_AUDITORIAS
    ON Texto
    ATTRIBUTES IdTienda, Ciudad, Zona, Gerencia, TipoSucursal, FechaRealizacion, NotaChecklist, EstadoChecklist
    WAREHOUSE = WH_HOL_OLIMPICA
    TARGET_LAG = '1 hour'
    AS
    SELECT IdTienda, Ciudad, Zona, Gerencia, TipoSucursal,
           FechaRealizacion, NotaChecklist, EstadoChecklist, Texto
    FROM T_OBSERVACIONES_ENRIQUECIDAS;

-- > 8.3 — Verificar el estado del servicio
-- Verificar estado del servicio (esperar a que indexing_state = 'ACTIVE')
SHOW CORTEX SEARCH SERVICES LIKE 'CSS_AUDITORIAS';

-- > 8.4 — Demo de búsqueda semántica
-- Búsqueda semántica: "cadena de frío producto vencido"
-- Aplanamos el JSON a columnas legibles para negocio
WITH busqueda AS (
    SELECT PARSE_JSON(
        SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
            'DB_HOL_OLIMPICA.PUBLIC.CSS_AUDITORIAS',
            '{
                "query": "cadena de frío producto vencido",
                "columns": ["Ciudad", "Zona", "Gerencia", "NotaChecklist", "Texto"],
                "limit": 5
            }'
        )
    )['results'] AS resultados
)
SELECT
    r.value:Ciudad::STRING              AS ciudad,
    r.value:Zona::STRING                AS zona,
    r.value:Gerencia::STRING            AS gerencia,
    ROUND(r.value:NotaChecklist::FLOAT, 1) AS nota_auditoria,
    r.value:Texto::STRING               AS hallazgo
FROM busqueda, LATERAL FLATTEN(input => busqueda.resultados) r;

-- > 8.5 — Alternativa por la UI (Snowsight)
-- Restaurar tamaño del warehouse
ALTER WAREHOUSE WH_HOL_OLIMPICA SET WAREHOUSE_SIZE = 'SMALL';

/* ----------------------------------------------------------------------
   Dynamic Tables
   > 9.1 — DT_VENTAS_TIENDA_MES (Ventas agregadas por tienda y mes)
   ---------------------------------------------------------------------- */
USE ROLE ACCOUNTADMIN;
USE DATABASE DB_HOL_OLIMPICA;
USE SCHEMA PUBLIC;
USE WAREHOUSE WH_HOL_OLIMPICA;

CREATE OR REPLACE DYNAMIC TABLE DT_VENTAS_TIENDA_MES
    TARGET_LAG   = '1 hour'
    WAREHOUSE    = WH_HOL_OLIMPICA
    REFRESH_MODE = INCREMENTAL
AS
SELECT
    DATE_TRUNC('month', ft.FECHA)  AS mes,
    t.IdTienda,
    t.Ciudad,
    t.Gerencia,
    COUNT(*)            AS tickets,
    SUM(ft.MontoTotal)  AS ventas,
    AVG(ft.MontoTotal)  AS ticket_promedio,
    SUM(ft.NumLineas)   AS lineas
FROM FACT_TICKET ft
JOIN DIM_TIENDA t ON t.IdTienda = ft.IdTienda
GROUP BY 1, 2, 3, 4;

-- > 9.2 — Verificar la Dynamic Table
-- Listar Dynamic Tables creadas
SHOW DYNAMIC TABLES IN SCHEMA DB_HOL_OLIMPICA.PUBLIC;

-- Consultar la Dynamic Table
SELECT * FROM DT_VENTAS_TIENDA_MES ORDER BY mes DESC LIMIT 10;

-- Historial de refresh
SELECT NAME, STATE, REFRESH_START_TIME, REFRESH_END_TIME,
       STATISTICS:numInsertedRows::INT AS filas_insertadas
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(
    NAME => 'DB_HOL_OLIMPICA.PUBLIC.DT_VENTAS_TIENDA_MES'
))
ORDER BY REFRESH_START_TIME DESC LIMIT 5;

/* ----------------------------------------------------------------------
   Cortex Analyst
   > 10.2 — Verified Queries (5 ejemplos)
   ---------------------------------------------------------------------- */
-- 1. tickets_por_gerencia_2026
SELECT t.Gerencia, COUNT(f.FACTURA) AS tickets
FROM DB_HOL_OLIMPICA.PUBLIC.FACT_TICKET f
JOIN DB_HOL_OLIMPICA.PUBLIC.DIM_TIENDA t ON t.IdTienda = f.IdTienda
WHERE YEAR(f.FECHA) = 2026
GROUP BY 1 ORDER BY 2 DESC;

-- 2. top_10_promociones
SELECT p.NomPromo, COUNT(*) AS frecuencia
FROM DB_HOL_OLIMPICA.PUBLIC.FACT_VENTA_LINEA l
JOIN DB_HOL_OLIMPICA.PUBLIC.DIM_PROMO p ON p.OFERTA_ID = l.OFERTA_ID
GROUP BY 1 ORDER BY 2 DESC LIMIT 10;

-- 3. ventas_por_ciudad
SELECT t.Ciudad, SUM(l.Venta) AS ventas_total
FROM DB_HOL_OLIMPICA.PUBLIC.FACT_VENTA_LINEA l
JOIN DB_HOL_OLIMPICA.PUBLIC.DIM_TIENDA t ON t.IdTienda = l.IdTienda
GROUP BY 1 ORDER BY 2 DESC;

-- 4. ventas_mensuales_categoria
SELECT DATE_TRUNC('month', l.FECHA) AS mes, l.Categoria,
       SUM(l.Venta) AS ventas
FROM DB_HOL_OLIMPICA.PUBLIC.FACT_VENTA_LINEA l
WHERE l.FECHA >= DATEADD(year, -1, CURRENT_DATE())
GROUP BY 1, 2 ORDER BY 1, 2;

-- 5. ticket_promedio_tienda
SELECT t.IdTienda, t.Ciudad, AVG(f.MontoTotal) AS ticket_promedio
FROM DB_HOL_OLIMPICA.PUBLIC.FACT_TICKET f
JOIN DB_HOL_OLIMPICA.PUBLIC.DIM_TIENDA t ON t.IdTienda = f.IdTienda
GROUP BY 1, 2 ORDER BY 3 DESC;

/* ----------------------------------------------------------------------
   Snowflake CoWork
   > 11.3 — Validar gobierno automático
   ---------------------------------------------------------------------- */
-- Cambiar de rol para validar masking
USE ROLE ANALISTA_OPERACIONES;

-- Ahora vuelve al agente AGT_OLIMPICA y pregunta:
-- "¿Quién es el director general de la zona Norte?"
-- Los nombres aparecerán enmascarados (****)

-- Volver al rol admin
USE ROLE ACCOUNTADMIN;

/* ----------------------------------------------------------------------
   Recursos & Cleanup
   > 12.3 — Limpieza del ambiente
   ---------------------------------------------------------------------- */
-- =============================================
-- CLEANUP: Eliminar todos los objetos del HOL
-- =============================================
USE ROLE ACCOUNTADMIN;

DROP DATABASE IF EXISTS DB_HOL_OLIMPICA;
DROP DATABASE IF EXISTS DB_HOL_OLIMPICA_DEV;
DROP WAREHOUSE IF EXISTS WH_HOL_OLIMPICA;
DROP ROLE IF EXISTS ANALISTA_OPERACIONES;
