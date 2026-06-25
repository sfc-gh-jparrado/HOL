# Sub-Skill: Customer 360

## Metadata
- **Parent**: snowflake-hol-generator
- **Name**: cross-functional/customer-360
- **Área**: Vista Unificada del Cliente
- **Aplicable a**: Todas las industrias
- **Duración**: ~20 minutos adicionales

---

## 🎯 Contexto de Negocio

Este módulo transversal implementa una vista 360° del cliente:
- Consolidación de datos de múltiples fuentes
- Segmentación dinámica
- Customer Lifetime Value (CLV)
- Propensión a compra/churn
- Next Best Action

---

## Arquitectura de Datos

```
┌─────────────────────────────────────────────────────────────┐
│                    FUENTES DE DATOS                         │
├─────────────┬──────────────┬──────────────┬────────────────┤
│   CRM       │  E-Commerce  │   Soporte    │   Marketing    │
│  (Ventas)   │ (Transacc.)  │  (Tickets)   │  (Campañas)    │
└──────┬──────┴──────┬───────┴──────┬───────┴───────┬────────┘
       │             │              │               │
       ▼             ▼              ▼               ▼
┌─────────────────────────────────────────────────────────────┐
│                  GOLDEN RECORD CLIENTE                       │
│  - ID único                                                  │
│  - Datos maestros consolidados                              │
│  - Métricas calculadas (CLV, RFM, Propensión)              │
└─────────────────────────────────────────────────────────────┘
```

---

## Datos Sintéticos

### Tabla: CLIENTES_MASTER
```sql
CREATE OR REPLACE TABLE RAW.CLIENTES_MASTER (
    ID_CLIENTE VARCHAR(15) PRIMARY KEY,
    -- Datos de identidad
    EMAIL VARCHAR(100),
    TELEFONO VARCHAR(20),
    NOMBRE VARCHAR(100),
    APELLIDO VARCHAR(100),
    FECHA_NACIMIENTO DATE,
    GENERO VARCHAR(20),
    
    -- Datos de ubicación
    DIRECCION VARCHAR(300),
    CIUDAD VARCHAR(50),
    ESTADO VARCHAR(50),
    CODIGO_POSTAL VARCHAR(10),
    PAIS VARCHAR(50),
    
    -- Datos de origen
    FECHA_PRIMER_CONTACTO DATE,
    CANAL_ADQUISICION VARCHAR(30),
    FUENTE_ORIGINAL VARCHAR(50),
    
    -- Flags
    ACEPTA_MARKETING BOOLEAN,
    VERIFICADO BOOLEAN,
    ESTATUS VARCHAR(20),
    
    -- Metadata
    CREATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- Generar clientes master
INSERT INTO RAW.CLIENTES_MASTER
SELECT 
    'CLI' || LPAD(SEQ4()::VARCHAR, 8, '0') AS ID_CLIENTE,
    LOWER(ARRAY_CONSTRUCT('juan', 'maria', 'carlos', 'ana', 'pedro', 'laura', 'diego', 'sofia')[UNIFORM(0, 7, RANDOM())]::VARCHAR || 
    '.' || ARRAY_CONSTRUCT('garcia', 'lopez', 'martinez', 'rodriguez', 'hernandez')[UNIFORM(0, 4, RANDOM())]::VARCHAR || 
    UNIFORM(1, 999, RANDOM())::VARCHAR || '@email.com') AS EMAIL,
    '+52' || UNIFORM(5500000000, 5599999999, RANDOM())::VARCHAR AS TELEFONO,
    ARRAY_CONSTRUCT('Juan', 'María', 'Carlos', 'Ana', 'Pedro', 'Laura', 'Diego', 'Sofía')[UNIFORM(0, 7, RANDOM())]::VARCHAR AS NOMBRE,
    ARRAY_CONSTRUCT('García', 'López', 'Martínez', 'Rodríguez', 'Hernández', 'González', 'Sánchez')[UNIFORM(0, 6, RANDOM())]::VARCHAR AS APELLIDO,
    DATEADD('year', -UNIFORM(18, 70, RANDOM()), CURRENT_DATE()) AS FECHA_NACIMIENTO,
    ARRAY_CONSTRUCT('Masculino', 'Femenino', 'No especificado')[UNIFORM(0, 2, RANDOM())]::VARCHAR AS GENERO,
    'Calle ' || UNIFORM(1, 500, RANDOM()) || ' #' || UNIFORM(1, 999, RANDOM()) AS DIRECCION,
    ARRAY_CONSTRUCT('Ciudad de México', 'Monterrey', 'Guadalajara', 'Puebla', 'Querétaro', 'Mérida')[UNIFORM(0, 5, RANDOM())]::VARCHAR AS CIUDAD,
    ARRAY_CONSTRUCT('CDMX', 'Nuevo León', 'Jalisco', 'Puebla', 'Querétaro', 'Yucatán')[UNIFORM(0, 5, RANDOM())]::VARCHAR AS ESTADO,
    LPAD(UNIFORM(10000, 99999, RANDOM())::VARCHAR, 5, '0') AS CODIGO_POSTAL,
    'México' AS PAIS,
    DATEADD('day', -UNIFORM(30, 1825, RANDOM()), CURRENT_DATE()) AS FECHA_PRIMER_CONTACTO,
    ARRAY_CONSTRUCT('Orgánico', 'Paid Search', 'Social Media', 'Referido', 'Email', 'Evento')[UNIFORM(0, 5, RANDOM())]::VARCHAR AS CANAL_ADQUISICION,
    ARRAY_CONSTRUCT('Google', 'Facebook', 'Instagram', 'Referencia', 'Tienda', 'LinkedIn')[UNIFORM(0, 5, RANDOM())]::VARCHAR AS FUENTE_ORIGINAL,
    UNIFORM(1, 10, RANDOM()) <= 7 AS ACEPTA_MARKETING,
    UNIFORM(1, 10, RANDOM()) <= 8 AS VERIFICADO,
    ARRAY_CONSTRUCT('ACTIVO', 'ACTIVO', 'ACTIVO', 'INACTIVO', 'SUSPENDIDO')[UNIFORM(0, 4, RANDOM())]::VARCHAR AS ESTATUS,
    CURRENT_TIMESTAMP() AS CREATED_AT,
    CURRENT_TIMESTAMP() AS UPDATED_AT
FROM TABLE(GENERATOR(ROWCOUNT => 10000));
```

