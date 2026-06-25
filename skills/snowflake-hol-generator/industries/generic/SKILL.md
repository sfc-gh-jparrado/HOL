# Industria Genérica

Sub-skill para generar datos sintéticos cuando la industria del cliente no coincide con las industrias específicas disponibles.

## Metadata
- **Industria**: Genérica / Adaptable
- **Tablas**: 5 tablas base
- **Registros sugeridos**: 500-2000 por tabla
- **Compatibilidad**: Trial ✅

---

## Modelo de Datos Base

Este modelo es adaptable y puede personalizarse según el negocio específico del cliente.

```
┌─────────────────┐       ┌─────────────────┐
│    CATEGORIAS   │       │    CLIENTES     │
│─────────────────│       │─────────────────│
│ categoria_id PK │       │ cliente_id PK   │
│ nombre          │       │ nombre          │
│ descripcion     │       │ email           │
│ activo          │       │ segmento        │
└────────┬────────┘       │ region          │
         │                │ fecha_registro  │
         │                │ activo          │
         │                └────────┬────────┘
         │                         │
         ▼                         │
┌─────────────────┐                │
│    PRODUCTOS    │                │
│─────────────────│                │
│ producto_id PK  │                │
│ categoria_id FK │                │
│ nombre          │                │
│ descripcion     │                │
│ precio          │                │
│ activo          │                │
└────────┬────────┘                │
         │                         │
         │    ┌────────────────────┘
         │    │
         ▼    ▼
┌─────────────────────┐
│    TRANSACCIONES    │
│─────────────────────│
│ transaccion_id PK   │
│ cliente_id FK       │
│ fecha               │
│ monto_total         │
│ estado              │
│ canal               │
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│      DETALLES       │
│─────────────────────│
│ detalle_id PK       │
│ transaccion_id FK   │
│ producto_id FK      │
│ cantidad            │
│ precio_unitario     │
│ descuento           │
└─────────────────────┘
```

---

## SQL de Generación de Datos

### 1. Crear Estructura

```sql
-- ============================================
-- INDUSTRIA GENÉRICA - SETUP
-- ============================================

-- Crear schema
CREATE SCHEMA IF NOT EXISTS {{DATABASE}}.GENERIC_DATA;
USE SCHEMA {{DATABASE}}.GENERIC_DATA;

-- Tabla de Categorías
CREATE OR REPLACE TABLE CATEGORIAS (
    categoria_id INT AUTOINCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    descripcion VARCHAR(500),
    activo BOOLEAN DEFAULT TRUE,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- Tabla de Clientes
CREATE OR REPLACE TABLE CLIENTES (
    cliente_id INT AUTOINCREMENT PRIMARY KEY,
    nombre VARCHAR(200) NOT NULL,
    email VARCHAR(200),
    telefono VARCHAR(50),
    segmento VARCHAR(50),
    region VARCHAR(50),
    fecha_registro DATE,
    activo BOOLEAN DEFAULT TRUE
);

-- Tabla de Productos/Servicios
CREATE OR REPLACE TABLE PRODUCTOS (
    producto_id INT AUTOINCREMENT PRIMARY KEY,
    categoria_id INT REFERENCES CATEGORIAS(categoria_id),
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(200) NOT NULL,
    descripcion VARCHAR(1000),
    precio DECIMAL(12,2),
    costo DECIMAL(12,2),
    activo BOOLEAN DEFAULT TRUE
);

-- Tabla de Transacciones
CREATE OR REPLACE TABLE TRANSACCIONES (
    transaccion_id INT AUTOINCREMENT PRIMARY KEY,
    cliente_id INT REFERENCES CLIENTES(cliente_id),
    fecha TIMESTAMP NOT NULL,
    monto_total DECIMAL(12,2),
    estado VARCHAR(50),
    canal VARCHAR(50),
    notas VARCHAR(500)
);

-- Tabla de Detalles
CREATE OR REPLACE TABLE DETALLES (
    detalle_id INT AUTOINCREMENT PRIMARY KEY,
    transaccion_id INT REFERENCES TRANSACCIONES(transaccion_id),
    producto_id INT REFERENCES PRODUCTOS(producto_id),
    cantidad INT,
    precio_unitario DECIMAL(12,2),
    descuento_pct DECIMAL(5,2) DEFAULT 0
);
```

### 2. Generar Datos Sintéticos

