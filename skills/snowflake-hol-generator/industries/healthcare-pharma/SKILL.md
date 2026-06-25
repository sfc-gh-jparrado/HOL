# Sub-Skill: Industria Healthcare/Pharma

## Metadata
- **Parent**: snowflake-hol-generator
- **Name**: industries/healthcare-pharma
- **Industria**: Healthcare / Farmacéutica
- **Duración**: ~25 minutos adicionales

---

## 🎯 Contexto de Negocio

El HOL para pharma/healthcare simula:
- Fuerza de ventas con representantes y territorios
- Médicos como clientes/prescriptores
- Productos farmacéuticos con líneas terapéuticas
- Visitas médicas y seguimiento
- Ventas y cuotas

---

## Datos Sintéticos

### Tabla: TERRITORIOS
```sql
CREATE OR REPLACE TABLE RAW.TERRITORIOS (
    ID_TERRITORIO VARCHAR(10) PRIMARY KEY,
    NOMBRE_TERRITORIO VARCHAR(100),
    REGION VARCHAR(50),
    ZONA VARCHAR(50),
    ESTADO VARCHAR(50),
    POBLACION_ESTIMADA NUMBER
);

INSERT INTO RAW.TERRITORIOS VALUES
('TER001', 'CDMX Norte', 'Centro', 'Metropolitana', 'Ciudad de México', 3500000),
('TER002', 'CDMX Sur', 'Centro', 'Metropolitana', 'Ciudad de México', 3200000),
('TER003', 'Monterrey Metro', 'Norte', 'Noreste', 'Nuevo León', 4500000),
('TER004', 'Guadalajara Metro', 'Occidente', 'Pacífico', 'Jalisco', 4200000),
('TER005', 'Bajío', 'Centro', 'Bajío', 'Guanajuato', 2800000),
('TER006', 'Sureste', 'Sur', 'Sureste', 'Yucatán', 2100000),
('TER007', 'Noroeste', 'Norte', 'Pacífico Norte', 'Sonora', 1800000),
('TER008', 'Costa Este', 'Este', 'Golfo', 'Veracruz', 2500000);
```

### Tabla: REPRESENTANTES
```sql
CREATE OR REPLACE TABLE RAW.REPRESENTANTES (
    ID_REPRESENTANTE VARCHAR(10) PRIMARY KEY,
    NOMBRE VARCHAR(100),
    EMAIL VARCHAR(100),
    TELEFONO VARCHAR(20),
    ID_TERRITORIO VARCHAR(10),
    FECHA_INGRESO DATE,
    NIVEL VARCHAR(20), -- JUNIOR, SENIOR, KEY_ACCOUNT
    ESPECIALIDAD VARCHAR(50),
    CUOTA_MENSUAL NUMBER(12,2),
    ACTIVO BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (ID_TERRITORIO) REFERENCES RAW.TERRITORIOS(ID_TERRITORIO)
);

INSERT INTO RAW.REPRESENTANTES VALUES
('REP001', 'Carlos Mendoza', 'cmendoza@[cliente].com', '+525551234567', 'TER001', '2020-03-15', 'SENIOR', 'Cardiología', 150000, TRUE),
('REP002', 'Ana García', 'agarcia@[cliente].com', '+525551234568', 'TER001', '2022-06-01', 'JUNIOR', 'Cardiología', 100000, TRUE),
('REP003', 'Roberto López', 'rlopez@[cliente].com', '+528181234567', 'TER003', '2019-01-10', 'KEY_ACCOUNT', 'Oncología', 200000, TRUE),
('REP004', 'María Fernández', 'mfernandez@[cliente].com', '+523331234567', 'TER004', '2021-08-20', 'SENIOR', 'Diabetes', 175000, TRUE),
('REP005', 'Jorge Ramírez', 'jramirez@[cliente].com', '+525551234569', 'TER002', '2023-02-01', 'JUNIOR', 'Cardiología', 90000, TRUE),
('REP006', 'Laura Sánchez', 'lsanchez@[cliente].com', '+524771234567', 'TER005', '2020-11-15', 'SENIOR', 'Diabetes', 160000, TRUE),
('REP007', 'Pedro Hernández', 'phernandez@[cliente].com', '+529991234567', 'TER006', '2022-04-10', 'JUNIOR', 'General', 85000, TRUE),
('REP008', 'Diana Torres', 'dtorres@[cliente].com', '+526621234567', 'TER007', '2021-07-01', 'SENIOR', 'Oncología', 180000, TRUE),
('REP009', 'Fernando Ruiz', 'fruiz@[cliente].com', '+522291234567', 'TER008', '2023-09-01', 'JUNIOR', 'General', 80000, TRUE),
('REP010', 'Sofía Morales', 'smorales@[cliente].com', '+525551234570', 'TER002', '2020-05-20', 'KEY_ACCOUNT', 'Especialidades', 220000, TRUE);
```

