/* ============================================================================
   HOL CredibanCo - RFP 10010806
   T4 - Analitica, ML e IA

   Equipo    : Data & Analytics
   Duracion  : 30 minutos
   Prerrequisito: haber ejecutado install_ingenieria.sql en esta cuenta

   Entrenar y explicar un modelo de abandono de comercio con SQL, leer documentos no estructurados con IA, y dejar un agente que responde en lenguaje natural sin que el dato salga del perimetro.
   ==========================================================================*/


-- ==========================================================================
-- Paso 1. Entrenar un clasificador de abandono con SQL
-- Que un analista entrene un modelo sin salir de SQL ni mover el dato.
-- ==========================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_ML;
USE SCHEMA CB_GOLD.PRODUCTOS;

-- las variables ya estan calculadas en el producto de datos
SELECT CHURN,
       COUNT(*)                        AS COMERCIOS,
       ROUND(AVG(TENDENCIA_3M), 4)     AS TENDENCIA_PROMEDIO,
       ROUND(AVG(MONTO_ULT_3M) / 1e6, 1) AS MONTO_ULT_3M_MILLONES,
       ROUND(AVG(MESES_ACTIVO), 1)     AS MESES_ACTIVO
FROM CB_GOLD.PRODUCTOS.COMERCIO_FEATURES_CHURN
GROUP BY CHURN;

-- particion de entrenamiento y prueba, estable y reproducible
CREATE OR REPLACE VIEW CB_GOLD.PRODUCTOS.VW_CHURN_ENTRENAMIENTO AS
SELECT TENDENCIA_3M, MONTO_ULT_3M, MESES_ACTIVO, TASA_APROBACION,
       TICKET_PROMEDIO, TASA_FRAUDE, TRX_TOTAL, TASA_DESCUENTO_PCT,
       SECTOR, SEGMENTO, DEPARTAMENTO,
       CHURN::VARCHAR AS CHURN
FROM CB_GOLD.PRODUCTOS.COMERCIO_FEATURES_CHURN
WHERE MOD(ABS(HASH(COMERCIO_ID)), 10) < 8;

CREATE OR REPLACE VIEW CB_GOLD.PRODUCTOS.VW_CHURN_PRUEBA AS
SELECT COMERCIO_ID,
       TENDENCIA_3M, MONTO_ULT_3M, MESES_ACTIVO, TASA_APROBACION,
       TICKET_PROMEDIO, TASA_FRAUDE, TRX_TOTAL, TASA_DESCUENTO_PCT,
       SECTOR, SEGMENTO, DEPARTAMENTO,
       CHURN::VARCHAR AS CHURN
FROM CB_GOLD.PRODUCTOS.COMERCIO_FEATURES_CHURN
WHERE MOD(ABS(HASH(COMERCIO_ID)), 10) >= 8;

SELECT (SELECT COUNT(*) FROM CB_GOLD.PRODUCTOS.VW_CHURN_ENTRENAMIENTO) AS ENTRENAMIENTO,
       (SELECT COUNT(*) FROM CB_GOLD.PRODUCTOS.VW_CHURN_PRUEBA)        AS PRUEBA;

-- el entrenamiento es una sentencia. El dato no se mueve ni se
-- exporta a un notebook: el modelo se construye donde vive el dato.
CREATE OR REPLACE SNOWFLAKE.ML.CLASSIFICATION CB_GOLD.PRODUCTOS.MODELO_CHURN_COMERCIO(
    INPUT_DATA        => SYSTEM$REFERENCE('VIEW', 'CB_GOLD.PRODUCTOS.VW_CHURN_ENTRENAMIENTO'),
    TARGET_COLNAME    => 'CHURN',
    CONFIG_OBJECT     => {'evaluate': TRUE, 'on_error': 'skip'}
);

CALL CB_PLATAFORMA.EVIDENCIA.LOG_EVIDENCIA('T4',
    'Modelo de abandono de comercio entrenado con SQL sobre el dato en sitio',
    'CB_GOLD.PRODUCTOS.MODELO_CHURN_COMERCIO',
    'Clasificador entrenado con una sentencia SQL sobre 144.000 comercios, sin exportar el dato ni provisionar infraestructura de entrenamiento',
    'Anexo 10 - 10.1 ciclo MLOps y 10.3 IA dentro del perimetro');


-- ==========================================================================
-- Paso 2. Evaluar y explicar antes de creerle
-- Obtener metricas de calidad y saber que variables pesan.
-- ==========================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_ML;

-- metricas de calidad calculadas en el entrenamiento
CALL CB_GOLD.PRODUCTOS.MODELO_CHURN_COMERCIO!SHOW_EVALUATION_METRICS();

