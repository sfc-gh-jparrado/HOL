---
name: snowflake-hol-generator
description: "Generates customized Snowflake Hands-on Labs (single HOL or multi-HOL workshops) fully compatible with trial accounts. Uses upfront planning with user approval and parallel generation via subagents for maximum speed. Use when: crear hol, hands-on lab, laboratorio snowflake, demo lab, hol para, generar laboratorio, create hol, generate lab, workshop, taller, multi-lab. Triggers: crear hol, hands-on lab, laboratorio snowflake, demo lab, hol para, generar laboratorio, create hol, generate lab, workshop, taller, multi-lab."
---

# Snowflake Hands-on Lab Generator

This skill automates end-to-end creation of **Snowflake Hands-on Labs** — either a single self-contained HTML lab, or a **multi-HOL workshop** with multiple connected labs, shared narrative, and a landing index page. Given a client name, industry, and website URL, it researches the client, generates a plan for approval, launches parallel subagents, assembles the HTML(s), and runs automated QA.

**Load**: [references/hol-reference.md](references/hol-reference.md) for trial compatibility, industries, modules, branding, rules, and metrics.

**For enterprise-scale, real-data (S3), SQL-first HOLs** (cientos de millones de filas, ingesta desde S3, Cortex multimodal, DT plana de consumo, agente CoWork en español) — **Load**: [references/real-data-and-advanced-patterns.md](references/real-data-and-advanced-patterns.md). Estos patrones complementan el modo por defecto (datos sintéticos con `GENERATOR`).

---

## Step 0: Determine Delivery Mode ⚠️ STOP — Ask first

Ask the user:

- **Mode**: Single HOL or Multi-HOL Workshop?
  - **Single HOL**: One self-contained lab covering selected modules (~45-90 min)
  - **Workshop**: Multiple connected labs with shared narrative, progressive complexity, and an index landing page (~2-6 labs, 3-8 hours total)

