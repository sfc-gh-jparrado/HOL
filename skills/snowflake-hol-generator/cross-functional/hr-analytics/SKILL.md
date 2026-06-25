# Sub-Skill: HR Analytics

## Metadata
- **Parent**: snowflake-hol-generator
- **Name**: cross-functional/hr-analytics
- **Área**: Recursos Humanos / People Analytics
- **Aplicable a**: Todas las industrias
- **Duración**: ~20 minutos adicionales

---

## 🎯 Contexto de Negocio

Este módulo transversal agrega capacidades de análisis de RRHH:
- Análisis de desempeño de empleados
- Rotación y retención
- Análisis de compensaciones
- Diversidad e inclusión
- Evaluación de candidatos con IA

---

## Datos Sintéticos

### Tabla: DEPARTAMENTOS
```sql
CREATE OR REPLACE TABLE RAW.DEPARTAMENTOS (
    ID_DEPARTAMENTO VARCHAR(10) PRIMARY KEY,
    NOMBRE_DEPARTAMENTO VARCHAR(100),
    DIVISION VARCHAR(50),
    RESPONSABLE VARCHAR(100),
    HEADCOUNT_APROBADO NUMBER,
    PRESUPUESTO_NOMINA NUMBER(15,2)
);

INSERT INTO RAW.DEPARTAMENTOS VALUES
('DEP001', 'Ventas', 'Comercial', 'Director Comercial', 50, 5000000),
('DEP002', 'Marketing', 'Comercial', 'Director Marketing', 15, 1800000),
('DEP003', 'Operaciones', 'Operaciones', 'Director Operaciones', 100, 7500000),
('DEP004', 'Tecnología', 'IT', 'CTO', 30, 4500000),
('DEP005', 'Recursos Humanos', 'Administración', 'Director RRHH', 10, 1200000),
('DEP006', 'Finanzas', 'Administración', 'CFO', 12, 1500000),
('DEP007', 'Legal', 'Administración', 'Director Legal', 5, 800000),
('DEP008', 'Servicio al Cliente', 'Comercial', 'Director Servicio', 25, 2200000);
```

### Tabla: PUESTOS
```sql
CREATE OR REPLACE TABLE RAW.PUESTOS (
    ID_PUESTO VARCHAR(10) PRIMARY KEY,
    NOMBRE_PUESTO VARCHAR(100),
    ID_DEPARTAMENTO VARCHAR(10),
    NIVEL VARCHAR(20), -- JUNIOR, MID, SENIOR, LEAD, MANAGER, DIRECTOR
    BANDA_SALARIAL_MIN NUMBER(10,2),
    BANDA_SALARIAL_MAX NUMBER(10,2),
    COMPETENCIAS_REQUERIDAS VARCHAR(500),
    FOREIGN KEY (ID_DEPARTAMENTO) REFERENCES RAW.DEPARTAMENTOS(ID_DEPARTAMENTO)
);

INSERT INTO RAW.PUESTOS VALUES
('PUE001', 'Representante de Ventas Jr', 'DEP001', 'JUNIOR', 15000, 22000, 'Comunicación, Negociación, CRM'),
('PUE002', 'Representante de Ventas Sr', 'DEP001', 'SENIOR', 25000, 35000, 'Comunicación, Negociación, Liderazgo'),
('PUE003', 'Gerente de Ventas', 'DEP001', 'MANAGER', 40000, 60000, 'Liderazgo, Estrategia, KPIs'),
('PUE004', 'Analista de Marketing', 'DEP002', 'MID', 20000, 30000, 'Analytics, Digital, Creatividad'),
('PUE005', 'Desarrollador Backend', 'DEP004', 'MID', 35000, 50000, 'Python, SQL, APIs, Cloud'),
('PUE006', 'Desarrollador Frontend', 'DEP004', 'MID', 30000, 45000, 'JavaScript, React, CSS'),
('PUE007', 'Data Engineer', 'DEP004', 'SENIOR', 45000, 70000, 'Snowflake, Python, ETL, dbt'),
('PUE008', 'Analista de RRHH', 'DEP005', 'MID', 18000, 28000, 'Excel, Comunicación, Normativas'),
('PUE009', 'Operador de Producción', 'DEP003', 'JUNIOR', 10000, 15000, 'Manufactura, Seguridad'),
('PUE010', 'Supervisor de Producción', 'DEP003', 'LEAD', 22000, 32000, 'Liderazgo, Lean, Calidad');
```