-- matriz de confusion: donde se equivoca y hacia que lado
CALL CB_GOLD.PRODUCTOS.MODELO_CHURN_COMERCIO!SHOW_CONFUSION_MATRIX();

-- que variables sostienen la prediccion
CALL CB_GOLD.PRODUCTOS.MODELO_CHURN_COMERCIO!SHOW_FEATURE_IMPORTANCE();

-- predecir sobre el conjunto que el modelo nunca vio
CREATE OR REPLACE TABLE CB_GOLD.PRODUCTOS.CHURN_PREDICCIONES AS
SELECT p.COMERCIO_ID,
       p.CHURN AS CHURN_REAL,
       pred:class::VARCHAR                          AS CHURN_PREDICHO,
       pred:probability:"1"::FLOAT                  AS PROBABILIDAD_ABANDONO
FROM (
    SELECT COMERCIO_ID, CHURN,
           CB_GOLD.PRODUCTOS.MODELO_CHURN_COMERCIO!PREDICT(
               OBJECT_CONSTRUCT(*)) AS pred
    FROM CB_GOLD.PRODUCTOS.VW_CHURN_PRUEBA
) p;

-- calidad sobre datos no vistos, en lenguaje de negocio
SELECT COUNT(*)                                                      AS COMERCIOS_EVALUADOS,
       COUNT_IF(CHURN_REAL = CHURN_PREDICHO)                         AS ACIERTOS,
       ROUND(100.0 * COUNT_IF(CHURN_REAL = CHURN_PREDICHO) / COUNT(*), 2) AS PCT_ACIERTO,
       COUNT_IF(CHURN_REAL = '1' AND CHURN_PREDICHO = '1')           AS ABANDONOS_DETECTADOS,
       COUNT_IF(CHURN_REAL = '1' AND CHURN_PREDICHO = '0')           AS ABANDONOS_NO_VISTOS,
       COUNT_IF(CHURN_REAL = '0' AND CHURN_PREDICHO = '1')           AS FALSAS_ALARMAS
FROM CB_GOLD.PRODUCTOS.CHURN_PREDICCIONES;

-- la lista accionable: comercios grandes en riesgo alto
SELECT p.COMERCIO_ID,
       c.RAZON_SOCIAL,
       c.SECTOR,
       c.CIUDAD,
       ROUND(p.PROBABILIDAD_ABANDONO, 3)   AS RIESGO,
       ROUND(f.MONTO_ULT_3M / 1e6, 1)      AS MONTO_ULT_3M_MILLONES,
       ROUND(f.TENDENCIA_3M, 3)            AS TENDENCIA
FROM CB_GOLD.PRODUCTOS.CHURN_PREDICCIONES p
JOIN CB_SILVER.ADQUIRENCIA.COMERCIOS c        ON c.COMERCIO_ID = p.COMERCIO_ID
JOIN CB_GOLD.PRODUCTOS.COMERCIO_FEATURES_CHURN f ON f.COMERCIO_ID = p.COMERCIO_ID
WHERE p.PROBABILIDAD_ABANDONO > 0.7
ORDER BY f.MONTO_ULT_3M DESC
LIMIT 20;

CALL CB_PLATAFORMA.EVIDENCIA.LOG_EVIDENCIA('T4',
    'Evaluacion, explicabilidad y prediccion sobre datos no vistos',
    'MODELO_CHURN_COMERCIO: metricas, matriz de confusion, importancia de variables y CHURN_PREDICCIONES',
    'Metricas de calidad, matriz de confusion e importancia de variables obtenidas del propio modelo, mas lista priorizada por monto en riesgo',
    'Anexo 10 - 10.1 MLOps con evaluacion y explicabilidad');


-- ==========================================================================
-- Paso 3. Leer documentos con IA, dentro del perimetro
-- Convertir vouchers y expedientes SARLAFT en datos consultables.
-- ==========================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_ML;

-- que documentos hay disponibles
SELECT TIPO_DOCUMENTO, COUNT(*) AS DOCUMENTOS, ROUND(SUM(SIZE)/1024.0, 1) AS KB
FROM CB_RAW.LANDING.VW_DOCUMENTOS
GROUP BY TIPO_DOCUMENTO
ORDER BY DOCUMENTOS DESC;

