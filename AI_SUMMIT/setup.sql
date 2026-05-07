-- =====================================================================
-- HOL AI SUMMIT - SETUP COMPLETO
-- Este script es invocado por bootstrap.sql via EXECUTE IMMEDIATE FROM @hol_repo.
-- Crea toda la infraestructura del HOL: stages, datos, tablas sintéticas,
-- Cortex Search, Semantic View, Agente con Snowflake Intelligence y notebook.
-- =====================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE HOL_AI_SUMMIT;
USE SCHEMA PUBLIC;
USE WAREHOUSE HOL_WH;

-- ---------------------------------------------------------------------
-- 1. Stages internos para imágenes, documentos y audio
-- ---------------------------------------------------------------------
CREATE OR REPLACE STAGE IMAGENES
  DIRECTORY = (ENABLE = TRUE)
  ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');

CREATE OR REPLACE STAGE DOCUMENTOS
  DIRECTORY = (ENABLE = TRUE)
  ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');

CREATE OR REPLACE STAGE AUDIO
  DIRECTORY = (ENABLE = TRUE)
  ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');

-- ---------------------------------------------------------------------
-- 2. Copiar archivos desde el repo Git al stage interno
-- ---------------------------------------------------------------------
COPY FILES INTO @IMAGENES
  FROM @hol_repo/branches/main/AI_SUMMIT/datasets/imagenes/;

COPY FILES INTO @DOCUMENTOS
  FROM @hol_repo/branches/main/AI_SUMMIT/datasets/documentos/;

COPY FILES INTO @AUDIO
  FROM @hol_repo/branches/main/AI_SUMMIT/datasets/audio/;

ALTER STAGE IMAGENES REFRESH;
ALTER STAGE DOCUMENTOS REFRESH;
ALTER STAGE AUDIO REFRESH;

-- ---------------------------------------------------------------------
-- 3. Tabla con documentos parseados (AI_PARSE_DOCUMENT soporta DOCX nativo)
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE DOCS_PARSED AS
SELECT
  RELATIVE_PATH AS file_name,
  TO_VARCHAR(
    AI_PARSE_DOCUMENT(
      TO_FILE('@DOCUMENTOS', RELATIVE_PATH),
      {'mode': 'LAYOUT'}
    ):content
  ) AS content
FROM DIRECTORY(@DOCUMENTOS);

-- ---------------------------------------------------------------------
-- 4. Tabla de transcripciones de audio
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE TRANSCRIPCIONES AS
SELECT
  RELATIVE_PATH AS file_name,
  TO_VARCHAR(
    AI_TRANSCRIBE(TO_FILE('@AUDIO', RELATIVE_PATH)):text
  ) AS transcripcion,
  AI_SENTIMENT(
    TO_VARCHAR(AI_TRANSCRIBE(TO_FILE('@AUDIO', RELATIVE_PATH)):text)
  ):categories[0]:sentiment::VARCHAR AS sentimiento
FROM DIRECTORY(@AUDIO);

-- ---------------------------------------------------------------------
-- 5. Data sintética: POLIZAS (ventas de seguros/inmobiliaria)
--    Enlazada temáticamente con los contratos y llamadas existentes
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE POLIZAS (
  id NUMBER,
  fecha DATE,
  tipo_poliza VARCHAR,
  producto VARCHAR,
  region VARCHAR,
  ciudad VARCHAR,
  cliente VARCHAR,
  vendedor VARCHAR,
  prima_mensual NUMBER(12,2),
  cobertura_total NUMBER(12,2),
  estado VARCHAR,
  canal_venta VARCHAR
);