```sql
-- ============================================
-- GENERAR DATOS SINTÉTICOS
-- ============================================

-- Categorías (adaptar nombres al negocio)
INSERT INTO CATEGORIAS (nombre, descripcion)
SELECT 
    'Categoría ' || SEQ4() AS nombre,
    'Descripción de la categoría ' || SEQ4() AS descripcion
FROM TABLE(GENERATOR(ROWCOUNT => 10));

-- Clientes
INSERT INTO CLIENTES (nombre, email, telefono, segmento, region, fecha_registro)
SELECT 
    ARRAY_CONSTRUCT(
        'Empresa', 'Corporación', 'Grupo', 'Compañía', 'Organización'
    )[UNIFORM(0, 4, RANDOM())::INT] || ' ' ||
    ARRAY_CONSTRUCT(
        'Alpha', 'Beta', 'Gamma', 'Delta', 'Epsilon', 'Omega', 
        'Prime', 'Global', 'Tech', 'Solutions'
    )[UNIFORM(0, 9, RANDOM())::INT] AS nombre,
    
    LOWER(REPLACE(nombre, ' ', '.')) || '@ejemplo.com' AS email,
    
    '+1-' || LPAD(UNIFORM(100, 999, RANDOM())::STRING, 3, '0') || '-' ||
    LPAD(UNIFORM(1000, 9999, RANDOM())::STRING, 4, '0') AS telefono,
    
    ARRAY_CONSTRUCT('Enterprise', 'SMB', 'Startup', 'Government')[
        UNIFORM(0, 3, RANDOM())::INT
    ] AS segmento,
    
    ARRAY_CONSTRUCT('Norte', 'Sur', 'Este', 'Oeste', 'Centro')[
        UNIFORM(0, 4, RANDOM())::INT
    ] AS region,
    
    DATEADD(day, -UNIFORM(1, 730, RANDOM()), CURRENT_DATE()) AS fecha_registro
FROM TABLE(GENERATOR(ROWCOUNT => 500));

-- Productos
INSERT INTO PRODUCTOS (categoria_id, codigo, nombre, descripcion, precio, costo)
SELECT 
    UNIFORM(1, 10, RANDOM()) AS categoria_id,
    'PROD-' || LPAD(SEQ4()::STRING, 5, '0') AS codigo,
    'Producto ' || SEQ4() AS nombre,
    'Descripción del producto ' || SEQ4() AS descripcion,
    ROUND(UNIFORM(10.00, 1000.00, RANDOM())::DECIMAL(12,2), 2) AS precio,
    ROUND(precio * UNIFORM(0.3, 0.7, RANDOM()), 2) AS costo
FROM TABLE(GENERATOR(ROWCOUNT => 100));

-- Transacciones (últimos 12 meses)
INSERT INTO TRANSACCIONES (cliente_id, fecha, monto_total, estado, canal)
SELECT 
    UNIFORM(1, 500, RANDOM()) AS cliente_id,
    DATEADD(
        minute, 
        UNIFORM(0, 1440, RANDOM()),
        DATEADD(day, -UNIFORM(0, 365, RANDOM()), CURRENT_DATE())
    ) AS fecha,
    0 AS monto_total, -- Se calculará después
    ARRAY_CONSTRUCT('Completado', 'Completado', 'Completado', 
                    'Pendiente', 'Cancelado')[UNIFORM(0, 4, RANDOM())::INT] AS estado,
    ARRAY_CONSTRUCT('Online', 'Presencial', 'Teléfono', 'Partner')[
        UNIFORM(0, 3, RANDOM())::INT
    ] AS canal
FROM TABLE(GENERATOR(ROWCOUNT => 2000));

-- Detalles de transacciones
INSERT INTO DETALLES (transaccion_id, producto_id, cantidad, precio_unitario, descuento_pct)
SELECT 
    t.transaccion_id,
    UNIFORM(1, 100, RANDOM()) AS producto_id,
    UNIFORM(1, 10, RANDOM()) AS cantidad,
    p.precio AS precio_unitario,
    CASE WHEN UNIFORM(0, 10, RANDOM()) > 7 
         THEN UNIFORM(5, 20, RANDOM()) 
         ELSE 0 
    END AS descuento_pct
FROM TRANSACCIONES t
CROSS JOIN TABLE(GENERATOR(ROWCOUNT => 3)) g
JOIN PRODUCTOS p ON p.producto_id = UNIFORM(1, 100, RANDOM());

-- Actualizar montos totales
UPDATE TRANSACCIONES t
SET monto_total = (
    SELECT SUM(cantidad * precio_unitario * (1 - descuento_pct/100))
    FROM DETALLES d
    WHERE d.transaccion_id = t.transaccion_id
);
```