### Tabla: EMPLEADOS
```sql
CREATE OR REPLACE TABLE RAW.EMPLEADOS (
    ID_EMPLEADO VARCHAR(10) PRIMARY KEY,
    NOMBRE VARCHAR(100),
    EMAIL VARCHAR(100),
    ID_PUESTO VARCHAR(10),
    FECHA_INGRESO DATE,
    FECHA_NACIMIENTO DATE,
    GENERO VARCHAR(20),
    ESTADO_CIVIL VARCHAR(20),
    NIVEL_EDUCATIVO VARCHAR(30),
    SALARIO_ACTUAL NUMBER(10,2),
    MODALIDAD_TRABAJO VARCHAR(20), -- PRESENCIAL, REMOTO, HIBRIDO
    ESTADO VARCHAR(20), -- ACTIVO, BAJA, INCAPACIDAD
    FECHA_BAJA DATE,
    MOTIVO_BAJA VARCHAR(100),
    FOREIGN KEY (ID_PUESTO) REFERENCES RAW.PUESTOS(ID_PUESTO)
);

-- Generar empleados
INSERT INTO RAW.EMPLEADOS
SELECT 
    'EMP' || LPAD(SEQ4()::VARCHAR, 4, '0') AS ID_EMPLEADO,
    ARRAY_CONSTRUCT('Juan', 'María', 'Carlos', 'Ana', 'Pedro', 'Laura', 'Diego', 'Sofía', 'Roberto', 'Elena')[UNIFORM(0, 9, RANDOM())]::VARCHAR || ' ' ||
    ARRAY_CONSTRUCT('García', 'López', 'Martínez', 'Rodríguez', 'Hernández', 'González', 'Sánchez', 'Ramírez', 'Torres', 'Flores')[UNIFORM(0, 9, RANDOM())]::VARCHAR AS NOMBRE,
    'empleado' || SEQ4() || '@[cliente].com' AS EMAIL,
    'PUE' || LPAD(UNIFORM(1, 10, RANDOM())::VARCHAR, 3, '0') AS ID_PUESTO,
    DATEADD('day', -UNIFORM(30, 2500, RANDOM()), CURRENT_DATE()) AS FECHA_INGRESO,
    DATEADD('year', -UNIFORM(22, 55, RANDOM()), CURRENT_DATE()) AS FECHA_NACIMIENTO,
    ARRAY_CONSTRUCT('Masculino', 'Femenino', 'No binario', 'Prefiere no decir')[UNIFORM(0, 3, RANDOM())]::VARCHAR AS GENERO,
    ARRAY_CONSTRUCT('Soltero/a', 'Casado/a', 'Unión libre', 'Divorciado/a')[UNIFORM(0, 3, RANDOM())]::VARCHAR AS ESTADO_CIVIL,
    ARRAY_CONSTRUCT('Preparatoria', 'Técnico', 'Licenciatura', 'Maestría', 'Doctorado')[UNIFORM(0, 4, RANDOM())]::VARCHAR AS NIVEL_EDUCATIVO,
    ROUND(UNIFORM(12000, 65000, RANDOM())::FLOAT, 2) AS SALARIO_ACTUAL,
    ARRAY_CONSTRUCT('PRESENCIAL', 'PRESENCIAL', 'REMOTO', 'HIBRIDO', 'HIBRIDO')[UNIFORM(0, 4, RANDOM())]::VARCHAR AS MODALIDAD_TRABAJO,
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 85 THEN 'ACTIVO' ELSE 'BAJA' END AS ESTADO,
    CASE WHEN UNIFORM(1, 100, RANDOM()) > 85 THEN DATEADD('day', -UNIFORM(1, 365, RANDOM()), CURRENT_DATE()) ELSE NULL END AS FECHA_BAJA,
    CASE WHEN UNIFORM(1, 100, RANDOM()) > 85 THEN ARRAY_CONSTRUCT('Renuncia voluntaria', 'Mejor oferta', 'Motivos personales', 'Desempeño', 'Reestructura')[UNIFORM(0, 4, RANDOM())]::VARCHAR ELSE NULL END AS MOTIVO_BAJA
FROM TABLE(GENERATOR(ROWCOUNT => 200));
```

