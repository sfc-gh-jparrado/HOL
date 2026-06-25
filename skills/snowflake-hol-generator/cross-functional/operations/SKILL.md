# Sub-Skill: Operations Analytics

## Metadata
- **Parent**: snowflake-hol-generator
- **Name**: cross-functional/operations
- **Área**: Operaciones / KPIs Operativos
- **Aplicable a**: Todas las industrias
- **Duración**: ~15 minutos adicionales

---

## 🎯 Contexto de Negocio

Este módulo transversal implementa monitoreo operativo:
- KPIs en tiempo real
- Sistema de alertas
- SLAs y cumplimiento
- Dashboards de control
- Detección de anomalías

---

## Datos Sintéticos

### Tabla: KPI_DEFINICIONES
```sql
CREATE OR REPLACE TABLE RAW.KPI_DEFINICIONES (
    ID_KPI VARCHAR(10) PRIMARY KEY,
    NOMBRE_KPI VARCHAR(100),
    DESCRIPCION VARCHAR(500),
    AREA VARCHAR(50),
    FORMULA VARCHAR(300),
    UNIDAD VARCHAR(20),
    META NUMBER(12,2),
    UMBRAL_ALERTA NUMBER(12,2),
    UMBRAL_CRITICO NUMBER(12,2),
    DIRECCION VARCHAR(10), -- MAYOR_MEJOR, MENOR_MEJOR
    FRECUENCIA_CALCULO VARCHAR(20) -- DIARIO, HORARIO, TIEMPO_REAL
);

INSERT INTO RAW.KPI_DEFINICIONES VALUES
('KPI001', 'Tasa de Cumplimiento de Entregas', 'Porcentaje de entregas realizadas a tiempo', 'Logística', '(Entregas_A_Tiempo / Total_Entregas) * 100', '%', 95.00, 90.00, 85.00, 'MAYOR_MEJOR', 'DIARIO'),
('KPI002', 'Tiempo Promedio de Respuesta', 'Tiempo promedio para primera respuesta al cliente', 'Soporte', 'AVG(Tiempo_Primera_Respuesta)', 'minutos', 5.00, 10.00, 15.00, 'MENOR_MEJOR', 'HORARIO'),
('KPI003', 'Disponibilidad de Sistema', 'Uptime del sistema principal', 'TI', '(Tiempo_Operativo / Tiempo_Total) * 100', '%', 99.90, 99.50, 99.00, 'MAYOR_MEJOR', 'TIEMPO_REAL'),
('KPI004', 'Tasa de Conversión', 'Porcentaje de leads que se convierten en clientes', 'Ventas', '(Clientes_Nuevos / Leads_Totales) * 100', '%', 15.00, 10.00, 5.00, 'MAYOR_MEJOR', 'DIARIO'),
('KPI005', 'Índice de Satisfacción (CSAT)', 'Satisfacción promedio del cliente', 'Experiencia', 'AVG(CSAT_Score)', 'puntos', 4.50, 4.00, 3.50, 'MAYOR_MEJOR', 'DIARIO'),
('KPI006', 'Eficiencia de Producción', 'Unidades producidas vs capacidad', 'Producción', '(Unidades_Producidas / Capacidad_Instalada) * 100', '%', 85.00, 75.00, 65.00, 'MAYOR_MEJOR', 'HORARIO'),
('KPI007', 'Tasa de Error', 'Porcentaje de transacciones con error', 'TI', '(Transacciones_Error / Total_Transacciones) * 100', '%', 0.10, 0.50, 1.00, 'MENOR_MEJOR', 'TIEMPO_REAL'),
('KPI008', 'Costo por Transacción', 'Costo promedio por transacción procesada', 'Finanzas', 'Costo_Total / Total_Transacciones', 'USD', 0.50, 0.75, 1.00, 'MENOR_MEJOR', 'DIARIO');
```