INSERT INTO POLIZAS VALUES
(1,'2025-11-05','Hogar','Protección Incendios','Bogotá','Bogotá','María Elena Rodríguez','Carlos Asesor',85000,50000000,'Activa','Telefónico'),
(2,'2025-11-12','Hogar','Protección Total','Bogotá','Bogotá','Carlos Andrés Moreno','Carlos Asesor',120000,80000000,'Activa','Presencial'),
(3,'2025-11-18','Vehicular','Todo Riesgo Auto','Antioquia','Medellín','Ana Patricia Silva','Luisa Ventas',250000,120000000,'Activa','Digital'),
(4,'2025-11-25','Hogar','Protección Básica','Valle','Cali','Diana Carolina Pérez','Pedro Comercial',55000,30000000,'Activa','Telefónico'),
(5,'2025-12-02','Vehicular','Responsabilidad Civil','Bogotá','Bogotá','Jorge Parrado','Carlos Asesor',95000,40000000,'Activa','Digital'),
(6,'2025-12-08','Vida','Vida Individual','Antioquia','Medellín','Sandra Milena López','Luisa Ventas',180000,200000000,'Activa','Presencial'),
(7,'2025-12-15','Hogar','Protección Incendios','Bogotá','Soacha','Roberto García','Pedro Comercial',75000,45000000,'Activa','Telefónico'),
(8,'2025-12-20','Vehicular','Todo Riesgo Moto','Valle','Cali','Camila Herrera','Andrea Digital',65000,25000000,'Activa','Digital'),
(9,'2026-01-05','Hogar','Protección Total','Bogotá','Bogotá','Luis Fernando Castro','Carlos Asesor',130000,90000000,'Activa','Presencial'),
(10,'2026-01-10','Vida','Vida Familiar','Antioquia','Medellín','Patricia Gómez','Luisa Ventas',320000,500000000,'Activa','Presencial'),
(11,'2026-01-15','Vehicular','Todo Riesgo Auto','Bogotá','Bogotá','Andrés Felipe Ruiz','Andrea Digital',270000,130000000,'Activa','Digital'),
(12,'2026-01-22','Hogar','Protección Básica','Santander','Bucaramanga','Martha Cecilia Díaz','Pedro Comercial',50000,28000000,'Cancelada','Telefónico'),
(13,'2026-02-01','Vehicular','Responsabilidad Civil','Valle','Palmira','Óscar Iván Muñoz','Carlos Asesor',88000,38000000,'Activa','Telefónico'),
(14,'2026-02-08','Hogar','Protección Incendios','Atlántico','Barranquilla','Gloria Estefanía Ríos','Andrea Digital',78000,42000000,'Activa','Digital'),
(15,'2026-02-14','Vida','Vida Individual','Bogotá','Bogotá','Héctor Julio Vargas','Luisa Ventas',195000,220000000,'Activa','Presencial'),
(16,'2026-02-20','Vehicular','Todo Riesgo Auto','Antioquia','Envigado','Natalia Restrepo','Andrea Digital',260000,125000000,'Activa','Digital'),
(17,'2026-03-01','Hogar','Protección Total','Bogotá','Chía','Fernando Cárdenas','Carlos Asesor',135000,95000000,'Activa','Presencial'),
(18,'2026-03-05','Vehicular','Todo Riesgo Moto','Bogotá','Bogotá','Juliana Pardo','Pedro Comercial',60000,22000000,'Activa','Telefónico'),
(19,'2026-03-10','Vida','Vida Familiar','Valle','Cali','Ricardo Salazar','Luisa Ventas',310000,480000000,'Activa','Presencial'),
(20,'2026-03-18','Hogar','Protección Básica','Santander','Bucaramanga','Claudia Marcela Ortiz','Andrea Digital',52000,30000000,'Activa','Digital'),
(21,'2026-03-22','Vehicular','Responsabilidad Civil','Atlántico','Barranquilla','Sergio Armando Peña','Carlos Asesor',92000,42000000,'Activa','Telefónico'),
(22,'2026-04-01','Hogar','Protección Incendios','Bogotá','Bogotá','Alejandra Méndez','Pedro Comercial',82000,48000000,'Activa','Presencial'),
(23,'2026-04-05','Vehicular','Todo Riesgo Auto','Antioquia','Medellín','Diego Armando Vélez','Luisa Ventas',275000,135000000,'Activa','Digital'),
(24,'2026-04-10','Vida','Vida Individual','Bogotá','Bogotá','Mónica Andrea Suárez','Andrea Digital',200000,230000000,'Activa','Digital'),
(25,'2026-04-15','Hogar','Protección Total','Valle','Cali','Germán Eduardo Flórez','Carlos Asesor',125000,85000000,'Activa','Telefónico'),
(26,'2026-04-20','Vehicular','Todo Riesgo Moto','Bogotá','Soacha','Valentina Rojas','Pedro Comercial',62000,24000000,'Cancelada','Telefónico'),
(27,'2026-04-25','Hogar','Protección Básica','Atlántico','Barranquilla','Fabián Andrés Molina','Andrea Digital',48000,26000000,'Activa','Digital'),
(28,'2026-05-01','Vida','Vida Familiar','Antioquia','Medellín','Carolina Betancur','Luisa Ventas',330000,520000000,'Activa','Presencial'),
(29,'2026-05-03','Vehicular','Todo Riesgo Auto','Bogotá','Bogotá','Mauricio Leal','Carlos Asesor',280000,140000000,'Activa','Presencial'),
(30,'2026-05-05','Hogar','Protección Incendios','Valle','Cali','Esperanza Caicedo','Pedro Comercial',80000,46000000,'Activa','Telefónico');

