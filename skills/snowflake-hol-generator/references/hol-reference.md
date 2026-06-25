# HOL Generator Reference

## Trial Account Compatibility

### Functions AVAILABLE in Trial
| Capability | Available | Notes |
|-----------|------------|-------|
| CREATE DATABASE/SCHEMA/TABLE | ✅ Yes | No restrictions |
| CREATE VIEW | ✅ Yes | No restrictions |
| Dynamic Tables | ✅ Yes | With TARGET_LAG |
| Time Travel | ✅ Yes | Up to 1 day |
| Zero-Copy Cloning | ✅ Yes | No restrictions |
| Cortex AI Functions | ✅ Yes | AI_COMPLETE, AI_SENTIMENT, SUMMARIZE, AI_TRANSLATE, AI_CLASSIFY_TEXT, AI_EXTRACT_ANSWER |
| Marketplace (free datasets) | ✅ Yes | Free datasets only |
| Snowsight UI | ✅ Yes | Full |

### Cortex AI Functions — Current Syntax (2025+)
| Function | Current Syntax | Notes |
|---------|----------------|-------|
| Complete/Generate text | `AI_COMPLETE('model', 'prompt')` | Models: `mistral-large2`, `llama3.1-70b`, `claude-sonnet-4-6` |
| Sentiment analysis | `AI_SENTIMENT('text')` | Returns OBJECT `{categories:[{name:"overall",sentiment:"positive\|negative\|neutral"}]}`. Extract with `:categories[0]:sentiment::VARCHAR` |
| Summarize text | `SNOWFLAKE.CORTEX.SUMMARIZE('text')` | No AI_ equivalent for individual text |
| Translate | `AI_TRANSLATE('text', 'source', 'target')` | |
| Classify text | `AI_CLASSIFY_TEXT('text', ['cat1','cat2'])` | |
| Extract answer | `AI_EXTRACT_ANSWER('text', 'question')` | |

> **IMPORTANT**: DO NOT use legacy syntax `SNOWFLAKE.CORTEX.COMPLETE()` or `SNOWFLAKE.CORTEX.SENTIMENT()`. Use `AI_COMPLETE()` and `AI_SENTIMENT()` respectively. The ONLY exception is `SNOWFLAKE.CORTEX.SUMMARIZE()` which has no `AI_` equivalent for individual text.
>
> **AI_SENTIMENT BREAKING CHANGE (2025)**: `AI_SENTIMENT()` no longer returns a float (-1 to 1). It now returns an OBJECT. To get the label use: `AI_SENTIMENT(text):categories[0]:sentiment::VARCHAR` which returns `'positive'`, `'negative'`, or `'neutral'`. You CANNOT compare with `> 0.3` or `< -0.3` anymore — use CASE WHEN on the string label instead.

### Functions with RESTRICTIONS in Trial
| Capability | Status | HOL Alternative |
|-----------|--------|----------------------|
| `SYSTEM$CORTEX_ANALYST_FAST_GENERATION` | ❌ Not available | Use **Snowsight UI → Semantic View Autopilot** |
| CREATE SEMANTIC VIEW (complex SQL) | ⚠️ Limited | Use **Snowsight UI → Semantic View Autopilot** |
| CREATE AGENT (SQL) | ⚠️ Limited | Use **Snowsight UI → Create Agent** |
| Data Sharing (create shares) | ⚠️ Requires config | Show concept only, optional |
| Snowpark Container Services | ❌ Not available | Omit from trial HOL |

---

## Available Industries (11)

| Industry | File | Description |
|-----------|---------|-------------|
| Retail/CPG | `retail-cpg/SKILL.md` | Stores, e-commerce, omnichannel |
| Manufacturing | `manufacturing/SKILL.md` | Production, quality, supply chain |
| Financial Services | `financial-services/SKILL.md` | Banking, insurance, credit, AML |
| Healthcare/Pharma | `healthcare-pharma/SKILL.md` | Hospitals, pharma, reps |
| Technology/SaaS | `technology-saas/SKILL.md` | MRR, ARR, churn, cohorts |
| Logistics | `logistics/SKILL.md` | Fleets, deliveries, GPS tracking |
| Energy/Utilities | `energy-utilities/SKILL.md` | Meters, readings, billing |
| Telecommunications | `telecommunications/SKILL.md` | Subscribers, usage, network, churn |
| CPG | `cpg/SKILL.md` | Brands, retail, POS, inventory |
| BPO | `bpo/SKILL.md` | Contact center, agents, NPS |
| Generic | `generic/SKILL.md` | Adaptable model for any industry |

---

