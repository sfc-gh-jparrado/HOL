# Workshop Index Page Template

This template generates the landing page for a multi-HOL workshop. It includes global progress tracking, lab cards with dependencies, and architecture overview.

## Template Principal

```html
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{WORKSHOP_TITLE}} | Snowflake Workshop</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@400;600;700;800&family=Lato:wght@300;400;700&display=swap" rel="stylesheet">
    <link rel="icon" type="image/svg+xml" href="https://www.logo.wine/a/logo/Snowflake_Inc./Snowflake_Inc.-Logo.wine.svg">
    <style>
        /* === CSS Variables === */
        :root {
            --sf-blue: #29B5E8;
            --sf-mid-blue: #11567F;
            --sf-dark: #0a3a5c;
            --sf-text: #5B5B5B;
            --sf-light-bg: #f8fafc;
            --sf-success: #51cf66;
            --sf-warning: #ffd43b;
            --sf-locked: #dee2e6;
            --font-heading: 'Montserrat', sans-serif;
            --font-body: 'Lato', sans-serif;
            --radius-lg: 12px;
            --radius-xl: 16px;
            --radius-full: 50px;
            --shadow-sm: 0 2px 8px rgba(0,0,0,0.08);
            --shadow-md: 0 4px 16px rgba(0,0,0,0.12);
            --shadow-lg: 0 8px 32px rgba(0,0,0,0.16);
            --space-sm: 0.5rem;
            --space-md: 1rem;
            --space-lg: 1.5rem;
            --space-xl: 2rem;
            --space-2xl: 3rem;
            --content-max-width: 1200px;
        }

        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: var(--font-body);
            color: var(--sf-text);
            line-height: 1.6;
            background: var(--sf-light-bg);
        }

        /* === Header === */
        .workshop-header {
            background: white;
            border-bottom: 1px solid #e9ecef;
            padding: 1rem 2rem;
            position: sticky;
            top: 0;
            z-index: 100;
        }
        .header-container {
            max-width: var(--content-max-width);
            margin: 0 auto;
            display: flex;
            align-items: center;
            justify-content: space-between;
        }
        .logo-section {
            display: flex;
            align-items: center;
            gap: 1rem;
        }
        .snowflake-logo { height: 40px; }
        .workshop-badge {
            background: var(--sf-blue);
            color: white;
            padding: 4px 12px;
            border-radius: var(--radius-full);
            font-size: 0.75rem;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }

        /* === Hero === */
        .hero-section {
            background: linear-gradient(135deg, var(--sf-mid-blue) 0%, var(--sf-dark) 100%);
            color: white;
            padding: 4rem 2rem;
            text-align: center;
        }
        .hero-container {
            max-width: var(--content-max-width);
            margin: 0 auto;
        }
        .hero-title {
            font-family: var(--font-heading);
            font-size: 2.5rem;
            font-weight: 800;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            margin-bottom: var(--space-md);
        }
        .hero-subtitle {
            font-size: 1.2rem;
            opacity: 0.9;
            max-width: 700px;
            margin: 0 auto var(--space-xl);
        }
        .hero-meta {
            display: flex;
            justify-content: center;
            gap: var(--space-xl);
            flex-wrap: wrap;
        }
        .meta-badge {
            background: rgba(255,255,255,0.15);
            padding: 8px 16px;
            border-radius: var(--radius-full);
            font-size: 0.9rem;
            font-weight: 600;
        }

        /* === Global Progress === */
        .progress-section {
            background: white;
            padding: var(--space-xl) 2rem;
            border-bottom: 1px solid #e9ecef;
        }
        .progress-container {
            max-width: var(--content-max-width);
            margin: 0 auto;
            display: flex;
            align-items: center;
            gap: var(--space-xl);
        }
        .progress-label {
            font-family: var(--font-heading);
            font-weight: 700;
            font-size: 0.9rem;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            white-space: nowrap;
        }
        .progress-bar-wrapper {
            flex: 1;
            background: #e9ecef;
            border-radius: var(--radius-full);
            height: 12px;
            overflow: hidden;
        }
        .progress-bar-fill {
            height: 100%;
            background: linear-gradient(90deg, var(--sf-blue), var(--sf-success));
            border-radius: var(--radius-full);
            transition: width 0.5s ease;
            width: 0%;
        }
        .progress-percent {
            font-weight: 700;
            font-size: 1.1rem;
            color: var(--sf-mid-blue);
            min-width: 45px;
        }

        /* === Labs Grid === */
        .labs-section {
            max-width: var(--content-max-width);
            margin: 0 auto;
            padding: var(--space-2xl) 2rem;
        }
        .section-title {
            font-family: var(--font-heading);
            font-size: 1.5rem;
            font-weight: 800;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            color: var(--sf-mid-blue);
            margin-bottom: var(--space-xl);
        }
        .labs-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(340px, 1fr));
            gap: var(--space-xl);
        }

        /* === Lab Card === */
        .lab-card {
            background: white;
            border-radius: var(--radius-xl);
            padding: var(--space-xl);
            box-shadow: var(--shadow-sm);
            border: 2px solid transparent;
            transition: all 0.3s ease;
            display: flex;
            flex-direction: column;
            position: relative;
            overflow: hidden;
        }
        .lab-card:hover {
            box-shadow: var(--shadow-md);
            transform: translateY(-2px);
        }
        .lab-card[data-status="completed"] {
            border-color: var(--sf-success);
        }
        .lab-card[data-status="in-progress"] {
            border-color: var(--sf-blue);
        }
        .lab-card[data-status="locked"] {
            opacity: 0.6;
        }
        .lab-number {
            position: absolute;
            top: var(--space-md);
            right: var(--space-md);
            background: var(--sf-light-bg);
            width: 36px;
            height: 36px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-family: var(--font-heading);
            font-weight: 800;
            font-size: 0.9rem;
            color: var(--sf-mid-blue);
        }
        .lab-title {
            font-family: var(--font-heading);
            font-size: 1.1rem;
            font-weight: 700;
            color: var(--sf-mid-blue);
            margin-bottom: var(--space-sm);
            padding-right: 40px;
        }
        .lab-description {
            font-size: 0.9rem;
            color: var(--sf-text);
            margin-bottom: var(--space-lg);
            flex: 1;
        }
        .lab-meta {
            display: flex;
            gap: var(--space-md);
            margin-bottom: var(--space-md);
            flex-wrap: wrap;
        }
        .lab-tag {
            background: var(--sf-light-bg);
            padding: 4px 10px;
            border-radius: var(--radius-full);
            font-size: 0.75rem;
            font-weight: 600;
        }
        .lab-prerequisites {
            font-size: 0.8rem;
            color: #868e96;
            margin-bottom: var(--space-md);
        }
        .lab-cta {
            display: inline-block;
            background: var(--sf-blue);
            color: white;
            padding: 10px 20px;
            border-radius: var(--radius-full);
            text-decoration: none;
            font-weight: 700;
            font-size: 0.875rem;
            text-align: center;
            transition: background 0.2s;
        }
        .lab-cta:hover { background: var(--sf-mid-blue); }
        .lab-card[data-status="locked"] .lab-cta {
            background: var(--sf-locked);
            color: #868e96;
            pointer-events: none;
        }
        .lab-card[data-status="completed"] .lab-cta {
            background: var(--sf-success);
        }

        /* === Status Badge === */
        .status-badge {
            position: absolute;
            top: var(--space-md);
            left: var(--space-md);
            padding: 3px 10px;
            border-radius: var(--radius-full);
            font-size: 0.7rem;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        .status-badge.completed { background: #d3f9d8; color: #2b8a3e; }
        .status-badge.in-progress { background: #d0ebff; color: #1864ab; }
        .status-badge.locked { background: #e9ecef; color: #868e96; }
        .status-badge.available { background: #fff3bf; color: #e67700; }

        /* === Architecture Section === */
        .architecture-section {
            background: white;
            padding: var(--space-2xl) 2rem;
            margin-top: var(--space-xl);
        }
        .architecture-container {
            max-width: var(--content-max-width);
            margin: 0 auto;
        }
        .architecture-diagram {
            background: var(--sf-light-bg);
            border-radius: var(--radius-xl);
            padding: var(--space-xl);
            font-family: monospace;
            font-size: 0.85rem;
            overflow-x: auto;
            white-space: pre;
            line-height: 1.4;
        }

        /* === Footer === */
        .workshop-footer {
            background: var(--sf-dark);
            color: white;
            padding: var(--space-2xl) 2rem;
            text-align: center;
            margin-top: var(--space-2xl);
        }
        .footer-logo { height: 32px; margin-bottom: var(--space-md); }
        .footer-text { opacity: 0.7; font-size: 0.85rem; }

        /* === Responsive === */
        @media (max-width: 768px) {
            .hero-title { font-size: 1.8rem; }
            .labs-grid { grid-template-columns: 1fr; }
            .hero-meta { flex-direction: column; align-items: center; }
        }
    </style>
</head>
<body>
    <!-- Header -->
    <header class="workshop-header">
        <div class="header-container">
            <div class="logo-section">
                <img src="https://www.logo.wine/a/logo/Snowflake_Inc./Snowflake_Inc.-Logo.wine.svg" 
                     alt="Snowflake" class="snowflake-logo">
                <span class="workshop-badge">Workshop</span>
            </div>
        </div>
    </header>

    <!-- Hero -->
    <section class="hero-section">
        <div class="hero-container">
            <h1 class="hero-title">{{WORKSHOP_TITLE}}</h1>
            <p class="hero-subtitle">{{WORKSHOP_SUBTITLE}}</p>
            <div class="hero-meta">
                <span class="meta-badge">{{TOTAL_LABS}} Labs</span>
                <span class="meta-badge">{{TOTAL_DURATION}} min totales</span>
                <span class="meta-badge">{{DIFFICULTY}}</span>
                <span class="meta-badge">{{INDUSTRY_TAG}}</span>
            </div>
        </div>
    </section>

    <!-- Global Progress -->
    <section class="progress-section">
        <div class="progress-container">
            <span class="progress-label">Progreso Global</span>
            <div class="progress-bar-wrapper">
                <div class="progress-bar-fill" id="globalProgressFill"></div>
            </div>
            <span class="progress-percent" id="globalProgressPercent">0%</span>
        </div>
    </section>

    <!-- Labs Grid -->
    <section class="labs-section">
        <h2 class="section-title">Laboratorios</h2>
        <div class="labs-grid">
            {{LAB_CARDS}}
        </div>
    </section>

    <!-- Architecture Overview -->
    <section class="architecture-section">
        <div class="architecture-container">
            <h2 class="section-title">Arquitectura del Workshop</h2>
            <div class="architecture-diagram">
{{ARCHITECTURE_DIAGRAM}}
            </div>
        </div>
    </section>

    <!-- Footer -->
    <footer class="workshop-footer">
        <img src="https://www.logo.wine/a/logo/Snowflake_Inc./Snowflake_Inc.-Logo.wine.svg" 
             alt="Snowflake" class="footer-logo">
        <p class="footer-text">© {{YEAR}} Snowflake Inc. All Rights Reserved.</p>
        <p class="footer-text">Generado con Snowflake HOL Generator</p>
    </footer>

    <script>
        // === Global Progress Tracking ===
        const TOTAL_LABS = {{TOTAL_LABS_JS}};
        const CLIENT_KEY = '{{CLIENT_KEY}}';

        function updateGlobalProgress() {
            let completedLabs = 0;
            for (let i = 1; i <= TOTAL_LABS; i++) {
                const key = `workshop_${CLIENT_KEY}_lab${i}_progress`;
                const data = JSON.parse(localStorage.getItem(key) || '{}');
                if (data.completed) completedLabs++;
            }
            const percent = Math.round((completedLabs / TOTAL_LABS) * 100);
            document.getElementById('globalProgressFill').style.width = percent + '%';
            document.getElementById('globalProgressPercent').textContent = percent + '%';

            // Update lab card statuses
            updateLabStatuses();
        }

        function updateLabStatuses() {
            const cards = document.querySelectorAll('.lab-card');
            cards.forEach(card => {
                const labNum = parseInt(card.dataset.lab);
                const key = `workshop_${CLIENT_KEY}_lab${labNum}_progress`;
                const data = JSON.parse(localStorage.getItem(key) || '{}');
                
                if (data.completed) {
                    card.dataset.status = 'completed';
                    const badge = card.querySelector('.status-badge');
                    if (badge) { badge.className = 'status-badge completed'; badge.textContent = 'Completado'; }
                    const cta = card.querySelector('.lab-cta');
                    if (cta) cta.textContent = '✓ Completado';
                } else if (data.started) {
                    card.dataset.status = 'in-progress';
                    const badge = card.querySelector('.status-badge');
                    if (badge) { badge.className = 'status-badge in-progress'; badge.textContent = 'En progreso'; }
                }
            });
        }

        // Initialize on load
        document.addEventListener('DOMContentLoaded', updateGlobalProgress);
    </script>
</body>
</html>
```

