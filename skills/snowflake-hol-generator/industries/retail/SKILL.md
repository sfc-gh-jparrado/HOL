# Sub-Skill: Industria Retail

## Metadata
- **Parent**: snowflake-hol-generator
- **Name**: industries/retail
- **Industria**: Retail / E-commerce
- **Duración**: ~25 minutos adicionales

---

## 🎯 Contexto de Negocio

El HOL para retail simula una empresa con:
- Múltiples tiendas/canales de venta
- Catálogo de productos por categoría
- Historial de transacciones y clientes
- Gestión de inventario

---

## Datos Sintéticos

### Tabla: TIENDAS
```sql
CREATE OR REPLACE TABLE RAW.TIENDAS (
    ID_TIENDA VARCHAR(10) PRIMARY KEY,
    NOMBRE_TIENDA VARCHAR(100),
    TIPO VARCHAR(20), -- FISICA, ONLINE, POPUP
    REGION VARCHAR(50),
    CIUDAD VARCHAR(50),
    DIRECCION VARCHAR(200),
    FECHA_APERTURA DATE,
    METROS_CUADRADOS NUMBER,
    NUM_EMPLEADOS NUMBER
);

-- Datos de ejemplo (adaptar con nombre de cliente)
INSERT INTO RAW.TIENDAS VALUES
('T001', '[CLIENTE] Centro', 'FISICA', 'Centro', 'Ciudad de México', 'Av. Reforma 123', '2018-03-15', 500, 15),
('T002', '[CLIENTE] Norte', 'FISICA', 'Norte', 'Monterrey', 'Av. Constitución 456', '2019-06-20', 400, 12),
('T003', '[CLIENTE] Sur', 'FISICA', 'Sur', 'Guadalajara', 'Av. Vallarta 789', '2020-01-10', 350, 10),
('T004', '[CLIENTE] Online', 'ONLINE', 'Nacional', 'Digital', 'www.[cliente].com', '2020-06-01', 0, 8),
('T005', '[CLIENTE] Express', 'POPUP', 'Centro', 'Ciudad de México', 'Plaza Satélite', '2023-11-01', 50, 3);
```

### Tabla: PRODUCTOS
```sql
CREATE OR REPLACE TABLE RAW.PRODUCTOS (
    ID_PRODUCTO VARCHAR(10) PRIMARY KEY,
    SKU VARCHAR(20),
    NOMBRE_PRODUCTO VARCHAR(200),
    CATEGORIA VARCHAR(50),
    SUBCATEGORIA VARCHAR(50),
    MARCA VARCHAR(50),
    PRECIO_LISTA NUMBER(10,2),
    COSTO NUMBER(10,2),
    PROVEEDOR VARCHAR(100),
    ACTIVO BOOLEAN DEFAULT TRUE
);

-- Generar productos variados
INSERT INTO RAW.PRODUCTOS
SELECT 
    'P' || LPAD(SEQ4()::VARCHAR, 4, '0') AS ID_PRODUCTO,
    'SKU-' || UNIFORM(10000, 99999, RANDOM()) AS SKU,
    ARRAY_CONSTRUCT(
        'Camiseta Básica', 'Pantalón Casual', 'Vestido Elegante', 'Zapatos Deportivos',
        'Bolso Premium', 'Reloj Clásico', 'Gafas de Sol', 'Cinturón Cuero',
        'Sudadera Urban', 'Chaqueta Invierno', 'Bufanda Lana', 'Gorra Sport'
    )[UNIFORM(0, 11, RANDOM())]::VARCHAR || ' ' || UNIFORM(1, 100, RANDOM()) AS NOMBRE_PRODUCTO,
    ARRAY_CONSTRUCT('Ropa', 'Calzado', 'Accesorios', 'Deportes')[UNIFORM(0, 3, RANDOM())]::VARCHAR AS CATEGORIA,
    ARRAY_CONSTRUCT('Hombre', 'Mujer', 'Unisex', 'Niños')[UNIFORM(0, 3, RANDOM())]::VARCHAR AS SUBCATEGORIA,
    ARRAY_CONSTRUCT('MarcaA', 'MarcaB', 'MarcaC', 'MarcaD', 'MarcaE')[UNIFORM(0, 4, RANDOM())]::VARCHAR AS MARCA,
    ROUND(UNIFORM(15, 500, RANDOM())::FLOAT, 2) AS PRECIO_LISTA,
    ROUND(UNIFORM(5, 200, RANDOM())::FLOAT, 2) AS COSTO,
    ARRAY_CONSTRUCT('Proveedor Alpha', 'Proveedor Beta', 'Proveedor Gamma')[UNIFORM(0, 2, RANDOM())]::VARCHAR AS PROVEEDOR,
    TRUE AS ACTIVO
FROM TABLE(GENERATOR(ROWCOUNT => 200));
```