### Tabla: TRANSACCIONES
```sql
CREATE OR REPLACE TABLE RAW.TRANSACCIONES (
    ID_TRANSACCION VARCHAR(20) PRIMARY KEY,
    ID_CLIENTE VARCHAR(15),
    FECHA TIMESTAMP,
    CANAL VARCHAR(20), -- WEB, APP, TIENDA, TELEFONO
    MONTO NUMBER(12,2),
    PRODUCTOS NUMBER,
    CATEGORIA_PRINCIPAL VARCHAR(50),
    DESCUENTO_APLICADO NUMBER(10,2),
    METODO_PAGO VARCHAR(30),
    ESTATUS VARCHAR(20),
    FOREIGN KEY (ID_CLIENTE) REFERENCES RAW.CLIENTES_MASTER(ID_CLIENTE)
);

-- Generar transacciones
INSERT INTO RAW.TRANSACCIONES
SELECT 
    'TXN' || TO_CHAR(CURRENT_DATE(), 'YYYYMMDD') || LPAD(SEQ4()::VARCHAR, 8, '0') AS ID_TRANSACCION,
    'CLI' || LPAD(UNIFORM(1, 10000, RANDOM())::VARCHAR, 8, '0') AS ID_CLIENTE,
    DATEADD('minute', -UNIFORM(1, 525600, RANDOM()), CURRENT_TIMESTAMP()) AS FECHA,
    ARRAY_CONSTRUCT('WEB', 'WEB', 'APP', 'TIENDA', 'TELEFONO')[UNIFORM(0, 4, RANDOM())]::VARCHAR AS CANAL,
    ROUND(UNIFORM(50, 10000, RANDOM())::FLOAT, 2) AS MONTO,
    UNIFORM(1, 10, RANDOM()) AS PRODUCTOS,
    ARRAY_CONSTRUCT('Electrónicos', 'Ropa', 'Hogar', 'Deportes', 'Alimentos', 'Salud')[UNIFORM(0, 5, RANDOM())]::VARCHAR AS CATEGORIA_PRINCIPAL,
    CASE WHEN UNIFORM(1, 10, RANDOM()) <= 4 THEN ROUND(UNIFORM(10, 500, RANDOM())::FLOAT, 2) ELSE 0 END AS DESCUENTO_APLICADO,
    ARRAY_CONSTRUCT('Tarjeta Crédito', 'Tarjeta Débito', 'PayPal', 'Transferencia', 'Efectivo')[UNIFORM(0, 4, RANDOM())]::VARCHAR AS METODO_PAGO,
    ARRAY_CONSTRUCT('COMPLETADA', 'COMPLETADA', 'COMPLETADA', 'COMPLETADA', 'PENDIENTE', 'CANCELADA')[UNIFORM(0, 5, RANDOM())]::VARCHAR AS ESTATUS
FROM TABLE(GENERATOR(ROWCOUNT => 50000));
```

