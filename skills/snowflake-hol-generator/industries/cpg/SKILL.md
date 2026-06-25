# Sub-Skill: Industria CPG (Consumer Packaged Goods)

## Metadata
- **Parent**: snowflake-hol-generator
- **Name**: industries/cpg
- **Industria**: Bienes de Consumo, Alimentos, Bebidas, Cuidado Personal
- **Duración**: ~25 minutos adicionales

---

## 🎯 Contexto de Negocio

El HOL para CPG simula:
- Portafolio de productos y marcas
- Ventas por canal (retail, mayoreo, e-commerce)
- Promociones y trade marketing
- Inventario en puntos de venta
- Ejecución en punto de venta

---

## Datos Sintéticos

### Tabla: MARCAS
```sql
CREATE OR REPLACE TABLE RAW.MARCAS (
    ID_MARCA VARCHAR(10) PRIMARY KEY,
    NOMBRE_MARCA VARCHAR(100),
    CATEGORIA VARCHAR(50),
    SEGMENTO_PRECIO VARCHAR(20), -- PREMIUM, MAINSTREAM, VALUE
    MERCADO_OBJETIVO VARCHAR(50),
    ANIO_LANZAMIENTO NUMBER(4),
    PARTICIPACION_MERCADO NUMBER(5,2)
);

INSERT INTO RAW.MARCAS VALUES
('MRC001', 'FrescoVida', 'Bebidas', 'PREMIUM', 'Adultos salud-conscientes', 2018, 8.5),
('MRC002', 'NutriSnack', 'Snacks', 'MAINSTREAM', 'Familias', 2015, 12.3),
('MRC003', 'CleanPro', 'Limpieza Hogar', 'MAINSTREAM', 'Hogares', 2010, 15.7),
('MRC004', 'BellaCare', 'Cuidado Personal', 'PREMIUM', 'Mujeres 25-45', 2019, 6.2),
('MRC005', 'EcoFresh', 'Alimentos', 'VALUE', 'Familias precio-sensibles', 2020, 4.8),
('MRC006', 'VitaPlus', 'Bebidas', 'MAINSTREAM', 'Deportistas', 2016, 9.1),
('MRC007', 'HomeCare', 'Limpieza Hogar', 'VALUE', 'Hogares precio-sensibles', 2012, 18.5),
('MRC008', 'PureNature', 'Alimentos', 'PREMIUM', 'Consumidores orgánicos', 2021, 3.2);
```