### Tabla: EVALUACIONES_DESEMPENO
```sql
CREATE OR REPLACE TABLE RAW.EVALUACIONES_DESEMPENO (
    ID_EVALUACION VARCHAR(15) PRIMARY KEY,
    ID_EMPLEADO VARCHAR(10),
    PERIODO VARCHAR(10), -- 2023-H1, 2023-H2, 2024-H1
    FECHA_EVALUACION DATE,
    CALIFICACION_OBJETIVOS NUMBER(3,1), -- 1-5
    CALIFICACION_COMPETENCIAS NUMBER(3,1),
    CALIFICACION_GENERAL NUMBER(3,1),
    POTENCIAL VARCHAR(20), -- ALTO, MEDIO, BAJO
    LISTO_PROMOCION BOOLEAN,
    COMENTARIOS_JEFE VARCHAR(1000),
    PLAN_DESARROLLO VARCHAR(500),
    FOREIGN KEY (ID_EMPLEADO) REFERENCES RAW.EMPLEADOS(ID_EMPLEADO)
);

-- Generar evaluaciones
INSERT INTO RAW.EVALUACIONES_DESEMPENO
SELECT 
    'EVAL' || e.ID_EMPLEADO || p.PERIODO AS ID_EVALUACION,
    e.ID_EMPLEADO,
    p.PERIODO,
    CASE 
        WHEN p.PERIODO LIKE '%H1' THEN DATE_FROM_PARTS(LEFT(p.PERIODO, 4)::INT, 6, 30)
        ELSE DATE_FROM_PARTS(LEFT(p.PERIODO, 4)::INT, 12, 31)
    END AS FECHA_EVALUACION,
    ROUND(UNIFORM(25, 50, RANDOM())::FLOAT / 10, 1) AS CALIFICACION_OBJETIVOS,
    ROUND(UNIFORM(25, 50, RANDOM())::FLOAT / 10, 1) AS CALIFICACION_COMPETENCIAS,
    ROUND(UNIFORM(25, 50, RANDOM())::FLOAT / 10, 1) AS CALIFICACION_GENERAL,
    ARRAY_CONSTRUCT('ALTO', 'MEDIO', 'MEDIO', 'BAJO')[UNIFORM(0, 3, RANDOM())]::VARCHAR AS POTENCIAL,
    UNIFORM(1, 10, RANDOM()) <= 2 AS LISTO_PROMOCION,
    ARRAY_CONSTRUCT(
        'Excelente desempeño en el período',
        'Cumple expectativas, oportunidad en comunicación',
        'Supera objetivos consistentemente',
        'Requiere desarrollo en habilidades técnicas',
        'Demuestra liderazgo y proactividad'
    )[UNIFORM(0, 4, RANDOM())]::VARCHAR AS COMENTARIOS_JEFE,
    ARRAY_CONSTRUCT(
        'Capacitación en liderazgo',
        'Certificación técnica',
        'Mentoría con senior',
        'Proyecto especial cross-funcional',
        'Curso de gestión de proyectos'
    )[UNIFORM(0, 4, RANDOM())]::VARCHAR AS PLAN_DESARROLLO
FROM RAW.EMPLEADOS e
CROSS JOIN (SELECT '2023-H1' AS PERIODO UNION SELECT '2023-H2' UNION SELECT '2024-H1') p
WHERE e.ESTADO = 'ACTIVO'
  AND UNIFORM(1, 10, RANDOM()) <= 8;
```