### Tabla: CLIENTES
```sql
CREATE OR REPLACE TABLE RAW.CLIENTES (
    ID_CLIENTE VARCHAR(10) PRIMARY KEY,
    NOMBRE VARCHAR(100),
    EMAIL VARCHAR(100),
    TELEFONO VARCHAR(20),
    FECHA_REGISTRO DATE,
    SEGMENTO VARCHAR(20), -- VIP, PREMIUM, REGULAR, NUEVO
    PUNTOS_ACUMULADOS NUMBER DEFAULT 0,
    CIUDAD VARCHAR(50),
    CANAL_ADQUISICION VARCHAR(30)
);

-- Generar clientes
INSERT INTO RAW.CLIENTES
SELECT 
    'C' || LPAD(SEQ4()::VARCHAR, 5, '0') AS ID_CLIENTE,
    ARRAY_CONSTRUCT('Juan', 'María', 'Carlos', 'Ana', 'Pedro', 'Laura', 'Diego', 'Sofia')[UNIFORM(0, 7, RANDOM())]::VARCHAR || ' ' ||
    ARRAY_CONSTRUCT('García', 'Rodríguez', 'López', 'Martínez', 'González', 'Hernández')[UNIFORM(0, 5, RANDOM())]::VARCHAR AS NOMBRE,
    LOWER(REPLACE(ARRAY_CONSTRUCT('Juan', 'María', 'Carlos', 'Ana', 'Pedro', 'Laura')[UNIFORM(0, 5, RANDOM())]::VARCHAR || 
    UNIFORM(100, 999, RANDOM())::VARCHAR || '@email.com', ' ', '')) AS EMAIL,
    '+52' || UNIFORM(5500000000, 5599999999, RANDOM())::VARCHAR AS TELEFONO,
    DATEADD('day', -UNIFORM(1, 1000, RANDOM()), CURRENT_DATE()) AS FECHA_REGISTRO,
    ARRAY_CONSTRUCT('VIP', 'VIP', 'PREMIUM', 'PREMIUM', 'PREMIUM', 'REGULAR', 'REGULAR', 'REGULAR', 'REGULAR', 'NUEVO')[UNIFORM(0, 9, RANDOM())]::VARCHAR AS SEGMENTO,
    UNIFORM(0, 5000, RANDOM()) AS PUNTOS_ACUMULADOS,
    ARRAY_CONSTRUCT('Ciudad de México', 'Monterrey', 'Guadalajara', 'Puebla', 'Querétaro')[UNIFORM(0, 4, RANDOM())]::VARCHAR AS CIUDAD,
    ARRAY_CONSTRUCT('Orgánico', 'Redes Sociales', 'Google Ads', 'Referido', 'Tienda')[UNIFORM(0, 4, RANDOM())]::VARCHAR AS CANAL_ADQUISICION
FROM TABLE(GENERATOR(ROWCOUNT => 1000));
```