### Tabla: INTERACCIONES_SOPORTE
```sql
CREATE OR REPLACE TABLE RAW.INTERACCIONES_SOPORTE (
    ID_INTERACCION VARCHAR(15) PRIMARY KEY,
    ID_CLIENTE VARCHAR(15),
    FECHA TIMESTAMP,
    CANAL VARCHAR(30),
    TIPO VARCHAR(30), -- CONSULTA, QUEJA, SOLICITUD, FELICITACION
    CATEGORIA VARCHAR(50),
    RESOLUCION VARCHAR(20),
    TIEMPO_RESOLUCION_HORAS NUMBER,
    CSAT_SCORE NUMBER(1),
    FOREIGN KEY (ID_CLIENTE) REFERENCES RAW.CLIENTES_MASTER(ID_CLIENTE)
);

-- Generar interacciones de soporte
INSERT INTO RAW.INTERACCIONES_SOPORTE
SELECT 
    'INT' || LPAD(SEQ4()::VARCHAR, 8, '0') AS ID_INTERACCION,
    'CLI' || LPAD(UNIFORM(1, 10000, RANDOM())::VARCHAR, 8, '0') AS ID_CLIENTE,
    DATEADD('hour', -UNIFORM(1, 8760, RANDOM()), CURRENT_TIMESTAMP()) AS FECHA,
    ARRAY_CONSTRUCT('Chat', 'Teléfono', 'Email', 'Redes Sociales', 'Tienda')[UNIFORM(0, 4, RANDOM())]::VARCHAR AS CANAL,
    ARRAY_CONSTRUCT('CONSULTA', 'QUEJA', 'SOLICITUD', 'FELICITACION')[UNIFORM(0, 3, RANDOM())]::VARCHAR AS TIPO,
    ARRAY_CONSTRUCT('Pedidos', 'Facturación', 'Producto', 'Devolución', 'Cuenta', 'Otro')[UNIFORM(0, 5, RANDOM())]::VARCHAR AS CATEGORIA,
    ARRAY_CONSTRUCT('RESUELTO', 'RESUELTO', 'RESUELTO', 'ESCALADO', 'PENDIENTE')[UNIFORM(0, 4, RANDOM())]::VARCHAR AS RESOLUCION,
    UNIFORM(1, 72, RANDOM()) AS TIEMPO_RESOLUCION_HORAS,
    UNIFORM(1, 5, RANDOM()) AS CSAT_SCORE
FROM TABLE(GENERATOR(ROWCOUNT => 15000));
```

