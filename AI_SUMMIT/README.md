# HOL AI Summit - IA Multimodal con Snowflake Cortex Code

Hands-on Lab de **20 minutos** para descubrir cómo Snowflake procesa **imágenes, documentos y audio** con IA nativa, y cómo cualquier persona puede crear **agentes conversacionales** usando solo lenguaje natural con **Cortex Code**.

## Qué vas a lograr

- Procesar y extraer valor de información no estructurada (imágenes, PDFs, DOCX, audio).
- Entender cómo funcionan funciones como `AI_COMPLETE`, `AI_PARSE_DOCUMENT`, `AI_EXTRACT`, `AI_TRANSCRIBE`, `AI_SENTIMENT`, `AI_CLASSIFY`.
- Crear un Cortex Search Service y un agente de IA pre-configurado.
- Usar **Cortex Code** dentro de Snowsight para generar vistas, agentes y apps Streamlit con prompts en español.

## Requisitos

- Cuenta trial de Snowflake (https://signup.snowflake.com/) en una de las regiones soportadas:
  - **AWS:** `us-west-2`, `us-east-1`, `eu-west-1`, `eu-central-1`
  - **Azure:** `westus3`, `eastus2`, `westeurope`
  - **GCP:** `us-central1`
- Rol `ACCOUNTADMIN` (lo trae cualquier trial nueva).
- Conocimientos: ninguno técnico avanzado.

## Cómo ejecutarlo (3 pasos)

1. Inicia sesión en tu cuenta trial y abre un **Worksheet** (Projects > Worksheets > +).
2. Copia y pega el contenido de [`bootstrap.sql`](bootstrap.sql) en el worksheet.
3. Selecciona todo (`Cmd/Ctrl + A`) y ejecuta (`Cmd/Ctrl + Return`).

En menos de 1 minuto tendrás:
- Base de datos `HOL_AI_SUMMIT` con stages, tablas y un agente pre-configurado.
- Un notebook llamado `NB_HOL_AI_SUMMIT` con 4 ejercicios listos.
- Un Cortex Search Service `DOCS_SEARCH` indexando los contratos.
- Un agente conversacional `AGENTE_HOL` listo para usar.

## Estructura del HOL (20 min)

| Min | Bloque | Qué se hace |
|-----|--------|------------|
| 0-1 | **Setup** | Pegar y ejecutar `bootstrap.sql` |
| 1-5 | **Ejercicio 1: Imágenes** | `AI_COMPLETE` multimodal sobre choque y cédula |
| 5-10 | **Ejercicio 2: Documentos** | `AI_PARSE_DOCUMENT` + `AI_EXTRACT` sobre contratos DOCX |
| 10-14 | **Ejercicio 3: Audio** | `AI_TRANSCRIBE` + `AI_SENTIMENT` + `AI_CLASSIFY` |
| 14-19 | **Ejercicio 4: Cortex Code** | Generar vistas, agente y Streamlit con prompts en español |
| 19-20 | **Cierre** | Demo del agente respondiendo en lenguaje natural |

## Datasets incluidos

| Tipo | Archivos | Descripción |
|------|----------|-------------|
| Imágenes | `TELCO.png`, `choque.png`, `cedula.jpg` | Logo, siniestro vehicular, documento de identidad |
| Documentos | `CONTRATO_ARRENDAMIENTO_01.docx`, `CONTRATO_ARRENDAMIENTO_02.docx` | Contratos de arrendamiento en español |
| Audio | `ofreciendo-producto.mp3`, `problema-servicio.mp3` | Llamadas de servicio al cliente en español |

## Estimación de costos

- **Créditos consumidos:** aprox. 3-5 créditos en una corrida completa.
- **Tiempo de ejecución:** ~20 minutos.
- **Storage:** menos de 10 MB.

Una trial nueva trae **400 USD de crédito** durante 30 días, por lo que puedes correr el HOL muchas veces sin preocupaciones.

## Qué diferencia a Snowflake (mensaje clave)

| Necesidad | Snowflake | Plataformas alternativas |
|-----------|-----------|--------------------------|
| Procesar imágenes | `AI_COMPLETE` con FILE | Servicio aparte (Vision API, Bedrock) + ETL |
| Parsear PDFs/DOCX | `AI_PARSE_DOCUMENT` nativo | Document AI / Azure Form Recognizer + pipeline |
| Transcripción audio | `AI_TRANSCRIBE` | Servicio Speech aparte + integración |
| Búsqueda semántica | `CORTEX SEARCH SERVICE` | Vector DB externa + embeddings + sync |
| Crear agentes | `CREATE AGENT` + Cortex Code | Frameworks de código + hosting + auth |
| Gobernanza unificada | Roles, masking, lineage end-to-end | Multiple services, policies dispersas |

**Una sola plataforma, gobernada, sin mover datos, con experiencia conversacional.** Eso es lo que demuestra este HOL.

## Troubleshooting

| Problema | Solución |
|----------|----------|
| `AI_TRANSCRIBE` no está disponible | Tu cuenta está en una región no soportada. Crea trial nueva en `us-west-2`. |
| `EXECUTE IMMEDIATE FROM` falla | Ejecuta primero `ALTER GIT REPOSITORY hol_repo FETCH;` |
| Notebook no aparece | Verifica que el repo Git haya hecho fetch correctamente con `LIST @hol_repo/branches/main/AI_SUMMIT/`. |
| El agente no responde | Verifica que el rol activo tenga `USAGE` sobre la base `HOL_AI_SUMMIT`. |

## Limpieza

Para borrar todo el HOL después de ejecutarlo:

```sql
DROP DATABASE IF EXISTS HOL_AI_SUMMIT;
DROP API INTEGRATION IF EXISTS github_hol_int;
DROP WAREHOUSE IF EXISTS HOL_WH;
```

## Soporte

Creado por el equipo Sales Engineering Latam. Para feedback, abre un issue en https://github.com/sfc-gh-jparrado/HOL/issues.