-- extraer campos de un expediente SARLAFT sin escribir un parser
CREATE OR REPLACE TABLE CB_GOLD.PRODUCTOS.SARLAFT_ESTRUCTURADO AS
SELECT RELATIVE_PATH AS ARCHIVO,
       AI_EXTRACT(
           file => TO_FILE('@CB_RAW.LANDING.STG_HOL', RELATIVE_PATH),
           responseFormat => {
               'nit': 'NIT del vinculado',
               'razon_social': 'Razon social del vinculado',
               'nivel_riesgo': 'Nivel de riesgo LA/FT: BAJO, MEDIO o ALTO',
               'es_pep': 'Indica si es Persona Expuesta Politicamente: SI o NO',
               'desviacion_pct': 'Desviacion porcentual entre el monto esperado y el observado',
               'recomendacion': 'Recomendacion del analista en una frase'
           }
       ):response AS DATOS
FROM CB_RAW.LANDING.VW_DOCUMENTOS
WHERE TIPO_DOCUMENTO = 'SARLAFT'
LIMIT 25;

SELECT ARCHIVO,
       DATOS:nit::VARCHAR           AS NIT,
       DATOS:razon_social::VARCHAR  AS RAZON_SOCIAL,
       DATOS:nivel_riesgo::VARCHAR  AS NIVEL_RIESGO,
       DATOS:es_pep::VARCHAR        AS ES_PEP,
       DATOS:recomendacion::VARCHAR AS RECOMENDACION
FROM CB_GOLD.PRODUCTOS.SARLAFT_ESTRUCTURADO
LIMIT 10;

-- ahora el texto libre se cruza con el dato transaccional
SELECT s.DATOS:nivel_riesgo::VARCHAR AS NIVEL_RIESGO,
       COUNT(*)                      AS COMERCIOS,
       ROUND(AVG(f.MONTO_ULT_3M) / 1e6, 1) AS MONTO_PROMEDIO_MILLONES,
       ROUND(AVG(f.TASA_FRAUDE) * 100, 4)  AS TASA_FRAUDE_PCT
FROM CB_GOLD.PRODUCTOS.SARLAFT_ESTRUCTURADO s
JOIN CB_SILVER.ADQUIRENCIA.COMERCIOS c
  ON c.NIT = s.DATOS:nit::VARCHAR
JOIN CB_GOLD.PRODUCTOS.COMERCIO_FEATURES_CHURN f
  ON f.COMERCIO_ID = c.COMERCIO_ID
GROUP BY NIVEL_RIESGO
ORDER BY NIVEL_RIESGO;

-- clasificar el motivo de una declinacion en texto libre
SELECT DESCRIPCION_RESPUESTA,
       COUNT(*) AS OCURRENCIAS,
       AI_CLASSIFY(
           ANY_VALUE(DESCRIPCION_RESPUESTA),
           ['problema de saldo', 'problema de la tarjeta', 'sospecha de fraude',
            'falla tecnica', 'restriccion del emisor']
       ):labels[0]::VARCHAR AS CATEGORIA
FROM CB_SILVER.ADQUIRENCIA.AUTORIZACIONES
WHERE APROBADA = FALSE
GROUP BY DESCRIPCION_RESPUESTA
ORDER BY OCURRENCIAS DESC;

CALL CB_PLATAFORMA.EVIDENCIA.LOG_EVIDENCIA('T4',
    'Documentos no estructurados convertidos en datos y cruzados con lo transaccional',
    'CB_GOLD.PRODUCTOS.SARLAFT_ESTRUCTURADO desde archivos de texto en el stage',
    'Campos extraidos de expedientes SARLAFT sin escribir un parser y cruzados por NIT con el comportamiento transaccional del comercio',
    'Anexo 10 - 10.3 GenIA en perimetro y consolidado 68 datos no estructurados');


-- ==========================================================================
-- Paso 4. Un agente que responde y respeta los permisos
-- Dejar el analisis disponible en lenguaje natural, con el gobierno intacto.
-- ==========================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_ML;

