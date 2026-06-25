# HTML Template para Hands-On Labs

Este template genera la estructura HTML completa para un HOL interactivo.

## Template Principal

```html
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{HOL_TITLE}} | Snowflake Hands-On Lab</title>
    <link rel="stylesheet" href="styles.css">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    <link rel="icon" type="image/svg+xml" href="https://www.logo.wine/a/logo/Snowflake_Inc./Snowflake_Inc.-Logo.wine.svg">
</head>
<body>
    <!-- Header -->
    <header class="hol-header">
        <div class="header-container">
            <div class="logo-section">
                <img src="https://www.logo.wine/a/logo/Snowflake_Inc./Snowflake_Inc.-Logo.wine.svg" 
                     alt="Snowflake" class="snowflake-logo">
                <span class="logo-divider"></span>
                <span class="hol-badge">Hands-On Lab</span>
            </div>
            <nav class="header-nav">
                <a href="#overview">Visión General</a>
                <a href="#prerequisites">Requisitos</a>
                <a href="#steps">Pasos</a>
                <a href="#resources">Recursos</a>
            </nav>
        </div>
    </header>

    <!-- Hero Section -->
    <section class="hero-section">
        <div class="hero-container">
            <div class="hero-content">
                <span class="industry-tag">{{INDUSTRY_TAG}}</span>
                <h1 class="hero-title">{{HOL_TITLE}}</h1>
                <p class="hero-subtitle">{{HOL_SUBTITLE}}</p>
                <div class="hero-meta">
                    <div class="meta-item">
                        <svg class="meta-icon" viewBox="0 0 24 24"><path d="M12 2C6.5 2 2 6.5 2 12s4.5 10 10 10 10-4.5 10-10S17.5 2 12 2zm0 18c-4.4 0-8-3.6-8-8s3.6-8 8-8 8 3.6 8 8-3.6 8-8 8zm.5-13H11v6l5.2 3.2.8-1.3-4.5-2.7V7z"/></svg>
                        <span>{{DURATION}} minutos</span>
                    </div>
                    <div class="meta-item">
                        <svg class="meta-icon" viewBox="0 0 24 24"><path d="M12 2L1 21h22L12 2zm0 4l7.5 13h-15L12 6z"/></svg>
                        <span>{{DIFFICULTY}}</span>
                    </div>
                    <div class="meta-item">
                        <svg class="meta-icon" viewBox="0 0 24 24"><path d="M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm0 16H5V5h14v14z"/></svg>
                        <span>{{STEPS_COUNT}} pasos</span>
                    </div>
                </div>
                <a href="#step-1" class="hero-cta">Comenzar Lab</a>
            </div>
            <div class="hero-visual">
                <div class="architecture-preview">
                    {{ARCHITECTURE_DIAGRAM}}
                </div>
            </div>
        </div>
    </section>

    <!-- Overview Section -->
    <section id="overview" class="content-section">
        <div class="section-container">
            <h2 class="section-title">Visión General</h2>
            <div class="overview-grid">
                <div class="overview-card">
                    <h3>Lo que aprenderás</h3>
                    <ul class="learning-list">
                        {{LEARNING_OBJECTIVES}}
                    </ul>
                </div>
                <div class="overview-card">
                    <h3>Tecnologías utilizadas</h3>
                    <div class="tech-tags">
                        {{TECHNOLOGIES}}
                    </div>
                </div>
                <div class="overview-card highlight">
                    <h3>Caso de uso</h3>
                    <p>{{USE_CASE_DESCRIPTION}}</p>
                </div>
            </div>
        </div>
    </section>

    <!-- Prerequisites Section -->
    <section id="prerequisites" class="content-section alt-bg">
        <div class="section-container">
            <h2 class="section-title">Requisitos Previos</h2>
            <div class="prerequisites-grid">
                {{PREREQUISITES}}
            </div>
        </div>
    </section>

    <!-- Progress Tracker -->
    <aside class="progress-tracker" id="progressTracker">
        <div class="progress-header">
            <span>Progreso</span>
            <span class="progress-percent">0%</span>
        </div>
        <div class="progress-bar">
            <div class="progress-fill" id="progressFill"></div>
        </div>
        <nav class="steps-nav" id="stepsNav">
            {{STEPS_NAV}}
        </nav>
    </aside>

    <!-- Steps Container -->
    <main class="steps-container" id="steps">
        {{STEPS_CONTENT}}
    </main>

    <!-- Resources Section -->
    <section id="resources" class="content-section">
        <div class="section-container">
            <h2 class="section-title">Recursos Adicionales</h2>
            <div class="resources-grid">
                {{RESOURCES}}
            </div>
        </div>
    </section>

    <!-- Completion Section -->
    <section class="completion-section" id="completionSection">
        <div class="completion-container">
            <div class="completion-icon">
                <svg viewBox="0 0 24 24"><path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17z"/></svg>
            </div>
            <h2>¡Felicitaciones!</h2>
            <p>Has completado el Hands-On Lab exitosamente.</p>
            <div class="completion-summary">
                <div class="summary-item">
                    <span class="summary-label">Tiempo total</span>
                    <span class="summary-value" id="totalTime">--</span>
                </div>
                <div class="summary-item">
                    <span class="summary-label">Pasos completados</span>
                    <span class="summary-value">{{STEPS_COUNT}}/{{STEPS_COUNT}}</span>
                </div>
            </div>
            <div class="next-actions">
                <h3>Próximos pasos recomendados</h3>
                {{NEXT_STEPS}}
            </div>
        </div>
    </section>

    <!-- Footer -->
    <footer class="hol-footer">
        <div class="footer-container">
            <div class="footer-brand">
                <img src="https://www.logo.wine/a/logo/Snowflake_Inc./Snowflake_Inc.-Logo.wine.svg" 
                     alt="Snowflake" class="footer-logo">
                <p>Snowflake Hands-On Labs</p>
            </div>
            <div class="footer-links">
                <a href="https://docs.snowflake.com" target="_blank">Documentación</a>
                <a href="https://community.snowflake.com" target="_blank">Comunidad</a>
                <a href="https://quickstarts.snowflake.com" target="_blank">Más Labs</a>
            </div>
            <div class="footer-meta">
                <p>Generado con Snowflake HOL Generator</p>
                <p>© {{YEAR}} Snowflake Inc.</p>
            </div>
        </div>
    </footer>

    <script src="hol-functions.js"></script>
</body>
</html>
```