-- ---------------------------------------------------------------------
-- 6. Data sintética: CLIENTES
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE CLIENTES (
  id NUMBER,
  nombre VARCHAR,
  cedula VARCHAR,
  segmento VARCHAR,
  ciudad VARCHAR,
  region VARCHAR,
  fecha_registro DATE,
  polizas_activas NUMBER,
  valor_total_primas NUMBER(12,2),
  canal_preferido VARCHAR
);

INSERT INTO CLIENTES VALUES
(1,'María Elena Rodríguez','52874369','Premium','Bogotá','Bogotá','2023-03-15',2,205000,'Presencial'),
(2,'Carlos Andrés Moreno','80123456','Estándar','Bogotá','Bogotá','2024-01-20',1,120000,'Telefónico'),
(3,'Ana Patricia Silva','31789234','Premium','Cali','Valle','2022-06-10',2,310000,'Digital'),
(4,'Diana Carolina Pérez','55432198','Estándar','Cali','Valle','2024-05-18',1,55000,'Telefónico'),
(5,'Jorge Parrado','19876543','Premium','Bogotá','Bogotá','2021-11-01',3,375000,'Digital'),
(6,'Sandra Milena López','43987612','Premium','Medellín','Antioquia','2023-08-22',1,180000,'Presencial'),
(7,'Roberto García','12345678','Básico','Soacha','Bogotá','2025-01-10',1,75000,'Telefónico'),
(8,'Camila Herrera','98765432','Estándar','Cali','Valle','2024-09-05',1,65000,'Digital'),
(9,'Luis Fernando Castro','11223344','Premium','Bogotá','Bogotá','2022-04-30',2,260000,'Presencial'),
(10,'Patricia Gómez','44556677','VIP','Medellín','Antioquia','2020-12-15',3,500000,'Presencial'),
(11,'Andrés Felipe Ruiz','77889900','Estándar','Bogotá','Bogotá','2024-07-12',1,270000,'Digital'),
(12,'Martha Cecilia Díaz','22334455','Básico','Bucaramanga','Santander','2025-06-20',0,0,'Telefónico'),
(13,'Óscar Iván Muñoz','66778899','Estándar','Palmira','Valle','2024-11-03',1,88000,'Telefónico'),
(14,'Gloria Estefanía Ríos','33445566','Estándar','Barranquilla','Atlántico','2025-01-28',1,78000,'Digital'),
(15,'Héctor Julio Vargas','99887766','Premium','Bogotá','Bogotá','2023-09-14',1,195000,'Presencial');

-- ---------------------------------------------------------------------
-- 7. Data sintética: RECLAMACIONES (siniestros)
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE RECLAMACIONES (
  id NUMBER,
  fecha DATE,
  cliente VARCHAR,
  tipo_poliza VARCHAR,
  tipo_siniestro VARCHAR,
  descripcion VARCHAR,
  monto_reclamado NUMBER(12,2),
  monto_aprobado NUMBER(12,2),
  estado VARCHAR,
  dias_resolucion NUMBER
);