**If Single HOL** → proceed to [Single HOL Workflow](#single-hol-workflow-8-steps) (unchanged behavior).
**If Workshop** → proceed to [Workshop Workflow](#workshop-workflow-10-steps).

---

# Single HOL Workflow (8 Steps)

### Step 1: Collect Client Information ⚠️ STOP — Collect before proceeding

Ask the user:

1. **Client/prospect name**
2. **Website URL** (to research the business)
3. **Primary industry**: Retail/CPG, Manufacturing, Financial Services, Healthcare/Pharma, Technology/SaaS, Logistics/Transport, Energy/Utilities, Telecommunications, BPO/Contact Center, or Other
4. **Is this a trial account?**: Yes / No
5. **Modules to include** (all by default): Snowflake Intelligence, Cortex AI Functions, Dynamic Tables, Time Travel & Cloning, Marketplace Integration, Streamlit Dashboard
6. **Cross-functional cases**: Finance, HR, Sales, Operations, Customer 360, or None

### Step 2: Research Client and Marketplace

1. **Fetch client URL** → Extract products/services, markets/geographies, business terminology
2. **Search Marketplace** for relevant free datasets:
   - **Load**: [references/marketplace-datasets.md](references/marketplace-datasets.md)

> **Data loading mode**: por defecto el HOL usa datos **sintéticos** (`GENERATOR`/`SEQ4`/`UNIFORM`). Si el cliente quiere **escala real** (ingesta desde S3, COPY masivo, demo de warehouse scaling), usa el modo **real-data** de [references/real-data-and-advanced-patterns.md](references/real-data-and-advanced-patterns.md) (external stage + `COPY INTO`, datos quedan en S3, credenciales por canal seguro).

### Step 3: Load Reference Modules

Read ALL necessary reference files for planning:
- **Load**: [industries/{INDUSTRY}/SKILL.md](industries/) for the selected industry
- **Load**: [setup/SKILL.md](setup/SKILL.md) — mandatory initial setup
- **Load**: Selected modules from [modules/](modules/)
- **Load**: Selected cross-functional cases from [cross-functional/](cross-functional/)
- **Load**: [references/sql-patterns.md](references/sql-patterns.md)
- **Load**: [references/trial-limitations.md](references/trial-limitations.md)

### Step 4: Generate HOL Plan ⚠️ STOP — Present plan and wait for user approval

**Before writing any HTML, generate a complete plan and present it to the user.**

The plan must include:

#### 4.1 Data Model
- Database, warehouse, schemas
- Table definitions with row counts, PKs, FKs, key columns
- FK ranges and UNIFORM parameters

#### 4.2 Step Structure with Timings
- Step number, title, duration (minutes), content summary
- Total duration must match hero section

#### 4.3 Views, Dynamic Tables, and Derived Objects
- Views with SQL descriptions
- Dynamic Tables with TARGET_LAG and CTE anti-fan-out patterns
- Semantic View (via UI) with metrics and dimensions
- Agent (via UI) with tools
- Streamlit app views

#### 4.4 AI Prompt Strategy
- AI_COMPLETE usage: model, purpose, prompt summary
- AI_SENTIMENT targets
- SUMMARIZE targets

#### 4.5 Subagent Assignments
| Subagent | Responsibility |
|----------|---------------|
| Agent A | HTML shell: header, hero, nav sidebar, CSS, JS, footer |
| Agent B | Steps 1-2: Setup + Data Loading (complete SQL) |
| Agent C | Steps 3-4: Cortex AI + Cross-functional analysis (geospatial, scoring, etc.) |
| Agent D | Steps 5-6-7: Dynamic Tables + Streamlit + Cleanup |

> **IMPORTANT — Step ordering rule**: Snowflake Intelligence (Semantic View + Cortex Agent) must ALWAYS be the **last functional step** (before Cleanup). The agent's Semantic View needs visibility into all previously created objects (views, Dynamic Tables, geospatial views). If the HOL includes Intelligence, place it as the step immediately before Time Travel/Marketplace/Cleanup.

> If the user requests changes, adjust and re-present. Only proceed to Step 5 when the user explicitly approves.

### Step 5: Parallel Generation with Subagents

Launch all 4 subagents **in parallel** using a single message with 4 Task tool calls.

Each subagent receives:
1. The **approved plan** (data model, steps, timings, prompts)
2. Relevant **reference modules**
3. **Templates** (HTML, CSS, JS) for consistency
4. Explicit **output format** instructions

**Agent A — HTML Shell + CSS + JS** (subagent_type: `general-purpose`)
- Complete HTML with DOCTYPE, head, meta, fonts
- Inline CSS (load css-styles.md as reference)
- Header with Snowflake logo (180px)
- Hero section with title, subtitle, duration, difficulty, step count
- Overview section with learning objectives and tech tags
- Sidebar navigation with ALL steps and timings (`.nav-time`)
- Placeholder for each step: `<!-- STEP_N_PLACEHOLDER -->`
- Resources, completion, footer sections
- Inline JavaScript (load js-functions.md as reference)
- Branding: `#29B5E8` primary, `#1565C0` dark

**Agent B — Steps 1-2: Setup + Data Loading** (subagent_type: `general-purpose`)
- Step 1: USE ROLE ACCOUNTADMIN, CREATE DB/WH/SCHEMAS, verification queries
- Step 2: CREATE TABLE + INSERT with GENERATOR(ROWCOUNT), SEQ4, UNIFORM, ARRAY_CONSTRUCT
- SQL rules: LPAD for IDs, UNIFORM for FKs, DATEADD for dates
- Use `AI_COMPLETE()` and `AI_SENTIMENT()` — **NEVER** legacy `SNOWFLAKE.CORTEX.*`

**Agent C — Steps 3-4: Cortex AI + Cross-functional Analysis** (subagent_type: `general-purpose`)
- Step 3: Views with AI, AI_COMPLETE for text generation, AI_SENTIMENT, SNOWFLAKE.CORTEX.SUMMARIZE
- Step 4: Cross-functional analysis (geospatial, scoring, industry-specific views)
- Only `SNOWFLAKE.CORTEX.SUMMARIZE()` uses the legacy namespace (no AI_ equivalent)

**Agent D — Steps 5-6-7: Dynamic Tables + Streamlit + Intelligence + Cleanup** (subagent_type: `general-purpose`)
- Step 5: CREATE DYNAMIC TABLE with TARGET_LAG, CTEs with DISTINCT to prevent fan-out
- Step 6: Complete Streamlit Python code with `get_active_session()`, multiple views, `@st.cache_data(ttl=600)`. **Intelligence step**: Consolidated analytical view, UI instructions for Semantic View (Autopilot) + Agent creation in Snowsight. The Semantic View should reference all views and Dynamic Tables created in previous steps.
- Step 7: Time Travel, Marketplace, DROP DATABASE, DROP WAREHOUSE, congratulations message

> **Reminder**: Intelligence (Semantic View + Agent) goes in the LAST functional step before Cleanup so the agent can see all created objects.

### Step 6: Assemble Final HTML

1. Take HTML shell from Agent A
2. Replace each `<!-- STEP_N_PLACEHOLDER -->` with the corresponding step HTML
3. Verify no unreplaced placeholders remain
4. Write the final HTML file

Assembly validations:
- All `id="step-N"` present and in order
- All `data-step="N"` in nav sidebar correspond to existing steps
- `totalSteps` in JS matches actual step count
- No CSS conflicts between sections
- Nav sidebar timings = step header timings = sum equals hero duration

### Step 7: Quality Control (QA) ⚠️ STOP — QA is mandatory before delivery

- **Load**: [qa-checklist.md](qa-checklist.md)
- Read the complete generated HTML
- Run ALL automated validations:
  - Check 1: Legacy Cortex syntax (must find 0 results for `SNOWFLAKE.CORTEX.COMPLETE` / `SNOWFLAKE.CORTEX.SENTIMENT`)
  - Check 2: Current AI syntax present (AI_COMPLETE, AI_SENTIMENT, SUMMARIZE)
  - Check 3: Nav sidebar vs step header timings match
  - Check 4: HTML tag balance + SQL parentheses/quotes in code blocks
  - Check 5: Step IDs, nav data-step, markStepComplete, toggleStep consistency (1-N no gaps)
  - Check 6: JS totalSteps matches actual step count
  - Check 7: Streamlit SiS compatibility (get_active_session, session.sql, no anti-patterns)
  - Check 8: Compile key SQL against Snowflake with `only_compile=true`
- Present QA report to user
- Fix any issues found

### Step 8: Delivery

- Inform the user of the generated file path
- Present summary: steps, duration, tables, records, AI functions used
- Offer adjustments if requested

---

## Single HOL Stopping Points

| Step | Condition | Action |
|------|-----------|--------|
| Step 1 | Missing client info | ⚠️ STOP — Collect all inputs before proceeding |
| Step 4 | Plan generated | ⚠️ STOP — Present plan, wait for explicit user approval |
| Step 7 | QA complete | ⚠️ STOP — Present QA report, fix any issues before delivery |

---

## Single HOL Output

The final deliverable is a **self-contained HTML file** with:
- All CSS and JavaScript inline (no external dependencies)
- Snowflake branding (#29B5E8 primary)
- Sidebar navigation with step timings
- Progress tracking with localStorage
- Code blocks with copy buttons
- Step completion checkboxes
- Responsive design with print support

**Output path**: `~/Documents/COCO/HOL/{prospect_name_lowercase}/`

---

# Workshop Workflow (10 Steps)

**Load**: [workshop/SKILL.md](workshop/SKILL.md) for workshop-specific orchestration logic, index template, and cross-lab validation rules.

### Step W1: Collect Workshop Information ⚠️ STOP — Collect before proceeding

Ask the user:

1. **Client/prospect name**
2. **Website URL** (to research the business)
3. **Primary industry**: Retail/CPG, Manufacturing, Financial Services, Healthcare/Pharma, Technology/SaaS, Logistics/Transport, Energy/Utilities, Telecommunications, BPO/Contact Center, or Other
4. **Is this a trial account?**: Yes / No
5. **Workshop title/theme** (e.g., "Data Monetization & Governance", "AI-Powered Analytics")
6. **Number of labs** (2-6 recommended, each 45-90 min)
7. **Lab topics** — list each lab's focus area and which modules it should cover
8. **Shared database?**: Yes (all labs share one DB with different schemas) / No (independent DB per lab)
9. **Progressive complexity?**: Yes (each lab builds on objects from previous labs) / No (each lab is fully independent)
10. **Target audience**: Technical (SQL-heavy) / Mixed (technical + business) / Executive (demo-oriented)

### Step W2: Research Client and Marketplace

Same as Single HOL Step 2:
1. **Fetch client URL** → Extract products/services, markets/geographies, business terminology
2. **Search Marketplace** for relevant free datasets:
   - **Load**: [references/marketplace-datasets.md](references/marketplace-datasets.md)

### Step W3: Load Reference Modules

Read ALL necessary reference files:
- **Load**: [industries/{INDUSTRY}/SKILL.md](industries/) for the selected industry
- **Load**: [setup/SKILL.md](setup/SKILL.md) — mandatory initial setup
- **Load**: ALL modules referenced across all labs from [modules/](modules/)
- **Load**: Selected cross-functional cases from [cross-functional/](cross-functional/)
- **Load**: [references/sql-patterns.md](references/sql-patterns.md)
- **Load**: [references/trial-limitations.md](references/trial-limitations.md)
- **Load**: [workshop/SKILL.md](workshop/SKILL.md) — workshop orchestration logic

### Step W4: Generate Workshop Master Plan ⚠️ STOP — Present plan and wait for user approval

**Before writing any HTML, generate a COMPLETE workshop master plan and present to the user.**

The master plan must include:

#### W4.1 Workshop Overview
- Workshop title, narrative arc, total duration
- Target audience and difficulty progression
- Shared infrastructure (DB, WH, schemas)

#### W4.2 Lab Breakdown Table

| # | Lab Title | Duration | Key Modules | Depends On | Shared Objects |
|---|-----------|----------|-------------|------------|----------------|
| 1 | ... | XX min | ... | None | Creates: TABLE_X, VIEW_Y |
| 2 | ... | XX min | ... | Lab 1 | Uses: VIEW_Y. Creates: SV_Z |
| ... | | | | | |

#### W4.3 Shared Data Model
- Database/warehouse/schemas shared across labs
- Tables created in Lab 1 that are used in subsequent labs
- Object dependency graph (what must exist before each lab starts)

#### W4.4 Per-Lab Summary
For each lab:
- Title, subtitle, duration, difficulty level
- Steps with timings (same format as Single HOL Step 4.2)
- Modules used
- Objects created and consumed
- Pre-requisites (objects from prior labs OR explicit "standalone" setup)

#### W4.5 Index Page Plan
- Workshop title, total duration, lab count
- Cards for each lab with description and prerequisites
- Global progress tracking strategy (localStorage keys)
- Recommended completion order

> If the user requests changes, adjust and re-present. Only proceed to Step W5 when the user explicitly approves.

### Step W5: Generate Labs Sequentially

For each lab (1 to N), execute the full Single HOL generation pipeline:

1. **Derive lab-specific plan** from the approved master plan
2. **If progressive**: include objects from previous labs as "pre-existing" in the setup step (add verification queries instead of CREATE statements for shared objects)
3. **If independent**: each lab has its own full setup step
4. **Execute Steps 3-8 from Single HOL Workflow** for this lab:
   - Load refs → Plan (already approved) → Parallel subagents → Assemble → QA → Write file
5. **Track shared objects**: maintain a running list of objects created by previous labs for downstream reference
6. **Output**: `{client}_workshop_lab{N}_{topic_slug}.html`

> **IMPORTANT**: For progressive workshops, Lab 1 ALWAYS includes the full setup (CREATE DATABASE, tables, etc.). Subsequent labs start with verification of pre-existing objects and only CREATE their new additions.

### Step W6: Generate Workshop Index Page

After ALL labs are generated:

1. **Load**: [templates/workshop-index-template.md](templates/workshop-index-template.md)
2. Generate the index HTML with:
   - Workshop title, total duration, difficulty, lab count
   - Hero section with workshop narrative
   - Card grid with each lab (title, duration, description, prerequisites, link)
   - Dependency visualization (which labs unlock which)
   - Global progress tracker (reads localStorage from each lab)
   - Architecture overview diagram
   - Resources and next steps
3. **Output**: `{client}_workshop_index.html`

### Step W7: Workshop-Level QA ⚠️ STOP — QA is mandatory before delivery

Beyond per-lab QA (already done in Step W5), run workshop-level validations:

- **Cross-lab consistency**: DB/schema/table names are identical across all HTMLs
- **Dependency correctness**: objects referenced in Lab N were created in Lab N-1 (or earlier)
- **Index links**: all `href` in index point to correct lab filenames
- **Progressive setup**: Lab 2+ verification queries reference objects from Lab 1
- **No duplicate CREATE**: if Lab 1 creates TABLE_X, Lab 2 should NOT recreate it (only SELECT from it)
- **Global progress**: localStorage keys don't collide between labs
- **Filename consistency**: index links match actual generated filenames

Present Workshop QA report to user. Fix any cross-lab issues found.

### Step W8: Delivery

- Inform the user of ALL generated file paths:
  - `~/Documents/COCO/HOL/{prospect_name_lowercase}/{client}_workshop_index.html`
  - `~/Documents/COCO/HOL/{prospect_name_lowercase}/{client}_workshop_lab1_{topic}.html`
  - `~/Documents/COCO/HOL/{prospect_name_lowercase}/{client}_workshop_lab2_{topic}.html`
  - ...
- Present workshop summary: total labs, total duration, total tables, total steps
- Offer adjustments if requested

---

## Workshop Stopping Points

| Step | Condition | Action |
|------|-----------|--------|
| Step W1 | Missing workshop info | ⚠️ STOP — Collect all inputs before proceeding |
| Step W4 | Master plan generated | ⚠️ STOP — Present plan, wait for explicit user approval |
| Step W7 | Workshop QA complete | ⚠️ STOP — Present QA report, fix any issues before delivery |

---

## Workshop Output

The final deliverable is a **set of HTML files**:
- **Index page**: Landing page with links to all labs, global progress tracking
- **Lab HTMLs**: Each lab is a self-contained HTML file (same format as Single HOL)
- All files in the same directory for relative links to work
- Consistent branding across all files
- Global progress visible from index page

**Output path**: `~/Documents/COCO/HOL/{prospect_name_lowercase}/`
**Naming**: `{client}_workshop_index.html`, `{client}_workshop_lab{N}_{topic_slug}.html`

---

## Available Modules (Technical + Advanced)

### Core Modules (included in Single HOL)
| Module | File | Duration |
|--------|------|----------|
| Snowflake Intelligence | [modules/intelligence/SKILL.md](modules/intelligence/SKILL.md) | ~15 min |
| Cortex AI Functions | [modules/cortex-ai/SKILL.md](modules/cortex-ai/SKILL.md) | ~12 min |
| Dynamic Tables | [modules/dynamic-tables/SKILL.md](modules/dynamic-tables/SKILL.md) | ~8 min |
| Time Travel & Cloning | [modules/time-travel/SKILL.md](modules/time-travel/SKILL.md) | ~8 min |
| Marketplace Integration | [modules/marketplace/SKILL.md](modules/marketplace/SKILL.md) | ~8 min |
| Streamlit Dashboard | [modules/streamlit/SKILL.md](modules/streamlit/SKILL.md) | ~15 min |

### Advanced Modules (for Workshops / Enterprise scenarios)
| Module | File | Duration | Requires Enterprise? |
|--------|------|----------|---------------------|
| Versioned Semantic Layer | [modules/versioned-semantic-layer/SKILL.md](modules/versioned-semantic-layer/SKILL.md) | ~20 min | Partial (multi-env needs Enterprise, versionable with schemas in trial) |
| dbt Semantic Layer | [modules/dbt-semantic-layer/SKILL.md](modules/dbt-semantic-layer/SKILL.md) | ~20 min | Yes (Workspaces require Enterprise+) |
| Data Clean Rooms | [modules/data-clean-rooms/SKILL.md](modules/data-clean-rooms/SKILL.md) | ~25 min | Yes (full DCR needs Enterprise+, simulable in trial) |
| Semantic View Composability | [modules/semantic-view-composability/SKILL.md](modules/semantic-view-composability/SKILL.md) | ~15 min | No |
| Data Monetization | [modules/data-monetization/SKILL.md](modules/data-monetization/SKILL.md) | ~20 min | Partial (Listings need Enterprise, architecture demo works) |

---

## Lessons Learned (Mandatory — Apply to EVERY generation)

### 1. AI_SENTIMENT Breaking Change (2025)
`AI_SENTIMENT()` no longer returns a float. It returns an OBJECT:
```json
{"categories":[{"name":"overall","sentiment":"positive"}]}
```
**Correct usage**:
```sql
AI_SENTIMENT(text):categories[0]:sentiment::VARCHAR  -- returns 'positive','negative','neutral'
CASE AI_SENTIMENT(text):categories[0]:sentiment::VARCHAR
    WHEN 'positive' THEN 'Positivo'
    WHEN 'negative' THEN 'Negativo'
    ELSE 'Neutral'
END AS clasificacion
```
**NEVER** use `AI_SENTIMENT(text) > 0.3` — this throws a type error.

### 2. Assembly — Extract Body Only
When assembling, subagents generate full `<article>` elements with their own step-headers. The shell already has step-headers in its `<div class="step-card">` structure. During assembly, extract ONLY the inner content from each step's `<div class="step-content">` and inject it into the shell's placeholder. Do NOT inject the full article — this creates duplicate IDs and nested step-headers.

### 3. Code Block Format Consistency
Subagents may use different button formats for copy buttons. The shell expects:
```html
<button class="btn-copy" onclick="copyCode(this)">Copiar</button>
```
During QA, verify ALL code blocks use this exact format. Subagents sometimes generate SVG-only buttons without the `btn-copy` class — these render invisible because CSS targets `.btn-copy`.

### 4. Brand Guidelines
Always invoke the `snowflake-brand-guidelines` skill AFTER assembly to apply:
- Official Snowflake logo PNGs (not logo.wine SVG) — blue on light, white on dark backgrounds
- Montserrat (headings, uppercase, letter-spacing: 0.5px) + Lato (body)
- Color palette: `#11567F` Mid Blue for headers/gradients, `#29B5E8` Snowflake Blue for accents, `#5B5B5B` body text
- Hero gradient: `linear-gradient(135deg, #11567F 0%, #0a3a5c 100%)`
- Footer: `© {YEAR} Snowflake Inc. All Rights Reserved.`

### 5. Synthetic Data Disclaimer
ALWAYS include a visible warning banner before Step 1:
```html
<div class="info-box warning" style="max-width:var(--content-max-width); margin:0 auto var(--space-lg); border-left:4px solid var(--sf-orange);">
    <span class="icon">⚠️</span>
    <div>
        <strong>Datos de prueba</strong>
        <p>Este laboratorio utiliza datos sintéticos generados para fines demostrativos. Los nombres, métricas e indicadores son ficticios y no representan información real.</p>
    </div>
</div>
```

### 6. AI_COMPLETE — NULL Safety
When building prompts with `||` concatenation, ALWAYS wrap nullable columns with `COALESCE()`:
```sql
'Puntaje: ' || ROUND(COALESCE(PUNTAJE_PROMEDIO, 0), 1)::VARCHAR
'Días: ' || COALESCE(DIAS_SIN_CONTACTO, 999)::VARCHAR
```
Without COALESCE, a NULL in any part of the concatenation makes the entire prompt NULL → AI_COMPLETE returns NULL silently.

### 7. Execute and Validate Before Delivery
After generating the HOL HTML, ALWAYS execute all SQL step-by-step on the target Snowflake account to catch:
- Type mismatches (like AI_SENTIMENT returning OBJECT instead of FLOAT)
- NULL concatenation issues in AI_COMPLETE prompts
- Missing COALESCE on nullable LEFT JOIN columns
- Dynamic Table syntax warnings
Only deliver the HOL after ALL SQL executes without errors.

### 8. Subagent ID Format Consistency
Instruct ALL subagents to use `id="step-N"` format (with hyphen). Some subagents generate `id="stepN"` (without hyphen) which breaks nav links and JavaScript. Add this as an explicit requirement in each subagent prompt.

### 9. Comunidad Snowflake Colombia
ALWAYS include a community CTA in the Resources section for Colombian prospects. Add after the resources-grid, before closing `</section>`:
- Copy `comunidad_snowflake_colombia_qr.jpg` from `~/Downloads/PHOTO-2026-05-14-12-25-20.jpg` to the HOL directory
- Link: `https://www.snowflake.com/es/webinars/thought-leadership/comunidad-snowflake-colombia/`
- Template:
```html
<div style="margin-top:var(--space-2xl); text-align:center; background:linear-gradient(135deg, #11567F 0%, #0a3a5c 100%); border-radius:var(--radius-xl); padding:var(--space-2xl); color:white;">
    <h3 style="font-family:var(--font-heading); font-size:1.5rem; font-weight:800; text-transform:uppercase; letter-spacing:0.5px; margin-bottom:var(--space-sm); color:#29B5E8;">Únete a nuestra comunidad en Colombia</h3>
    <p style="font-size:1rem; opacity:0.9; margin-bottom:var(--space-lg);">Conecta con profesionales de datos e IA, comparte conocimiento y lidera la conversación en el país.</p>
    <div style="display:flex; align-items:center; justify-content:center; gap:var(--space-2xl); flex-wrap:wrap;">
        <img src="comunidad_snowflake_colombia_qr.jpg" alt="QR Comunidad Snowflake Colombia" style="width:220px; height:auto; border-radius:var(--radius-lg); box-shadow:0 8px 24px rgba(0,0,0,0.3);">
        <div style="text-align:left;">
            <p style="font-size:0.9rem; opacity:0.8; margin-bottom:var(--space-md);">Escanea el QR o haz clic en el enlace:</p>
            <a href="https://www.snowflake.com/es/webinars/thought-leadership/comunidad-snowflake-colombia/" target="_blank" style="display:inline-block; background:#29B5E8; color:white; padding:var(--space-sm) var(--space-xl); border-radius:var(--radius-full); font-weight:700; font-size:0.9375rem; text-decoration:none;">Registrarme en la Comunidad →</a>
        </div>
    </div>
</div>
```

### 10. Real-data, enterprise-scale & SQL-first patterns
Para HOLs de **escala real** (datos en S3, Cortex multimodal, capa de consumo viva, agente CoWork),
**Load**: [references/real-data-and-advanced-patterns.md](references/real-data-and-advanced-patterns.md). Reglas de oro que ahí se detallan:

- **Dynamic Table plana sin fan-out**: una sola DT de consumo, aplana lo uno-a-muchos por lado con `LEFT JOIN` filtrados; **valida `COUNT(DT) == COUNT(base)`**. Es la única tabla del semantic model.
- **Cortex Search SIEMPRE desde tablas BASE**, nunca desde una DT en `REFRESH_MODE=FULL` (no soporta change tracking → error). Construye el servicio sobre el JOIN de las tablas base.
- **Masking en la base Y en la DT** (`ALTER DYNAMIC TABLE ... MODIFY COLUMN ... SET MASKING POLICY`) para que Analyst/CoWork enmascaren a roles no-admin.
- **Time Travel robusto**: `BEFORE(STATEMENT => $qid)` siempre funciona; `AT(OFFSET => -N)` falla sin N seg de historia. Recupera in-place con `INSERT OVERWRITE`. Todo en el mismo worksheet.
- **Cortex multimodal**: `pixtral-large` + `TO_FILE` (imagen), `AI_TRANSCRIBE` (audio) desde stage con `DIRECTORY=(ENABLE=TRUE)`.
- **Streamlit vía PROMPT de Cortex Code** (no a mano), apuntando a la DT de consumo.
- **Agente / ventanas flotantes**: responde en **español, markdown, con gráfico y 3 preguntas de seguimiento** (preferencia estándar, aplica a todo agente que generes).
- **Estilo**: comentarios del SQL sin narrar conteos de archivos ni tiempos (eso lo habla el instructor).

### 11. SQL-first: un solo origen (.sql → HTML)
Mantén un **master `.sql`** con marcadores `PARTE N` y genera el HTML desde él. El regex del `STEPS`
debe tolerar espacios antes del cierre (`const STEPS = \[.*?\n\s*\];`) y ser **idempotente**
(no fallar si no hay cambios). **No edites el HTML a mano**; edita el SQL y regenera.

### 12. Validación en namespace AISLADO (antes de entregar)
La Parte 1 hace `CREATE OR REPLACE DATABASE/WAREHOUSE`. Para validar end-to-end **sin destruir**
apps/agentes ya desplegados con el nombre productivo, corre todo en `DB_<NS>_TEST` / `WH_<NS>_TEST`
y haz `DROP` al terminar. Valida: conteos, `COUNT(DT)==COUNT(base)`, masking con rol no-admin,
Cortex (texto/imagen/audio), Search `ACTIVE`+preview, Analyst genera SQL, agente responde por REST.

### 13. Comentarios del SQL: NO narres lo que dice el instructor
Los comentarios del código describen el **qué** y el **por qué** del SQL, no el guion de la demo.
**El instructor narra en vivo** la mecánica y el impacto; el código no debe duplicarlo. Evita en los comentarios:
- **Nodos / arquitectura de cómputo** ("usa N nodos", "el XLARGE tiene 16 servidores", "paraleliza en X hilos").
- **Tiempos / velocidad** ("carga en ~30 segundos", "tarda 2 min", "instantáneo").
- **Conteos de archivos** ("128 archivos de ~37MB", "particionado en N partes").
- **Frases de presentador** ("esto demuestra que…", "como ves, Snowflake es rapidísimo", "¡impresionante!").

Por qué: esos detalles son el discurso del instructor; en el código distraen, envejecen mal y le quitan
protagonismo a quien presenta. Bien: `-- Recargamos con un warehouse mayor para comparar.`
Mal: `-- Con XLARGE (16 nodos) recargamos los 128 archivos en ~25s para impresionar.`