### Tabla: VENTAS
```sql
CREATE OR REPLACE TABLE RAW.VENTAS (
    ID_VENTA VARCHAR(15) PRIMARY KEY,
    FECHA TIMESTAMP,
    ID_TIENDA VARCHAR(10),
    ID_CLIENTE VARCHAR(10),
    ID_PRODUCTO VARCHAR(10),
    CANTIDAD NUMBER,
    PRECIO_UNITARIO NUMBER(10,2),
    DESCUENTO_PCT NUMBER(5,2),
    MONTO NUMBER(12,2),
    METODO_PAGO VARCHAR(20),
    FOREIGN KEY (ID_TIENDA) REFERENCES RAW.TIENDAS(ID_TIENDA),
    FOREIGN KEY (ID_CLIENTE) REFERENCES RAW.CLIENTES(ID_CLIENTE),
    FOREIGN KEY (ID_PRODUCTO) REFERENCES RAW.PRODUCTOS(ID_PRODUCTO)
);

-- Generar ventas
INSERT INTO RAW.VENTAS
SELECT 
    'V' || TO_CHAR(CURRENT_DATE(), 'YYYYMMDD') || LPAD(SEQ4()::VARCHAR, 6, '0') AS ID_VENTA,
    DATEADD('minute', -UNIFORM(1, 525600, RANDOM()), CURRENT_TIMESTAMP()) AS FECHA,
    'T00' || UNIFORM(1, 5, RANDOM()) AS ID_TIENDA,
    'C' || LPAD(UNIFORM(1, 1000, RANDOM())::VARCHAR, 5, '0') AS ID_CLIENTE,
    'P' || LPAD(UNIFORM(1, 200, RANDOM())::VARCHAR, 4, '0') AS ID_PRODUCTO,
    UNIFORM(1, 5, RANDOM()) AS CANTIDAD,
    p.PRECIO_LISTA AS PRECIO_UNITARIO,
    CASE WHEN UNIFORM(1, 10, RANDOM()) <= 3 THEN UNIFORM(5, 30, RANDOM()) ELSE 0 END AS DESCUENTO_PCT,
    ROUND(UNIFORM(1, 5, RANDOM()) * p.PRECIO_LISTA * (1 - CASE WHEN UNIFORM(1, 10, RANDOM()) <= 3 THEN UNIFORM(5, 30, RANDOM())/100 ELSE 0 END), 2) AS MONTO,
    ARRAY_CONSTRUCT('Efectivo', 'Tarjeta Crédito', 'Tarjeta Débito', 'Transferencia', 'Puntos')[UNIFORM(0, 4, RANDOM())]::VARCHAR AS METODO_PAGO
FROM TABLE(GENERATOR(ROWCOUNT => 10000)) g
JOIN RAW.PRODUCTOS p ON p.ID_PRODUCTO = 'P' || LPAD(UNIFORM(1, 200, RANDOM())::VARCHAR, 4, '0');
```

### Tabla: INVENTARIO
```sql
CREATE OR REPLACE TABLE RAW.INVENTARIO (
    ID_TIENDA VARCHAR(10),
    ID_PRODUCTO VARCHAR(10),
    STOCK_ACTUAL NUMBER,
    STOCK_MINIMO NUMBER,
    STOCK_MAXIMO NUMBER,
    ULTIMO_REABASTECIMIENTO DATE,
    PRIMARY KEY (ID_TIENDA, ID_PRODUCTO)
);

-- Generar inventario por tienda-producto
INSERT INTO RAW.INVENTARIO
SELECT 
    t.ID_TIENDA,
    p.ID_PRODUCTO,
    UNIFORM(0, 100, RANDOM()) AS STOCK_ACTUAL,
    10 AS STOCK_MINIMO,
    100 AS STOCK_MAXIMO,
    DATEADD('day', -UNIFORM(1, 30, RANDOM()), CURRENT_DATE()) AS ULTIMO_REABASTECIMIENTO
FROM RAW.TIENDAS t
CROSS JOIN RAW.PRODUCTOS p
WHERE UNIFORM(1, 10, RANDOM()) <= 7; -- No todos los productos en todas las tiendas
```

