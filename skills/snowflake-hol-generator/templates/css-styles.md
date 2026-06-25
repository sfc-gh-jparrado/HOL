# CSS Styles para Hands-On Labs

Estilos CSS completos para HOLs con branding Snowflake.

## Variables y Colores Base

```css
:root {
    /* Snowflake Brand Colors */
    --sf-blue-primary: #29B5E8;
    --sf-blue-dark: #1565C0;
    --sf-blue-light: #E3F2FD;
    --sf-green: #51cf66;
    --sf-red: #ff6b6b;
    --sf-yellow: #ffd43b;
    --sf-orange: #ff922b;
    
    /* Neutral Colors */
    --gray-50: #f8fafc;
    --gray-100: #f1f5f9;
    --gray-200: #e2e8f0;
    --gray-300: #cbd5e1;
    --gray-400: #94a3b8;
    --gray-500: #64748b;
    --gray-600: #475569;
    --gray-700: #334155;
    --gray-800: #1e293b;
    --gray-900: #0f172a;
    
    /* Semantic Colors */
    --color-success: var(--sf-green);
    --color-warning: var(--sf-yellow);
    --color-error: var(--sf-red);
    --color-info: var(--sf-blue-primary);
    
    /* Typography */
    --font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    --font-mono: 'JetBrains Mono', 'Fira Code', 'Consolas', monospace;
    
    /* Spacing */
    --space-xs: 0.25rem;
    --space-sm: 0.5rem;
    --space-md: 1rem;
    --space-lg: 1.5rem;
    --space-xl: 2rem;
    --space-2xl: 3rem;
    --space-3xl: 4rem;
    
    /* Border Radius */
    --radius-sm: 4px;
    --radius-md: 8px;
    --radius-lg: 12px;
    --radius-xl: 16px;
    --radius-full: 9999px;
    
    /* Shadows */
    --shadow-sm: 0 1px 2px rgba(0, 0, 0, 0.05);
    --shadow-md: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
    --shadow-lg: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
    --shadow-xl: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
    
    /* Transitions */
    --transition-fast: 150ms ease;
    --transition-normal: 250ms ease;
    --transition-slow: 350ms ease;
    
    /* Layout */
    --header-height: 64px;
    --sidebar-width: 280px;
    --content-max-width: 900px;
}
```

## Reset y Base

```css
*, *::before, *::after {
    box-sizing: border-box;
    margin: 0;
    padding: 0;
}

html {
    scroll-behavior: smooth;
    scroll-padding-top: calc(var(--header-height) + var(--space-lg));
}

body {
    font-family: var(--font-family);
    font-size: 16px;
    line-height: 1.6;
    color: var(--gray-800);
    background-color: var(--gray-50);
    -webkit-font-smoothing: antialiased;
    -moz-osx-font-smoothing: grayscale;
}

img {
    max-width: 100%;
    height: auto;
}

a {
    color: var(--sf-blue-primary);
    text-decoration: none;
    transition: color var(--transition-fast);
}

a:hover {
    color: var(--sf-blue-dark);
}
```

## Header

```css
.hol-header {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    height: var(--header-height);
    background: white;
    border-bottom: 1px solid var(--gray-200);
    z-index: 100;
    box-shadow: var(--shadow-sm);
}

.header-container {
    max-width: 1400px;
    margin: 0 auto;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0 var(--space-xl);
}

.logo-section {
    display: flex;
    align-items: center;
    gap: var(--space-md);
}

.snowflake-logo {
    height: 40px;
    width: auto;
}

.logo-divider {
    width: 1px;
    height: 24px;
    background: var(--gray-300);
}

.hol-badge {
    background: linear-gradient(135deg, var(--sf-blue-primary), var(--sf-blue-dark));
    color: white;
    padding: var(--space-xs) var(--space-sm);
    border-radius: var(--radius-sm);
    font-size: 0.75rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.5px;
}

.header-nav {
    display: flex;
    gap: var(--space-lg);
}

.header-nav a {
    color: var(--gray-600);
    font-weight: 500;
    font-size: 0.875rem;
    padding: var(--space-sm);
    border-radius: var(--radius-sm);
    transition: all var(--transition-fast);
}

.header-nav a:hover {
    color: var(--sf-blue-primary);
    background: var(--sf-blue-light);
}
```

## Hero Section