INSERT INTO RECLAMACIONES VALUES
(1,'2025-12-10','Jorge Parrado','Vehicular','Choque','Colisión en intersección con motocicleta',8500000,7200000,'Aprobada',12),
(2,'2026-01-15','María Elena Rodríguez','Hogar','Incendio','Daño menor por cortocircuito en cocina',3200000,3200000,'Aprobada',8),
(3,'2026-02-20','Ana Patricia Silva','Vehicular','Robo','Robo de vehículo en parqueadero',45000000,40000000,'En proceso',NULL),
(4,'2026-03-05','Carlos Andrés Moreno','Hogar','Inundación','Daño por tubería rota en baño',1800000,1500000,'Aprobada',15),
(5,'2026-03-18','Sandra Milena López','Vida','Hospitalización','Cirugía programada rodilla',12000000,10000000,'Aprobada',5),
(6,'2026-04-02','Andrés Felipe Ruiz','Vehicular','Choque','Colisión lateral en autopista',15000000,12500000,'Aprobada',10),
(7,'2026-04-15','Roberto García','Hogar','Robo','Robo de electrodomésticos',4500000,0,'Rechazada',20),
(8,'2026-04-28','Patricia Gómez','Vida','Hospitalización','Emergencia cardíaca',25000000,25000000,'Aprobada',3),
(9,'2026-05-01','Diana Carolina Pérez','Hogar','Incendio','Daño eléctrico por tormenta',2100000,NULL,'En proceso',NULL),
(10,'2026-05-05','Jorge Parrado','Vehicular','Choque','Daño menor en parqueadero',3500000,NULL,'En proceso',NULL);

-- ---------------------------------------------------------------------
-- 8. Cortex Search Service unificado (contratos + transcripciones)
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE BASE_CONOCIMIENTO AS
SELECT file_name, 'Contrato' AS tipo_documento, content AS contenido FROM DOCS_PARSED
UNION ALL
SELECT file_name, 'Transcripción llamada', transcripcion FROM TRANSCRIPCIONES;

CREATE OR REPLACE CORTEX SEARCH SERVICE DOCS_SEARCH
  ON contenido
  ATTRIBUTES tipo_documento, file_name
  WAREHOUSE = HOL_WH
  TARGET_LAG = '1 hour'
  EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'
AS (SELECT contenido, tipo_documento, file_name FROM BASE_CONOCIMIENTO);