### Tabla: PRODUCTOS
```sql
CREATE OR REPLACE TABLE RAW.PRODUCTOS (
    ID_PRODUCTO VARCHAR(10) PRIMARY KEY,
    SKU VARCHAR(20),
    NOMBRE_PRODUCTO VARCHAR(200),
    ID_MARCA VARCHAR(10),
    CATEGORIA VARCHAR(50),
    SUBCATEGORIA VARCHAR(50),
    TAMANO VARCHAR(30),
    UNIDAD_MEDIDA VARCHAR(10),
    PRECIO_LISTA NUMBER(10,2),
    COSTO NUMBER(10,2),
    CODIGO_BARRAS VARCHAR(15),
    ACTIVO BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (ID_MARCA) REFERENCES RAW.MARCAS(ID_MARCA)
);

-- Generar productos
INSERT INTO RAW.PRODUCTOS
SELECT 
    'PRD' || LPAD(SEQ4()::VARCHAR, 5, '0') AS ID_PRODUCTO,
    'SKU' || LPAD(UNIFORM(100000, 999999, RANDOM())::VARCHAR, 6, '0') AS SKU,
    ARRAY_CONSTRUCT(
        'Agua Mineral', 'Jugo Natural', 'Papas Fritas', 'Galletas', 'Detergente', 
        'Suavizante', 'Shampoo', 'Crema Corporal', 'Cereal', 'Yogurt'
    )[UNIFORM(0, 9, RANDOM())]::VARCHAR || ' ' || 
    ARRAY_CONSTRUCT('Original', 'Light', 'Premium', 'Familiar', 'Individual')[UNIFORM(0, 4, RANDOM())]::VARCHAR AS NOMBRE_PRODUCTO,
    'MRC' || LPAD(UNIFORM(1, 8, RANDOM())::VARCHAR, 3, '0') AS ID_MARCA,
    ARRAY_CONSTRUCT('Bebidas', 'Snacks', 'Limpieza Hogar', 'Cuidado Personal', 'Alimentos')[UNIFORM(0, 4, RANDOM())]::VARCHAR AS CATEGORIA,
    ARRAY_CONSTRUCT('Hidratación', 'Botanas', 'Ropa', 'Cabello', 'Lácteos', 'Cereales')[UNIFORM(0, 5, RANDOM())]::VARCHAR AS SUBCATEGORIA,
    ARRAY_CONSTRUCT('250ml', '500ml', '1L', '100g', '250g', '500g', '1kg')[UNIFORM(0, 6, RANDOM())]::VARCHAR AS TAMANO,
    ARRAY_CONSTRUCT('ml', 'g', 'kg', 'unidades')[UNIFORM(0, 3, RANDOM())]::VARCHAR AS UNIDAD_MEDIDA,
    ROUND(UNIFORM(10, 150, RANDOM())::FLOAT, 2) AS PRECIO_LISTA,
    ROUND(UNIFORM(5, 80, RANDOM())::FLOAT, 2) AS COSTO,
    LPAD(UNIFORM(1000000000000, 9999999999999, RANDOM())::VARCHAR, 13, '0') AS CODIGO_BARRAS,
    TRUE AS ACTIVO
FROM TABLE(GENERATOR(ROWCOUNT => 200));
```

### Tabla: CANALES
```sql
CREATE OR REPLACE TABLE RAW.CANALES (
    ID_CANAL VARCHAR(10) PRIMARY KEY,
    NOMBRE_CANAL VARCHAR(50),
    TIPO VARCHAR(30), -- AUTOSERVICIO, CONVENIENCIA, MAYOREO, ECOMMERCE, TRADICIONAL
    DESCRIPCION VARCHAR(200)
);

INSERT INTO RAW.CANALES VALUES
('CAN001', 'Autoservicio', 'AUTOSERVICIO', 'Supermercados y tiendas de autoservicio'),
('CAN002', 'Conveniencia', 'CONVENIENCIA', 'Tiendas de conveniencia 24/7'),
('CAN003', 'Mayoreo', 'MAYOREO', 'Clubes de precio y mayoristas'),
('CAN004', 'E-commerce', 'ECOMMERCE', 'Ventas en línea propias y marketplaces'),
('CAN005', 'Tradicional', 'TRADICIONAL', 'Tiendas de abarrotes y misceláneas'),
('CAN006', 'Farmacias', 'FARMACIAS', 'Cadenas de farmacias');
```