### Tabla: KPI_MEDICIONES
```sql
CREATE OR REPLACE TABLE RAW.KPI_MEDICIONES (
    ID_MEDICION VARCHAR(20) PRIMARY KEY,
    ID_KPI VARCHAR(10),
    FECHA_HORA TIMESTAMP,
    VALOR NUMBER(12,4),
    DIMENSION_1 VARCHAR(50), -- Ej: Región, Canal, Producto
    DIMENSION_2 VARCHAR(50), -- Ej: SubRegión, Categoría
    FUENTE VARCHAR(50),
    FOREIGN KEY (ID_KPI) REFERENCES RAW.KPI_DEFINICIONES(ID_KPI)
);

-- Generar mediciones de KPIs
INSERT INTO RAW.KPI_MEDICIONES
SELECT 
    'MED' || TO_CHAR(CURRENT_DATE(), 'YYYYMMDD') || LPAD(SEQ4()::VARCHAR, 8, '0') AS ID_MEDICION,
    'KPI' || LPAD(UNIFORM(1, 8, RANDOM())::VARCHAR, 3, '0') AS ID_KPI,
    DATEADD('minute', -UNIFORM(1, 43200, RANDOM()), CURRENT_TIMESTAMP()) AS FECHA_HORA,
    ROUND(UNIFORM(0, 100, RANDOM())::FLOAT + RANDOM() * 5, 4) AS VALOR,
    ARRAY_CONSTRUCT('Norte', 'Centro', 'Sur', 'Occidente', 'Global')[UNIFORM(0, 4, RANDOM())]::VARCHAR AS DIMENSION_1,
    ARRAY_CONSTRUCT('Canal A', 'Canal B', 'Canal C', NULL)[UNIFORM(0, 3, RANDOM())]::VARCHAR AS DIMENSION_2,
    'Sistema Automático' AS FUENTE
FROM TABLE(GENERATOR(ROWCOUNT => 100000));
```

### Tabla: ALERTAS_OPERATIVAS
```sql
CREATE OR REPLACE TABLE RAW.ALERTAS_OPERATIVAS (
    ID_ALERTA VARCHAR(15) PRIMARY KEY,
    ID_KPI VARCHAR(10),
    FECHA_GENERACION TIMESTAMP,
    VALOR_DETECTADO NUMBER(12,4),
    UMBRAL_VIOLADO VARCHAR(20), -- ALERTA, CRITICO
    DIMENSION_AFECTADA VARCHAR(100),
    DESCRIPCION VARCHAR(500),
    ESTATUS VARCHAR(20), -- ABIERTA, RECONOCIDA, EN_PROCESO, CERRADA
    RESPONSABLE VARCHAR(100),
    FECHA_RESOLUCION TIMESTAMP,
    ACCIONES_TOMADAS VARCHAR(500),
    FOREIGN KEY (ID_KPI) REFERENCES RAW.KPI_DEFINICIONES(ID_KPI)
);

-- Generar alertas
INSERT INTO RAW.ALERTAS_OPERATIVAS
SELECT 
    'ALR' || LPAD(SEQ4()::VARCHAR, 8, '0') AS ID_ALERTA,
    'KPI' || LPAD(UNIFORM(1, 8, RANDOM())::VARCHAR, 3, '0') AS ID_KPI,
    DATEADD('minute', -UNIFORM(1, 10080, RANDOM()), CURRENT_TIMESTAMP()) AS FECHA_GENERACION,
    ROUND(UNIFORM(0, 100, RANDOM())::FLOAT, 4) AS VALOR_DETECTADO,
    ARRAY_CONSTRUCT('ALERTA', 'ALERTA', 'CRITICO')[UNIFORM(0, 2, RANDOM())]::VARCHAR AS UMBRAL_VIOLADO,
    ARRAY_CONSTRUCT('Norte', 'Centro', 'Sur', 'Occidente', 'Global')[UNIFORM(0, 4, RANDOM())]::VARCHAR AS DIMENSION_AFECTADA,
    'KPI fuera de umbral esperado' AS DESCRIPCION,
    ARRAY_CONSTRUCT('ABIERTA', 'RECONOCIDA', 'EN_PROCESO', 'CERRADA', 'CERRADA')[UNIFORM(0, 4, RANDOM())]::VARCHAR AS ESTATUS,
    'Operador ' || UNIFORM(1, 10, RANDOM()) AS RESPONSABLE,
    CASE WHEN UNIFORM(1, 10, RANDOM()) >= 6 
         THEN DATEADD('minute', -UNIFORM(1, 5000, RANDOM()), CURRENT_TIMESTAMP()) 
         ELSE NULL END AS FECHA_RESOLUCION,
    CASE WHEN UNIFORM(1, 10, RANDOM()) >= 6 
         THEN ARRAY_CONSTRUCT('Escalado a equipo técnico', 'Reinicio de servicio', 'Ajuste de parámetros', 'Contacto con proveedor')[UNIFORM(0, 3, RANDOM())]::VARCHAR 
         ELSE NULL END AS ACCIONES_TOMADAS
FROM TABLE(GENERATOR(ROWCOUNT => 1000));
```