```css
.hero-section {
    margin-top: var(--header-height);
    background: linear-gradient(135deg, var(--gray-900) 0%, var(--gray-800) 100%);
    padding: var(--space-3xl) 0;
    color: white;
}

.hero-container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 0 var(--space-xl);
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: var(--space-3xl);
    align-items: center;
}

.industry-tag {
    display: inline-block;
    background: rgba(41, 181, 232, 0.2);
    color: var(--sf-blue-primary);
    padding: var(--space-xs) var(--space-md);
    border-radius: var(--radius-full);
    font-size: 0.875rem;
    font-weight: 500;
    margin-bottom: var(--space-md);
}

.hero-title {
    font-size: 2.5rem;
    font-weight: 700;
    line-height: 1.2;
    margin-bottom: var(--space-md);
}

.hero-subtitle {
    font-size: 1.125rem;
    color: var(--gray-300);
    margin-bottom: var(--space-xl);
    line-height: 1.7;
}

.hero-meta {
    display: flex;
    gap: var(--space-xl);
    margin-bottom: var(--space-xl);
}

.meta-item {
    display: flex;
    align-items: center;
    gap: var(--space-sm);
    color: var(--gray-400);
    font-size: 0.875rem;
}

.meta-icon {
    width: 18px;
    height: 18px;
    fill: currentColor;
}

.hero-cta {
    display: inline-flex;
    align-items: center;
    gap: var(--space-sm);
    background: var(--sf-blue-primary);
    color: white;
    padding: var(--space-md) var(--space-xl);
    border-radius: var(--radius-md);
    font-weight: 600;
    transition: all var(--transition-fast);
}

.hero-cta:hover {
    background: var(--sf-blue-dark);
    color: white;
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(41, 181, 232, 0.4);
}

.architecture-preview {
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: var(--radius-lg);
    padding: var(--space-xl);
    backdrop-filter: blur(10px);
}
```

## Content Sections

```css
.content-section {
    padding: var(--space-3xl) 0;
}

.content-section.alt-bg {
    background: white;
}

.section-container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 0 var(--space-xl);
}

.section-title {
    font-size: 1.75rem;
    font-weight: 700;
    color: var(--gray-900);
    margin-bottom: var(--space-xl);
    position: relative;
    padding-bottom: var(--space-md);
}

.section-title::after {
    content: '';
    position: absolute;
    bottom: 0;
    left: 0;
    width: 60px;
    height: 4px;
    background: linear-gradient(90deg, var(--sf-blue-primary), var(--sf-blue-dark));
    border-radius: var(--radius-full);
}
```

## Overview Grid

```css
.overview-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: var(--space-lg);
}

.overview-card {
    background: white;
    border: 1px solid var(--gray-200);
    border-radius: var(--radius-lg);
    padding: var(--space-xl);
    transition: all var(--transition-fast);
}

.overview-card:hover {
    border-color: var(--sf-blue-primary);
    box-shadow: var(--shadow-md);
}

.overview-card.highlight {
    background: linear-gradient(135deg, var(--sf-blue-light), white);
    border-color: var(--sf-blue-primary);
}

.overview-card h3 {
    font-size: 1rem;
    font-weight: 600;
    color: var(--gray-700);
    margin-bottom: var(--space-md);
}

.learning-list {
    list-style: none;
}

.learning-list li {
    position: relative;
    padding-left: var(--space-lg);
    margin-bottom: var(--space-sm);
    color: var(--gray-600);
}

.learning-list li::before {
    content: '';
    position: absolute;
    left: 0;
    top: 8px;
    width: 8px;
    height: 8px;
    background: var(--sf-blue-primary);
    border-radius: 50%;
}

.tech-tags {
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-sm);
}

.tech-tag {
    display: inline-flex;
    align-items: center;
    gap: var(--space-xs);
    background: var(--gray-100);
    padding: var(--space-xs) var(--space-sm);
    border-radius: var(--radius-sm);
    font-size: 0.8125rem;
    color: var(--gray-700);
}

.tech-icon {
    width: 16px;
    height: 16px;
}
```

## Progress Tracker