## Cross-Functional Modules (5)

| Module | File | Use Cases |
|--------|---------|--------------|
| Finance | `finance/SKILL.md` | P&L, quarterly reports, variance |
| HR | `hr-analytics/SKILL.md` | Performance, CV analysis, turnover |
| Sales | `sales-analytics/SKILL.md` | Pipeline, forecasting, win/loss |
| Operations | `operations/SKILL.md` | Real-time KPIs, alerts, SLAs |
| Customer 360 | `customer-360/SKILL.md` | RFM, CLV, Next Best Action |

---

## Module Flow (Independent)

```
┌─────────────────────────────────────────────────────────────┐
│                    SETUP (MANDATORY)                          │
│  - CREATE DATABASE, WAREHOUSE, SCHEMAS                       │
│  - Verify account capabilities                               │
│  - Load synthetic data for the industry                      │
└─────────────────────────────────────────────────────────────┘
                              │
         ┌────────────────────┼────────────────────┐
         │                    │                    │
         ▼                    ▼                    ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│   CORTEX AI     │  │ CROSS-FUNCTIONAL│  │ DYNAMIC TABLES  │
│  (Optional)     │  │  (Optional)     │  │   (Optional)    │
│ - SENTIMENT()   │  │ - Geospatial    │  │ - Auto KPIs     │
│ - COMPLETE()    │  │ - Scoring       │  │ - Alerts        │
│ - SUMMARIZE()   │  │ - Industry views│  │ - TARGET_LAG    │
└─────────────────┘  └─────────────────┘  └─────────────────┘
         │                    │                    │
         └────────────────────┼────────────────────┘
                              │
         ┌────────────────────┼────────────────────┐
         │                    │                    │
         ▼                    ▼                    ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│   STREAMLIT     │  │  INTELLIGENCE   │  │  TIME TRAVEL    │
│  (Optional)     │  │ (LAST before    │  │  (Optional)     │
│ - SiS Dashboard │  │  Cleanup)       │  │ - AT(OFFSET)    │
│ - Visualization │  │ - Semantic View │  │ - CLONE         │
│ - KPIs          │  │ - Cortex Agent  │  │ - MARKETPLACE   │
└─────────────────┘  │ - NL Questions  │  │ - Recovery      │
                     └─────────────────┘  └─────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              CROSS-FUNCTIONAL CASES (Optional)               │
│  - Finance: P&L, quarterly reports, variance                 │
│  - HR: Performance, CV analysis, NLP                         │
│  - Sales: Pipeline, forecasting, win/loss analysis           │
│  - Operations: Real-time KPIs, alerts, SLAs                  │
│  - Customer 360: RFM, CLV, Next Best Action                  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      CLEANUP (Final)                         │
│  - Complete cleanup script                                   │
│  - Verify all objects removed                                │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│               QA - QUALITY CONTROL (MANDATORY)               │
│  - Validate SQL syntax                                       │
│  - Verify data consistency                                   │
│  - Review logical flow                                       │
│  - Confirm trial compatibility                               │
│  - Document results                                          │
└─────────────────────────────────────────────────────────────┘
```

---

## Generation Checklist

### Pre-Generation
- [ ] Client URL obtained and analyzed
- [ ] Industry identified
- [ ] Marketplace datasets selected
- [ ] Modules to include defined
- [ ] Is trial account? → Adjust capabilities

### During Generation
- [ ] Initial setup complete
- [ ] Synthetic data coherent with the business
- [ ] Each module is independent
- [ ] Clear Snowsight UI instructions (if trial)
- [ ] Verifications after each step

### Post-Generation
- [ ] Self-contained and functional HTML
- [ ] SQL scripts in separate folder
- [ ] Cleanup script included
- [ ] No competitor comparisons
- [ ] Synthetic data disclaimer included
- [ ] **QA completed and documented** ✅

---

## Templates HTML/CSS/JS

### Snowflake Branding
| Color | Hex | Use |
|-------|-----|-----|
| Primary Blue | `#29B5E8` | CTAs, links, highlights |
| Dark Blue | `#1565C0` | Headers, gradients |
| Green | `#51cf66` | Success, completed |
| Red | `#ff6b6b` | Error, warning |
| Yellow | `#ffd43b` | Warning, tips |

### Logo
- URL: `https://www.logo.wine/a/logo/Snowflake_Inc./Snowflake_Inc.-Logo.wine.svg`
- Recommended size: 180px x 180px

### Available Templates
| Template | Description |
|----------|-------------|
| `html-template.md` | Complete HTML structure with variables |
| `css-styles.md` | CSS with variables, components, responsive, print |
| `js-functions.md` | Progress tracking, copy code, syntax highlight |