-- ---------------------------------------------------------------------
-- 9. Semantic View para Cortex Analyst (datos estructurados)
-- ---------------------------------------------------------------------
CALL SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML('HOL_AI_SUMMIT.PUBLIC.SV_SEGUROS', $$
name: seguros_inmobiliaria
description: "Vista semántica de una empresa de seguros e inmobiliaria. Incluye pólizas vendidas, clientes y reclamaciones por siniestros."

tables:
  - name: polizas
    description: "Pólizas de seguros vendidas (hogar, vehicular, vida)"
    base_table:
      database: HOL_AI_SUMMIT
      schema: PUBLIC
      table: POLIZAS
    dimensions:
      - name: tipo_poliza
        synonyms: ["tipo de seguro", "ramo", "línea de negocio"]
        description: "Tipo de póliza: Hogar, Vehicular o Vida"
        expr: tipo_poliza
        data_type: VARCHAR
        is_enum: true
        sample_values: ["Hogar", "Vehicular", "Vida"]
      - name: producto
        synonyms: ["plan", "nombre del producto"]
        description: "Nombre del producto de seguro específico"
        expr: producto
        data_type: VARCHAR
      - name: region
        synonyms: ["departamento", "zona"]
        description: "Región geográfica de Colombia"
        expr: region
        data_type: VARCHAR
        is_enum: true
        sample_values: ["Bogotá", "Antioquia", "Valle", "Santander", "Atlántico"]
      - name: ciudad
        description: "Ciudad donde se vendió la póliza"
        expr: ciudad
        data_type: VARCHAR
      - name: cliente
        synonyms: ["asegurado", "tomador"]
        description: "Nombre del cliente que adquirió la póliza"
        expr: cliente
        data_type: VARCHAR
      - name: vendedor
        synonyms: ["asesor", "agente"]
        description: "Nombre del vendedor o asesor comercial"
        expr: vendedor
        data_type: VARCHAR
      - name: estado
        description: "Estado de la póliza: Activa o Cancelada"
        expr: estado
        data_type: VARCHAR
        is_enum: true
        sample_values: ["Activa", "Cancelada"]
      - name: canal_venta
        synonyms: ["canal", "canal de adquisición"]
        description: "Canal por el cual se vendió: Telefónico, Digital, Presencial"
        expr: canal_venta
        data_type: VARCHAR
        is_enum: true
        sample_values: ["Telefónico", "Digital", "Presencial"]
    time_dimensions:
      - name: fecha
        synonyms: ["fecha de venta", "fecha emisión"]
        description: "Fecha en que se emitió la póliza"
        expr: fecha
        data_type: DATE
    facts:
      - name: prima_mensual
        synonyms: ["prima", "valor mensual", "cuota"]
        description: "Prima mensual que paga el cliente en pesos colombianos"
        expr: prima_mensual
        data_type: NUMBER
      - name: cobertura_total
        synonyms: ["valor asegurado", "cobertura", "suma asegurada"]
        description: "Monto total de cobertura de la póliza en pesos colombianos"
        expr: cobertura_total
        data_type: NUMBER
    metrics:
      - name: total_primas
        synonyms: ["ingresos por primas", "recaudo"]
        description: "Suma total de primas mensuales"
        expr: SUM(prima_mensual)
      - name: promedio_prima
        synonyms: ["prima promedio", "ticket promedio"]
        description: "Prima mensual promedio por póliza"
        expr: AVG(prima_mensual)
      - name: total_polizas
        synonyms: ["cantidad de pólizas", "pólizas vendidas"]
        description: "Número total de pólizas"
        expr: COUNT(*)
      - name: cobertura_promedio
        description: "Cobertura promedio por póliza"
        expr: AVG(cobertura_total)
    filters:
      - name: polizas_activas
        description: "Solo pólizas con estado Activa"
        expr: "estado = 'Activa'"
      - name: ultimo_trimestre
        description: "Pólizas emitidas en los últimos 3 meses"
        expr: "fecha >= DATEADD(month, -3, CURRENT_DATE())"

  - name: clientes
    description: "Clientes registrados en la aseguradora"
    base_table:
      database: HOL_AI_SUMMIT
      schema: PUBLIC
      table: CLIENTES
    dimensions:
      - name: nombre
        synonyms: ["nombre cliente", "asegurado"]
        description: "Nombre completo del cliente"
        expr: nombre
        data_type: VARCHAR
      - name: segmento
        synonyms: ["categoría cliente", "nivel"]
        description: "Segmento del cliente: Básico, Estándar, Premium, VIP"
        expr: segmento
        data_type: VARCHAR
        is_enum: true
        sample_values: ["Básico", "Estándar", "Premium", "VIP"]
      - name: ciudad_cliente
        synonyms: ["ciudad del cliente"]
        description: "Ciudad de residencia del cliente"
        expr: ciudad
        data_type: VARCHAR
      - name: region_cliente
        description: "Región del cliente"
        expr: region
        data_type: VARCHAR
      - name: canal_preferido
        description: "Canal preferido de contacto del cliente"
        expr: canal_preferido
        data_type: VARCHAR
        is_enum: true
        sample_values: ["Presencial", "Telefónico", "Digital"]
    time_dimensions:
      - name: fecha_registro
        description: "Fecha de registro del cliente"
        expr: fecha_registro
        data_type: DATE
    facts:
      - name: polizas_activas_cliente
        description: "Número de pólizas activas del cliente"
        expr: polizas_activas
        data_type: NUMBER
      - name: valor_total_primas_cliente
        description: "Valor total de primas mensuales del cliente"
        expr: valor_total_primas
        data_type: NUMBER
    metrics:
      - name: total_clientes
        description: "Número total de clientes"
        expr: COUNT(*)
      - name: ltv_promedio
        synonyms: ["valor promedio del cliente"]
        description: "Valor promedio de primas por cliente"
        expr: AVG(valor_total_primas)

  - name: reclamaciones
    description: "Reclamaciones y siniestros reportados por clientes"
    base_table:
      database: HOL_AI_SUMMIT
      schema: PUBLIC
      table: RECLAMACIONES
    dimensions:
      - name: cliente_reclamacion
        synonyms: ["reclamante"]
        description: "Cliente que presenta la reclamación"
        expr: cliente
        data_type: VARCHAR
      - name: tipo_poliza_reclamacion
        description: "Tipo de póliza asociada a la reclamación"
        expr: tipo_poliza
        data_type: VARCHAR
      - name: tipo_siniestro
        synonyms: ["tipo de evento", "causa"]
        description: "Tipo de siniestro: Choque, Incendio, Robo, Inundación, Hospitalización"
        expr: tipo_siniestro
        data_type: VARCHAR
        is_enum: true
        sample_values: ["Choque", "Incendio", "Robo", "Inundación", "Hospitalización"]
      - name: estado_reclamacion
        synonyms: ["estado del caso"]
        description: "Estado: Aprobada, Rechazada, En proceso"
        expr: estado
        data_type: VARCHAR
        is_enum: true
        sample_values: ["Aprobada", "Rechazada", "En proceso"]
    time_dimensions:
      - name: fecha_reclamacion
        synonyms: ["fecha del siniestro"]
        description: "Fecha en que se reportó la reclamación"
        expr: fecha
        data_type: DATE
    facts:
      - name: monto_reclamado
        synonyms: ["valor reclamado"]
        description: "Monto solicitado por el cliente"
        expr: monto_reclamado
        data_type: NUMBER
      - name: monto_aprobado
        synonyms: ["valor aprobado", "indemnización"]
        description: "Monto aprobado para pago"
        expr: monto_aprobado
        data_type: NUMBER
      - name: dias_resolucion
        synonyms: ["tiempo de respuesta"]
        description: "Días que tomó resolver la reclamación"
        expr: dias_resolucion
        data_type: NUMBER
    metrics:
      - name: total_reclamaciones
        description: "Número total de reclamaciones"
        expr: COUNT(*)
      - name: monto_total_aprobado
        synonyms: ["total indemnizado"]
        description: "Suma total de montos aprobados"
        expr: SUM(monto_aprobado)
      - name: promedio_dias_resolucion
        synonyms: ["tiempo promedio de resolución"]
        description: "Promedio de días para resolver reclamaciones"
        expr: AVG(dias_resolucion)
      - name: tasa_aprobacion
        synonyms: ["porcentaje de aprobación"]
        description: "Porcentaje de reclamaciones aprobadas"
        expr: "COUNT(CASE WHEN estado = 'Aprobada' THEN 1 END) * 100.0 / COUNT(*)"

relationships:
  - name: polizas_a_clientes
    left_table: polizas
    right_table: clientes
    relationship_columns:
      - left_column: cliente
        right_column: nombre
  - name: reclamaciones_a_clientes
    left_table: reclamaciones
    right_table: clientes
    relationship_columns:
      - left_column: cliente
        right_column: nombre

verified_queries:
  - name: ventas_por_region
    question: "¿Cuál es el total de primas por región?"
    use_as_onboarding_question: true
    sql: |
      SELECT region, SUM(prima_mensual) AS total_primas, COUNT(*) AS num_polizas
      FROM HOL_AI_SUMMIT.PUBLIC.POLIZAS
      WHERE estado = 'Activa'
      GROUP BY region
      ORDER BY total_primas DESC
  - name: top_vendedores
    question: "¿Quiénes son los mejores vendedores?"
    use_as_onboarding_question: true
    sql: |
      SELECT vendedor, COUNT(*) AS polizas_vendidas, SUM(prima_mensual) AS total_primas
      FROM HOL_AI_SUMMIT.PUBLIC.POLIZAS
      WHERE estado = 'Activa'
      GROUP BY vendedor
      ORDER BY total_primas DESC
  - name: reclamaciones_pendientes
    question: "¿Cuántas reclamaciones están en proceso?"
    use_as_onboarding_question: true
    sql: |
      SELECT tipo_siniestro, cliente, monto_reclamado, fecha
      FROM HOL_AI_SUMMIT.PUBLIC.RECLAMACIONES
      WHERE estado = 'En proceso'
      ORDER BY monto_reclamado DESC
  - name: clientes_premium
    question: "¿Cuáles son los clientes premium y VIP?"
    sql: |
      SELECT nombre, segmento, ciudad, polizas_activas, valor_total_primas
      FROM HOL_AI_SUMMIT.PUBLIC.CLIENTES
      WHERE segmento IN ('Premium', 'VIP')
      ORDER BY valor_total_primas DESC
$$);