```css
.progress-tracker {
    position: fixed;
    left: 0;
    top: var(--header-height);
    bottom: 0;
    width: var(--sidebar-width);
    background: white;
    border-right: 1px solid var(--gray-200);
    padding: var(--space-xl);
    overflow-y: auto;
    z-index: 50;
}

.progress-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: var(--space-md);
    font-weight: 600;
    color: var(--gray-700);
}

.progress-percent {
    color: var(--sf-blue-primary);
}

.progress-bar {
    height: 6px;
    background: var(--gray-200);
    border-radius: var(--radius-full);
    margin-bottom: var(--space-xl);
    overflow: hidden;
}

.progress-fill {
    height: 100%;
    background: linear-gradient(90deg, var(--sf-blue-primary), var(--sf-green));
    border-radius: var(--radius-full);
    width: 0%;
    transition: width var(--transition-normal);
}

.steps-nav {
    display: flex;
    flex-direction: column;
    gap: var(--space-xs);
}

.step-nav-item {
    display: flex;
    align-items: center;
    gap: var(--space-sm);
    padding: var(--space-sm) var(--space-md);
    border-radius: var(--radius-md);
    color: var(--gray-600);
    font-size: 0.875rem;
    transition: all var(--transition-fast);
    text-decoration: none;
}

.step-nav-item:hover {
    background: var(--gray-100);
    color: var(--gray-800);
}

.step-nav-item.active {
    background: var(--sf-blue-light);
    color: var(--sf-blue-dark);
    font-weight: 500;
}

.step-nav-item.completed {
    color: var(--sf-green);
}

.step-nav-item .step-indicator {
    width: 24px;
    height: 24px;
    border-radius: 50%;
    border: 2px solid currentColor;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 0.75rem;
    font-weight: 600;
    flex-shrink: 0;
}

.step-nav-item.completed .step-indicator {
    background: var(--sf-green);
    border-color: var(--sf-green);
    color: white;
}
```

## Steps Container

```css
.steps-container {
    margin-left: var(--sidebar-width);
    padding: var(--space-2xl);
    max-width: calc(var(--content-max-width) + var(--sidebar-width) + var(--space-3xl) * 2);
}

.step-card {
    background: white;
    border: 1px solid var(--gray-200);
    border-radius: var(--radius-lg);
    margin-bottom: var(--space-xl);
    overflow: hidden;
    transition: all var(--transition-fast);
}

.step-card:hover {
    box-shadow: var(--shadow-md);
}

.step-card.completed {
    border-color: var(--sf-green);
}

.step-card.completed .step-number {
    background: var(--sf-green);
}

.step-header {
    display: flex;
    align-items: center;
    gap: var(--space-md);
    padding: var(--space-lg);
    background: var(--gray-50);
    border-bottom: 1px solid var(--gray-200);
    cursor: pointer;
}

.step-number {
    width: 40px;
    height: 40px;
    background: var(--sf-blue-primary);
    color: white;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 700;
    font-size: 1.125rem;
    flex-shrink: 0;
}

.step-info {
    flex: 1;
}

.step-title {
    font-size: 1.125rem;
    font-weight: 600;
    color: var(--gray-800);
    margin: 0;
}

.step-duration {
    font-size: 0.8125rem;
    color: var(--gray-500);
}

.step-toggle {
    background: none;
    border: none;
    padding: var(--space-sm);
    cursor: pointer;
    color: var(--gray-400);
    transition: transform var(--transition-fast);
}

.step-toggle[aria-expanded="false"] {
    transform: rotate(-90deg);
}

.step-toggle svg {
    width: 24px;
    height: 24px;
    fill: currentColor;
}

.step-content {
    padding: var(--space-xl);
}

.step-content.collapsed {
    display: none;
}

.step-description {
    color: var(--gray-600);
    margin-bottom: var(--space-xl);
    line-height: 1.7;
}

.step-actions {
    display: flex;
    justify-content: flex-end;
    padding-top: var(--space-lg);
    border-top: 1px solid var(--gray-200);
    margin-top: var(--space-xl);
}

.btn-check {
    display: inline-flex;
    align-items: center;
    gap: var(--space-sm);
    background: var(--gray-100);
    color: var(--gray-700);
    border: none;
    padding: var(--space-sm) var(--space-lg);
    border-radius: var(--radius-md);
    font-weight: 500;
    cursor: pointer;
    transition: all var(--transition-fast);
}

.btn-check:hover {
    background: var(--sf-green);
    color: white;
}

.btn-check svg {
    width: 18px;
    height: 18px;
    fill: currentColor;
}
```

