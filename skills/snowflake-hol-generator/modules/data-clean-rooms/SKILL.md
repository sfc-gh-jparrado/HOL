# Sub-Skill: Data Clean Rooms

## Metadata
- **Parent**: snowflake-hol-generator
- **Name**: modules/data-clean-rooms
- **Obligatorio**: ❌ No
- **Duración**: ~25 minutos
- **Dependencias**: Setup completado, datos cargados

---

## 🎯 Objetivo

Demostrar colaboración segura de datos entre organizaciones usando Data Clean Rooms:
- Modelo de colaboración **Payer/Provider** (aseguradora + proveedor de salud)
- Acceso exclusivamente por **templates** (sin SQL directo sobre datos raw)
- Analítica **agregada** sin exponer datos individuales (PHI)
- Compliance **HIPAA** por arquitectura (no por confianza)

---

## ✅ Compatibilidad Trial

| Característica | Trial | Enterprise+ | Notas |
|---------------|-------|-------------|-------|
| Schemas separados (simulación) | ✅ | ✅ | Simula provider/consumer en misma cuenta |
| Row Access Policies | ✅ | ✅ | Disponible en todas las ediciones |
| Column Masking Policies | ✅ | ✅ | Disponible en todas las ediciones |
| Stored Procedures como Templates | ✅ | ✅ | Funciona completamente |
| ACCESS_HISTORY | ✅ | ✅ | Via ACCOUNT_USAGE (latencia ~2h) |
| Data Clean Rooms nativo (UI) | ❌ | ✅ | Requiere Enterprise+ con org-level setup |
| Cross-Account Sharing real | ❌ | ✅ | Requiere cuentas separadas |
| Snowflake DCR Collaboration API | ❌ | ✅ | Requiere habilitación por Snowflake |

> **⚠️ Nota para Trial**: Este módulo **simula** la arquitectura de un Data Clean Room usando dos schemas en la misma cuenta. Los conceptos y patrones son idénticos a los de producción, pero en Enterprise+ se usarían cuentas separadas con Secure Data Sharing.

---

## Paso 1: Arquitectura del Clean Room

```sql
-- ===========================================
-- PASO 1: CREAR ARQUITECTURA DEL CLEAN ROOM
-- ===========================================

USE DATABASE [CLIENTE_HOL];
USE WAREHOUSE [CLIENTE]_WH;

-- Schema del Provider: contiene datos raw (PHI incluido)
CREATE OR REPLACE SCHEMA PROVIDER_DATA
    COMMENT = 'Datos raw del Provider — contiene PHI, nunca expuesto directamente';

-- Schema del Consumer: solo resultados agregados
CREATE OR REPLACE SCHEMA CONSUMER_RESULTS
    COMMENT = 'Resultados agregados para el Consumer — sin PHI, solo estadísticas';

-- Schema del Clean Room: templates y políticas
CREATE OR REPLACE SCHEMA CLEAN_ROOM
    COMMENT = 'Templates de análisis aprobados y políticas de acceso';
```

### Diagrama de Arquitectura

```
┌─────────────────────────────────────────────────────────────────────┐
│                      DATA CLEAN ROOM                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌────────────────────┐    ┌────────────────────┐                  │
│  │  PROVIDER_DATA     │    │  CLEAN_ROOM        │                  │
│  │  ─────────────     │    │  ──────────        │                  │
│  │  • patients        │    │  • Templates       │                  │
│  │  • claims          │◄───│  • Row Policies    │                  │
│  │  • prescriptions   │    │  • Masking Policies│                  │
│  │                    │    │  • Audit Config    │                  │
│  │  ⚠️ PHI PRESENTE   │    └─────────┬──────────┘                  │
│  └────────────────────┘              │                              │
│                                      │ Solo vía templates           │
│                                      ▼                              │
│                         ┌────────────────────┐                     │
│                         │  CONSUMER_RESULTS  │                     │
│                         │  ────────────────  │                     │
│                         │  • Solo agregados  │                     │
│                         │  • Min grupo = 10  │                     │
│                         │  • Sin PHI         │                     │
│                         └────────────────────┘                     │
│                                      │                              │
│                                      ▼                              │
│                            ┌──────────────────┐                    │
│                            │  CONSUMER (Role)  │                   │
│                            │  Solo puede:      │                   │
│                            │  • CALL templates │                   │
│                            │  • SELECT results │                   │
│                            └──────────────────┘                    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Paso 2: Crear Datos del Provider

```sql
-- ===========================================
-- PASO 2: DATOS SINTÉTICOS DEL PROVIDER (PHI)
-- ===========================================

USE SCHEMA PROVIDER_DATA;

-- Tabla de pacientes (contiene PHI)
CREATE OR REPLACE TABLE PATIENTS (
    PATIENT_ID VARCHAR(20),
    FIRST_NAME VARCHAR(50),          -- PHI
    LAST_NAME VARCHAR(50),           -- PHI
    DATE_OF_BIRTH DATE,              -- PHI
    SSN VARCHAR(11),                 -- PHI
    GENDER VARCHAR(10),
    AGE_GROUP VARCHAR(20),
    ZIP_CODE VARCHAR(10),            -- PHI (primeros 3 dígitos OK para análisis)
    STATE_CODE VARCHAR(2),
    CHRONIC_CONDITIONS ARRAY,
    RISK_SCORE FLOAT,
    ENROLLMENT_DATE DATE,
    PLAN_TYPE VARCHAR(30)
);

