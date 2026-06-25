# Snowflake Hands-On Lab Generator

<p align="center">
  <img src="https://www.logo.wine/a/logo/Snowflake_Inc./Snowflake_Inc.-Logo.wine.svg" alt="Snowflake" width="180" height="180">
</p>

<p align="center">
  <strong>Generate personalized Snowflake Hands-on Labs by industry</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-3.0-blue" alt="Version">
  <img src="https://img.shields.io/badge/industries-11-green" alt="Industries">
  <img src="https://img.shields.io/badge/modules-11-orange" alt="Modules">
  <img src="https://img.shields.io/badge/trial_compatible-yes-success" alt="Trial Compatible">
</p>

---

## Description

This skill generates fully personalized Snowflake Hands-On Labs (HOLs) for clients and prospects. Generated labs:

- Work on **trial accounts** without special configurations
- Use **synthetic data** relevant to the client's industry
- Are **modular** (each module is independent)
- Include **self-contained HTML** ready to use
- Pass an **exhaustive quality control** check

---

## Installation

### In Cortex Code

```bash
# The skill loads automatically from:
/Users/[user]/Documents/COCO/skills/snowflake-hol-generator/

# To invoke the skill, use any of these triggers:
- "create hol"
- "hands-on lab"
- "snowflake lab"
- "demo lab"
- "hol for [client]"
- "generate lab"
```

### Export to Another Environment

```bash
# Copy the complete folder
cp -r skills/snowflake-hol-generator /destination/skills/

# Required structure:
snowflake-hol-generator/
├── SKILL.md          # Entry point (required)
├── README.md         # This file
├── qa-checklist.md   # Mandatory QA
├── setup/
├── modules/
├── industries/
├── cross-functional/
├── references/
└── templates/
```

---

## Quick Start

### 1. Invoke the skill

```
User: create hol for Acme Corp
```

### 2. Answer the questions

The skill will ask for:
- Client name
- Website URL
- Industry
- If it's a trial account
- Modules to include
- Cross-functional cases

### 3. Receive the output

The skill generates:
- Self-contained HTML with the complete lab
- SQL scripts separated by step
- Cleanup script
- QA report

---

## Supported Industries

| Industry | Folder | Description |
|----------|--------|-------------|
| Retail/CPG | `retail-cpg/` | Stores, e-commerce, omnichannel |
| Manufacturing | `manufacturing/` | Production, quality, supply chain |
| Financial Services | `financial-services/` | Banking, insurance, credits, AML |
| Healthcare/Pharma | `healthcare-pharma/` | Hospitals, pharma, medical reps |
| Technology/SaaS | `technology-saas/` | MRR, ARR, churn, cohorts |
| Logistics | `logistics/` | Fleets, deliveries, GPS tracking |
| Energy/Utilities | `energy-utilities/` | Meters, readings, billing |
| Telecommunications | `telecommunications/` | Subscribers, usage, network, churn |
| CPG | `cpg/` | Brands, retail, POS, inventory |
| BPO | `bpo/` | Contact center, agents, NPS |
| Generic | `generic/` | Adaptable model |

---

## Technical Modules

| Module | Description | Trial Compatible |
|--------|-------------|------------------|
| **Snowflake Intelligence** | Semantic Views, Cortex Analyst, NL questions | ✅ (via Snowsight UI) |
| **Cortex AI Functions** | SENTIMENT, COMPLETE, SUMMARIZE, TRANSLATE | ✅ |
| **Dynamic Tables** | Automatic pipelines with TARGET_LAG | ✅ |
| **Time Travel** | Data recovery, AT(OFFSET), CLONE | ✅ |
| **Marketplace** | Free external datasets | ✅ |
| **Streamlit** | Interactive dashboards in Snowflake | ✅ |

---

## Cross-Functional Modules

| Module | Use Cases |
|--------|-----------|
| **Finance** | P&L, quarterly reports, variance analysis |
| **HR** | Performance, CV analysis with NLP, turnover |
| **Sales** | Pipeline, forecasting, win/loss, performance |
| **Operations** | Real-time KPIs, alerts, SLAs, compliance |
| **Customer 360** | RFM, CLV, Next Best Action, unified view |