### Tabla: CANDIDATOS (para análisis con IA)
```sql
CREATE OR REPLACE TABLE RAW.CANDIDATOS (
    ID_CANDIDATO VARCHAR(10) PRIMARY KEY,
    NOMBRE VARCHAR(100),
    EMAIL VARCHAR(100),
    TELEFONO VARCHAR(20),
    ID_PUESTO_APLICA VARCHAR(10),
    FECHA_APLICACION DATE,
    FUENTE VARCHAR(30),
    EXPERIENCIA_ANIOS NUMBER,
    EDUCACION VARCHAR(100),
    RESUMEN_CV VARCHAR(2000),
    ESTADO_PROCESO VARCHAR(30), -- NUEVO, EN_REVISION, ENTREVISTA, OFERTA, CONTRATADO, RECHAZADO
    NOTAS_RECLUTADOR VARCHAR(500),
    FOREIGN KEY (ID_PUESTO_APLICA) REFERENCES RAW.PUESTOS(ID_PUESTO)
);

-- Generar candidatos con CVs sintéticos
INSERT INTO RAW.CANDIDATOS
SELECT 
    'CAN' || LPAD(SEQ4()::VARCHAR, 4, '0') AS ID_CANDIDATO,
    ARRAY_CONSTRUCT('Andrea', 'Miguel', 'Valentina', 'Sebastián', 'Camila', 'Mateo', 'Isabella', 'Santiago')[UNIFORM(0, 7, RANDOM())]::VARCHAR || ' ' ||
    ARRAY_CONSTRUCT('Rivera', 'Moreno', 'Jiménez', 'Ruiz', 'Díaz', 'Vargas', 'Castro', 'Ortiz')[UNIFORM(0, 7, RANDOM())]::VARCHAR AS NOMBRE,
    'candidato' || SEQ4() || '@email.com' AS EMAIL,
    '+52' || UNIFORM(5500000000, 5599999999, RANDOM())::VARCHAR AS TELEFONO,
    'PUE' || LPAD(UNIFORM(1, 10, RANDOM())::VARCHAR, 3, '0') AS ID_PUESTO_APLICA,
    DATEADD('day', -UNIFORM(1, 180, RANDOM()), CURRENT_DATE()) AS FECHA_APLICACION,
    ARRAY_CONSTRUCT('LinkedIn', 'Indeed', 'Referido', 'Página Web', 'Universidad')[UNIFORM(0, 4, RANDOM())]::VARCHAR AS FUENTE,
    UNIFORM(0, 15, RANDOM()) AS EXPERIENCIA_ANIOS,
    ARRAY_CONSTRUCT('Ingeniería en Sistemas', 'Administración de Empresas', 'Mercadotecnia', 'Ingeniería Industrial', 'Contaduría', 'Psicología Organizacional')[UNIFORM(0, 5, RANDOM())]::VARCHAR AS EDUCACION,
    'Profesional con ' || UNIFORM(1, 10, RANDOM()) || ' años de experiencia en ' || 
    ARRAY_CONSTRUCT('ventas B2B', 'desarrollo de software', 'gestión de proyectos', 'análisis de datos', 'operaciones', 'recursos humanos')[UNIFORM(0, 5, RANDOM())]::VARCHAR ||
    '. Habilidades destacadas en ' ||
    ARRAY_CONSTRUCT('liderazgo de equipos', 'negociación', 'análisis cuantitativo', 'comunicación efectiva', 'resolución de problemas')[UNIFORM(0, 4, RANDOM())]::VARCHAR ||
    '. Logros: ' ||
    ARRAY_CONSTRUCT('incrementó ventas 30%', 'redujo costos 20%', 'implementó sistema ERP', 'lideró equipo de 15 personas', 'certificación PMP')[UNIFORM(0, 4, RANDOM())]::VARCHAR ||
    '. Busca oportunidad de crecimiento en empresa innovadora.' AS RESUMEN_CV,
    ARRAY_CONSTRUCT('NUEVO', 'EN_REVISION', 'ENTREVISTA', 'OFERTA', 'CONTRATADO', 'RECHAZADO')[UNIFORM(0, 5, RANDOM())]::VARCHAR AS ESTADO_PROCESO,
    NULL AS NOTAS_RECLUTADOR
FROM TABLE(GENERATOR(ROWCOUNT => 100));
```