## Code Blocks

```css
.code-block {
    background: var(--gray-900);
    border-radius: var(--radius-md);
    margin: var(--space-lg) 0;
    overflow: hidden;
}

.code-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: var(--space-sm) var(--space-md);
    background: var(--gray-800);
    border-bottom: 1px solid var(--gray-700);
}

.code-language {
    color: var(--gray-400);
    font-size: 0.75rem;
    font-weight: 500;
    text-transform: uppercase;
    letter-spacing: 0.5px;
}

.code-actions {
    display: flex;
    gap: var(--space-xs);
}

.code-actions button {
    background: transparent;
    border: none;
    padding: var(--space-xs);
    cursor: pointer;
    color: var(--gray-400);
    border-radius: var(--radius-sm);
    transition: all var(--transition-fast);
}

.code-actions button:hover {
    background: var(--gray-700);
    color: var(--sf-blue-primary);
}

.code-actions button svg {
    width: 18px;
    height: 18px;
    fill: currentColor;
}

.code-block pre {
    margin: 0;
    padding: var(--space-lg);
    overflow-x: auto;
}

.code-block code {
    font-family: var(--font-mono);
    font-size: 0.875rem;
    line-height: 1.6;
    color: var(--gray-100);
}

/* SQL Syntax Highlighting */
.code-block[data-language="sql"] .keyword {
    color: var(--sf-blue-primary);
    font-weight: 500;
}

.code-block[data-language="sql"] .function {
    color: var(--sf-yellow);
}

.code-block[data-language="sql"] .string {
    color: var(--sf-green);
}

.code-block[data-language="sql"] .number {
    color: var(--sf-orange);
}

.code-block[data-language="sql"] .comment {
    color: var(--gray-500);
    font-style: italic;
}
```

## Callouts

```css
.callout {
    display: flex;
    gap: var(--space-md);
    padding: var(--space-lg);
    border-radius: var(--radius-md);
    margin: var(--space-lg) 0;
}

.callout-icon {
    flex-shrink: 0;
    width: 24px;
    height: 24px;
}

.callout-icon svg {
    width: 100%;
    height: 100%;
}

.callout-content {
    flex: 1;
}

.callout-title {
    display: block;
    margin-bottom: var(--space-xs);
}

.callout-content p {
    margin: 0;
    font-size: 0.9375rem;
}

/* Callout Types */
.callout-info {
    background: var(--sf-blue-light);
    border-left: 4px solid var(--sf-blue-primary);
}

.callout-info .callout-icon {
    color: var(--sf-blue-primary);
}

.callout-warning {
    background: #fff9e6;
    border-left: 4px solid var(--sf-yellow);
}

.callout-warning .callout-icon {
    color: var(--sf-orange);
}

.callout-success {
    background: #e6fff2;
    border-left: 4px solid var(--sf-green);
}

.callout-success .callout-icon {
    color: var(--sf-green);
}

.callout-tip {
    background: #f0fff0;
    border-left: 4px solid var(--sf-green);
}

.callout-tip .callout-icon {
    color: var(--sf-green);
}

.callout-danger {
    background: #fff0f0;
    border-left: 4px solid var(--sf-red);
}

.callout-danger .callout-icon {
    color: var(--sf-red);
}
```

## Tables

```css
.table-wrapper {
    overflow-x: auto;
    margin: var(--space-lg) 0;
    border-radius: var(--radius-md);
    border: 1px solid var(--gray-200);
}

.data-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.875rem;
}

.data-table th {
    background: var(--gray-100);
    padding: var(--space-md);
    text-align: left;
    font-weight: 600;
    color: var(--gray-700);
    border-bottom: 2px solid var(--gray-300);
    white-space: nowrap;
}

.data-table td {
    padding: var(--space-md);
    border-bottom: 1px solid var(--gray-200);
    color: var(--gray-600);
}

.data-table tbody tr:hover {
    background: var(--gray-50);
}

.data-table tbody tr:last-child td {
    border-bottom: none;
}

.data-table code {
    background: var(--gray-100);
    padding: 2px 6px;
    border-radius: var(--radius-sm);
    font-family: var(--font-mono);
    font-size: 0.8125rem;
}
```

## Completion Section