-- la capa semantica: nombres de negocio, metricas y relaciones.
-- Es lo que evita que el modelo invente una definicion de ticket promedio.
CREATE OR REPLACE SEMANTIC VIEW CB_GOLD.PRODUCTOS.SV_ADQUIRENCIA
    TABLES (
        COMERCIOS AS CB_SILVER.ADQUIRENCIA.COMERCIOS
            PRIMARY KEY (COMERCIO_ID)
            WITH SYNONYMS = ('comercio', 'afiliado', 'establecimiento')
            COMMENT = 'Comercios afiliados a la red de adquirencia',
        VENTAS AS CB_GOLD.PRODUCTOS.VENTAS_MENSUALES_COMERCIO
            PRIMARY KEY (COMERCIO_ID, MES)
            WITH SYNONYMS = ('ventas', 'facturacion', 'transacciones')
            COMMENT = 'Ventas mensuales agregadas por comercio'
    )
    RELATIONSHIPS (
        VENTAS_A_COMERCIO AS VENTAS (COMERCIO_ID) REFERENCES COMERCIOS (COMERCIO_ID)
    )
    DIMENSIONS (
        COMERCIOS.RAZON_SOCIAL AS RAZON_SOCIAL WITH SYNONYMS = ('nombre del comercio'),
        COMERCIOS.SECTOR       AS SECTOR       WITH SYNONYMS = ('rubro', 'actividad'),
        COMERCIOS.SEGMENTO     AS SEGMENTO     WITH SYNONYMS = ('tamano del comercio'),
        VENTAS.CIUDAD AS CIUDAD_COMERCIO       WITH SYNONYMS = ('ciudad', 'plaza'),
        VENTAS.DEPARTAMENTO    AS DEPARTAMENTO WITH SYNONYMS = ('departamento', 'region'),
        VENTAS.MES             AS MES          WITH SYNONYMS = ('mes', 'periodo')
    )
    METRICS (
        VENTAS.MONTO_APROBADO AS SUM(VENTAS.MONTO_APROBADO_COP)
            COMMENT = 'Monto aprobado en pesos colombianos',
        VENTAS.TRANSACCIONES  AS SUM(VENTAS.TRX_TOTAL)
            COMMENT = 'Cantidad total de transacciones',
        VENTAS.TICKET_PROMEDIO AS SUM(VENTAS.MONTO_APROBADO_COP) / NULLIF(SUM(VENTAS.TRX_APROBADAS), 0)
            COMMENT = 'Ticket promedio en pesos',
        VENTAS.TASA_APROBACION AS 100.0 * SUM(VENTAS.TRX_APROBADAS) / NULLIF(SUM(VENTAS.TRX_TOTAL), 0)
            COMMENT = 'Porcentaje de transacciones aprobadas',
        VENTAS.CLIENTES AS SUM(VENTAS.CLIENTES_UNICOS)
            COMMENT = 'Clientes unicos que compraron'
    )
    COMMENT = 'Modelo semantico de adquirencia para consulta en lenguaje natural';

SHOW SEMANTIC VIEWS LIKE 'SV_ADQUIRENCIA' IN SCHEMA CB_GOLD.PRODUCTOS;

-- la capa semantica se consulta tambien con SQL, lo que permite
-- verificar que las metricas dan lo mismo por los dos caminos
SELECT * FROM SEMANTIC_VIEW(
    CB_GOLD.PRODUCTOS.SV_ADQUIRENCIA
    DIMENSIONS SECTOR
    METRICS MONTO_APROBADO, TRANSACCIONES, TICKET_PROMEDIO
)
ORDER BY MONTO_APROBADO DESC
LIMIT 10;

-- permisos para que el negocio consulte
GRANT USAGE ON DATABASE CB_GOLD TO ROLE RL_NEGOCIO;
GRANT USAGE ON SCHEMA CB_GOLD.PRODUCTOS TO ROLE RL_NEGOCIO;
GRANT SELECT ON SEMANTIC VIEW CB_GOLD.PRODUCTOS.SV_ADQUIRENCIA TO ROLE RL_NEGOCIO;
GRANT SELECT ON SEMANTIC VIEW CB_GOLD.PRODUCTOS.SV_ADQUIRENCIA TO ROLE RL_ANALISTA;

CALL CB_PLATAFORMA.EVIDENCIA.LOG_EVIDENCIA('T4',
    'Capa semantica de negocio para consulta en lenguaje natural',
    'CB_GOLD.PRODUCTOS.SV_ADQUIRENCIA con 6 dimensiones y 5 metricas',
    'Metricas de negocio definidas una sola vez y consultables por SQL y por lenguaje natural, con permisos por rol',
    'Anexo 10 - 8.2 consulta en lenguaje natural sobre datos gobernados');


-- ==========================================================================
-- Cierre: evidencia del track
-- ==========================================================================

-- Resumen de lo ejecutado en este track. Es el artefacto que se entrega al
-- cierre, como exige el numeral 3.2 del Anexo 11.
SELECT PASO, OBJETO, RESULTADO, REQUISITO, EJECUTADO_POR, ROL, MOMENTO
FROM CB_PLATAFORMA.EVIDENCIA.ARTEFACTOS
WHERE TRACK = 'T4'
ORDER BY MOMENTO;

SELECT * FROM CB_PLATAFORMA.EVIDENCIA.VW_EVIDENCIA_POR_TRACK
WHERE TRACK = 'T4';