---

## Vistas Analíticas

```sql
-- Vista de métricas de empleados
CREATE OR REPLACE VIEW ANALYTICS.V_METRICAS_EMPLEADOS AS
SELECT 
    e.ID_EMPLEADO,
    e.NOMBRE,
    p.NOMBRE_PUESTO,
    p.NIVEL,
    d.NOMBRE_DEPARTAMENTO,
    d.DIVISION,
    
    -- Datos demográficos
    DATEDIFF('year', e.FECHA_NACIMIENTO, CURRENT_DATE()) AS EDAD,
    e.GENERO,
    e.NIVEL_EDUCATIVO,
    
    -- Antigüedad
    e.FECHA_INGRESO,
    DATEDIFF('month', e.FECHA_INGRESO, CURRENT_DATE()) AS ANTIGUEDAD_MESES,
    DATEDIFF('year', e.FECHA_INGRESO, CURRENT_DATE()) AS ANTIGUEDAD_ANIOS,
    
    -- Compensación
    e.SALARIO_ACTUAL,
    p.BANDA_SALARIAL_MIN,
    p.BANDA_SALARIAL_MAX,
    ROUND((e.SALARIO_ACTUAL - p.BANDA_SALARIAL_MIN) / NULLIF(p.BANDA_SALARIAL_MAX - p.BANDA_SALARIAL_MIN, 0) * 100, 1) AS POSICION_EN_BANDA,
    
    -- Desempeño (última evaluación)
    ev.CALIFICACION_GENERAL AS ULTIMA_CALIFICACION,
    ev.POTENCIAL,
    ev.LISTO_PROMOCION,
    
    e.MODALIDAD_TRABAJO,
    e.ESTADO

FROM RAW.EMPLEADOS e
JOIN RAW.PUESTOS p ON e.ID_PUESTO = p.ID_PUESTO
JOIN RAW.DEPARTAMENTOS d ON p.ID_DEPARTAMENTO = d.ID_DEPARTAMENTO
LEFT JOIN (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY ID_EMPLEADO ORDER BY FECHA_EVALUACION DESC) AS RN
    FROM RAW.EVALUACIONES_DESEMPENO
) ev ON e.ID_EMPLEADO = ev.ID_EMPLEADO AND ev.RN = 1;

-- Vista de análisis de rotación
CREATE OR REPLACE VIEW ANALYTICS.V_ROTACION AS
SELECT 
    DATE_TRUNC('MONTH', e.FECHA_BAJA) AS MES_BAJA,
    d.NOMBRE_DEPARTAMENTO,
    p.NIVEL,
    e.MOTIVO_BAJA,
    COUNT(*) AS CANTIDAD_BAJAS,
    AVG(DATEDIFF('month', e.FECHA_INGRESO, e.FECHA_BAJA)) AS PROMEDIO_PERMANENCIA_MESES,
    AVG(e.SALARIO_ACTUAL) AS SALARIO_PROMEDIO_BAJAS
FROM RAW.EMPLEADOS e
JOIN RAW.PUESTOS p ON e.ID_PUESTO = p.ID_PUESTO
JOIN RAW.DEPARTAMENTOS d ON p.ID_DEPARTAMENTO = d.ID_DEPARTAMENTO
WHERE e.ESTADO = 'BAJA'
GROUP BY DATE_TRUNC('MONTH', e.FECHA_BAJA), d.NOMBRE_DEPARTAMENTO, p.NIVEL, e.MOTIVO_BAJA;

-- Vista de Nine-Box (Desempeño vs Potencial)
CREATE OR REPLACE VIEW ANALYTICS.V_NINE_BOX AS
SELECT 
    e.ID_EMPLEADO,
    e.NOMBRE,
    p.NOMBRE_PUESTO,
    d.NOMBRE_DEPARTAMENTO,
    ev.CALIFICACION_GENERAL AS DESEMPENO,
    ev.POTENCIAL,
    CASE 
        WHEN ev.CALIFICACION_GENERAL >= 4 AND ev.POTENCIAL = 'ALTO' THEN '⭐ Estrella'
        WHEN ev.CALIFICACION_GENERAL >= 4 AND ev.POTENCIAL = 'MEDIO' THEN '📈 Alto Desempeño'
        WHEN ev.CALIFICACION_GENERAL >= 4 AND ev.POTENCIAL = 'BAJO' THEN '🎯 Experto'
        WHEN ev.CALIFICACION_GENERAL >= 3 AND ev.POTENCIAL = 'ALTO' THEN '🚀 Alto Potencial'
        WHEN ev.CALIFICACION_GENERAL >= 3 AND ev.POTENCIAL = 'MEDIO' THEN '✅ Core Player'
        WHEN ev.CALIFICACION_GENERAL >= 3 AND ev.POTENCIAL = 'BAJO' THEN '📊 Efectivo'
        WHEN ev.POTENCIAL = 'ALTO' THEN '❓ Enigma'
        WHEN ev.POTENCIAL = 'MEDIO' THEN '📉 En desarrollo'
        ELSE '⚠️ Acción requerida'
    END AS CLASIFICACION_NINE_BOX,
    ev.LISTO_PROMOCION
FROM RAW.EMPLEADOS e
JOIN RAW.PUESTOS p ON e.ID_PUESTO = p.ID_PUESTO
JOIN RAW.DEPARTAMENTOS d ON p.ID_DEPARTAMENTO = d.ID_DEPARTAMENTO
JOIN (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY ID_EMPLEADO ORDER BY FECHA_EVALUACION DESC) AS RN
    FROM RAW.EVALUACIONES_DESEMPENO
) ev ON e.ID_EMPLEADO = ev.ID_EMPLEADO AND ev.RN = 1
WHERE e.ESTADO = 'ACTIVO';
```

