# Sub-Skill: Workshop Orchestration

## Metadata
- **Parent**: snowflake-hol-generator
- **Name**: workshop
- **Purpose**: Orchestrate multi-HOL workshop generation with shared narrative, progressive complexity, and cross-lab validation

---

## Overview

A **Workshop** is a collection of 2-6 connected Hands-on Labs that share:
- A common business narrative and industry context
- A shared Snowflake database/warehouse infrastructure
- Progressive complexity (optional) — later labs build on objects from earlier labs
- A landing index page with global progress tracking

---

## Workshop Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    WORKSHOP INDEX PAGE                            │
│  - Title, narrative, total duration                              │
│  - Lab cards with progress indicators                            │
│  - Dependency graph (visual)                                     │
│  - Global progress tracker (localStorage)                        │
└─────────────────────────────────────────────────────────────────┘
         │              │              │              │
         ▼              ▼              ▼              ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│    LAB 1     │ │    LAB 2     │ │    LAB 3     │ │    LAB N     │
│ (Foundation) │ │ (Builds on 1)│ │ (Builds on 2)│ │ (Capstone)   │
│              │ │              │ │              │ │              │
│ Full setup   │ │ Verify +     │ │ Verify +     │ │ Verify +     │
│ + base data  │ │ extend       │ │ extend       │ │ advanced     │
└──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘
```

---

## Workshop Modes

### Mode A: Progressive (Recommended)
- Lab 1 creates all shared infrastructure (DB, WH, schemas, base tables)
- Labs 2-N verify pre-existing objects and only add their own
- Objects accumulate: Lab 3 can use objects from Lab 1 AND Lab 2
- Best for: Deep-dive workshops where each lab builds on the previous

### Mode B: Independent
- Each lab is fully self-contained with its own setup/teardown
- Labs can be done in any order
- Shared only: database name and warehouse (for consistency)
- Best for: Modular workshops where attendees choose their labs

---

## Shared Data Model Strategy

### Progressive Workshop Data Model

```sql
-- Lab 1 creates the foundation:
CREATE DATABASE {CLIENT}_WORKSHOP;
CREATE SCHEMA RAW_DATA;        -- Base tables (Lab 1)
CREATE SCHEMA ANALYTICS;       -- Views and derived objects (Lab 1+)
CREATE SCHEMA GOVERNANCE;      -- Policies, semantic views (Lab 2+)
CREATE SCHEMA PRODUCTS;        -- Data products, shares (Lab 3+)
CREATE SCHEMA AGENTS;          -- Cortex Agents (final lab)

CREATE WAREHOUSE {CLIENT}_WH WITH WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 60 AUTO_RESUME = TRUE INITIALLY_SUSPENDED = TRUE;
```

### Object Tracking Table

Maintain a running registry of objects across labs:

```sql
-- Internal tracking (not in the HOL, for generation logic only)
-- Used to validate cross-lab references during QA

OBJECT_REGISTRY:
| Object Name | Type | Created In | Used In | Schema |
|-------------|------|-----------|---------|--------|
| DIM_PRODUCTS | TABLE | Lab 1 | Lab 2, 3, 4 | RAW_DATA |
| V_ANALYTICS_BASE | VIEW | Lab 1 | Lab 2, 3 | ANALYTICS |
| SV_CORE_METRICS | SEMANTIC VIEW | Lab 2 | Lab 3, 4 | GOVERNANCE |
| ...
```

---

## Lab Interconnection Patterns

### Pattern 1: Foundation → Extension
```
Lab 1: Creates TABLE_A, TABLE_B, VIEW_C
Lab 2: Uses VIEW_C, creates DYNAMIC_TABLE_D, SEMANTIC_VIEW_E
```

Lab 2's setup step should include:
```sql
-- =====================================================
-- VERIFICACIÓN: Objetos del Lab 1
-- Si no has completado el Lab 1, hazlo primero.
-- =====================================================
SELECT COUNT(*) AS filas FROM {CLIENT}_WORKSHOP.RAW_DATA.TABLE_A;
-- Esperado: > 0 filas

SELECT COUNT(*) AS filas FROM {CLIENT}_WORKSHOP.ANALYTICS.VIEW_C;
-- Esperado: > 0 filas

SELECT '✅ Pre-requisitos del Lab 1 verificados' AS STATUS;
```

### Pattern 2: Independent with Shared Context
```
Lab 1: Creates TABLE_A, TABLE_B (shared)
Lab 2: Uses TABLE_A (read-only), creates its own objects in separate schema
Lab 3: Uses TABLE_B (read-only), creates its own objects in separate schema
```

### Pattern 3: Capstone Lab
The final lab uses ALL objects from previous labs:
```
Lab N (Capstone): Uses objects from ALL previous labs
  - Creates final Agent with multiple Semantic Views
  - Creates comprehensive Streamlit dashboard
  - Demonstrates the full architecture working together
```

---

## Index Page Generation Rules

### localStorage Strategy

Each lab stores its progress independently:
```javascript
// Lab 1 uses key: "workshop_{client}_lab1_progress"
// Lab 2 uses key: "workshop_{client}_lab2_progress"
// etc.