## Componentes Reutilizables

### Step Template

```html
<article class="step-card" id="step-{{STEP_NUMBER}}" data-step="{{STEP_NUMBER}}">
    <div class="step-header">
        <div class="step-number">{{STEP_NUMBER}}</div>
        <div class="step-info">
            <h2 class="step-title">{{STEP_TITLE}}</h2>
            <span class="step-duration">~{{STEP_DURATION}} min</span>
        </div>
        <button class="step-toggle" aria-expanded="true">
            <svg viewBox="0 0 24 24"><path d="M7.41 8.59L12 13.17l4.59-4.58L18 10l-6 6-6-6 1.41-1.41z"/></svg>
        </button>
    </div>
    <div class="step-content">
        <div class="step-description">
            {{STEP_DESCRIPTION}}
        </div>
        {{STEP_SUBSTEPS}}
        <div class="step-actions">
            <button class="btn-check" onclick="markStepComplete({{STEP_NUMBER}})">
                <svg viewBox="0 0 24 24"><path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17z"/></svg>
                Marcar como completado
            </button>
        </div>
    </div>
</article>
```

### Code Block Template

```html
<div class="code-block" data-language="{{LANGUAGE}}">
    <div class="code-header">
        <span class="code-language">{{LANGUAGE}}</span>
        <div class="code-actions">
            <button class="btn-copy" onclick="copyCode(this)" title="Copiar código">
                <svg viewBox="0 0 24 24"><path d="M16 1H4c-1.1 0-2 .9-2 2v14h2V3h12V1zm3 4H8c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h11c1.1 0 2-.9 2-2V7c0-1.1-.9-2-2-2zm0 16H8V7h11v14z"/></svg>
            </button>
            <button class="btn-run" onclick="openInSnowsight(this)" title="Abrir en Snowsight">
                <svg viewBox="0 0 24 24"><path d="M8 5v14l11-7L8 5z"/></svg>
            </button>
        </div>
    </div>
    <pre><code class="language-{{LANGUAGE}}">{{CODE_CONTENT}}</code></pre>
</div>
```

### Alert/Callout Template

```html
<div class="callout callout-{{TYPE}}">
    <div class="callout-icon">
        {{CALLOUT_ICON}}
    </div>
    <div class="callout-content">
        <strong class="callout-title">{{CALLOUT_TITLE}}</strong>
        <p>{{CALLOUT_MESSAGE}}</p>
    </div>
</div>
```

**Tipos de Callout:**
- `info`: Información general (icono: círculo con i)
- `warning`: Advertencias (icono: triángulo con !)
- `success`: Éxito/completado (icono: check)
- `tip`: Tips y mejores prácticas (icono: bombilla)
- `danger`: Errores o acciones destructivas (icono: X)

### Table Template