---

## Vistas Analíticas

### Dashboard Principal

```sql
CREATE OR REPLACE VIEW V_DASHBOARD_PRINCIPAL AS
SELECT 
    DATE_TRUNC('month', t.fecha) AS mes,
    COUNT(DISTINCT t.transaccion_id) AS total_transacciones,
    COUNT(DISTINCT t.cliente_id) AS clientes_activos,
    SUM(t.monto_total) AS ingresos_totales,
    AVG(t.monto_total) AS ticket_promedio
FROM TRANSACCIONES t
WHERE t.estado = 'Completado'
GROUP BY 1
ORDER BY 1;
```

### Análisis por Segmento

```sql
CREATE OR REPLACE VIEW V_ANALISIS_SEGMENTO AS
SELECT 
    c.segmento,
    COUNT(DISTINCT c.cliente_id) AS total_clientes,
    COUNT(t.transaccion_id) AS total_transacciones,
    SUM(t.monto_total) AS ingresos,
    AVG(t.monto_total) AS ticket_promedio,
    SUM(t.monto_total) / COUNT(DISTINCT c.cliente_id) AS valor_por_cliente
FROM CLIENTES c
LEFT JOIN TRANSACCIONES t ON c.cliente_id = t.cliente_id AND t.estado = 'Completado'
GROUP BY c.segmento;
```

### Top Productos

```sql
CREATE OR REPLACE VIEW V_TOP_PRODUCTOS AS
SELECT 
    p.nombre AS producto,
    cat.nombre AS categoria,
    COUNT(d.detalle_id) AS veces_vendido,
    SUM(d.cantidad) AS unidades_vendidas,
    SUM(d.cantidad * d.precio_unitario * (1 - d.descuento_pct/100)) AS ingresos,
    AVG(d.descuento_pct) AS descuento_promedio
FROM PRODUCTOS p
JOIN DETALLES d ON p.producto_id = d.producto_id
JOIN CATEGORIAS cat ON p.categoria_id = cat.categoria_id
GROUP BY 1, 2
ORDER BY ingresos DESC
LIMIT 20;
```

### Tendencia Temporal

```sql
CREATE OR REPLACE VIEW V_TENDENCIA AS
SELECT 
    DATE_TRUNC('week', fecha) AS semana,
    canal,
    COUNT(*) AS transacciones,
    SUM(monto_total) AS ingresos,
    AVG(monto_total) AS ticket_promedio
FROM TRANSACCIONES
WHERE estado = 'Completado'
GROUP BY 1, 2
ORDER BY 1, 2;
```

---

## Preguntas para Cortex Analyst

### Preguntas Sugeridas

1. **Rendimiento General**
   - "¿Cuáles son los ingresos totales del último trimestre?"
   - "¿Cuál es el ticket promedio por canal?"
   - "¿Cómo ha evolucionado el número de transacciones mes a mes?"

2. **Análisis de Clientes**
   - "¿Cuántos clientes nuevos tenemos este mes?"
   - "¿Cuál es el segmento con mayor valor promedio?"
   - "¿Qué región tiene más clientes activos?"

3. **Productos**
   - "¿Cuáles son los 10 productos más vendidos?"
   - "¿Qué categoría genera más ingresos?"
   - "¿Cuál es el margen promedio por categoría?"

4. **Tendencias**
   - "¿El canal online está creciendo vs presencial?"
   - "¿Hay estacionalidad en las ventas?"
   - "¿Cuál es la tendencia de ticket promedio?"

---

## Personalización

Este modelo genérico debe adaptarse al cliente:

| Campo | Personalizar con |
|-------|------------------|
| `CATEGORIAS.nombre` | Categorías reales del negocio |
| `CLIENTES.segmento` | Segmentos que usa el cliente |
| `TRANSACCIONES.canal` | Canales de venta del cliente |
| `TRANSACCIONES.estado` | Estados de su proceso |

### Ejemplo de Personalización

```sql
-- Para un cliente de servicios profesionales
UPDATE CATEGORIAS SET nombre = 
    CASE categoria_id
        WHEN 1 THEN 'Consultoría'
        WHEN 2 THEN 'Auditoría'
        WHEN 3 THEN 'Implementación'
        WHEN 4 THEN 'Soporte'
        WHEN 5 THEN 'Capacitación'
        ELSE nombre
    END;
```

---

## Notas

- Este modelo es un punto de partida
- Adaptar nomenclatura al dominio del cliente
- Ajustar volúmenes según necesidad de demo
- Agregar campos específicos del negocio según sea necesario