### Tabla: PRODUCTOS
```sql
CREATE OR REPLACE TABLE RAW.PRODUCTOS (
    ID_PRODUCTO VARCHAR(10) PRIMARY KEY,
    NOMBRE_COMERCIAL VARCHAR(100),
    PRINCIPIO_ACTIVO VARCHAR(100),
    LINEA_TERAPEUTICA VARCHAR(50),
    FORMA_FARMACEUTICA VARCHAR(30),
    PRESENTACION VARCHAR(50),
    PRECIO_LISTA NUMBER(10,2),
    COSTO NUMBER(10,2),
    REQUIERE_RECETA BOOLEAN,
    ACTIVO BOOLEAN DEFAULT TRUE
);

INSERT INTO RAW.PRODUCTOS VALUES
('MED001', 'Cardioplus 100mg', 'Atorvastatina', 'Cardiología', 'Tableta', 'Caja 30 tabletas', 450.00, 180.00, TRUE, TRUE),
('MED002', 'Cardioplus 50mg', 'Atorvastatina', 'Cardiología', 'Tableta', 'Caja 30 tabletas', 320.00, 128.00, TRUE, TRUE),
('MED003', 'Tensionil 10mg', 'Lisinopril', 'Cardiología', 'Tableta', 'Caja 28 tabletas', 280.00, 112.00, TRUE, TRUE),
('MED004', 'Gluconorm 850mg', 'Metformina', 'Diabetes', 'Tableta', 'Caja 60 tabletas', 180.00, 54.00, TRUE, TRUE),
('MED005', 'Gluconorm 500mg', 'Metformina', 'Diabetes', 'Tableta', 'Caja 60 tabletas', 120.00, 36.00, TRUE, TRUE),
('MED006', 'Insulex Pen', 'Insulina Glargina', 'Diabetes', 'Inyectable', 'Pluma 3ml', 1200.00, 480.00, TRUE, TRUE),
('MED007', 'Oncotarget 250mg', 'Imatinib', 'Oncología', 'Cápsula', 'Frasco 30 cápsulas', 25000.00, 12500.00, TRUE, TRUE),
('MED008', 'Oncotarget 100mg', 'Imatinib', 'Oncología', 'Cápsula', 'Frasco 60 cápsulas', 18000.00, 9000.00, TRUE, TRUE),
('MED009', 'Inmunomax', 'Pembrolizumab', 'Oncología', 'Inyectable', 'Vial 100mg', 45000.00, 22500.00, TRUE, TRUE),
('MED010', 'Painrelief 400mg', 'Ibuprofeno', 'Analgésicos', 'Tableta', 'Caja 20 tabletas', 85.00, 25.50, FALSE, TRUE),
('MED011', 'Digestpro', 'Omeprazol', 'Gastroenterología', 'Cápsula', 'Caja 14 cápsulas', 150.00, 45.00, FALSE, TRUE),
('MED012', 'Alerginil', 'Loratadina', 'Alergias', 'Tableta', 'Caja 10 tabletas', 95.00, 28.50, FALSE, TRUE),
('MED013', 'Respiraflex', 'Salbutamol', 'Respiratorio', 'Inhalador', 'Aerosol 200 dosis', 280.00, 112.00, TRUE, TRUE),
('MED014', 'Neurobalance', 'Pregabalina', 'Neurología', 'Cápsula', 'Caja 28 cápsulas', 520.00, 208.00, TRUE, TRUE),
('MED015', 'Vitamax Plus', 'Multivitamínico', 'Suplementos', 'Tableta', 'Frasco 100 tabletas', 180.00, 54.00, FALSE, TRUE);
```

