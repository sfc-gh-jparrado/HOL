# Snowflake Hands-On Lab Generator

<p align="center">
  <img src="https://www.logo.wine/a/logo/Snowflake_Inc./Snowflake_Inc.-Logo.wine.svg" alt="Snowflake" width="180" height="180">
</p>

<p align="center">
  <strong>Genera laboratorios prácticos de Snowflake personalizados por industria</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-3.0-blue" alt="Version">
  <img src="https://img.shields.io/badge/industries-11-green" alt="Industries">
  <img src="https://img.shields.io/badge/modules-11-orange" alt="Modules">
  <img src="https://img.shields.io/badge/trial_compatible-yes-success" alt="Trial Compatible">
</p>

---

## Descripción

Este skill genera Hands-On Labs (HOLs) de Snowflake completamente personalizados para clientes y prospectos. Los labs generados:

- Funcionan en **cuentas trial** sin configuraciones especiales
- Usan **datos sintéticos** relevantes a la industria del cliente
- Son **modulares** (cada módulo es independiente)
- Incluyen **HTML autocontenido** listo para usar
- Pasan un **control de calidad exhaustivo**

---

## Instalación

### En Cortex Code

```bash
# El skill se carga automáticamente desde:
/Users/[usuario]/Documents/COCO/skills/snowflake-hol-generator/

# Para invocar el skill, usar cualquiera de estos triggers:
- "crear hol"
- "hands-on lab"
- "laboratorio snowflake"
- "demo lab"
- "hol para [cliente]"
- "generar laboratorio"
```

### Exportar a otro entorno

```bash
# Copiar la carpeta completa
cp -r skills/snowflake-hol-generator /destino/skills/

# Estructura requerida:
snowflake-hol-generator/
├── SKILL.md          # Entry point (requerido)
├── README.md         # Este archivo
├── qa-checklist.md   # QA obligatorio
├── setup/
├── modules/
├── industries/
├── cross-functional/
├── references/
└── templates/
```

---

## Uso Rápido

### 1. Invocar el skill

```
Usuario: crear hol para Acme Corp
```

### 2. Responder las preguntas

El skill preguntará:
- Nombre del cliente
- URL del sitio web
- Industria
- Si es cuenta trial
- Módulos a incluir
- Casos transversales

### 3. Recibir el output

El skill genera:
- HTML autocontenido con el lab completo
- Scripts SQL separados por paso
- Script de cleanup
- Reporte de QA

---

## Industrias Soportadas

| Industria | Archivo | Descripción |
|-----------|---------|-------------|
| Retail/CPG | `retail-cpg/` | Tiendas, e-commerce, omnicanalidad |
| Manufactura | `manufacturing/` | Producción, calidad, supply chain |
| Servicios Financieros | `financial-services/` | Banca, seguros, créditos, AML |
| Healthcare/Pharma | `healthcare-pharma/` | Hospitales, farma, visitadores |
| Tecnología/SaaS | `technology-saas/` | MRR, ARR, churn, cohortes |
| Logística | `logistics/` | Flotas, entregas, tracking GPS |
| Energía/Utilities | `energy-utilities/` | Medidores, lecturas, facturación |
| Telecomunicaciones | `telecommunications/` | Suscriptores, uso, red, churn |
| CPG | `cpg/` | Marcas, retail, PDV, inventario |
| BPO | `bpo/` | Contact center, agentes, NPS |
| Genérico | `generic/` | Modelo adaptable |

---

## Módulos Técnicos

| Módulo | Descripción | Trial Compatible |
|--------|-------------|------------------|
| **Snowflake Intelligence** | Semantic Views, Cortex Analyst, preguntas NL | ✅ (via Snowsight UI) |
| **Cortex AI Functions** | SENTIMENT, COMPLETE, SUMMARIZE, TRANSLATE | ✅ |
| **Dynamic Tables** | Pipelines automáticos con TARGET_LAG | ✅ |
| **Time Travel** | Recuperación de datos, AT(OFFSET), CLONE | ✅ |
| **Marketplace** | Datasets externos gratuitos | ✅ |
| **Streamlit** | Dashboards interactivos en Snowflake | ✅ |

---

## Módulos Cross-Functional

| Módulo | Casos de Uso |
|--------|--------------|
| **Finanzas** | P&G, reportes trimestrales, análisis de varianza |
| **RRHH** | Performance, análisis de CVs con NLP, rotación |
| **Ventas** | Pipeline, forecasting, win/loss, desempeño |
| **Operaciones** | KPIs real-time, alertas, SLAs, compliance |
| **Customer 360** | RFM, CLV, Next Best Action, vista unificada |

---

## Templates de Output

### HTML
- Estructura responsive completa
- Progress tracker con localStorage
- Syntax highlighting para SQL
- Botón "Copiar código"
- Botón "Abrir en Snowsight"