### Tabla: SLAs
```sql
CREATE OR REPLACE TABLE RAW.SLAS (
    ID_SLA VARCHAR(10) PRIMARY KEY,
    NOMBRE_SLA VARCHAR(100),
    DESCRIPCION VARCHAR(300),
    CLIENTE_SERVICIO VARCHAR(100),
    METRICA VARCHAR(100),
    OBJETIVO NUMBER(12,2),
    UNIDAD VARCHAR(20),
    PENALIZACION_PCT NUMBER(5,2),
    VIGENCIA_INICIO DATE,
    VIGENCIA_FIN DATE
);

INSERT INTO RAW.SLAS VALUES
('SLA001', 'Disponibilidad Core Banking', 'Uptime del sistema de core bancario', 'Interno', 'Disponibilidad', 99.95, '%', 5.00, '2024-01-01', '2024-12-31'),
('SLA002', 'Tiempo de Respuesta API', 'Latencia máxima de APIs públicas', 'Clientes API', 'P95 Latency', 200, 'ms', 2.00, '2024-01-01', '2024-12-31'),
('SLA003', 'Resolución de Tickets P1', 'Tiempo máximo para resolver tickets críticos', 'Interno', 'Tiempo Resolución', 4, 'horas', 10.00, '2024-01-01', '2024-12-31'),
('SLA004', 'Procesamiento de Transacciones', 'Transacciones procesadas en tiempo', 'Clientes', 'On-Time Processing', 99.90, '%', 3.00, '2024-01-01', '2024-12-31');
```

### Tabla: SLA_MEDICIONES
```sql
CREATE OR REPLACE TABLE RAW.SLA_MEDICIONES (
    ID_MEDICION VARCHAR(20) PRIMARY KEY,
    ID_SLA VARCHAR(10),
    PERIODO_INICIO TIMESTAMP,
    PERIODO_FIN TIMESTAMP,
    VALOR_LOGRADO NUMBER(12,4),
    CUMPLE BOOLEAN,
    PENALIZACION_APLICADA NUMBER(12,2),
    FOREIGN KEY (ID_SLA) REFERENCES RAW.SLAS(ID_SLA)
);

-- Generar mediciones de SLA
INSERT INTO RAW.SLA_MEDICIONES
SELECT 
    'SLAM' || LPAD(SEQ4()::VARCHAR, 8, '0') AS ID_MEDICION,
    'SLA' || LPAD(UNIFORM(1, 4, RANDOM())::VARCHAR, 3, '0') AS ID_SLA,
    DATEADD('hour', -UNIFORM(1, 720, RANDOM()), CURRENT_TIMESTAMP()) AS PERIODO_INICIO,
    DATEADD('hour', -UNIFORM(0, 719, RANDOM()), CURRENT_TIMESTAMP()) AS PERIODO_FIN,
    ROUND(UNIFORM(95, 100, RANDOM())::FLOAT + RANDOM(), 4) AS VALOR_LOGRADO,
    UNIFORM(1, 10, RANDOM()) <= 9 AS CUMPLE,
    CASE WHEN UNIFORM(1, 10, RANDOM()) > 9 THEN ROUND(UNIFORM(100, 5000, RANDOM())::FLOAT, 2) ELSE 0 END AS PENALIZACION_APLICADA
FROM TABLE(GENERATOR(ROWCOUNT => 5000));
```

---

## Vistas Analíticas