### Tabla: MEDICOS
```sql
CREATE OR REPLACE TABLE RAW.MEDICOS (
    ID_MEDICO VARCHAR(10) PRIMARY KEY,
    NOMBRE VARCHAR(100),
    ESPECIALIDAD VARCHAR(50),
    HOSPITAL_CLINICA VARCHAR(100),
    ID_TERRITORIO VARCHAR(10),
    EMAIL VARCHAR(100),
    TELEFONO VARCHAR(20),
    POTENCIAL VARCHAR(20), -- ALTO, MEDIO, BAJO
    FRECUENCIA_VISITA VARCHAR(20), -- SEMANAL, QUINCENAL, MENSUAL
    FOREIGN KEY (ID_TERRITORIO) REFERENCES RAW.TERRITORIOS(ID_TERRITORIO)
);

-- Generar médicos
INSERT INTO RAW.MEDICOS
SELECT 
    'DOC' || LPAD(SEQ4()::VARCHAR, 3, '0') AS ID_MEDICO,
    ARRAY_CONSTRUCT('Dr. Juan', 'Dra. María', 'Dr. Carlos', 'Dra. Ana', 'Dr. Roberto', 'Dra. Laura', 'Dr. Pedro', 'Dra. Sofia')[UNIFORM(0, 7, RANDOM())]::VARCHAR || ' ' ||
    ARRAY_CONSTRUCT('García', 'López', 'Martínez', 'Rodríguez', 'Hernández', 'González', 'Sánchez', 'Ramírez')[UNIFORM(0, 7, RANDOM())]::VARCHAR AS NOMBRE,
    ARRAY_CONSTRUCT('Cardiología', 'Endocrinología', 'Oncología', 'Medicina Interna', 'Medicina General', 'Neurología')[UNIFORM(0, 5, RANDOM())]::VARCHAR AS ESPECIALIDAD,
    ARRAY_CONSTRUCT('Hospital General', 'Clínica Privada Centro', 'Hospital Universitario', 'Centro Médico Nacional', 'Consultorio Particular', 'Hospital Regional')[UNIFORM(0, 5, RANDOM())]::VARCHAR AS HOSPITAL_CLINICA,
    'TER00' || UNIFORM(1, 8, RANDOM()) AS ID_TERRITORIO,
    'doctor' || SEQ4() || '@hospital.com' AS EMAIL,
    '+52' || UNIFORM(5500000000, 5599999999, RANDOM())::VARCHAR AS TELEFONO,
    ARRAY_CONSTRUCT('ALTO', 'ALTO', 'MEDIO', 'MEDIO', 'MEDIO', 'BAJO')[UNIFORM(0, 5, RANDOM())]::VARCHAR AS POTENCIAL,
    ARRAY_CONSTRUCT('SEMANAL', 'QUINCENAL', 'QUINCENAL', 'MENSUAL')[UNIFORM(0, 3, RANDOM())]::VARCHAR AS FRECUENCIA_VISITA
FROM TABLE(GENERATOR(ROWCOUNT => 50));
```