```html
<div class="table-wrapper">
    <table class="data-table">
        <thead>
            <tr>
                {{TABLE_HEADERS}}
            </tr>
        </thead>
        <tbody>
            {{TABLE_ROWS}}
        </tbody>
    </table>
</div>
```

### Prerequisites Card Template

```html
<div class="prereq-card">
    <div class="prereq-icon {{PREREQ_STATUS}}">
        {{PREREQ_ICON}}
    </div>
    <div class="prereq-info">
        <h4>{{PREREQ_TITLE}}</h4>
        <p>{{PREREQ_DESCRIPTION}}</p>
    </div>
    <a href="{{PREREQ_LINK}}" class="prereq-action" target="_blank">
        {{PREREQ_ACTION_TEXT}}
    </a>
</div>
```

### Technology Tag Template

```html
<span class="tech-tag" data-category="{{CATEGORY}}">
    <img src="{{TECH_ICON}}" alt="{{TECH_NAME}}" class="tech-icon">
    {{TECH_NAME}}
</span>
```

### Resource Card Template

```html
<a href="{{RESOURCE_URL}}" class="resource-card" target="_blank">
    <div class="resource-icon">
        {{RESOURCE_ICON}}
    </div>
    <div class="resource-info">
        <h4>{{RESOURCE_TITLE}}</h4>
        <p>{{RESOURCE_DESCRIPTION}}</p>
    </div>
    <svg class="external-icon" viewBox="0 0 24 24"><path d="M19 19H5V5h7V3H5a2 2 0 00-2 2v14a2 2 0 002 2h14c1.1 0 2-.9 2-2v-7h-2v7zM14 3v2h3.59l-9.83 9.83 1.41 1.41L19 6.41V10h2V3h-7z"/></svg>
</a>
```

## Variables del Template

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `{{HOL_TITLE}}` | Título del lab | "Customer 360 con Cortex AI" |
| `{{HOL_SUBTITLE}}` | Subtítulo descriptivo | "Construye una visión 360° del cliente..." |
| `{{INDUSTRY_TAG}}` | Tag de industria | "Retail", "Healthcare", "Financial Services" |
| `{{DURATION}}` | Duración en minutos | "60" |
| `{{DIFFICULTY}}` | Nivel de dificultad | "Intermedio" |
| `{{STEPS_COUNT}}` | Número total de pasos | "8" |
| `{{YEAR}}` | Año actual | "2025" |

## Iconos SVG Incluidos

```html
<!-- Check -->
<svg viewBox="0 0 24 24"><path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17z"/></svg>

<!-- Clock -->
<svg viewBox="0 0 24 24"><path d="M12 2C6.5 2 2 6.5 2 12s4.5 10 10 10 10-4.5 10-10S17.5 2 12 2zm0 18c-4.4 0-8-3.6-8-8s3.6-8 8-8 8 3.6 8 8-3.6 8-8 8zm.5-13H11v6l5.2 3.2.8-1.3-4.5-2.7V7z"/></svg>

<!-- Info -->
<svg viewBox="0 0 24 24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-6h2v6zm0-8h-2V7h2v2z"/></svg>

<!-- Warning -->
<svg viewBox="0 0 24 24"><path d="M1 21h22L12 2 1 21zm12-3h-2v-2h2v2zm0-4h-2v-4h2v4z"/></svg>

<!-- Lightbulb (Tip) -->
<svg viewBox="0 0 24 24"><path d="M9 21c0 .5.4 1 1 1h4c.6 0 1-.5 1-1v-1H9v1zm3-19C8.1 2 5 5.1 5 9c0 2.4 1.2 4.5 3 5.7V17c0 .5.4 1 1 1h6c.6 0 1-.5 1-1v-2.3c1.8-1.3 3-3.4 3-5.7 0-3.9-3.1-7-7-7z"/></svg>

<!-- Copy -->
<svg viewBox="0 0 24 24"><path d="M16 1H4c-1.1 0-2 .9-2 2v14h2V3h12V1zm3 4H8c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h11c1.1 0 2-.9 2-2V7c0-1.1-.9-2-2-2zm0 16H8V7h11v14z"/></svg>

<!-- Play -->
<svg viewBox="0 0 24 24"><path d="M8 5v14l11-7L8 5z"/></svg>

<!-- External Link -->
<svg viewBox="0 0 24 24"><path d="M19 19H5V5h7V3H5a2 2 0 00-2 2v14a2 2 0 002 2h14c1.1 0 2-.9 2-2v-7h-2v7zM14 3v2h3.59l-9.83 9.83 1.41 1.41L19 6.41V10h2V3h-7z"/></svg>
```