### Tabla: EVENTOS_MARKETING
```sql
CREATE OR REPLACE TABLE RAW.EVENTOS_MARKETING (
    ID_EVENTO VARCHAR(15) PRIMARY KEY,
    ID_CLIENTE VARCHAR(15),
    FECHA TIMESTAMP,
    CAMPANA VARCHAR(100),
    CANAL VARCHAR(30),
    TIPO_EVENTO VARCHAR(30), -- SENT, OPEN, CLICK, CONVERSION
    FOREIGN KEY (ID_CLIENTE) REFERENCES RAW.CLIENTES_MASTER(ID_CLIENTE)
);

-- Generar eventos de marketing
INSERT INTO RAW.EVENTOS_MARKETING
SELECT 
    'MKT' || LPAD(SEQ4()::VARCHAR, 8, '0') AS ID_EVENTO,
    'CLI' || LPAD(UNIFORM(1, 10000, RANDOM())::VARCHAR, 8, '0') AS ID_CLIENTE,
    DATEADD('hour', -UNIFORM(1, 4380, RANDOM()), CURRENT_TIMESTAMP()) AS FECHA,
    ARRAY_CONSTRUCT('Newsletter Mensual', 'Promo Temporada', 'Abandono Carrito', 'Reactivación', 'Nuevo Producto')[UNIFORM(0, 4, RANDOM())]::VARCHAR AS CAMPANA,
    ARRAY_CONSTRUCT('Email', 'SMS', 'Push', 'WhatsApp')[UNIFORM(0, 3, RANDOM())]::VARCHAR AS CANAL,
    ARRAY_CONSTRUCT('SENT', 'SENT', 'OPEN', 'OPEN', 'CLICK', 'CONVERSION')[UNIFORM(0, 5, RANDOM())]::VARCHAR AS TIPO_EVENTO
FROM TABLE(GENERATOR(ROWCOUNT => 100000));
```

---

## Vista Customer 360