-- ---------------------------------------------------------------------
-- 10. Agente con Cortex Analyst + Cortex Search + Chart
--     Este es el agente que se usa en Snowflake Intelligence
-- ---------------------------------------------------------------------
CREATE OR REPLACE AGENT HOL_AI_SUMMIT.PUBLIC.AGENTE_HOL
  WITH PROFILE='{"display_name": "Agente Seguros 360"}'
  COMMENT = 'Agente inteligente que analiza datos de pólizas, busca en contratos y genera gráficos'
  FROM SPECIFICATION $$
{
  "models": {"orchestration": "claude-4-sonnet"},
  "instructions": {
    "response": "Responde siempre en español, de forma clara y profesional. Cuando cites datos numéricos, indica la fuente. Usa gráficos cuando sea posible para visualizar tendencias.",
    "orchestration": "Para preguntas sobre ventas, pólizas, clientes, reclamaciones o métricas de negocio, usa la herramienta analizar_datos (Cortex Analyst). Para preguntas sobre contratos, cláusulas legales, transcripciones de llamadas o contenido de documentos, usa buscar_documentos (Cortex Search). Siempre que puedas responder visualmente con un gráfico, genera uno.",
    "system": "Eres un asistente inteligente de una empresa de seguros e inmobiliaria en Colombia. Tienes acceso a datos de pólizas vendidas, información de clientes, reclamaciones por siniestros, contratos de arrendamiento y transcripciones de llamadas de servicio al cliente."
  },
  "tools": [
    {
      "tool_spec": {
        "type": "cortex_analyst_text_to_sql",
        "name": "analizar_datos",
        "description": "Analiza datos estructurados de pólizas de seguros, clientes y reclamaciones. Usa esta herramienta para preguntas sobre ventas, ingresos por primas, rendimiento de vendedores, siniestros, métricas de negocio y segmentación de clientes."
      }
    },
    {
      "tool_spec": {
        "type": "cortex_search",
        "name": "buscar_documentos",
        "description": "Busca información en contratos de arrendamiento y transcripciones de llamadas de servicio al cliente. Usa esta herramienta para preguntas sobre cláusulas contractuales, términos legales, quejas de clientes, ofertas realizadas por teléfono y detalles de conversaciones."
      }
    },
    {
      "tool_spec": {
        "type": "data_to_chart",
        "name": "data_to_chart",
        "description": "Genera visualizaciones y gráficos a partir de datos. Usa siempre que puedas responder visualmente."
      }
    }
  ],
  "tool_resources": {
    "analizar_datos": {
      "semantic_view": "HOL_AI_SUMMIT.PUBLIC.SV_SEGUROS"
    },
    "buscar_documentos": {
      "name": "HOL_AI_SUMMIT.PUBLIC.DOCS_SEARCH",
      "max_results": 5,
      "id_column": "file_name",
      "title_column": "tipo_documento"
    }
  },
  "sample_questions": [
    {"question": "¿Cuál es el total de primas vendidas por región?"},
    {"question": "¿Qué dice el contrato sobre las obligaciones del arrendatario?"},
    {"question": "¿Cuál fue el sentimiento del cliente en la última llamada?"},
    {"question": "Muéstrame un gráfico de reclamaciones por tipo de siniestro"},
    {"question": "¿Quién es el mejor vendedor del trimestre?"}
  ]
}
$$;

-- ---------------------------------------------------------------------
-- 11. Crear el notebook desde el repo Git
-- ---------------------------------------------------------------------
CREATE OR REPLACE NOTEBOOK NB_HOL_AI_SUMMIT
  FROM '@hol_repo/branches/main/AI_SUMMIT/'
  MAIN_FILE = 'notebook_ai_summit.ipynb'
  QUERY_WAREHOUSE = HOL_WH;

ALTER NOTEBOOK NB_HOL_AI_SUMMIT ADD LIVE VERSION FROM LAST;

-- ---------------------------------------------------------------------
-- 12. Resumen final
-- ---------------------------------------------------------------------
SELECT 'Setup completo.' AS status,
       'Abre Snowsight > Projects > Notebooks > NB_HOL_AI_SUMMIT' AS siguiente_paso,
       'Prueba el agente en AI & ML > Snowflake Intelligence > Agente Seguros 360' AS bonus,
       'Cortex Analyst listo: Semantic View SV_SEGUROS creada' AS analyst,
       'Cortex Search: contratos + transcripciones indexados' AS search;