```css
.completion-section {
    display: none;
    background: linear-gradient(135deg, var(--sf-green), #38a169);
    color: white;
    padding: var(--space-3xl) 0;
    text-align: center;
}

.completion-section.visible {
    display: block;
}

.completion-container {
    max-width: 600px;
    margin: 0 auto;
    padding: 0 var(--space-xl);
}

.completion-icon {
    width: 80px;
    height: 80px;
    background: white;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    margin: 0 auto var(--space-xl);
}

.completion-icon svg {
    width: 48px;
    height: 48px;
    fill: var(--sf-green);
}

.completion-section h2 {
    font-size: 2rem;
    margin-bottom: var(--space-md);
}

.completion-summary {
    display: flex;
    justify-content: center;
    gap: var(--space-2xl);
    margin: var(--space-xl) 0;
}

.summary-item {
    text-align: center;
}

.summary-label {
    display: block;
    font-size: 0.875rem;
    opacity: 0.9;
    margin-bottom: var(--space-xs);
}

.summary-value {
    font-size: 1.5rem;
    font-weight: 700;
}

.next-actions {
    background: rgba(255, 255, 255, 0.1);
    border-radius: var(--radius-lg);
    padding: var(--space-xl);
    margin-top: var(--space-xl);
}

.next-actions h3 {
    margin-bottom: var(--space-md);
}
```

## Footer

```css
.hol-footer {
    background: var(--gray-900);
    color: var(--gray-400);
    padding: var(--space-2xl) 0;
    margin-left: var(--sidebar-width);
}

.footer-container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 0 var(--space-xl);
    display: flex;
    justify-content: space-between;
    align-items: center;
}

.footer-brand {
    display: flex;
    align-items: center;
    gap: var(--space-md);
}

.footer-logo {
    height: 32px;
    width: auto;
    filter: brightness(0) invert(1);
}

.footer-links {
    display: flex;
    gap: var(--space-xl);
}

.footer-links a {
    color: var(--gray-400);
    transition: color var(--transition-fast);
}

.footer-links a:hover {
    color: white;
}

.footer-meta {
    text-align: right;
    font-size: 0.8125rem;
}
```

## Responsive Design

```css
@media (max-width: 1200px) {
    .hero-container {
        grid-template-columns: 1fr;
    }
    
    .hero-visual {
        display: none;
    }
}

@media (max-width: 992px) {
    .progress-tracker {
        display: none;
    }
    
    .steps-container,
    .hol-footer {
        margin-left: 0;
    }
    
    .overview-grid {
        grid-template-columns: 1fr;
    }
}

@media (max-width: 768px) {
    .header-nav {
        display: none;
    }
    
    .hero-title {
        font-size: 1.75rem;
    }
    
    .hero-meta {
        flex-wrap: wrap;
        gap: var(--space-md);
    }
    
    .completion-summary {
        flex-direction: column;
        gap: var(--space-md);
    }
    
    .footer-container {
        flex-direction: column;
        gap: var(--space-xl);
        text-align: center;
    }
}

@media (max-width: 480px) {
    .section-container,
    .steps-container {
        padding: var(--space-md);
    }
    
    .step-header {
        flex-wrap: wrap;
    }
}
```

## Print Styles

```css
@media print {
    .progress-tracker,
    .header-nav,
    .step-toggle,
    .step-actions,
    .code-actions,
    .hero-cta {
        display: none !important;
    }
    
    .steps-container,
    .hol-footer {
        margin-left: 0;
    }
    
    .step-content.collapsed {
        display: block !important;
    }
    
    .step-card {
        break-inside: avoid;
        page-break-inside: avoid;
    }
    
    .code-block {
        background: white !important;
        border: 1px solid #ccc;
    }
    
    .code-block code {
        color: black !important;
    }
}
```

## Animations

```css
@keyframes fadeIn {
    from { opacity: 0; transform: translateY(10px); }
    to { opacity: 1; transform: translateY(0); }
}

@keyframes pulse {
    0%, 100% { transform: scale(1); }
    50% { transform: scale(1.05); }
}

@keyframes checkmark {
    0% { stroke-dashoffset: 50; }
    100% { stroke-dashoffset: 0; }
}

.step-card {
    animation: fadeIn 0.3s ease;
}

.btn-check:active {
    animation: pulse 0.2s ease;
}

.completion-icon svg path {
    stroke-dasharray: 50;
    animation: checkmark 0.5s ease forwards;
}
```