```sql
-- Vista principal Customer 360
CREATE OR REPLACE VIEW ANALYTICS.V_CUSTOMER_360 AS
SELECT 
    c.ID_CLIENTE,
    c.NOMBRE || ' ' || c.APELLIDO AS NOMBRE_COMPLETO,
    c.EMAIL,
    c.TELEFONO,
    c.CIUDAD,
    c.FECHA_PRIMER_CONTACTO,
    c.CANAL_ADQUISICION,
    DATEDIFF('day', c.FECHA_PRIMER_CONTACTO, CURRENT_DATE()) AS DIAS_COMO_CLIENTE,
    DATEDIFF('year', c.FECHA_NACIMIENTO, CURRENT_DATE()) AS EDAD,
    c.GENERO,
    c.ACEPTA_MARKETING,
    
    -- Métricas transaccionales
    COALESCE(t.TOTAL_TRANSACCIONES, 0) AS TOTAL_COMPRAS,
    COALESCE(t.VALOR_TOTAL, 0) AS VALOR_TOTAL_COMPRAS,
    COALESCE(t.TICKET_PROMEDIO, 0) AS TICKET_PROMEDIO,
    t.ULTIMA_COMPRA,
    DATEDIFF('day', t.ULTIMA_COMPRA, CURRENT_DATE()) AS DIAS_DESDE_ULTIMA_COMPRA,
    t.CANAL_PREFERIDO,
    t.CATEGORIA_FAVORITA,
    
    -- RFM Scores
    CASE 
        WHEN DATEDIFF('day', t.ULTIMA_COMPRA, CURRENT_DATE()) <= 30 THEN 5
        WHEN DATEDIFF('day', t.ULTIMA_COMPRA, CURRENT_DATE()) <= 60 THEN 4
        WHEN DATEDIFF('day', t.ULTIMA_COMPRA, CURRENT_DATE()) <= 90 THEN 3
        WHEN DATEDIFF('day', t.ULTIMA_COMPRA, CURRENT_DATE()) <= 180 THEN 2
        ELSE 1
    END AS RECENCY_SCORE,
    CASE 
        WHEN COALESCE(t.TOTAL_TRANSACCIONES, 0) >= 20 THEN 5
        WHEN COALESCE(t.TOTAL_TRANSACCIONES, 0) >= 10 THEN 4
        WHEN COALESCE(t.TOTAL_TRANSACCIONES, 0) >= 5 THEN 3
        WHEN COALESCE(t.TOTAL_TRANSACCIONES, 0) >= 2 THEN 2
        ELSE 1
    END AS FREQUENCY_SCORE,
    CASE 
        WHEN COALESCE(t.VALOR_TOTAL, 0) >= 50000 THEN 5
        WHEN COALESCE(t.VALOR_TOTAL, 0) >= 20000 THEN 4
        WHEN COALESCE(t.VALOR_TOTAL, 0) >= 10000 THEN 3
        WHEN COALESCE(t.VALOR_TOTAL, 0) >= 5000 THEN 2
        ELSE 1
    END AS MONETARY_SCORE,
    
    -- Segmentación RFM
    CASE 
        WHEN CASE WHEN DATEDIFF('day', t.ULTIMA_COMPRA, CURRENT_DATE()) <= 30 THEN 5
             WHEN DATEDIFF('day', t.ULTIMA_COMPRA, CURRENT_DATE()) <= 60 THEN 4
             WHEN DATEDIFF('day', t.ULTIMA_COMPRA, CURRENT_DATE()) <= 90 THEN 3
             WHEN DATEDIFF('day', t.ULTIMA_COMPRA, CURRENT_DATE()) <= 180 THEN 2
             ELSE 1 END >= 4 AND COALESCE(t.TOTAL_TRANSACCIONES, 0) >= 10 AND COALESCE(t.VALOR_TOTAL, 0) >= 20000 THEN '💎 Champions'
        WHEN CASE WHEN DATEDIFF('day', t.ULTIMA_COMPRA, CURRENT_DATE()) <= 30 THEN 5 ELSE 1 END >= 4 AND COALESCE(t.TOTAL_TRANSACCIONES, 0) < 5 THEN '🌟 Nuevos Prometedores'
        WHEN CASE WHEN DATEDIFF('day', t.ULTIMA_COMPRA, CURRENT_DATE()) <= 90 THEN 3 ELSE 1 END >= 3 AND COALESCE(t.VALOR_TOTAL, 0) >= 10000 THEN '🎯 Leales'
        WHEN DATEDIFF('day', t.ULTIMA_COMPRA, CURRENT_DATE()) > 180 AND COALESCE(t.VALOR_TOTAL, 0) >= 20000 THEN '😴 En Riesgo - Alto Valor'
        WHEN DATEDIFF('day', t.ULTIMA_COMPRA, CURRENT_DATE()) > 180 THEN '❄️ Hibernando'
        ELSE '👋 Casuales'
    END AS SEGMENTO_RFM,
    
    -- CLV Estimado (simplificado)
    ROUND(COALESCE(t.VALOR_TOTAL, 0) * 
          (12.0 / NULLIF(GREATEST(DATEDIFF('month', c.FECHA_PRIMER_CONTACTO, CURRENT_DATE()), 1), 0)) * 
          3, 2) AS CLV_ESTIMADO_3Y,
    
    -- Interacciones soporte
    COALESCE(s.TOTAL_TICKETS, 0) AS TOTAL_TICKETS_SOPORTE,
    COALESCE(s.QUEJAS, 0) AS TOTAL_QUEJAS,
    s.CSAT_PROMEDIO,
    
    -- Engagement marketing
    COALESCE(m.EMAILS_RECIBIDOS, 0) AS EMAILS_RECIBIDOS,
    COALESCE(m.EMAILS_ABIERTOS, 0) AS EMAILS_ABIERTOS,
    ROUND(COALESCE(m.EMAILS_ABIERTOS, 0)::FLOAT / NULLIF(COALESCE(m.EMAILS_RECIBIDOS, 0), 0) * 100, 2) AS OPEN_RATE,
    
    c.ESTATUS

FROM RAW.CLIENTES_MASTER c
LEFT JOIN (
    SELECT 
        ID_CLIENTE,
        COUNT(*) AS TOTAL_TRANSACCIONES,
        SUM(MONTO) AS VALOR_TOTAL,
        ROUND(AVG(MONTO), 2) AS TICKET_PROMEDIO,
        MAX(FECHA) AS ULTIMA_COMPRA,
        MODE(CANAL) AS CANAL_PREFERIDO,
        MODE(CATEGORIA_PRINCIPAL) AS CATEGORIA_FAVORITA
    FROM RAW.TRANSACCIONES
    WHERE ESTATUS = 'COMPLETADA'
    GROUP BY ID_CLIENTE
) t ON c.ID_CLIENTE = t.ID_CLIENTE
LEFT JOIN (
    SELECT 
        ID_CLIENTE,
        COUNT(*) AS TOTAL_TICKETS,
        COUNT(CASE WHEN TIPO = 'QUEJA' THEN 1 END) AS QUEJAS,
        ROUND(AVG(CSAT_SCORE), 2) AS CSAT_PROMEDIO
    FROM RAW.INTERACCIONES_SOPORTE
    GROUP BY ID_CLIENTE
) s ON c.ID_CLIENTE = s.ID_CLIENTE
LEFT JOIN (
    SELECT 
        ID_CLIENTE,
        COUNT(CASE WHEN TIPO_EVENTO = 'SENT' THEN 1 END) AS EMAILS_RECIBIDOS,
        COUNT(CASE WHEN TIPO_EVENTO = 'OPEN' THEN 1 END) AS EMAILS_ABIERTOS
    FROM RAW.EVENTOS_MARKETING
    WHERE CANAL = 'Email'
    GROUP BY ID_CLIENTE
) m ON c.ID_CLIENTE = m.ID_CLIENTE;
```