-- Insertar datos sintéticos de pacientes
INSERT INTO PATIENTS
SELECT 
    'PAT-' || LPAD(SEQ4()::VARCHAR, 6, '0') AS PATIENT_ID,
    -- PHI fields (sintéticos)
    CASE MOD(SEQ4(), 10) 
        WHEN 0 THEN 'María' WHEN 1 THEN 'Carlos' WHEN 2 THEN 'Ana'
        WHEN 3 THEN 'José' WHEN 4 THEN 'Laura' WHEN 5 THEN 'Roberto'
        WHEN 6 THEN 'Carmen' WHEN 7 THEN 'Miguel' WHEN 8 THEN 'Elena'
        ELSE 'Diego' END AS FIRST_NAME,
    CASE MOD(SEQ4(), 8)
        WHEN 0 THEN 'García' WHEN 1 THEN 'Rodríguez' WHEN 2 THEN 'López'
        WHEN 3 THEN 'Martínez' WHEN 4 THEN 'Hernández' WHEN 5 THEN 'González'
        WHEN 6 THEN 'Pérez' ELSE 'Sánchez' END AS LAST_NAME,
    DATEADD('day', -UNIFORM(6570, 29200, RANDOM()), CURRENT_DATE()) AS DATE_OF_BIRTH,
    LPAD(UNIFORM(100,999,RANDOM())::VARCHAR,3,'0') || '-' || 
        LPAD(UNIFORM(10,99,RANDOM())::VARCHAR,2,'0') || '-' || 
        LPAD(UNIFORM(1000,9999,RANDOM())::VARCHAR,4,'0') AS SSN,
    CASE WHEN UNIFORM(0,1,RANDOM()) = 0 THEN 'M' ELSE 'F' END AS GENDER,
    CASE 
        WHEN UNIFORM(0,4,RANDOM()) = 0 THEN '18-30'
        WHEN UNIFORM(0,4,RANDOM()) = 1 THEN '31-45'
        WHEN UNIFORM(0,4,RANDOM()) = 2 THEN '46-60'
        WHEN UNIFORM(0,4,RANDOM()) = 3 THEN '61-75'
        ELSE '76+' END AS AGE_GROUP,
    LPAD(UNIFORM(10000,99999,RANDOM())::VARCHAR, 5, '0') AS ZIP_CODE,
    CASE MOD(SEQ4(), 5) 
        WHEN 0 THEN 'CA' WHEN 1 THEN 'TX' WHEN 2 THEN 'FL'
        WHEN 3 THEN 'NY' ELSE 'IL' END AS STATE_CODE,
    PARSE_JSON(CASE MOD(SEQ4(), 4)
        WHEN 0 THEN '["diabetes","hypertension"]'
        WHEN 1 THEN '["asthma"]'
        WHEN 2 THEN '["diabetes","CKD","hypertension"]'
        ELSE '[]' END) AS CHRONIC_CONDITIONS,
    ROUND(UNIFORM(1.0, 5.0, RANDOM())::FLOAT, 2) AS RISK_SCORE,
    DATEADD('day', -UNIFORM(30, 1095, RANDOM()), CURRENT_DATE()) AS ENROLLMENT_DATE,
    CASE MOD(SEQ4(), 3)
        WHEN 0 THEN 'HMO' WHEN 1 THEN 'PPO' ELSE 'Medicare Advantage' END AS PLAN_TYPE
FROM TABLE(GENERATOR(ROWCOUNT => 5000));

-- Tabla de reclamaciones médicas
CREATE OR REPLACE TABLE CLAIMS (
    CLAIM_ID VARCHAR(20),
    PATIENT_ID VARCHAR(20),
    SERVICE_DATE DATE,
    DIAGNOSIS_CODE VARCHAR(10),
    DIAGNOSIS_DESC VARCHAR(100),
    PROCEDURE_CODE VARCHAR(10),
    PROVIDER_NPI VARCHAR(10),
    BILLED_AMOUNT FLOAT,
    ALLOWED_AMOUNT FLOAT,
    PAID_AMOUNT FLOAT,
    CLAIM_STATUS VARCHAR(20)
);

INSERT INTO CLAIMS
SELECT
    'CLM-' || LPAD(SEQ4()::VARCHAR, 8, '0') AS CLAIM_ID,
    'PAT-' || LPAD(UNIFORM(0, 4999, RANDOM())::VARCHAR, 6, '0') AS PATIENT_ID,
    DATEADD('day', -UNIFORM(0, 365, RANDOM()), CURRENT_DATE()) AS SERVICE_DATE,
    CASE MOD(SEQ4(), 6)
        WHEN 0 THEN 'E11.9' WHEN 1 THEN 'I10' WHEN 2 THEN 'J45.20'
        WHEN 3 THEN 'N18.3' WHEN 4 THEN 'M54.5' ELSE 'Z00.00' END AS DIAGNOSIS_CODE,
    CASE MOD(SEQ4(), 6)
        WHEN 0 THEN 'Type 2 Diabetes' WHEN 1 THEN 'Essential Hypertension'
        WHEN 2 THEN 'Moderate Persistent Asthma' WHEN 3 THEN 'Chronic Kidney Disease Stage 3'
        WHEN 4 THEN 'Low Back Pain' ELSE 'General Exam' END AS DIAGNOSIS_DESC,
    CASE MOD(SEQ4(), 4)
        WHEN 0 THEN '99213' WHEN 1 THEN '99214'
        WHEN 2 THEN '99215' ELSE '99203' END AS PROCEDURE_CODE,
    LPAD(UNIFORM(1000000000, 1999999999, RANDOM())::VARCHAR, 10, '0') AS PROVIDER_NPI,
    ROUND(UNIFORM(75.0, 2500.0, RANDOM())::FLOAT, 2) AS BILLED_AMOUNT,
    ROUND(UNIFORM(50.0, 2000.0, RANDOM())::FLOAT, 2) AS ALLOWED_AMOUNT,
    ROUND(UNIFORM(40.0, 1800.0, RANDOM())::FLOAT, 2) AS PAID_AMOUNT,
    CASE MOD(SEQ4(), 4)
        WHEN 0 THEN 'PAID' WHEN 1 THEN 'PAID' 
        WHEN 2 THEN 'PENDING' ELSE 'DENIED' END AS CLAIM_STATUS