```sql
-- Vista de estado actual de KPIs
CREATE OR REPLACE VIEW ANALYTICS.V_KPI_ESTADO_ACTUAL AS
WITH ULTIMO_VALOR AS (
    SELECT 
        m.ID_KPI,
        m.VALOR,
        m.FECHA_HORA,
        m.DIMENSION_1,
        ROW_NUMBER() OVER (PARTITION BY m.ID_KPI ORDER BY m.FECHA_HORA DESC) AS RN
    FROM RAW.KPI_MEDICIONES m
)
SELECT 
    k.ID_KPI,
    k.NOMBRE_KPI,
    k.AREA,
    k.UNIDAD,
    k.META,
    k.UMBRAL_ALERTA,
    k.UMBRAL_CRITICO,
    k.DIRECCION,
    uv.VALOR AS VALOR_ACTUAL,
    uv.FECHA_HORA AS ULTIMA_MEDICION,
    
    -- Cálculo de estado
    CASE 
        WHEN k.DIRECCION = 'MAYOR_MEJOR' THEN
            CASE 
                WHEN uv.VALOR >= k.META THEN '🟢 En Meta'
                WHEN uv.VALOR >= k.UMBRAL_ALERTA THEN '🟡 Alerta'
                ELSE '🔴 Crítico'
            END
        ELSE -- MENOR_MEJOR
            CASE 
                WHEN uv.VALOR <= k.META THEN '🟢 En Meta'
                WHEN uv.VALOR <= k.UMBRAL_ALERTA THEN '🟡 Alerta'
                ELSE '🔴 Crítico'
            END
    END AS ESTADO,
    
    -- Variación vs meta
    ROUND((uv.VALOR - k.META) / NULLIF(k.META, 0) * 100, 2) AS VARIACION_VS_META_PCT

FROM RAW.KPI_DEFINICIONES k
JOIN ULTIMO_VALOR uv ON k.ID_KPI = uv.ID_KPI AND uv.RN = 1;

-- Vista de tendencia de KPIs
CREATE OR REPLACE VIEW ANALYTICS.V_KPI_TENDENCIA AS
SELECT 
    k.NOMBRE_KPI,
    k.AREA,
    DATE_TRUNC('HOUR', m.FECHA_HORA) AS HORA,
    ROUND(AVG(m.VALOR), 4) AS VALOR_PROMEDIO,
    ROUND(MIN(m.VALOR), 4) AS VALOR_MIN,
    ROUND(MAX(m.VALOR), 4) AS VALOR_MAX,
    k.META,
    k.UMBRAL_ALERTA
FROM RAW.KPI_MEDICIONES m
JOIN RAW.KPI_DEFINICIONES k ON m.ID_KPI = k.ID_KPI
WHERE m.FECHA_HORA >= DATEADD('day', -7, CURRENT_TIMESTAMP())
GROUP BY k.NOMBRE_KPI, k.AREA, DATE_TRUNC('HOUR', m.FECHA_HORA), k.META, k.UMBRAL_ALERTA
ORDER BY k.NOMBRE_KPI, HORA;

-- Vista de alertas activas
CREATE OR REPLACE VIEW ANALYTICS.V_ALERTAS_ACTIVAS AS
SELECT 
    a.ID_ALERTA,
    k.NOMBRE_KPI,
    k.AREA,
    a.FECHA_GENERACION,
    a.VALOR_DETECTADO,
    k.META,
    a.UMBRAL_VIOLADO,
    a.DIMENSION_AFECTADA,
    a.ESTATUS,
    a.RESPONSABLE,
    DATEDIFF('minute', a.FECHA_GENERACION, CURRENT_TIMESTAMP()) AS MINUTOS_ABIERTA,
    
    -- Prioridad calculada
    CASE 
        WHEN a.UMBRAL_VIOLADO = 'CRITICO' AND a.ESTATUS = 'ABIERTA' THEN '🚨 URGENTE'
        WHEN a.UMBRAL_VIOLADO = 'CRITICO' THEN '🔴 Alta'
        WHEN a.ESTATUS = 'ABIERTA' THEN '🟡 Media'
        ELSE '🟢 Baja'
    END AS PRIORIDAD

FROM RAW.ALERTAS_OPERATIVAS a
JOIN RAW.KPI_DEFINICIONES k ON a.ID_KPI = k.ID_KPI
WHERE a.ESTATUS IN ('ABIERTA', 'RECONOCIDA', 'EN_PROCESO')
ORDER BY 
    CASE WHEN a.UMBRAL_VIOLADO = 'CRITICO' THEN 0 ELSE 1 END,
    a.FECHA_GENERACION DESC;

-- Vista de cumplimiento de SLAs
CREATE OR REPLACE VIEW ANALYTICS.V_CUMPLIMIENTO_SLAS AS
SELECT 
    s.NOMBRE_SLA,
    s.CLIENTE_SERVICIO,
    s.METRICA,
    s.OBJETIVO,
    s.UNIDAD,
    COUNT(m.ID_MEDICION) AS MEDICIONES_PERIODO,
    COUNT(CASE WHEN m.CUMPLE THEN 1 END) AS MEDICIONES_CUMPLIDAS,
    ROUND(COUNT(CASE WHEN m.CUMPLE THEN 1 END)::FLOAT / NULLIF(COUNT(m.ID_MEDICION), 0) * 100, 2) AS PCT_CUMPLIMIENTO,
    ROUND(AVG(m.VALOR_LOGRADO), 4) AS VALOR_PROMEDIO,
    SUM(m.PENALIZACION_APLICADA) AS PENALIZACION_ACUMULADA,
    
    -- Estado
    CASE 
        WHEN COUNT(CASE WHEN m.CUMPLE THEN 1 END)::FLOAT / NULLIF(COUNT(m.ID_MEDICION), 0) >= 0.99 THEN '🟢 Excelente'
        WHEN COUNT(CASE WHEN m.CUMPLE THEN 1 END)::FLOAT / NULLIF(COUNT(m.ID_MEDICION), 0) >= 0.95 THEN '🟡 Aceptable'
        ELSE '🔴 Incumplimiento'
    END AS ESTADO_SLA

FROM RAW.SLAS s
LEFT JOIN RAW.SLA_MEDICIONES m ON s.ID_SLA = m.ID_SLA
    AND m.PERIODO_INICIO >= DATEADD('month', -1, CURRENT_TIMESTAMP())
GROUP BY s.NOMBRE_SLA, s.CLIENTE_SERVICIO, s.METRICA, s.OBJETIVO, s.UNIDAD;

-- Vista resumen ejecutivo
CREATE OR REPLACE VIEW ANALYTICS.V_RESUMEN_OPERATIVO AS
SELECT 
    'KPIs en Meta' AS METRICA,
    (SELECT COUNT(*) FROM ANALYTICS.V_KPI_ESTADO_ACTUAL WHERE ESTADO = '🟢 En Meta')::VARCHAR AS VALOR,
    (SELECT COUNT(*) FROM ANALYTICS.V_KPI_ESTADO_ACTUAL)::VARCHAR AS TOTAL
UNION ALL
SELECT 
    'Alertas Abiertas',
    (SELECT COUNT(*) FROM ANALYTICS.V_ALERTAS_ACTIVAS)::VARCHAR,
    NULL
UNION ALL
SELECT 
    'Alertas Críticas',
    (SELECT COUNT(*) FROM ANALYTICS.V_ALERTAS_ACTIVAS WHERE PRIORIDAD = '🚨 URGENTE')::VARCHAR,
    NULL
UNION ALL
SELECT 
    'SLAs Cumpliendo',
    (SELECT COUNT(*) FROM ANALYTICS.V_CUMPLIMIENTO_SLAS WHERE ESTADO_SLA != '🔴 Incumplimiento')::VARCHAR,
    (SELECT COUNT(*) FROM ANALYTICS.V_CUMPLIMIENTO_SLAS)::VARCHAR;
```

---

## Preguntas Sugeridas para el Agente

- "¿Cuál es el estado actual de todos los KPIs?"
- "¿Cuántas alertas críticas hay abiertas?"
- "Tendencia del KPI de disponibilidad últimas 24 horas"
- "¿Qué SLAs están en riesgo de incumplimiento?"
- "Top 5 KPIs con peor desempeño"
- "Alertas sin resolver por más de 2 horas"
- "Resumen ejecutivo de operaciones"
- "KPIs del área de TI"