---

## Vistas Adicionales

```sql
-- Vista de segmentación
CREATE OR REPLACE VIEW ANALYTICS.V_SEGMENTOS_CLIENTES AS
SELECT 
    SEGMENTO_RFM,
    COUNT(*) AS TOTAL_CLIENTES,
    ROUND(COUNT(*)::FLOAT / SUM(COUNT(*)) OVER () * 100, 2) AS PCT_BASE,
    ROUND(AVG(VALOR_TOTAL_COMPRAS), 2) AS VALOR_PROMEDIO,
    ROUND(AVG(TOTAL_COMPRAS), 1) AS COMPRAS_PROMEDIO,
    ROUND(AVG(DIAS_DESDE_ULTIMA_COMPRA), 0) AS DIAS_INACTIVO_PROMEDIO,
    ROUND(AVG(CLV_ESTIMADO_3Y), 2) AS CLV_PROMEDIO
FROM ANALYTICS.V_CUSTOMER_360
GROUP BY SEGMENTO_RFM
ORDER BY CLV_PROMEDIO DESC;

-- Vista de Next Best Action
CREATE OR REPLACE VIEW ANALYTICS.V_NEXT_BEST_ACTION AS
SELECT 
    ID_CLIENTE,
    NOMBRE_COMPLETO,
    SEGMENTO_RFM,
    VALOR_TOTAL_COMPRAS,
    DIAS_DESDE_ULTIMA_COMPRA,
    CATEGORIA_FAVORITA,
    
    CASE 
        WHEN SEGMENTO_RFM = '😴 En Riesgo - Alto Valor' THEN 'Campaña de reactivación personalizada'
        WHEN SEGMENTO_RFM = '💎 Champions' THEN 'Programa de lealtad VIP'
        WHEN SEGMENTO_RFM = '🌟 Nuevos Prometedores' THEN 'Onboarding + primera promoción'
        WHEN SEGMENTO_RFM = '❄️ Hibernando' THEN 'Win-back con descuento agresivo'
        WHEN SEGMENTO_RFM = '🎯 Leales' THEN 'Cross-sell categorías complementarias'
        ELSE 'Nurturing general'
    END AS NEXT_BEST_ACTION,
    
    CASE 
        WHEN SEGMENTO_RFM IN ('😴 En Riesgo - Alto Valor', '💎 Champions') THEN 'ALTA'
        WHEN SEGMENTO_RFM IN ('🌟 Nuevos Prometedores', '🎯 Leales') THEN 'MEDIA'
        ELSE 'BAJA'
    END AS PRIORIDAD

FROM ANALYTICS.V_CUSTOMER_360
WHERE ESTATUS = 'ACTIVO' AND ACEPTA_MARKETING = TRUE
ORDER BY CLV_ESTIMADO_3Y DESC;
```

---

## Preguntas Sugeridas para el Agente

- "¿Cuántos clientes tengo en cada segmento RFM?"
- "Top 20 clientes por CLV estimado"
- "¿Qué clientes de alto valor están en riesgo?"
- "Distribución de clientes por canal de adquisición"
- "¿Cuál es el ticket promedio por segmento?"
- "Clientes Champions que no han abierto emails"
- "Resumen de Next Best Action por prioridad"
- "Comparativo de CLV por ciudad"