FROM TABLE(GENERATOR(ROWCOUNT => 25000));

-- Tabla de prescripciones
CREATE OR REPLACE TABLE PRESCRIPTIONS (
    RX_ID VARCHAR(20),
    PATIENT_ID VARCHAR(20),
    PRESCRIBE_DATE DATE,
    NDC_CODE VARCHAR(12),
    DRUG_NAME VARCHAR(100),
    DRUG_CLASS VARCHAR(50),
    QUANTITY INT,
    DAYS_SUPPLY INT,
    REFILLS_REMAINING INT,
    PHARMACY_NPI VARCHAR(10)
);

INSERT INTO PRESCRIPTIONS
SELECT
    'RX-' || LPAD(SEQ4()::VARCHAR, 8, '0') AS RX_ID,
    'PAT-' || LPAD(UNIFORM(0, 4999, RANDOM())::VARCHAR, 6, '0') AS PATIENT_ID,
    DATEADD('day', -UNIFORM(0, 180, RANDOM()), CURRENT_DATE()) AS PRESCRIBE_DATE,
    LPAD(UNIFORM(10000000000, 99999999999, RANDOM())::VARCHAR, 11, '0') AS NDC_CODE,
    CASE MOD(SEQ4(), 8)
        WHEN 0 THEN 'Metformin 500mg' WHEN 1 THEN 'Lisinopril 10mg'
        WHEN 2 THEN 'Atorvastatin 20mg' WHEN 3 THEN 'Albuterol Inhaler'
        WHEN 4 THEN 'Omeprazole 20mg' WHEN 5 THEN 'Amlodipine 5mg'
        WHEN 6 THEN 'Ozempic 1mg' ELSE 'Jardiance 25mg' END AS DRUG_NAME,
    CASE MOD(SEQ4(), 5)
        WHEN 0 THEN 'Antidiabetic' WHEN 1 THEN 'Antihypertensive'
        WHEN 2 THEN 'Statin' WHEN 3 THEN 'Bronchodilator'
        ELSE 'GLP-1 Agonist' END AS DRUG_CLASS,
    CASE MOD(SEQ4(), 3) WHEN 0 THEN 30 WHEN 1 THEN 60 ELSE 90 END AS QUANTITY,
    CASE MOD(SEQ4(), 3) WHEN 0 THEN 30 WHEN 1 THEN 60 ELSE 90 END AS DAYS_SUPPLY,
    UNIFORM(0, 5, RANDOM()) AS REFILLS_REMAINING,
    LPAD(UNIFORM(1000000000, 1999999999, RANDOM())::VARCHAR, 10, '0') AS PHARMACY_NPI
FROM TABLE(GENERATOR(ROWCOUNT => 15000));

-- Verificar datos creados
SELECT 'PATIENTS' AS TABLA, COUNT(*) AS FILAS FROM PATIENTS
UNION ALL
SELECT 'CLAIMS', COUNT(*) FROM CLAIMS
UNION ALL
SELECT 'PRESCRIPTIONS', COUNT(*) FROM PRESCRIPTIONS;
```

---

## Paso 3: Crear Templates de Análisis

```sql
-- ===========================================
-- PASO 3: TEMPLATES DE ANÁLISIS (CLEAN ROOM)
-- ===========================================

USE SCHEMA CLEAN_ROOM;

-- ───────────────────────────────────────────
-- TEMPLATE 1: Análisis de Overlap de Cohortes
-- ───────────────────────────────────────────
-- El consumer puede saber cuántos pacientes cumplen criterios,
-- pero NUNCA puede ver quiénes son.

CREATE OR REPLACE PROCEDURE TEMPLATE_COHORT_OVERLAP(
    P_CONDITION_1 VARCHAR,
    P_CONDITION_2 VARCHAR,
    P_MIN_GROUP_SIZE INT DEFAULT 10
)
RETURNS TABLE (
    COHORT VARCHAR,
    PATIENT_COUNT INT,
    AVG_RISK_SCORE FLOAT,
    AVG_CLAIMS_PER_PATIENT FLOAT,
    TOTAL_COST FLOAT
)
LANGUAGE SQL
AS
$$
DECLARE
    result RESULTSET;
BEGIN
    -- Validar tamaño mínimo de grupo (k-anonymity)
    IF (P_MIN_GROUP_SIZE < 10) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 
            'ERROR: Tamaño mínimo de grupo debe ser >= 10 para cumplir k-anonymity';
    END IF;

    result := (
        WITH cohort_patients AS (
            SELECT 
                p.PATIENT_ID,
                p.RISK_SCORE,
                CASE 
                    WHEN ARRAY_CONTAINS(:P_CONDITION_1::VARIANT, p.CHRONIC_CONDITIONS)
                         AND ARRAY_CONTAINS(:P_CONDITION_2::VARIANT, p.CHRONIC_CONDITIONS)
                    THEN 'Both Conditions'
                    WHEN ARRAY_CONTAINS(:P_CONDITION_1::VARIANT, p.CHRONIC_CONDITIONS)
                    THEN :P_CONDITION_1 || ' Only'
                    WHEN ARRAY_CONTAINS(:P_CONDITION_2::VARIANT, p.CHRONIC_CONDITIONS)
                    THEN :P_CONDITION_2 || ' Only'
                    ELSE 'Neither'
                END AS COHORT
            FROM PROVIDER_DATA.PATIENTS p
        ),
        cohort_claims AS (
            SELECT 
                cp.COHORT,
                cp.PATIENT_ID,
                cp.RISK_SCORE,
                COUNT(c.CLAIM_ID) AS NUM_CLAIMS,
                SUM(c.PAID_AMOUNT) AS TOTAL_PAID
            FROM cohort_patients cp
            LEFT JOIN PROVIDER_DATA.CLAIMS c ON cp.PATIENT_ID = c.PATIENT_ID
            GROUP BY cp.COHORT, cp.PATIENT_ID, cp.RISK_SCORE
        )
        SELECT 
            COHORT,
            COUNT(*) AS PATIENT_COUNT,
            ROUND(AVG(RISK_SCORE), 2) AS AVG_RISK_SCORE,
            ROUND(AVG(NUM_CLAIMS), 1) AS AVG_CLAIMS_PER_PATIENT,
            ROUND(SUM(TOTAL_PAID), 2) AS TOTAL_COST
        FROM cohort_claims
        GROUP BY COHORT
        HAVING COUNT(*) >= :P_MIN_GROUP_SIZE  -- k-anonymity enforcement
        ORDER BY PATIENT_COUNT DESC
    );
    RETURN TABLE(result);
