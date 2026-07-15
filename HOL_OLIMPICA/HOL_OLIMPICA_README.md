# HOL Olímpica — "De S3 a Snowflake CoWork"

Hands-on Lab end-to-end para una cadena de retail colombiana (**Olímpica**): carga masiva desde Amazon S3, gobierno con masking dinámico (AI_REDACT), Cortex AI Functions, Cortex AI multimodal, Cortex Search, Dynamic Tables, Cortex Analyst y **Snowflake CoWork**.

> **Datos sintéticos.** Todos los nombres, métricas e indicadores son ficticios, generados para fines demostrativos a partir de una muestra del cliente.

---

## Contenido de la carpeta

| Archivo | Descripción |
|---|---|
| `olimpica_hol.html` | HOL interactivo self-contained (12 pasos, ~100 min). Incluye botón **Descargar SQL**. |
| `HOL_OLIMPICA.sql` | Script SQL completo, comentado por partes, para recorrer en un Worksheet de Snowflake. |
| `README.md` | Esta guía. |

---

## Prerrequisitos

- Cuenta Snowflake con rol `ACCOUNTADMIN`.
- Una **Storage Integration** con acceso de lectura al bucket S3 del dataset (`s3://demosjparrado/olimpica_hol/`).
- Cortex habilitado (cross-region: `ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';`).

---

## Modelo de datos (~347M filas)

Origen: **3 archivos del cliente** normalizados a un esquema estrella (4 dimensiones + 4 hechos), enlazados por la dimensión **TIENDA** (POS ↔ auditorías) y un crosswalk **PRODUCTO** `PLU_SAP ↔ GTIN` (POS ↔ sell-out).

| Tabla | Filas | Origen |
|---|---|---|
| `DIM_TIENDA` / `DIM_PRODUCTO` / `DIM_PROVEEDOR` / `DIM_PROMO` | 1.8K / 50K / 2K / 20K | dimensiones compartidas |
| `FACT_VENTA_LINEA` | 150M | Ventas POS |
| `FACT_SELLOUT_INV` | 150M | Sell-out + inventario de proveedor (GS1) |
| `FACT_TICKET` | 39M | tickets POS |
| `FACT_CHECKLIST` | 8M | auditorías operativas de tienda (con observaciones de texto libre para IA) |

---

## Recorrido (12 partes)

1. Setup del ambiente
2. Stage S3 + carga COPY INTO (~347M filas)
3. Performance & análisis cruzado
4. Time Travel & Zero-Copy Cloning
5. Masking dinámico por rol (con `AI_REDACT`)
6. Cortex AI Functions (sobre observaciones de auditoría)
7. Cortex AI Multimodal (PDF, imágenes, audio)
8. Cortex Search (búsqueda semántica)
9. Dynamic Table incremental
10. Semantic View + Cortex Analyst
11. Snowflake CoWork (agente conversacional)
12. Recursos & Limpieza

Tiempo estimado: **~100 min**.

---

## Limpieza

```sql
USE ROLE ACCOUNTADMIN;
DROP DATABASE  IF EXISTS DB_HOL_OLIMPICA;
DROP DATABASE  IF EXISTS DB_HOL_OLIMPICA_DEV;
DROP WAREHOUSE IF EXISTS WH_HOL_OLIMPICA;
DROP ROLE      IF EXISTS ANALISTA_OPERACIONES;
```

---

© 2026 Snowflake Inc. Datos sintéticos para fines demostrativos.