### Tabla: VISITAS
```sql
CREATE OR REPLACE TABLE RAW.VISITAS (
    ID_VISITA VARCHAR(15) PRIMARY KEY,
    FECHA TIMESTAMP,
    ID_REPRESENTANTE VARCHAR(10),
    ID_MEDICO VARCHAR(10),
    TIPO_VISITA VARCHAR(20), -- PRESENCIAL, VIRTUAL, CONGRESO
    DURACION_MINUTOS NUMBER,
    PRODUCTOS_PRESENTADOS VARCHAR(500),
    MUESTRAS_ENTREGADAS VARCHAR(200),
    RESULTADO VARCHAR(20), -- EXITOSA, PARCIAL, NO_DISPONIBLE
    NOTAS VARCHAR(1000),
    FOREIGN KEY (ID_REPRESENTANTE) REFERENCES RAW.REPRESENTANTES(ID_REPRESENTANTE),
    FOREIGN KEY (ID_MEDICO) REFERENCES RAW.MEDICOS(ID_MEDICO)
);

-- Generar visitas
INSERT INTO RAW.VISITAS
SELECT 
    'VIS' || TO_CHAR(CURRENT_DATE(), 'YYYYMMDD') || LPAD(SEQ4()::VARCHAR, 5, '0') AS ID_VISITA,
    DATEADD('minute', -UNIFORM(1, 262800, RANDOM()), CURRENT_TIMESTAMP()) AS FECHA,
    'REP' || LPAD(UNIFORM(1, 10, RANDOM())::VARCHAR, 3, '0') AS ID_REPRESENTANTE,
    'DOC' || LPAD(UNIFORM(1, 50, RANDOM())::VARCHAR, 3, '0') AS ID_MEDICO,
    ARRAY_CONSTRUCT('PRESENCIAL', 'PRESENCIAL', 'PRESENCIAL', 'VIRTUAL', 'CONGRESO')[UNIFORM(0, 4, RANDOM())]::VARCHAR AS TIPO_VISITA,
    UNIFORM(10, 45, RANDOM()) AS DURACION_MINUTOS,
    'MED' || LPAD(UNIFORM(1, 15, RANDOM())::VARCHAR, 3, '0') AS PRODUCTOS_PRESENTADOS,
    CASE WHEN UNIFORM(1, 10, RANDOM()) <= 7 THEN 'MED' || LPAD(UNIFORM(1, 15, RANDOM())::VARCHAR, 3, '0') ELSE NULL END AS MUESTRAS_ENTREGADAS,
    ARRAY_CONSTRUCT('EXITOSA', 'EXITOSA', 'EXITOSA', 'PARCIAL', 'NO_DISPONIBLE')[UNIFORM(0, 4, RANDOM())]::VARCHAR AS RESULTADO,
    ARRAY_CONSTRUCT(
        'Médico interesado en nuevo producto',
        'Solicitó más información clínica',
        'Prescribe competencia actualmente',
        'Receptivo a cambiar tratamiento',
        'Requiere seguimiento próxima semana'
    )[UNIFORM(0, 4, RANDOM())]::VARCHAR AS NOTAS
FROM TABLE(GENERATOR(ROWCOUNT => 2000));
```

### Tabla: VENTAS
```sql
CREATE OR REPLACE TABLE RAW.VENTAS (
    ID_VENTA VARCHAR(15) PRIMARY KEY,
    FECHA DATE,
    ID_REPRESENTANTE VARCHAR(10),
    ID_MEDICO VARCHAR(10),
    ID_PRODUCTO VARCHAR(10),
    CANTIDAD NUMBER,
    PRECIO_UNITARIO NUMBER(10,2),
    DESCUENTO_PCT NUMBER(5,2),
    MONTO NUMBER(12,2),
    CANAL VARCHAR(20), -- FARMACIA, HOSPITAL, DISTRIBUIDOR
    FOREIGN KEY (ID_REPRESENTANTE) REFERENCES RAW.REPRESENTANTES(ID_REPRESENTANTE),
    FOREIGN KEY (ID_PRODUCTO) REFERENCES RAW.PRODUCTOS(ID_PRODUCTO)
);

-- Generar ventas
INSERT INTO RAW.VENTAS
SELECT 
    'VTA' || TO_CHAR(CURRENT_DATE(), 'YYYYMMDD') || LPAD(SEQ4()::VARCHAR, 5, '0') AS ID_VENTA,
    DATEADD('day', -UNIFORM(1, 365, RANDOM()), CURRENT_DATE()) AS FECHA,
    'REP' || LPAD(UNIFORM(1, 10, RANDOM())::VARCHAR, 3, '0') AS ID_REPRESENTANTE,
    'DOC' || LPAD(UNIFORM(1, 50, RANDOM())::VARCHAR, 3, '0') AS ID_MEDICO,
    p.ID_PRODUCTO,
    UNIFORM(1, 20, RANDOM()) AS CANTIDAD,
    p.PRECIO_LISTA AS PRECIO_UNITARIO,
    CASE WHEN UNIFORM(1, 10, RANDOM()) <= 3 THEN UNIFORM(5, 15, RANDOM()) ELSE 0 END AS DESCUENTO_PCT,
    ROUND(UNIFORM(1, 20, RANDOM()) * p.PRECIO_LISTA * (1 - UNIFORM(0, 15, RANDOM())/100), 2) AS MONTO,
    ARRAY_CONSTRUCT('FARMACIA', 'FARMACIA', 'HOSPITAL', 'DISTRIBUIDOR')[UNIFORM(0, 3, RANDOM())]::VARCHAR AS CANAL
FROM TABLE(GENERATOR(ROWCOUNT => 5000)) g
JOIN RAW.PRODUCTOS p ON p.ID_PRODUCTO = 'MED' || LPAD(UNIFORM(1, 15, RANDOM())::VARCHAR, 3, '0');
```