// Index page reads ALL keys to show global progress:
function getGlobalProgress() {
    const labs = {TOTAL_LABS};
    let completed = 0;
    for (let i = 1; i <= labs; i++) {
        const key = `workshop_{client}_lab${i}_progress`;
        const data = JSON.parse(localStorage.getItem(key) || '{}');
        if (data.completed) completed++;
    }
    return Math.round((completed / labs) * 100);
}
```

### Lab Card Component
```html
<div class="lab-card" data-lab="N" data-status="locked|available|in-progress|completed">
    <div class="lab-number">Lab N</div>
    <div class="lab-info">
        <h3 class="lab-title">{LAB_TITLE}</h3>
        <p class="lab-description">{LAB_DESCRIPTION}</p>
        <div class="lab-meta">
            <span class="lab-duration">~{DURATION} min</span>
            <span class="lab-difficulty">{DIFFICULTY}</span>
        </div>
        <div class="lab-prerequisites">
            <span class="prereq-label">Requiere:</span>
            <span class="prereq-labs">{PREREQUISITE_LABS}</span>
        </div>
    </div>
    <div class="lab-status-indicator"></div>
    <a href="{LAB_FILENAME}" class="lab-cta">Comenzar →</a>
</div>
```

---

## Cross-Lab QA Checklist

### Naming Consistency
```
[ ] Database name identical across all lab HTMLs
[ ] Warehouse name identical across all lab HTMLs
[ ] Schema names consistent (RAW_DATA, ANALYTICS, etc.)
[ ] Table/view names referenced in Lab N match exactly as created in Lab M
```

### Dependency Validation
```
[ ] No forward references (Lab 2 doesn't reference objects created in Lab 3)
[ ] All objects referenced in verification queries actually exist from prior labs
[ ] Progressive labs never DROP objects that later labs need
[ ] Cleanup only happens in the LAST lab (or not at all if workshop is meant to persist)
```

### Index Page Validation
```
[ ] All href links point to actual generated filenames
[ ] Lab count in index matches actual number of lab HTMLs
[ ] Progress tracking localStorage keys match between index and labs
[ ] Dependency arrows in visualization match actual lab prerequisites
[ ] Total duration in index equals sum of all lab durations
```

### File System
```
[ ] All files in same directory (relative links work)
[ ] Filenames follow convention: {client}_workshop_lab{N}_{topic_slug}.html
[ ] Index filename: {client}_workshop_index.html
[ ] No spaces in filenames (use underscores)
[ ] All lowercase
```

---

## Workshop Cleanup Strategy

### Option A: Cleanup in Last Lab Only
- Labs 1 to N-1: NO cleanup step
- Lab N (final): includes full cleanup (DROP DATABASE, DROP WAREHOUSE)
- Best for progressive workshops

### Option B: Per-Lab Cleanup (Independent Mode)
- Each lab has its own cleanup section
- Cleanup is marked as OPTIONAL
- Warning: "If you plan to do the next lab, DO NOT run cleanup"

### Option C: No Cleanup (Persistent Workshop)
- Workshop is meant to remain for ongoing exploration
- Cleanup instructions provided in a separate "Cleanup Guide" section of the index page
- Best for paid workshops or POC environments

---

## Timing Guidelines for Workshops

| Workshop Type | Labs | Total Duration | Recommended Format |
|---------------|------|----------------|-------------------|
| Half-day | 2-3 | 3-4 hours | Morning session |
| Full-day | 4-5 | 6-8 hours | Full day with breaks |
| Multi-day | 5-6 | 8-12 hours | 2 days, 4-6h each |

### Per-Lab Duration Targets
| Lab Position | Recommended Duration | Notes |
|-------------|---------------------|-------|
| Lab 1 (Foundation) | 60-90 min | Includes full setup + base data |
| Labs 2-N-1 (Core) | 45-75 min | Focused on specific modules |
| Lab N (Capstone) | 60-90 min | Synthesis of all previous work |

---

## Narrative Arc Patterns

### Pattern: Build → Govern → Monetize
```
Lab 1: Build the Data Foundation (tables, views, AI enrichment)
Lab 2: Add Governance & Semantic Layer (policies, semantic views, versioning)
Lab 3: Enable Self-Service Analytics (Cortex Analyst, Streamlit)
Lab 4: Monetize & Share (Listings, Clean Rooms, data products)
```

### Pattern: Explore → Transform → Analyze → Deploy
```
Lab 1: Explore & Load Data (Marketplace, ingestion, time travel)
Lab 2: Transform with dbt & Dynamic Tables (pipelines, scheduling)
Lab 3: Analyze with AI (Cortex AI, Semantic Views, NL queries)
Lab 4: Deploy & Monitor (Streamlit, alerts, Agents)
```

### Pattern: Single Domain Deep-Dive
```
Lab 1: Domain Data Model (industry-specific tables, relationships)
Lab 2: Business Logic Layer (views, calculations, KPIs)
Lab 3: AI & Intelligence Layer (Cortex, Agents, NL analytics)
Lab 4: Presentation & Sharing (Streamlit, Clean Rooms, Listings)
```

---

## Generation Order

When generating a workshop, labs MUST be generated in order (1, 2, 3, ...) because:
1. Each lab's setup verification depends on knowing exactly what prior labs created
2. The subagent for Lab N needs the complete object registry from Labs 1 to N-1
3. Cross-lab references must be validated incrementally

However, WITHIN each lab, the 4 subagents still run in parallel (same as Single HOL).

---

## Output File Structure

```
~/Documents/COCO/HOL/{prospect_name_lowercase}/
├── {client}_workshop_index.html          # Landing page
├── {client}_workshop_lab1_{topic}.html   # Lab 1
├── {client}_workshop_lab2_{topic}.html   # Lab 2
├── {client}_workshop_lab3_{topic}.html   # Lab 3
├── ...
└── comunidad_snowflake_colombia_qr.jpg   # Community QR (if Colombian prospect)
```