END;
$$;

-- ───────────────────────────────────────────
-- TEMPLATE 2: Conteo Agregado de Prescripciones
-- ───────────────────────────────────────────
-- Solo muestra totales por clase de medicamento, nunca por paciente.

CREATE OR REPLACE PROCEDURE TEMPLATE_PRESCRIPTION_SUMMARY(
    P_DRUG_CLASS VARCHAR DEFAULT NULL,
    P_STATE_CODE VARCHAR DEFAULT NULL,
    P_MIN_GROUP_SIZE INT DEFAULT 10
)
RETURNS TABLE (
    DRUG_CLASS VARCHAR,
    STATE_CODE VARCHAR,
    TOTAL_PRESCRIPTIONS INT,
    UNIQUE_PATIENTS INT,
    AVG_DAYS_SUPPLY FLOAT,
    AVG_REFILLS FLOAT
)
LANGUAGE SQL
AS
$$
DECLARE
    result RESULTSET;
BEGIN
    IF (P_MIN_GROUP_SIZE < 10) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 
            'ERROR: Tamaño mínimo de grupo debe ser >= 10 para cumplir k-anonymity';
    END IF;

    result := (
        SELECT 
            rx.DRUG_CLASS,
            p.STATE_CODE,
            COUNT(*) AS TOTAL_PRESCRIPTIONS,
            COUNT(DISTINCT rx.PATIENT_ID) AS UNIQUE_PATIENTS,
            ROUND(AVG(rx.DAYS_SUPPLY), 1) AS AVG_DAYS_SUPPLY,
            ROUND(AVG(rx.REFILLS_REMAINING), 1) AS AVG_REFILLS
        FROM PROVIDER_DATA.PRESCRIPTIONS rx
        JOIN PROVIDER_DATA.PATIENTS p ON rx.PATIENT_ID = p.PATIENT_ID
        WHERE (rx.DRUG_CLASS = :P_DRUG_CLASS OR :P_DRUG_CLASS IS NULL)
          AND (p.STATE_CODE = :P_STATE_CODE OR :P_STATE_CODE IS NULL)
        GROUP BY rx.DRUG_CLASS, p.STATE_CODE
        HAVING COUNT(DISTINCT rx.PATIENT_ID) >= :P_MIN_GROUP_SIZE
        ORDER BY TOTAL_PRESCRIPTIONS DESC
    );
    RETURN TABLE(result);
END;
$$;

-- ───────────────────────────────────────────
-- TEMPLATE 3: Distribuciones Demográficas
-- ───────────────────────────────────────────
-- Solo porcentajes y conteos, nunca datos individuales.

CREATE OR REPLACE PROCEDURE TEMPLATE_DEMOGRAPHIC_DISTRIBUTION(
    P_DIAGNOSIS_CODE VARCHAR DEFAULT NULL,
    P_PLAN_TYPE VARCHAR DEFAULT NULL,
    P_MIN_GROUP_SIZE INT DEFAULT 10
)
RETURNS TABLE (
    AGE_GROUP VARCHAR,
    GENDER VARCHAR,
    PLAN_TYPE VARCHAR,
    PATIENT_COUNT INT,
    PCT_OF_TOTAL FLOAT,
    AVG_RISK_SCORE FLOAT,
    AVG_ANNUAL_COST FLOAT
)
LANGUAGE SQL
AS
$$
DECLARE
    result RESULTSET;