---

## Vistas Analíticas

```sql
-- Vista de análisis de ventas
CREATE OR REPLACE VIEW ANALYTICS.V_VENTAS_PHARMA AS
SELECT 
    v.ID_VENTA,
    v.FECHA,
    DATE_TRUNC('MONTH', v.FECHA) AS MES,
    DATE_TRUNC('QUARTER', v.FECHA) AS TRIMESTRE,
    
    -- Representante
    r.ID_REPRESENTANTE,
    r.NOMBRE AS REPRESENTANTE,
    r.NIVEL,
    r.ESPECIALIDAD AS ESPECIALIDAD_REP,
    r.CUOTA_MENSUAL,
    
    -- Territorio
    t.NOMBRE_TERRITORIO,
    t.REGION,
    t.ZONA,
    
    -- Producto
    p.ID_PRODUCTO,
    p.NOMBRE_COMERCIAL,
    p.LINEA_TERAPEUTICA,
    p.COSTO AS COSTO_UNITARIO,
    
    -- Métricas
    v.CANTIDAD,
    v.MONTO AS INGRESO,
    v.CANTIDAD * p.COSTO AS COSTO_TOTAL,
    v.MONTO - (v.CANTIDAD * p.COSTO) AS MARGEN,
    v.CANAL

FROM RAW.VENTAS v
JOIN RAW.REPRESENTANTES r ON v.ID_REPRESENTANTE = r.ID_REPRESENTANTE
JOIN RAW.TERRITORIOS t ON r.ID_TERRITORIO = t.ID_TERRITORIO
JOIN RAW.PRODUCTOS p ON v.ID_PRODUCTO = p.ID_PRODUCTO;

-- Vista de KPIs por representante
CREATE OR REPLACE VIEW ANALYTICS.V_KPI_REPRESENTANTES AS
SELECT 
    r.ID_REPRESENTANTE,
    r.NOMBRE,
    r.NIVEL,
    t.NOMBRE_TERRITORIO,
    r.CUOTA_MENSUAL,
    
    -- Métricas de visitas
    COUNT(DISTINCT vis.ID_VISITA) AS TOTAL_VISITAS,
    COUNT(DISTINCT vis.ID_MEDICO) AS MEDICOS_VISITADOS,
    ROUND(AVG(vis.DURACION_MINUTOS), 1) AS DURACION_PROMEDIO,
    
    -- Métricas de ventas
    SUM(ven.MONTO) AS VENTAS_TOTALES,
    ROUND(SUM(ven.MONTO) / NULLIF(r.CUOTA_MENSUAL, 0) * 100, 1) AS PCT_CUOTA,
    
    -- Efectividad
    ROUND(COUNT(CASE WHEN vis.RESULTADO = 'EXITOSA' THEN 1 END)::FLOAT / NULLIF(COUNT(vis.ID_VISITA), 0) * 100, 1) AS PCT_VISITAS_EXITOSAS

FROM RAW.REPRESENTANTES r
JOIN RAW.TERRITORIOS t ON r.ID_TERRITORIO = t.ID_TERRITORIO
LEFT JOIN RAW.VISITAS vis ON r.ID_REPRESENTANTE = vis.ID_REPRESENTANTE
LEFT JOIN RAW.VENTAS ven ON r.ID_REPRESENTANTE = ven.ID_REPRESENTANTE
WHERE r.ACTIVO = TRUE
GROUP BY r.ID_REPRESENTANTE, r.NOMBRE, r.NIVEL, t.NOMBRE_TERRITORIO, r.CUOTA_MENSUAL;
```

---

## Preguntas Sugeridas para el Agente

- "¿Cuál es el avance de cuota por representante este mes?"
- "Top 5 productos por margen en Cardiología"
- "¿Cuántas visitas ha realizado cada representante esta semana?"
- "Comparar ventas por línea terapéutica vs año anterior"
- "¿Qué médicos de alto potencial no han sido visitados en 30 días?"
- "Efectividad de visitas por tipo (presencial vs virtual)"
- "Ranking de territorios por venta per cápita"