---

## Quick References

| Resource | Location |
|---------|-----------|
| HTML Template | [templates/html-template.md](../templates/html-template.md) |
| CSS Styles | [templates/css-styles.md](../templates/css-styles.md) |
| JavaScript | [templates/js-functions.md](../templates/js-functions.md) |
| QA Checklist | [qa-checklist.md](../qa-checklist.md) |
| Marketplace Datasets | [marketplace-datasets.md](marketplace-datasets.md) |
| Trial Limitations | [trial-limitations.md](trial-limitations.md) |
| Troubleshooting | [troubleshooting.md](troubleshooting.md) |

---

## Critical Rules

1. **ALWAYS** ask if it's a trial account before generating
2. **NEVER** use `SYSTEM$CORTEX_ANALYST_FAST_GENERATION` → Use Snowsight UI
3. **ALWAYS** include synthetic data disclaimer
4. **NEVER** compare with competitors (AWS, Azure, Databricks, etc.)
5. **ALWAYS** use logo from `logo.wine` at 180px
6. **ALWAYS** make modules independent (no dependencies between them except setup)
7. **ALWAYS** run QA checklist before delivery
8. **NEVER** deliver without validating SQL syntax
9. **ALWAYS** include per-step timings in sidebar nav and total time in hero section
10. **ALWAYS** generate and present the PLAN before writing HTML — requires user approval
11. **ALWAYS** use parallel generation with subagents (4 agents minimum)
12. **NEVER** generate the full HOL in a single sequential task
13. **ALWAYS** use `AI_COMPLETE()` and `AI_SENTIMENT()` — NEVER `SNOWFLAKE.CORTEX.COMPLETE()` or `SNOWFLAKE.CORTEX.SENTIMENT()` (legacy)
14. **ALWAYS** assemble final HTML verifying no placeholders remain unreplaced
15. **ALWAYS** place Snowflake Intelligence (Semantic View + Cortex Agent) as the **LAST functional step** before Cleanup/Time Travel. The agent's Semantic View needs visibility into ALL objects created in prior steps (views, Dynamic Tables, geospatial views). Never place Intelligence before steps that create analytical objects.

---

## Metrics

| Metric | Value |
|---------|-------|
| Supported industries | 11 |
| Technical modules | 6 |
| Cross-functional modules | 5 |
| Output templates | 3 |
| Parallel subagents | 4 |
| Average generation time | 8-12 min (parallel) |
| Generated HOL duration | 45-90 min |

### Timing per Activity (Reference)

Each HOL step **MUST** include its estimated duration in:
1. The step's `step-header` (`<span class="step-duration">~X min</span>`)
2. The sidebar navigation (`<span class="nav-time">X min</span>`)
3. The total time in the hero section and progress bar

| Step Type | Recommended Duration |
|--------------|---------------------|
| Setup (DB, WH, schemas) | 3-5 min |
| Load synthetic data | 8-15 min |
| Cortex AI Functions | 10-15 min |
| Snowflake Intelligence (SV + Agent) | 12-18 min |
| Dynamic Tables | 5-10 min |
| Streamlit in Snowflake | 12-18 min |
| Time Travel & Cloning | 5-8 min |
| Marketplace Integration | 5-10 min |
| Cross-functional case | 8-12 min |
| Cleanup | 2-3 min |

**Rule**: The sum of all step times must equal the `{{DURATION}}` in the hero section.

---

## Workshop Mode

### Workshop vs Single HOL

| Aspect | Single HOL | Workshop |
|--------|-----------|----------|
| Output | 1 HTML file | N lab HTMLs + 1 index HTML |
| Duration | 45-90 min | 3-8 hours (2-6 labs) |
| Modules | 1-6 core modules | Core + advanced modules |
| Complexity | Linear | Progressive or independent |
| Progress | Per-step localStorage | Per-lab + global localStorage |
| Audience | Individual practitioner | Team training / deep-dive |

### Workshop Naming Convention
```
{client}_workshop_index.html
{client}_workshop_lab1_{topic_slug}.html
{client}_workshop_lab2_{topic_slug}.html
...
```

### Workshop localStorage Keys
```
// Per-lab progress (written by each lab HTML):
workshop_{client_key}_lab{N}_progress = { started: true, completed: false, steps: {...} }

// Global progress (read by index page):
// Reads ALL per-lab keys to compute overall %
```

### Advanced Modules (Workshop-only)