### Tabla: CLIENTES_RETAIL
```sql
CREATE OR REPLACE TABLE RAW.CLIENTES_RETAIL (
    ID_CLIENTE VARCHAR(10) PRIMARY KEY,
    NOMBRE_CLIENTE VARCHAR(200),
    ID_CANAL VARCHAR(10),
    REGION VARCHAR(50),
    CIUDAD VARCHAR(50),
    NUMERO_TIENDAS NUMBER,
    CATEGORIA_CLIENTE VARCHAR(20), -- A, B, C (por volumen)
    EJECUTIVO_ASIGNADO VARCHAR(100),
    FOREIGN KEY (ID_CANAL) REFERENCES RAW.CANALES(ID_CANAL)
);

INSERT INTO RAW.CLIENTES_RETAIL
SELECT 
    'RET' || LPAD(SEQ4()::VARCHAR, 5, '0') AS ID_CLIENTE,
    ARRAY_CONSTRUCT(
        'Walmart', 'Soriana', 'Chedraui', 'HEB', 'Oxxo', 'Seven Eleven', 
        'Costco', 'Sams Club', 'Amazon', 'Mercado Libre', 'Farmacias Similares',
        'Tienda Local', 'Abarrotes Centro', 'Super del Barrio'
    )[UNIFORM(0, 13, RANDOM())]::VARCHAR || ' ' || UNIFORM(1, 500, RANDOM()) AS NOMBRE_CLIENTE,
    'CAN' || LPAD(UNIFORM(1, 6, RANDOM())::VARCHAR, 3, '0') AS ID_CANAL,
    ARRAY_CONSTRUCT('Norte', 'Centro', 'Sur', 'Occidente', 'Sureste')[UNIFORM(0, 4, RANDOM())]::VARCHAR AS REGION,
    ARRAY_CONSTRUCT('Ciudad de México', 'Monterrey', 'Guadalajara', 'Puebla', 'Querétaro', 'Mérida')[UNIFORM(0, 5, RANDOM())]::VARCHAR AS CIUDAD,
    UNIFORM(1, 500, RANDOM()) AS NUMERO_TIENDAS,
    ARRAY_CONSTRUCT('A', 'A', 'B', 'B', 'B', 'C', 'C', 'C', 'C')[UNIFORM(0, 8, RANDOM())]::VARCHAR AS CATEGORIA_CLIENTE,
    'KAM ' || UNIFORM(1, 20, RANDOM()) AS EJECUTIVO_ASIGNADO
FROM TABLE(GENERATOR(ROWCOUNT => 500));
```

### Tabla: VENTAS
```sql
CREATE OR REPLACE TABLE RAW.VENTAS (
    ID_VENTA VARCHAR(20) PRIMARY KEY,
    FECHA DATE,
    ID_PRODUCTO VARCHAR(10),
    ID_CLIENTE VARCHAR(10),
    CANTIDAD NUMBER,
    PRECIO_UNITARIO NUMBER(10,2),
    DESCUENTO_PCT NUMBER(5,2),
    MONTO NUMBER(12,2),
    TIPO_PROMOCION VARCHAR(30),
    FOREIGN KEY (ID_PRODUCTO) REFERENCES RAW.PRODUCTOS(ID_PRODUCTO),
    FOREIGN KEY (ID_CLIENTE) REFERENCES RAW.CLIENTES_RETAIL(ID_CLIENTE)
);

-- Generar ventas
INSERT INTO RAW.VENTAS
SELECT 
    'VTA' || TO_CHAR(CURRENT_DATE(), 'YYYYMMDD') || LPAD(SEQ4()::VARCHAR, 8, '0') AS ID_VENTA,
    DATEADD('day', -UNIFORM(1, 365, RANDOM()), CURRENT_DATE()) AS FECHA,
    'PRD' || LPAD(UNIFORM(1, 200, RANDOM())::VARCHAR, 5, '0') AS ID_PRODUCTO,
    'RET' || LPAD(UNIFORM(1, 500, RANDOM())::VARCHAR, 5, '0') AS ID_CLIENTE,
    UNIFORM(1, 500, RANDOM()) AS CANTIDAD,
    ROUND(UNIFORM(10, 150, RANDOM())::FLOAT, 2) AS PRECIO_UNITARIO,
    CASE WHEN UNIFORM(1, 10, RANDOM()) <= 4 THEN UNIFORM(5, 30, RANDOM()) ELSE 0 END AS DESCUENTO_PCT,
    ROUND(UNIFORM(1, 500, RANDOM()) * UNIFORM(10, 150, RANDOM())::FLOAT * (1 - UNIFORM(0, 30, RANDOM())/100), 2) AS MONTO,
    CASE WHEN UNIFORM(1, 10, RANDOM()) <= 4 
         THEN ARRAY_CONSTRUCT('2x1', '3x2', 'Descuento directo', 'Bundle', 'Precio especial')[UNIFORM(0, 4, RANDOM())]::VARCHAR 
         ELSE NULL END AS TIPO_PROMOCION
FROM TABLE(GENERATOR(ROWCOUNT => 50000));
```