---

## Vistas Analíticas

```sql
-- Vista principal de análisis
CREATE OR REPLACE VIEW ANALYTICS.V_VENTAS_RETAIL AS
SELECT 
    v.ID_VENTA,
    v.FECHA,
    DATE_TRUNC('DAY', v.FECHA) AS DIA,
    DATE_TRUNC('MONTH', v.FECHA) AS MES,
    DAYNAME(v.FECHA) AS DIA_SEMANA,
    HOUR(v.FECHA) AS HORA,
    
    -- Tienda
    t.ID_TIENDA,
    t.NOMBRE_TIENDA,
    t.TIPO AS TIPO_TIENDA,
    t.REGION,
    t.CIUDAD AS CIUDAD_TIENDA,
    
    -- Producto
    p.ID_PRODUCTO,
    p.NOMBRE_PRODUCTO,
    p.CATEGORIA,
    p.SUBCATEGORIA,
    p.MARCA,
    p.COSTO AS COSTO_UNITARIO,
    
    -- Cliente
    c.ID_CLIENTE,
    c.NOMBRE AS NOMBRE_CLIENTE,
    c.SEGMENTO,
    c.CIUDAD AS CIUDAD_CLIENTE,
    
    -- Métricas
    v.CANTIDAD,
    v.PRECIO_UNITARIO,
    v.DESCUENTO_PCT,
    v.MONTO AS INGRESO,
    v.CANTIDAD * p.COSTO AS COSTO_TOTAL,
    v.MONTO - (v.CANTIDAD * p.COSTO) AS MARGEN,
    v.METODO_PAGO

FROM RAW.VENTAS v
JOIN RAW.TIENDAS t ON v.ID_TIENDA = t.ID_TIENDA
JOIN RAW.PRODUCTOS p ON v.ID_PRODUCTO = p.ID_PRODUCTO
JOIN RAW.CLIENTES c ON v.ID_CLIENTE = c.ID_CLIENTE;

-- Vista de inventario con alertas
CREATE OR REPLACE VIEW ANALYTICS.V_ALERTAS_INVENTARIO AS
SELECT 
    t.NOMBRE_TIENDA,
    p.NOMBRE_PRODUCTO,
    p.CATEGORIA,
    i.STOCK_ACTUAL,
    i.STOCK_MINIMO,
    CASE 
        WHEN i.STOCK_ACTUAL = 0 THEN '🔴 Sin Stock'
        WHEN i.STOCK_ACTUAL < i.STOCK_MINIMO THEN '🟡 Stock Bajo'
        ELSE '🟢 OK'
    END AS ESTADO_STOCK,
    i.ULTIMO_REABASTECIMIENTO,
    DATEDIFF('day', i.ULTIMO_REABASTECIMIENTO, CURRENT_DATE()) AS DIAS_SIN_REABASTECIMIENTO
FROM RAW.INVENTARIO i
JOIN RAW.TIENDAS t ON i.ID_TIENDA = t.ID_TIENDA
JOIN RAW.PRODUCTOS p ON i.ID_PRODUCTO = p.ID_PRODUCTO
ORDER BY i.STOCK_ACTUAL ASC;
```

---

## Preguntas Sugeridas para el Agente

- "¿Cuáles son las ventas totales del último mes por tienda?"
- "¿Qué categoría de producto tiene mejor margen?"
- "¿Cuál es el ticket promedio por segmento de cliente?"
- "¿Qué productos están con stock bajo?"
- "¿Cuál es la tendencia de ventas por día de la semana?"
- "Top 10 clientes por monto de compra"
- "Comparar ventas tienda física vs online"

---

## Datasets de Marketplace Recomendados

- **Weather Source**: Correlacionar ventas con clima
- **Cybersyn Consumer Behavior**: Patrones de consumo
- **Knoema Demographics**: Datos demográficos por región