### CSS
- Variables de branding Snowflake
- Componentes: cards, callouts, tables, code blocks
- Estilos responsive y print-friendly
- Animaciones suaves

### JavaScript
- Tracking de progreso por paso
- Persistencia en localStorage
- Atajos de teclado (Alt+1-9, Alt+C, Alt+N/P)
- Analytics events

---

## Branding

### Colores Snowflake

| Color | Hex | Uso |
|-------|-----|-----|
| Azul Principal | `#29B5E8` | CTAs, links, highlights |
| Azul Oscuro | `#1565C0` | Headers, gradients |
| Verde | `#51cf66` | Success, completado |
| Rojo | `#ff6b6b` | Error, danger |
| Amarillo | `#ffd43b` | Warning, tips |

### Logo

```html
<img src="https://www.logo.wine/a/logo/Snowflake_Inc./Snowflake_Inc.-Logo.wine.svg" 
     alt="Snowflake" 
     width="180" 
     height="180">
```

---

## Control de Calidad (QA)

Cada HOL generado pasa por un checklist de QA obligatorio que valida:

1. **Sintaxis SQL** - Statements completos, paréntesis balanceados
2. **Compatibilidad Trial** - No usar funciones restringidas
3. **Consistencia de Datos** - FKs válidas, rangos correctos
4. **Flujo Lógico** - Pasos secuenciales, dependencias claras
5. **Documentación** - Instrucciones claras, sin jerga
6. **Seguridad** - Sin credenciales, sin PII real

Ver [qa-checklist.md](qa-checklist.md) para el checklist completo.

---

## Limitaciones en Trial

| Funcionalidad | Estado | Alternativa |
|---------------|--------|-------------|
| `SYSTEM$CORTEX_ANALYST_FAST_GENERATION` | ❌ | Snowsight UI |
| CREATE SEMANTIC VIEW (SQL) | ⚠️ | Snowsight Autopilot |
| CREATE AGENT (SQL) | ⚠️ | Snowsight UI |
| Snowpark Container Services | ❌ | Omitir |

---

## Estructura de Archivos

```
snowflake-hol-generator/
├── SKILL.md                    # Entry point principal
├── README.md                   # Documentación (este archivo)
├── qa-checklist.md             # Checklist QA obligatorio
│
├── setup/
│   └── SKILL.md                # Setup inicial obligatorio
│
├── modules/
│   ├── intelligence/SKILL.md   # Cortex Analyst
│   ├── cortex-ai/SKILL.md      # AI Functions
│   ├── dynamic-tables/SKILL.md # Dynamic Tables
│   ├── time-travel/SKILL.md    # Time Travel
│   ├── marketplace/SKILL.md    # Marketplace
│   └── streamlit/SKILL.md      # Streamlit
│
├── industries/                 # 11 industrias
│   ├── retail-cpg/
│   ├── manufacturing/
│   ├── financial-services/
│   ├── healthcare-pharma/
│   ├── technology-saas/
│   ├── logistics/
│   ├── energy-utilities/
│   ├── telecommunications/
│   ├── cpg/
│   ├── bpo/
│   └── generic/
│
├── cross-functional/           # 5 módulos transversales
│   ├── finance/
│   ├── hr-analytics/
│   ├── sales-analytics/
│   ├── operations/
│   └── customer-360/
│
├── references/
│   ├── marketplace-datasets.md
│   ├── trial-limitations.md
│   ├── sql-patterns.md
│   └── troubleshooting.md
│
└── templates/
    ├── html-template.md
    ├── css-styles.md
    └── js-functions.md
```

---

## Contribuir

### Agregar nueva industria

1. Crear carpeta `industries/nueva-industria/`
2. Crear `SKILL.md` siguiendo el template de industrias existentes
3. Incluir:
   - Modelo de datos (mínimo 5 tablas)
   - SQL de generación de datos sintéticos
   - Vistas analíticas sugeridas
   - Preguntas para Cortex Analyst
4. Actualizar `SKILL.md` principal

### Agregar nuevo módulo

1. Crear carpeta en `modules/` o `cross-functional/`
2. Seguir estructura de módulos existentes
3. Asegurar independencia (solo dependencia de setup)
4. Actualizar documentación

---

## Changelog

| Versión | Fecha | Cambios |
|---------|-------|---------|
| 3.0 | 2025-01 | +7 industrias, +3 cross-functional, QA obligatorio, templates |
| 2.0 | 2024-11 | Arquitectura modular, compatibilidad trial |
| 1.0 | 2024-10 | Versión inicial |

---

## Soporte

Para reportar issues o sugerir mejoras:
- Abrir issue en el repositorio
- Contactar al equipo de Professional Services

---

## Licencia

Uso interno Snowflake. No distribuir externamente sin autorización.

---

<p align="center">
  <sub>Generado con Snowflake HOL Generator v3.0</sub>
</p>