### Tabla: INVENTARIO_PDV
```sql
CREATE OR REPLACE TABLE RAW.INVENTARIO_PDV (
    ID_REGISTRO VARCHAR(20) PRIMARY KEY,
    FECHA DATE,
    ID_PRODUCTO VARCHAR(10),
    ID_CLIENTE VARCHAR(10),
    STOCK_UNIDADES NUMBER,
    DIAS_INVENTARIO NUMBER,
    FACING NUMBER, -- Número de caras en anaquel
    PRECIO_ANAQUEL NUMBER(10,2),
    EN_PROMOCION BOOLEAN,
    AGOTADO BOOLEAN
);

-- Generar inventario
INSERT INTO RAW.INVENTARIO_PDV
SELECT 
    'INV' || TO_CHAR(CURRENT_DATE(), 'YYYYMMDD') || LPAD(SEQ4()::VARCHAR, 8, '0') AS ID_REGISTRO,
    DATEADD('day', -UNIFORM(0, 30, RANDOM()), CURRENT_DATE()) AS FECHA,
    'PRD' || LPAD(UNIFORM(1, 200, RANDOM())::VARCHAR, 5, '0') AS ID_PRODUCTO,
    'RET' || LPAD(UNIFORM(1, 500, RANDOM())::VARCHAR, 5, '0') AS ID_CLIENTE,
    UNIFORM(0, 500, RANDOM()) AS STOCK_UNIDADES,
    UNIFORM(0, 45, RANDOM()) AS DIAS_INVENTARIO,
    UNIFORM(1, 6, RANDOM()) AS FACING,
    ROUND(UNIFORM(10, 150, RANDOM())::FLOAT, 2) AS PRECIO_ANAQUEL,
    UNIFORM(1, 10, RANDOM()) <= 3 AS EN_PROMOCION,
    UNIFORM(1, 100, RANDOM()) <= 5 AS AGOTADO
FROM TABLE(GENERATOR(ROWCOUNT => 20000));
```

---

## Vistas Analíticas