| Module | File | Duration | Enterprise? |
|--------|------|----------|-------------|
| Versioned Semantic Layer | `modules/versioned-semantic-layer/SKILL.md` | ~20 min | Partial |
| dbt Semantic Layer | `modules/dbt-semantic-layer/SKILL.md` | ~20 min | Yes |
| Data Clean Rooms | `modules/data-clean-rooms/SKILL.md` | ~25 min | Yes |
| Semantic View Composability | `modules/semantic-view-composability/SKILL.md` | ~15 min | No |
| Data Monetization | `modules/data-monetization/SKILL.md` | ~20 min | Partial |

---

## Versioning

| Version | Date | Changes |
|---------|-------|---------|
| 1.0 | 2024-10 | Initial version with retail |
| 2.0 | 2024-11 | Modular modules, trial compatibility |
| 3.0 | 2025-01 | +7 industries, +3 cross-functional, mandatory QA, HTML/CSS/JS templates |
| 3.1 | 2025-03 | Per-activity timings in sidebar nav and hero, duration guide per step type |
| 4.0 | 2026-03 | Mandatory upfront planning, parallel generation with 4 subagents, updated Cortex AI syntax (AI_COMPLETE/AI_SENTIMENT), placeholder-based assembly, 8-step workflow |
| 5.0 | 2026-05 | Multi-HOL Workshop mode, 5 advanced modules (versioned SL, dbt, DCR, composability, monetization), workshop index template, cross-lab QA |

---

## Directory Structure

```
snowflake-hol-generator/
├── SKILL.md                              # Entry point (Single HOL + Workshop)
├── SKILL_EN.md                           # English version
├── README.md                             # Documentation for export
├── qa-checklist.md                       # Mandatory QA checklist
│
├── workshop/
│   └── SKILL.md                          # Workshop orchestration logic
│
├── setup/
│   └── SKILL.md                          # Initial setup (MANDATORY)
│
├── modules/
│   ├── intelligence/SKILL.md             # Snowflake Intelligence (Cortex Analyst)
│   ├── cortex-ai/SKILL.md               # Cortex AI Functions
│   ├── dynamic-tables/SKILL.md          # Dynamic Tables
│   ├── time-travel/SKILL.md             # Time Travel & Cloning
│   ├── marketplace/SKILL.md             # Marketplace Integration
│   ├── streamlit/SKILL.md               # Streamlit Dashboard
│   ├── versioned-semantic-layer/SKILL.md # Versioned Semantic Layer (Advanced)
│   ├── dbt-semantic-layer/SKILL.md      # dbt Projects + Semantic Views (Advanced)
│   ├── data-clean-rooms/SKILL.md        # Data Clean Rooms (Advanced)
│   ├── semantic-view-composability/SKILL.md # SV Composability (Advanced)
│   └── data-monetization/SKILL.md       # Data Monetization Architecture (Advanced)
│
├── industries/
│   ├── retail/SKILL.md                   # Retail
│   ├── cpg/SKILL.md                     # Consumer Packaged Goods
│   ├── manufacturing/SKILL.md           # Manufacturing
│   ├── financial-services/SKILL.md      # Financial Services
│   ├── healthcare-pharma/SKILL.md       # Healthcare and Pharma
│   ├── technology-saas/SKILL.md         # Technology and SaaS
│   ├── logistics/SKILL.md               # Logistics and Transport
│   ├── energy-utilities/SKILL.md        # Energy and Utilities
│   ├── telecommunications/SKILL.md      # Telecommunications
│   ├── bpo/SKILL.md                     # BPO and Contact Centers
│   └── generic/SKILL.md                 # Generic (any industry)
│
├── cross-functional/
│   ├── finance/SKILL.md                 # Finance (P&L, reports)
│   ├── hr-analytics/SKILL.md            # HR (performance, CVs)
│   ├── sales-analytics/SKILL.md         # Sales (pipeline, forecasting)
│   ├── operations/SKILL.md              # Operations (KPIs, alerts)
│   └── customer-360/SKILL.md            # Customer 360 (RFM, CLV, NBA)
│
├── references/
│   ├── hol-reference.md                 # This file — tables, rules, metrics
│   ├── marketplace-datasets.md          # Free datasets by industry
│   ├── trial-limitations.md             # Trial account limitations
│   ├── sql-patterns.md                  # Reusable SQL patterns
│   └── troubleshooting.md              # Common errors and solutions
│
└── templates/
    ├── html-template.md                 # Base HTML template (Single HOL)
    ├── workshop-index-template.md       # Workshop index page template
    ├── css-styles.md                    # Snowflake branding CSS
    └── js-functions.md                  # JavaScript for interactivity
```