## Lab Card Template

Use this template for each lab in the `{{LAB_CARDS}}` placeholder:

```html
<div class="lab-card" data-lab="{{LAB_NUMBER}}" data-status="available">
    <span class="status-badge available">Disponible</span>
    <div class="lab-number">{{LAB_NUMBER}}</div>
    <h3 class="lab-title">{{LAB_TITLE}}</h3>
    <p class="lab-description">{{LAB_DESCRIPTION}}</p>
    <div class="lab-meta">
        <span class="lab-tag">~{{LAB_DURATION}} min</span>
        <span class="lab-tag">{{LAB_DIFFICULTY}}</span>
        {{LAB_MODULE_TAGS}}
    </div>
    <p class="lab-prerequisites">
        {{#IF_HAS_PREREQUISITES}}
        Requiere: {{PREREQUISITE_TEXT}}
        {{/IF_HAS_PREREQUISITES}}
        {{#IF_NO_PREREQUISITES}}
        Sin pre-requisitos
        {{/IF_NO_PREREQUISITES}}
    </p>
    <a href="{{LAB_FILENAME}}" class="lab-cta">Comenzar →</a>
</div>
```

## Variables del Template

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `{{WORKSHOP_TITLE}}` | Título del workshop | "Data Monetization & Governance" |
| `{{WORKSHOP_SUBTITLE}}` | Descripción del workshop | "Construye una plataforma de datos..." |
| `{{TOTAL_LABS}}` | Número total de labs | "4" |
| `{{TOTAL_LABS_JS}}` | Mismo valor para JS (sin quotes) | 4 |
| `{{TOTAL_DURATION}}` | Duración total en minutos | "300" |
| `{{DIFFICULTY}}` | Dificultad general | "Intermedio - Avanzado" |
| `{{INDUSTRY_TAG}}` | Tag de industria | "Healthcare/Pharma" |
| `{{CLIENT_KEY}}` | Key para localStorage (lowercase, no spaces) | "acme_pharma" |
| `{{LAB_CARDS}}` | Cards HTML generadas | (ver template arriba) |
| `{{ARCHITECTURE_DIAGRAM}}` | Diagrama ASCII de arquitectura | (monospace text) |
| `{{YEAR}}` | Año actual | "2026" |

## Module Tag Template

For each module in a lab, add a tag in `{{LAB_MODULE_TAGS}}`:

```html
<span class="lab-tag" style="background:#d0ebff; color:#1864ab;">{{MODULE_NAME}}</span>
```

## Dependency Visualization (Optional)

For progressive workshops, include a dependency flow after the labs grid:

```html
<div style="text-align:center; padding:var(--space-xl) 0; font-family:monospace; font-size:0.9rem; color:var(--sf-text);">
    <div style="display:inline-block; text-align:left;">
Lab 1 ──→ Lab 2 ──→ Lab 3 ──→ Lab 4
(Foundation)  (Governance)  (Analytics)  (Monetization)
    </div>
</div>
```