```sql
-- Vista de ventas por marca y canal
CREATE OR REPLACE VIEW ANALYTICS.V_VENTAS_MARCA_CANAL AS
SELECT 
    DATE_TRUNC('MONTH', v.FECHA) AS MES,
    m.NOMBRE_MARCA,
    m.CATEGORIA,
    m.SEGMENTO_PRECIO,
    cn.NOMBRE_CANAL,
    
    -- Volumen
    SUM(v.CANTIDAD) AS UNIDADES_VENDIDAS,
    SUM(v.MONTO) AS VENTA_NETA,
    
    -- Precio promedio
    ROUND(SUM(v.MONTO) / NULLIF(SUM(v.CANTIDAD), 0), 2) AS PRECIO_PROMEDIO,
    
    -- Margen
    SUM(v.MONTO) - SUM(v.CANTIDAD * p.COSTO) AS MARGEN_BRUTO,
    ROUND((SUM(v.MONTO) - SUM(v.CANTIDAD * p.COSTO)) / NULLIF(SUM(v.MONTO), 0) * 100, 2) AS MARGEN_PCT,
    
    -- Promociones
    ROUND(COUNT(CASE WHEN v.TIPO_PROMOCION IS NOT NULL THEN 1 END)::FLOAT / 
          NULLIF(COUNT(*), 0) * 100, 2) AS PCT_VENTAS_PROMOCION

FROM RAW.VENTAS v
JOIN RAW.PRODUCTOS p ON v.ID_PRODUCTO = p.ID_PRODUCTO
JOIN RAW.MARCAS m ON p.ID_MARCA = m.ID_MARCA
JOIN RAW.CLIENTES_RETAIL cr ON v.ID_CLIENTE = cr.ID_CLIENTE
JOIN RAW.CANALES cn ON cr.ID_CANAL = cn.ID_CANAL
GROUP BY DATE_TRUNC('MONTH', v.FECHA), m.NOMBRE_MARCA, m.CATEGORIA, m.SEGMENTO_PRECIO, cn.NOMBRE_CANAL;

-- Vista de ejecución en punto de venta
CREATE OR REPLACE VIEW ANALYTICS.V_EJECUCION_PDV AS
SELECT 
    i.FECHA,
    cr.NOMBRE_CLIENTE,
    cn.NOMBRE_CANAL,
    cr.REGION,
    
    -- Disponibilidad
    COUNT(*) AS TOTAL_SKUS_MEDIDOS,
    COUNT(CASE WHEN NOT i.AGOTADO THEN 1 END) AS SKUS_DISPONIBLES,
    ROUND(COUNT(CASE WHEN NOT i.AGOTADO THEN 1 END)::FLOAT / NULLIF(COUNT(*), 0) * 100, 2) AS DISPONIBILIDAD_PCT,
    
    -- Agotados
    COUNT(CASE WHEN i.AGOTADO THEN 1 END) AS SKUS_AGOTADOS,
    
    -- Inventario
    ROUND(AVG(i.DIAS_INVENTARIO), 1) AS DIAS_INV_PROMEDIO,
    
    -- Exhibición
    ROUND(AVG(i.FACING), 1) AS FACING_PROMEDIO,
    
    -- Promociones
    COUNT(CASE WHEN i.EN_PROMOCION THEN 1 END) AS SKUS_EN_PROMOCION

FROM RAW.INVENTARIO_PDV i
JOIN RAW.CLIENTES_RETAIL cr ON i.ID_CLIENTE = cr.ID_CLIENTE
JOIN RAW.CANALES cn ON cr.ID_CANAL = cn.ID_CANAL
GROUP BY i.FECHA, cr.NOMBRE_CLIENTE, cn.NOMBRE_CANAL, cr.REGION;

-- Vista de participación de mercado simulada
CREATE OR REPLACE VIEW ANALYTICS.V_PARTICIPACION_MERCADO AS
SELECT 
    DATE_TRUNC('MONTH', v.FECHA) AS MES,
    p.CATEGORIA,
    m.NOMBRE_MARCA,
    SUM(v.MONTO) AS VENTAS_MARCA,
    SUM(SUM(v.MONTO)) OVER (PARTITION BY DATE_TRUNC('MONTH', v.FECHA), p.CATEGORIA) AS VENTAS_CATEGORIA,
    ROUND(SUM(v.MONTO) / NULLIF(SUM(SUM(v.MONTO)) OVER (PARTITION BY DATE_TRUNC('MONTH', v.FECHA), p.CATEGORIA), 0) * 100, 2) AS SHARE_PCT
FROM RAW.VENTAS v
JOIN RAW.PRODUCTOS p ON v.ID_PRODUCTO = p.ID_PRODUCTO
JOIN RAW.MARCAS m ON p.ID_MARCA = m.ID_MARCA
GROUP BY DATE_TRUNC('MONTH', v.FECHA), p.CATEGORIA, m.NOMBRE_MARCA;
```

---

## Preguntas Sugeridas para el Agente

- "¿Cuál es la participación de mercado por marca en Bebidas?"
- "Top 10 productos por volumen de ventas"
- "Efectividad de promociones por canal"
- "¿Cuál es la disponibilidad en anaquel por región?"
- "Margen bruto por categoría y segmento de precio"
- "Tendencia de ventas por canal últimos 6 meses"
- "Productos con mayor tasa de agotamiento"
- "Comparativo de precio promedio por canal"