---

## Output Templates

### HTML
- Complete responsive structure
- Progress tracker with localStorage
- Syntax highlighting for SQL
- "Copy code" button
- "Open in Snowsight" button

### CSS
- Snowflake branding variables
- Components: cards, callouts, tables, code blocks
- Responsive and print-friendly styles
- Smooth animations

### JavaScript
- Step-by-step progress tracking
- localStorage persistence
- Keyboard shortcuts (Alt+1-9, Alt+C, Alt+N/P)
- Analytics events

---

## Branding

### Snowflake Colors

| Color | Hex | Usage |
|-------|-----|-------|
| Primary Blue | `#29B5E8` | CTAs, links, highlights |
| Dark Blue | `#1565C0` | Headers, gradients |
| Green | `#51cf66` | Success, completed |
| Red | `#ff6b6b` | Error, danger |
| Yellow | `#ffd43b` | Warning, tips |

### Logo

```html
<img src="https://www.logo.wine/a/logo/Snowflake_Inc./Snowflake_Inc.-Logo.wine.svg" 
     alt="Snowflake" 
     width="180" 
     height="180">
```

---

## Quality Assurance (QA)

Every generated HOL goes through a mandatory QA checklist that validates:

1. **SQL Syntax** - Complete statements, balanced parentheses
2. **Trial Compatibility** - Don't use restricted functions
3. **Data Consistency** - Valid FKs, correct ranges
4. **Logical Flow** - Sequential steps, clear dependencies
5. **Documentation** - Clear instructions, no jargon
6. **Security** - No credentials, no real PII

See [qa-checklist.md](qa-checklist.md) for the complete checklist.

---

## Trial Limitations

| Feature | Status | Alternative |
|---------|--------|-------------|
| `SYSTEM$CORTEX_ANALYST_FAST_GENERATION` | ❌ | Snowsight UI |
| CREATE SEMANTIC VIEW (SQL) | ⚠️ | Snowsight Autopilot |
| CREATE AGENT (SQL) | ⚠️ | Snowsight UI |
| Snowpark Container Services | ❌ | Omit |

---

## File Structure

```
snowflake-hol-generator/
├── SKILL.md                    # Main entry point (Spanish)
├── SKILL_EN.md                 # Main entry point (English)
├── README.md                   # Documentation (Spanish)
├── README_EN.md                # Documentation (English)
├── qa-checklist.md             # Mandatory QA checklist
│
├── setup/
│   └── SKILL.md                # Mandatory initial setup
│
├── modules/
│   ├── intelligence/SKILL.md   # Cortex Analyst
│   ├── cortex-ai/SKILL.md      # AI Functions
│   ├── dynamic-tables/SKILL.md # Dynamic Tables
│   ├── time-travel/SKILL.md    # Time Travel
│   ├── marketplace/SKILL.md    # Marketplace
│   └── streamlit/SKILL.md      # Streamlit
│
├── industries/                 # 11 industries
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
├── cross-functional/           # 5 cross-functional modules
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

## Contributing

### Add a New Industry

1. Create folder `industries/new-industry/`
2. Create `SKILL.md` following the template of existing industries
3. Include:
   - Data model (minimum 5 tables)
   - Synthetic data generation SQL
   - Suggested analytical views
   - Questions for Cortex Analyst
4. Update main `SKILL.md`

### Add a New Module

1. Create folder in `modules/` or `cross-functional/`
2. Follow structure of existing modules
3. Ensure independence (only dependency on setup)
4. Update documentation

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 3.0 | 2025-01 | +7 industries, +3 cross-functional, mandatory QA, templates |
| 2.0 | 2024-11 | Modular architecture, trial compatibility |
| 1.0 | 2024-10 | Initial version |

---

## Support

To report issues or suggest improvements:
- Open an issue in the repository
- Contact the Professional Services team

---

## License

Internal Snowflake use. Do not distribute externally without authorization.

---

<p align="center">
  <sub>Generated with Snowflake HOL Generator v3.0</sub>
</p>
