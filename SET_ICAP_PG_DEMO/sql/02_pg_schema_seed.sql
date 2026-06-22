-- ============================================================================
-- Demo SET-ICAP - Esquema SET-FX como tablas Iceberg (pg_lake) + seed inicial
-- Se ejecuta EN POSTGRES:  psql "service=setfx connect_timeout=10" -f este.sql
-- Requiere pg_lake habilitado (extensiones) y managed storage en la instancia.
-- ============================================================================

-- pg_lake / extensiones (idempotente; el setup script tambien las habilita)
CREATE EXTENSION IF NOT EXISTS pg_lake CASCADE;

-- ---------------------------------------------------------------------------
-- Catalogo de entidades (Intermediarios del Mercado Cambiario) - Iceberg
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS operation_set_fx;
DROP TABLE IF EXISTS entidad;

CREATE TABLE entidad (
  entidad_id      int  NOT NULL,
  entidad_sigla   text NOT NULL,
  entidad_nombre  text NOT NULL,
  entidad_clase   text NOT NULL,
  entidad_ciudad  text NOT NULL
) USING iceberg;

INSERT INTO entidad (entidad_id, entidad_sigla, entidad_nombre, entidad_clase, entidad_ciudad) VALUES
 (1,'BANREP','Banco de la República','Banco Central','Bogotá'),
 (2,'BANCOLOM','Bancolombia S.A.','Banco','Medellín'),
 (3,'BBOGOTA','Banco de Bogotá S.A.','Banco','Bogotá'),
 (4,'DAVIV','Banco Davivienda S.A.','Banco','Bogotá'),
 (5,'BBVA','BBVA Colombia S.A.','Banco','Bogotá'),
 (6,'OCCID','Banco de Occidente S.A.','Banco','Cali'),
 (7,'ITAU','Itaú Colombia S.A.','Banco','Bogotá'),
 (8,'COLPAT','Scotiabank Colpatria S.A.','Banco','Bogotá'),
 (9,'GNB','Banco GNB Sudameris S.A.','Banco','Bogotá'),
 (10,'CITI','Citibank Colombia S.A.','Banco','Bogotá'),
 (11,'JPM','JPMorgan Chase Bank Colombia','Banco','Bogotá'),
 (12,'SANTAN','Banco Santander Colombia S.A.','Banco','Bogotá'),
 (13,'BTG','BTG Pactual Colombia S.A.','Comisionista','Bogotá'),
 (14,'CREDIC','Credicorp Capital Colombia S.A.','Comisionista','Bogotá'),
 (15,'CORFICOL','Corficolombiana S.A.','Corporación Financiera','Bogotá');

-- ---------------------------------------------------------------------------
-- Operaciones FX (SET-FX) - Iceberg. Seed inicial ~2,000 operaciones.
-- TRM ancla ~3445 COP/USD (junio 2026). Horario 8:00-13:00 COT.
-- ---------------------------------------------------------------------------
CREATE TABLE operation_set_fx (
  id                 bigint     NOT NULL,
  fecha              date       NOT NULL,
  hora               time       NOT NULL,
  anulada            boolean    NOT NULL,
  mercado            int        NOT NULL,
  mcod_transaccion   text       NOT NULL,
  monto_usd          numeric(18,2) NOT NULL,
  monto_cop          numeric(20,2) NOT NULL,
  precio             numeric(12,4) NOT NULL,
  precio_spot        numeric(12,4) NOT NULL,
  plazo_curva        text       NOT NULL,
  entidad_compradora int        NOT NULL,
  entidad_vendedora  int        NOT NULL,
  texto_term         text,
  ts_carga           timestamp  NOT NULL DEFAULT now()
) USING iceberg;

INSERT INTO operation_set_fx
  (id, fecha, hora, anulada, mercado, mcod_transaccion, monto_usd, monto_cop,
   precio, precio_spot, plazo_curva, entidad_compradora, entidad_vendedora, texto_term)
SELECT
  22500000 + g                                            AS id,
  CURRENT_DATE                                            AS fecha,
  (TIME '08:00:00' + (random()*interval '5 hours'))::time AS hora,
  (random() < 0.015)                                      AS anulada,
  (ARRAY[76,76,76,77,78,79])[1+floor(random()*6)::int]    AS mercado,
  'FWSEED' || to_hex(g)                                   AS mcod_transaccion,
  m.monto_usd,
  round(m.monto_usd * p.precio, 2)                        AS monto_cop,
  p.precio,
  3445.00                                                 AS precio_spot,
  (ARRAY['T+1','T+1','T+1','T+0','1M','3M'])[1+floor(random()*6)::int] AS plazo_curva,
  1 + floor(random()*15)::int                             AS entidad_compradora,
  1 + ((floor(random()*15)::int + 3) % 15)                AS entidad_vendedora,
  CASE WHEN random() < 0.08
       THEN (ARRAY[
         'Demanda corporativa sostenida durante la sesión.',
         'Exportadores ofrecen dólares, presión a la baja.',
         'Spreads ajustados entre IMC, jornada estable.',
         'Volatilidad por dato de inflación en EE.UU.',
         'Banco de la República monitorea la TRM.'])[1+floor(random()*5)::int]
       ELSE NULL END                                      AS texto_term
FROM generate_series(1, 2000) AS g
CROSS JOIN LATERAL (
  SELECT (round((50000 + random()*1950000)/50000)*50000)::numeric(18,2) AS monto_usd
) m
CROSS JOIN LATERAL (
  SELECT round((3445 + (random()-0.5)*10)::numeric, 2) AS precio
) p;

-- Verificacion
SELECT count(*) AS operaciones, round(avg(precio),2) AS trm_prom FROM operation_set_fx;
SELECT count(*) AS entidades FROM entidad;