BEGIN
    IF (P_MIN_GROUP_SIZE < 10) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 
            'ERROR: Tamaño mínimo de grupo debe ser >= 10 para cumplir k-anonymity';
    END IF;

    result := (
        WITH filtered_patients AS (
            SELECT DISTINCT p.*
            FROM PROVIDER_DATA.PATIENTS p
            LEFT JOIN PROVIDER_DATA.CLAIMS c ON p.PATIENT_ID = c.PATIENT_ID
            WHERE (:P_DIAGNOSIS_CODE IS NULL OR c.DIAGNOSIS_CODE = :P_DIAGNOSIS_CODE)
              AND (:P_PLAN_TYPE IS NULL OR p.PLAN_TYPE = :P_PLAN_TYPE)
        ),
        demographics AS (
            SELECT 
                fp.AGE_GROUP,
                fp.GENDER,
                fp.PLAN_TYPE,
                fp.PATIENT_ID,
                fp.RISK_SCORE
            FROM filtered_patients fp
        ),
        costs AS (
            SELECT 
                d.AGE_GROUP,
                d.GENDER,
                d.PLAN_TYPE,
                d.PATIENT_ID,
                d.RISK_SCORE,
                COALESCE(SUM(c.PAID_AMOUNT), 0) AS ANNUAL_COST
            FROM demographics d
            LEFT JOIN PROVIDER_DATA.CLAIMS c ON d.PATIENT_ID = c.PATIENT_ID
                AND c.SERVICE_DATE >= DATEADD('year', -1, CURRENT_DATE())
            GROUP BY d.AGE_GROUP, d.GENDER, d.PLAN_TYPE, d.PATIENT_ID, d.RISK_SCORE
        ),
        total_count AS (
            SELECT COUNT(DISTINCT PATIENT_ID) AS TOTAL FROM costs
        )
        SELECT 
            c.AGE_GROUP,
            c.GENDER,
            c.PLAN_TYPE,
            COUNT(*) AS PATIENT_COUNT,
            ROUND(COUNT(*) * 100.0 / MAX(t.TOTAL), 2) AS PCT_OF_TOTAL,
            ROUND(AVG(c.RISK_SCORE), 2) AS AVG_RISK_SCORE,
            ROUND(AVG(c.ANNUAL_COST), 2) AS AVG_ANNUAL_COST
        FROM costs c
        CROSS JOIN total_count t
        GROUP BY c.AGE_GROUP, c.GENDER, c.PLAN_TYPE
        HAVING COUNT(*) >= :P_MIN_GROUP_SIZE
        ORDER BY PATIENT_COUNT DESC
    );
    RETURN TABLE(result);
END;
$$;
```

---

## Paso 4: Políticas de Acceso

```sql
-- ===========================================
-- PASO 4: POLÍTICAS DE SEGURIDAD
-- ===========================================

USE SCHEMA CLEAN_ROOM;