---

## Análisis con Cortex AI

```sql
-- Análisis de CVs con IA
CREATE OR REPLACE VIEW ANALYTICS.V_CANDIDATOS_ANALISIS_IA AS
SELECT 
    c.ID_CANDIDATO,
    c.NOMBRE,
    c.ID_PUESTO_APLICA,
    p.NOMBRE_PUESTO,
    c.EXPERIENCIA_ANIOS,
    c.RESUMEN_CV,
    c.ESTADO_PROCESO,
    
    -- Análisis de sentimiento del CV
    SNOWFLAKE.CORTEX.SENTIMENT(c.RESUMEN_CV) AS SENTIMIENTO_CV,
    
    -- Extraer habilidades clave
    SNOWFLAKE.CORTEX.COMPLETE(
        'mistral-large',
        'Extrae las 5 habilidades principales de este CV en formato de lista. CV: ' || c.RESUMEN_CV
    ) AS HABILIDADES_EXTRAIDAS,
    
    -- Match con requisitos del puesto
    SNOWFLAKE.CORTEX.COMPLETE(
        'mistral-large',
        'Evalúa del 1 al 10 qué tan bien este candidato cumple con los requisitos del puesto. ' ||
        'Requisitos: ' || p.COMPETENCIAS_REQUERIDAS || '. ' ||
        'CV del candidato: ' || c.RESUMEN_CV || '. ' ||
        'Responde solo con el número y una breve justificación de 1 línea.'
    ) AS SCORE_MATCH
    
FROM RAW.CANDIDATOS c
JOIN RAW.PUESTOS p ON c.ID_PUESTO_APLICA = p.ID_PUESTO;
```

---

## Preguntas Sugeridas para el Agente

- "¿Cuál es la tasa de rotación por departamento?"
- "Muestra la distribución del Nine-Box"
- "¿Cuántos empleados están listos para promoción?"
- "Análisis de equidad salarial por género"
- "¿Cuáles son las principales causas de rotación?"
- "Headcount actual vs aprobado por departamento"
- "¿Qué candidatos tienen mejor match para el puesto de Data Engineer?"
- "Promedio de permanencia por nivel de puesto"