-- ───────────────────────────────────────────
-- ROW ACCESS POLICY: Bloquear acceso directo
-- ───────────────────────────────────────────
-- El consumer NO puede hacer SELECT directo sobre datos raw.
-- Solo los templates (ejecutados con caller's rights del owner) pueden leer.

CREATE OR REPLACE ROW ACCESS POLICY RAP_PROVIDER_ONLY
AS (PATIENT_ID VARCHAR) RETURNS BOOLEAN ->
    -- Solo roles del Provider pueden ver filas individuales
    CURRENT_ROLE() IN ('SYSADMIN', 'ACCOUNTADMIN', 'PROVIDER_ROLE')
    OR
    -- Los templates del Clean Room se ejecutan como owner (SYSADMIN)
    -- por lo que pasan esta política
    INVOKER_ROLE() IN ('SYSADMIN', 'ACCOUNTADMIN', 'PROVIDER_ROLE');

-- Aplicar a tablas del Provider
ALTER TABLE PROVIDER_DATA.PATIENTS 
    ADD ROW ACCESS POLICY RAP_PROVIDER_ONLY ON (PATIENT_ID);

ALTER TABLE PROVIDER_DATA.CLAIMS 
    ADD ROW ACCESS POLICY RAP_PROVIDER_ONLY ON (PATIENT_ID);

ALTER TABLE PROVIDER_DATA.PRESCRIPTIONS 
    ADD ROW ACCESS POLICY RAP_PROVIDER_ONLY ON (PATIENT_ID);

-- ───────────────────────────────────────────
-- MASKING POLICY: Ocultar PHI
-- ───────────────────────────────────────────
-- Incluso si alguien logra consultar la tabla,
-- los campos PHI están enmascarados.

CREATE OR REPLACE MASKING POLICY MASK_PHI_STRING
AS (VAL VARCHAR) RETURNS VARCHAR ->
    CASE 
        WHEN CURRENT_ROLE() IN ('SYSADMIN', 'ACCOUNTADMIN', 'PROVIDER_ROLE')
        THEN VAL
        ELSE '***REDACTED***'
    END;

CREATE OR REPLACE MASKING POLICY MASK_PHI_DATE
AS (VAL DATE) RETURNS DATE ->
    CASE 
        WHEN CURRENT_ROLE() IN ('SYSADMIN', 'ACCOUNTADMIN', 'PROVIDER_ROLE')
        THEN VAL
        ELSE DATE_FROM_PARTS(YEAR(VAL), 1, 1)  -- Solo muestra el año
    END;

-- Aplicar masking a campos PHI
ALTER TABLE PROVIDER_DATA.PATIENTS MODIFY COLUMN 
    FIRST_NAME SET MASKING POLICY MASK_PHI_STRING;
ALTER TABLE PROVIDER_DATA.PATIENTS MODIFY COLUMN 
    LAST_NAME SET MASKING POLICY MASK_PHI_STRING;
ALTER TABLE PROVIDER_DATA.PATIENTS MODIFY COLUMN 
    SSN SET MASKING POLICY MASK_PHI_STRING;
ALTER TABLE PROVIDER_DATA.PATIENTS MODIFY COLUMN 
    DATE_OF_BIRTH SET MASKING POLICY MASK_PHI_DATE;
ALTER TABLE PROVIDER_DATA.PATIENTS MODIFY COLUMN 
    ZIP_CODE SET MASKING POLICY MASK_PHI_STRING;

-- ───────────────────────────────────────────
-- CREAR ROL CONSUMER (simulación)
-- ───────────────────────────────────────────

-- Nota: En trial, usamos el rol actual como Provider y
-- creamos un rol limitado como Consumer.

CREATE OR REPLACE ROLE CONSUMER_ROLE
    COMMENT = 'Rol del Consumer — solo puede ejecutar templates y ver resultados';

-- Consumer puede usar el warehouse
GRANT USAGE ON WAREHOUSE [CLIENTE]_WH TO ROLE CONSUMER_ROLE;

-- Consumer puede usar la base de datos y schemas permitidos
GRANT USAGE ON DATABASE [CLIENTE_HOL] TO ROLE CONSUMER_ROLE;
GRANT USAGE ON SCHEMA [CLIENTE_HOL].CLEAN_ROOM TO ROLE CONSUMER_ROLE;
GRANT USAGE ON SCHEMA [CLIENTE_HOL].CONSUMER_RESULTS TO ROLE CONSUMER_ROLE;

-- Consumer puede ejecutar templates (procedures)
GRANT USAGE ON ALL PROCEDURES IN SCHEMA [CLIENTE_HOL].CLEAN_ROOM TO ROLE CONSUMER_ROLE;

-- Consumer puede ver resultados
GRANT SELECT ON ALL TABLES IN SCHEMA [CLIENTE_HOL].CONSUMER_RESULTS TO ROLE CONSUMER_ROLE;
GRANT SELECT ON FUTURE TABLES IN SCHEMA [CLIENTE_HOL].CONSUMER_RESULTS TO ROLE CONSUMER_ROLE;

-- Consumer NO tiene acceso a PROVIDER_DATA (no grant)

-- Asignar al usuario actual para poder probar
GRANT ROLE CONSUMER_ROLE TO USER CURRENT_USER();
```

---

## Paso 5: Ejecutar Análisis como Consumer

```sql
-- ===========================================
-- PASO 5: ANÁLISIS DESDE PERSPECTIVA CONSUMER
-- ===========================================

-- ───────────────────────────────────────────
-- Lo que el CONSUMER VE (resultados agregados)
-- ───────────────────────────────────────────

-- Ejecutar template de overlap de cohortes
CALL CLEAN_ROOM.TEMPLATE_COHORT_OVERLAP('diabetes', 'hypertension', 10);

-- Ejecutar template de prescripciones
CALL CLEAN_ROOM.TEMPLATE_PRESCRIPTION_SUMMARY('Antidiabetic', NULL, 10);

-- Ejecutar template demográfico
CALL CLEAN_ROOM.TEMPLATE_DEMOGRAPHIC_DISTRIBUTION('E11.9', NULL, 10);

-- ───────────────────────────────────────────
-- Lo que el CONSUMER NO PUEDE VER
-- ───────────────────────────────────────────

-- ⛔ ESTO FALLARÁ para el CONSUMER_ROLE:
-- USE ROLE CONSUMER_ROLE;
-- SELECT * FROM PROVIDER_DATA.PATIENTS LIMIT 10;
-- Error: Insufficient privileges / 0 rows returned (RAP)

-- ⛔ Intentar bajar el tamaño de grupo:
-- CALL CLEAN_ROOM.TEMPLATE_COHORT_OVERLAP('diabetes', 'hypertension', 5);
-- Error: Tamaño mínimo de grupo debe ser >= 10

-- ───────────────────────────────────────────
-- DEMOSTRACIÓN: Comparar Provider vs Consumer
-- ───────────────────────────────────────────

-- Como PROVIDER — puedes ver todo:
SELECT PATIENT_ID, FIRST_NAME, LAST_NAME, SSN, DATE_OF_BIRTH, CHRONIC_CONDITIONS
FROM PROVIDER_DATA.PATIENTS 
LIMIT 5;
-- Resultado: Datos completos visibles ✅

-- Simulación como CONSUMER (con masking):
-- Si el consumer pudiera acceder (que no puede por RAP):
-- Vería: ***REDACTED*** en FIRST_NAME, LAST_NAME, SSN
-- Vería: 1985-01-01 en vez de 1985-07-15 para DATE_OF_BIRTH

-- ───────────────────────────────────────────
-- DEMOSTRACIÓN: k-Anonymity en acción
-- ───────────────────────────────────────────

-- Grupos pequeños se ELIMINAN automáticamente
-- El template TEMPLATE_DEMOGRAPHIC_DISTRIBUTION excluye
-- combinaciones con < 10 pacientes, protegiendo identidades.

-- Ejemplo: Si solo 3 mujeres de 76+ con Medicare tienen CKD,
-- ese grupo NO aparece en los resultados.
CALL CLEAN_ROOM.TEMPLATE_DEMOGRAPHIC_DISTRIBUTION('N18.3', 'Medicare Advantage', 10);
```

---

## Paso 6: Audit y Compliance

```sql
-- ===========================================
-- PASO 6: AUDITORÍA Y COMPLIANCE HIPAA
-- ===========================================

-- ───────────────────────────────────────────
-- AUDIT LOG: Quién accedió qué y cuándo
-- ───────────────────────────────────────────

-- Nota: ACCESS_HISTORY tiene ~2h de latencia en ACCOUNT_USAGE.
-- En producción, esto alimenta reportes de compliance.

-- Ver historial de acceso a tablas del Provider
SELECT 
    QUERY_START_TIME,
    USER_NAME,
    ROLE_NAME,
    QUERY_TEXT,
    DIRECT_OBJECTS_ACCESSED,
    BASE_OBJECTS_ACCESSED
FROM SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY
WHERE ARRAY_SIZE(BASE_OBJECTS_ACCESSED) > 0
  AND BASE_OBJECTS_ACCESSED[0]:objectName::VARCHAR LIKE '%PATIENT%'
ORDER BY QUERY_START_TIME DESC
LIMIT 20;

-- ───────────────────────────────────────────
-- COMPLIANCE: Verificar que PHI no se expuso
-- ───────────────────────────────────────────

-- Ver todas las columnas accedidas (column-level audit)
SELECT 
    QUERY_START_TIME,
    USER_NAME,
    ROLE_NAME,
    f.VALUE:objectName::VARCHAR AS TABLE_NAME,
    f.VALUE:columnName::VARCHAR AS COLUMN_NAME
FROM SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY,
    LATERAL FLATTEN(input => DIRECT_OBJECTS_ACCESSED, outer => true) f
WHERE f.VALUE:objectName::VARCHAR LIKE '%PROVIDER_DATA%'
  AND QUERY_START_TIME >= DATEADD('hour', -24, CURRENT_TIMESTAMP())
ORDER BY QUERY_START_TIME DESC
LIMIT 50;

-- ───────────────────────────────────────────
-- REPORTE DE COMPLIANCE
-- ───────────────────────────────────────────

-- Crear tabla de audit en CONSUMER_RESULTS
CREATE OR REPLACE TABLE CONSUMER_RESULTS.CLEAN_ROOM_AUDIT_LOG (
    AUDIT_TIMESTAMP TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    TEMPLATE_NAME VARCHAR,
    CALLING_ROLE VARCHAR,
    PARAMETERS VARIANT,
    ROWS_RETURNED INT,
    COMPLIANT BOOLEAN DEFAULT TRUE,
    NOTES VARCHAR
);

-- Los templates pueden logear sus ejecuciones aquí
-- En producción, esto es automático con event tables.

-- ───────────────────────────────────────────
-- RESUMEN DE PROTECCIONES ACTIVAS
-- ───────────────────────────────────────────

-- Ver políticas aplicadas
SELECT 
    POLICY_NAME,
    POLICY_KIND,
    REF_ENTITY_NAME AS TABLE_NAME,
    REF_COLUMN_NAME AS COLUMN_NAME
FROM TABLE(INFORMATION_SCHEMA.POLICY_REFERENCES(
    REF_ENTITY_NAME => 'PROVIDER_DATA.PATIENTS',
    REF_ENTITY_DOMAIN => 'TABLE'
));
```

---

## Verificación

```sql
-- ===========================================
-- VERIFICACIÓN FINAL
-- ===========================================

-- 1. Verificar que las políticas están activas
SELECT 'Row Access Policies' AS CHECK_TYPE, COUNT(*) AS ACTIVE_POLICIES
FROM TABLE(INFORMATION_SCHEMA.POLICY_REFERENCES(
    REF_ENTITY_NAME => 'PROVIDER_DATA.PATIENTS',
    REF_ENTITY_DOMAIN => 'TABLE'
))
WHERE POLICY_KIND = 'ROW_ACCESS_POLICY'
UNION ALL
SELECT 'Masking Policies', COUNT(*)
FROM TABLE(INFORMATION_SCHEMA.POLICY_REFERENCES(
    REF_ENTITY_NAME => 'PROVIDER_DATA.PATIENTS',
    REF_ENTITY_DOMAIN => 'TABLE'
))
WHERE POLICY_KIND = 'MASKING_POLICY';

-- 2. Verificar que templates funcionan
CALL CLEAN_ROOM.TEMPLATE_COHORT_OVERLAP('diabetes', 'hypertension', 10);

-- 3. Verificar que k-anonymity se aplica
-- (debe devolver ERROR si min_group < 10)
-- CALL CLEAN_ROOM.TEMPLATE_COHORT_OVERLAP('diabetes', 'hypertension', 5);

-- 4. Verificar schemas creados
SHOW SCHEMAS IN DATABASE [CLIENTE_HOL] LIKE '%PROVIDER%';
SHOW SCHEMAS IN DATABASE [CLIENTE_HOL] LIKE '%CONSUMER%';
SHOW SCHEMAS IN DATABASE [CLIENTE_HOL] LIKE '%CLEAN_ROOM%';

-- 5. Verificar datos
SELECT 'PATIENTS' AS T, COUNT(*) AS N FROM PROVIDER_DATA.PATIENTS
UNION ALL SELECT 'CLAIMS', COUNT(*) FROM PROVIDER_DATA.CLAIMS
UNION ALL SELECT 'PRESCRIPTIONS', COUNT(*) FROM PROVIDER_DATA.PRESCRIPTIONS;
```

---

## Contenido HTML para el HOL

```html
<h2>🔒 Data Clean Rooms: Colaboración Segura</h2>

<p>Un Data Clean Room permite que dos organizaciones colaboren con datos 
sin exponer información sensible (PHI/PII) a la otra parte.</p>

<div class="info-box warning">
    <span class="info-icon">⚠️</span>
    <div class="info-content">
        <h4>Compliance HIPAA por Arquitectura</h4>
        <p>Este Data Clean Room cumple con HIPAA <strong>por diseño</strong>, no por confianza:</p>
        <ul>
            <li>Los datos PHI <strong>nunca salen</strong> del schema del Provider</li>
            <li>El Consumer <strong>no puede ejecutar SQL</strong> arbitrario</li>
            <li>Los resultados tienen <strong>k-anonymity</strong> (mínimo 10 pacientes por grupo)</li>
            <li>Todas las consultas quedan en <strong>ACCESS_HISTORY</strong></li>
        </ul>
    </div>
</div>

<h3>Arquitectura del Clean Room</h3>

<div class="architecture-diagram">
    <div style="display: flex; justify-content: space-between; align-items: flex-start; 
                padding: 20px; background: #f8f9fa; border-radius: 8px; border: 2px solid #dee2e6;">
        
        <!-- Provider Side -->
        <div style="flex: 1; padding: 15px; background: #fff3cd; border-radius: 8px; 
                    border: 2px solid #ffc107; margin-right: 10px;">
            <h4 style="color: #856404; margin-top: 0;">🏥 Provider (Datos Raw)</h4>
            <ul style="font-size: 0.9em;">
                <li>patients (PHI ⚠️)</li>
                <li>claims</li>
                <li>prescriptions</li>
            </ul>
            <p style="font-size: 0.8em; color: #856404;">
                <strong>Acceso:</strong> Solo PROVIDER_ROLE
            </p>
        </div>

        <!-- Clean Room Center -->
        <div style="flex: 1; padding: 15px; background: #d4edda; border-radius: 8px; 
                    border: 2px solid #28a745; margin: 0 10px;">
            <h4 style="color: #155724; margin-top: 0;">🧹 Clean Room (Templates)</h4>
            <ul style="font-size: 0.9em;">
                <li>template_cohort_overlap()</li>
                <li>template_prescription_summary()</li>
                <li>template_demographic_distribution()</li>
            </ul>
            <p style="font-size: 0.8em; color: #155724;">
                <strong>Reglas:</strong> k-anonymity, solo agregados
            </p>
        </div>

        <!-- Consumer Side -->
        <div style="flex: 1; padding: 15px; background: #cce5ff; border-radius: 8px; 
                    border: 2px solid #007bff; margin-left: 10px;">
            <h4 style="color: #004085; margin-top: 0;">🏢 Consumer (Resultados)</h4>
            <ul style="font-size: 0.9em;">
                <li>Solo agregados</li>
                <li>Min grupo = 10</li>
                <li>Sin PHI</li>
            </ul>
            <p style="font-size: 0.8em; color: #004085;">
                <strong>Acceso:</strong> CALL templates + SELECT results
            </p>
        </div>
    </div>

    <!-- Flow arrows -->
    <div style="text-align: center; padding: 10px 0; font-size: 1.2em;">
        <p style="margin: 5px 0;">
            <span style="color: #dc3545;">⛔ Consumer NO puede:</span> 
            SELECT * FROM provider_data.patients
        </p>
        <p style="margin: 5px 0;">
            <span style="color: #28a745;">✅ Consumer SÍ puede:</span> 
            CALL clean_room.template_cohort_overlap(...)
        </p>
    </div>
</div>

<div class="info-box tip">
    <span class="info-icon">💡</span>
    <div class="info-content">
        <h4>Trial vs Enterprise+</h4>
        <p>En este lab simulamos el Clean Room con <strong>schemas separados</strong> 
        en la misma cuenta. En producción con Enterprise+:</p>
        <ul>
            <li>El Provider y Consumer están en <strong>cuentas Snowflake separadas</strong></li>
            <li>Los datos se comparten via <strong>Secure Data Sharing</strong> (sin copia)</li>
            <li>La UI de <strong>Snowflake Data Clean Rooms</strong> gestiona templates y políticas</li>
            <li>La <strong>Collaboration API</strong> automatiza el lifecycle completo</li>
        </ul>
    </div>
</div>

<h3>Protecciones en Capas</h3>

<table>
    <thead>
        <tr>
            <th>Capa</th>
            <th>Mecanismo</th>
            <th>Protección</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td>1. Acceso</td>
            <td>RBAC (Roles)</td>
            <td>Consumer no tiene USAGE en PROVIDER_DATA</td>
        </tr>
        <tr>
            <td>2. Filas</td>
            <td>Row Access Policy</td>
            <td>Si accede, ve 0 filas (doble barrera)</td>
        </tr>
        <tr>
            <td>3. Columnas</td>
            <td>Masking Policy</td>
            <td>Si accede, PHI muestra ***REDACTED***</td>
        </tr>
        <tr>
            <td>4. Agregación</td>
            <td>k-Anonymity en Templates</td>
            <td>Grupos &lt; 10 se eliminan de resultados</td>
        </tr>
        <tr>
            <td>5. Auditoría</td>
            <td>ACCESS_HISTORY</td>
            <td>Todo acceso queda registrado</td>
        </tr>
    </tbody>
</table>

<div class="info-box danger">
    <span class="info-icon">🚨</span>
    <div class="info-content">
        <h4>Importante: Datos Sintéticos</h4>
        <p>Los datos en este lab son <strong>100% sintéticos</strong>. 
        Ningún nombre, SSN, o fecha de nacimiento corresponde a una persona real. 
        En producción, nunca cargue PHI real en ambientes de desarrollo o training.</p>
    </div>
</div>
```

---

## Troubleshooting

| Error | Causa | Solución |
|-------|-------|----------|
| `Insufficient privileges to operate on schema 'PROVIDER_DATA'` | Consumer intentando acceso directo | Correcto — el Consumer NO debe tener acceso. Usar templates. |
| `Tamaño mínimo de grupo debe ser >= 10` | Intentando k < 10 en template | Mantener P_MIN_GROUP_SIZE >= 10 para compliance |
| `Object does not exist or not authorized` | Falta GRANT en CLEAN_ROOM procedures | `GRANT USAGE ON ALL PROCEDURES IN SCHEMA CLEAN_ROOM TO ROLE CONSUMER_ROLE;` |
| `Row access policy conflict` | Dos RAP en misma tabla | Solo una RAP por tabla — verificar con `POLICY_REFERENCES` |
| `Masking policy already set on column` | Doble masking | `ALTER TABLE ... MODIFY COLUMN ... UNSET MASKING POLICY;` y re-aplicar |
| Template devuelve 0 filas | Todos los grupos < min_group_size | Reducir granularidad (quitar un GROUP BY) o ampliar filtros |
| `ACCESS_HISTORY` vacío | Latencia de ~2 horas | Normal en ACCOUNT_USAGE — esperar o usar `QUERY_HISTORY` para validar ejecución |
| `Cannot resolve column 'INVOKER_ROLE'` | Versión de Snowflake antigua | Usar `IS_ROLE_IN_SESSION('PROVIDER_ROLE')` como alternativa |

---

## Siguiente Módulo

- **Cortex AI**: [../cortex-ai/SKILL.md](../cortex-ai/SKILL.md)
- **Dynamic Tables**: [../dynamic-tables/SKILL.md](../dynamic-tables/SKILL.md)
