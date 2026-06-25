# JavaScript Functions para Hands-On Labs

Funciones JavaScript para interactividad del HOL.

## Script Principal

```javascript
/**
 * Snowflake HOL Interactive Functions
 * Version: 1.0.0
 */

// ============================================
// Estado Global
// ============================================
const HOLState = {
    totalSteps: 0,
    completedSteps: new Set(),
    startTime: null,
    currentStep: 1
};

// ============================================
// Inicialización
// ============================================
document.addEventListener('DOMContentLoaded', function() {
    initializeHOL();
});

function initializeHOL() {
    // Contar pasos totales
    HOLState.totalSteps = document.querySelectorAll('.step-card').length;
    
    // Registrar tiempo de inicio
    HOLState.startTime = new Date();
    
    // Cargar progreso guardado
    loadProgress();
    
    // Inicializar event listeners
    initStepToggles();
    initCodeBlocks();
    initScrollSpy();
    initKeyboardShortcuts();
    
    // Actualizar UI
    updateProgressUI();
    
    console.log('HOL initialized with', HOLState.totalSteps, 'steps');
}

// ============================================
// Gestión de Progreso
// ============================================
function markStepComplete(stepNumber) {
    HOLState.completedSteps.add(stepNumber);
    
    // Actualizar UI del step
    const stepCard = document.getElementById(`step-${stepNumber}`);
    if (stepCard) {
        stepCard.classList.add('completed');
        
        // Actualizar botón
        const btn = stepCard.querySelector('.btn-check');
        if (btn) {
            btn.innerHTML = `
                <svg viewBox="0 0 24 24"><path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17z"/></svg>
                Completado
            `;
            btn.disabled = true;
            btn.style.background = 'var(--sf-green)';
            btn.style.color = 'white';
        }
    }
    
    // Actualizar navegación lateral
    const navItem = document.querySelector(`.step-nav-item[data-step="${stepNumber}"]`);
    if (navItem) {
        navItem.classList.add('completed');
    }
    
    // Guardar progreso
    saveProgress();
    
    // Actualizar barra de progreso
    updateProgressUI();
    
    // Verificar si se completó todo
    if (HOLState.completedSteps.size === HOLState.totalSteps) {
        showCompletion();
    }
    
    // Auto-scroll al siguiente step
    if (stepNumber < HOLState.totalSteps) {
        setTimeout(() => {
            scrollToStep(stepNumber + 1);
        }, 500);
    }
}

function updateProgressUI() {
    const progress = (HOLState.completedSteps.size / HOLState.totalSteps) * 100;
    
    // Actualizar barra de progreso
    const progressFill = document.getElementById('progressFill');
    if (progressFill) {
        progressFill.style.width = `${progress}%`;
    }
    
    // Actualizar porcentaje
    const progressPercent = document.querySelector('.progress-percent');
    if (progressPercent) {
        progressPercent.textContent = `${Math.round(progress)}%`;
    }
}

function saveProgress() {
    const holId = document.body.dataset.holId || 'default-hol';
    const data = {
        completedSteps: Array.from(HOLState.completedSteps),
        startTime: HOLState.startTime.toISOString(),
        lastUpdated: new Date().toISOString()
    };
    localStorage.setItem(`hol-progress-${holId}`, JSON.stringify(data));
}

function loadProgress() {
    const holId = document.body.dataset.holId || 'default-hol';
    const saved = localStorage.getItem(`hol-progress-${holId}`);
    
    if (saved) {
        try {
            const data = JSON.parse(saved);
            data.completedSteps.forEach(step => {
                HOLState.completedSteps.add(step);
                
                // Restaurar UI
                const stepCard = document.getElementById(`step-${step}`);
                if (stepCard) {
                    stepCard.classList.add('completed');
                }
                
                const navItem = document.querySelector(`.step-nav-item[data-step="${step}"]`);
                if (navItem) {
                    navItem.classList.add('completed');
                }
            });
            
            if (data.startTime) {
                HOLState.startTime = new Date(data.startTime);
            }
        } catch (e) {
            console.error('Error loading progress:', e);
        }
    }
}

function resetProgress() {
    if (confirm('¿Estás seguro de que deseas reiniciar tu progreso?')) {
        const holId = document.body.dataset.holId || 'default-hol';
        localStorage.removeItem(`hol-progress-${holId}`);
        location.reload();
    }
}

// ============================================
// Toggle de Steps
// ============================================
function initStepToggles() {
    document.querySelectorAll('.step-toggle').forEach(toggle => {
        toggle.addEventListener('click', function(e) {
            e.stopPropagation();
            const stepCard = this.closest('.step-card');
            const content = stepCard.querySelector('.step-content');
            const isExpanded = this.getAttribute('aria-expanded') === 'true';
            
            this.setAttribute('aria-expanded', !isExpanded);
            content.classList.toggle('collapsed', isExpanded);
        });
    });
    
    // Click en header también toggle
    document.querySelectorAll('.step-header').forEach(header => {
        header.addEventListener('click', function() {
            const toggle = this.querySelector('.step-toggle');
            if (toggle) {
                toggle.click();
            }
        });
    });
}

// ============================================
// Code Blocks
// ============================================
function initCodeBlocks() {
    document.querySelectorAll('.code-block').forEach(block => {
        const code = block.querySelector('code');
        if (code && block.dataset.language === 'sql') {
            code.innerHTML = highlightSQL(code.textContent);
        }
    });
}

function copyCode(button) {
    const codeBlock = button.closest('.code-block');
    const code = codeBlock.querySelector('code');
    const text = code.textContent;
    
    navigator.clipboard.writeText(text).then(() => {
        // Feedback visual
        const originalHTML = button.innerHTML;
        button.innerHTML = `
            <svg viewBox="0 0 24 24"><path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17z"/></svg>
        `;
        button.style.color = 'var(--sf-green)';
        
        setTimeout(() => {
            button.innerHTML = originalHTML;
            button.style.color = '';
        }, 2000);
    }).catch(err => {
        console.error('Error copying:', err);
        alert('Error al copiar el código');
    });
}

function openInSnowsight(button) {
    const codeBlock = button.closest('.code-block');
    const code = codeBlock.querySelector('code');
    const sql = code.textContent.trim();
    
    // Codificar SQL para URL
    const encoded = encodeURIComponent(sql);
    
    // URL de Snowsight (worksheet)
    // Nota: El usuario debe estar autenticado
    const snowsightUrl = `https://app.snowflake.com/worksheet?query=${encoded}`;
    
    // Abrir en nueva pestaña
    window.open(snowsightUrl, '_blank');
}

// SQL Syntax Highlighting básico
function highlightSQL(code) {
    const keywords = [
        'SELECT', 'FROM', 'WHERE', 'AND', 'OR', 'NOT', 'IN', 'LIKE',
        'JOIN', 'LEFT', 'RIGHT', 'INNER', 'OUTER', 'ON', 'AS',
        'GROUP BY', 'ORDER BY', 'HAVING', 'LIMIT', 'OFFSET',
        'INSERT', 'INTO', 'VALUES', 'UPDATE', 'SET', 'DELETE',
        'CREATE', 'TABLE', 'VIEW', 'DATABASE', 'SCHEMA', 'DROP', 'ALTER',
        'INDEX', 'PRIMARY KEY', 'FOREIGN KEY', 'REFERENCES',
        'NULL', 'NOT NULL', 'DEFAULT', 'UNIQUE', 'CHECK',
        'CASE', 'WHEN', 'THEN', 'ELSE', 'END',
        'UNION', 'INTERSECT', 'EXCEPT', 'ALL', 'DISTINCT',
        'WITH', 'RECURSIVE', 'CTE', 'OVER', 'PARTITION BY',
        'WINDOW', 'ROWS', 'RANGE', 'BETWEEN', 'UNBOUNDED', 'PRECEDING', 'FOLLOWING',
        'TRUE', 'FALSE', 'IS', 'ISNULL', 'COALESCE', 'NULLIF',
        'CAST', 'CONVERT', 'TRY_CAST',
        'COUNT', 'SUM', 'AVG', 'MIN', 'MAX', 'MEDIAN',
        'ROW_NUMBER', 'RANK', 'DENSE_RANK', 'NTILE', 'LAG', 'LEAD',
        'FIRST_VALUE', 'LAST_VALUE', 'NTH_VALUE',
        'DATE', 'TIME', 'TIMESTAMP', 'INTERVAL', 'EXTRACT', 'DATEADD', 'DATEDIFF',
        'SEMANTIC', 'CORTEX', 'COMPLETE', 'SENTIMENT', 'TRANSLATE', 'SUMMARIZE'
    ];
    
    const functions = [
        'SNOWFLAKE\\.CORTEX\\.COMPLETE',
        'SNOWFLAKE\\.CORTEX\\.SENTIMENT',
        'SNOWFLAKE\\.CORTEX\\.SUMMARIZE',
        'SNOWFLAKE\\.CORTEX\\.TRANSLATE',
        'SNOWFLAKE\\.CORTEX\\.CLASSIFY_TEXT',
        'SNOWFLAKE\\.CORTEX\\.EXTRACT_ANSWER'
    ];
    
    let highlighted = code;
    
    // Escapar HTML
    highlighted = highlighted
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;');
    
    // Comentarios
    highlighted = highlighted.replace(
        /(--.*$)/gm,
        '<span class="comment">$1</span>'
    );
    
    // Strings
    highlighted = highlighted.replace(
        /('(?:[^'\\]|\\.)*')/g,
        '<span class="string">$1</span>'
    );
    
    // Números
    highlighted = highlighted.replace(
        /\b(\d+(?:\.\d+)?)\b/g,
        '<span class="number">$1</span>'
    );
    
    // Keywords
    keywords.forEach(keyword => {
        const regex = new RegExp(`\\b(${keyword})\\b`, 'gi');
        highlighted = highlighted.replace(
            regex,
            '<span class="keyword">$1</span>'
        );
    });
    
    // Funciones Cortex
    functions.forEach(func => {
        const regex = new RegExp(`(${func})`, 'gi');
        highlighted = highlighted.replace(
            regex,
            '<span class="function">$1</span>'
        );
    });
    
    return highlighted;
}

// ============================================
// Scroll Spy
// ============================================
function initScrollSpy() {
    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                const stepNumber = entry.target.dataset.step;
                updateActiveNavItem(stepNumber);
                HOLState.currentStep = parseInt(stepNumber);
            }
        });
    }, {
        rootMargin: '-100px 0px -50% 0px'
    });
    
    document.querySelectorAll('.step-card').forEach(card => {
        observer.observe(card);
    });
}

function updateActiveNavItem(stepNumber) {
    document.querySelectorAll('.step-nav-item').forEach(item => {
        item.classList.remove('active');
    });
    
    const activeItem = document.querySelector(`.step-nav-item[data-step="${stepNumber}"]`);
    if (activeItem) {
        activeItem.classList.add('active');
    }
}

function scrollToStep(stepNumber) {
    const stepCard = document.getElementById(`step-${stepNumber}`);
    if (stepCard) {
        stepCard.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
}

// ============================================
// Keyboard Shortcuts
// ============================================
function initKeyboardShortcuts() {
    document.addEventListener('keydown', function(e) {
        // Alt + número para ir a step
        if (e.altKey && e.key >= '1' && e.key <= '9') {
            const stepNumber = parseInt(e.key);
            if (stepNumber <= HOLState.totalSteps) {
                scrollToStep(stepNumber);
                e.preventDefault();
            }
        }
        
        // Alt + C para marcar step actual como completado
        if (e.altKey && e.key === 'c') {
            if (!HOLState.completedSteps.has(HOLState.currentStep)) {
                markStepComplete(HOLState.currentStep);
            }
            e.preventDefault();
        }
        
        // Alt + N para ir al siguiente step
        if (e.altKey && e.key === 'n') {
            if (HOLState.currentStep < HOLState.totalSteps) {
                scrollToStep(HOLState.currentStep + 1);
            }
            e.preventDefault();
        }
        
        // Alt + P para ir al step anterior
        if (e.altKey && e.key === 'p') {
            if (HOLState.currentStep > 1) {
                scrollToStep(HOLState.currentStep - 1);
            }
            e.preventDefault();
        }
    });
}

// ============================================
// Completion
// ============================================
function showCompletion() {
    const completionSection = document.getElementById('completionSection');
    if (completionSection) {
        completionSection.classList.add('visible');
        completionSection.scrollIntoView({ behavior: 'smooth' });
        
        // Calcular tiempo total
        const endTime = new Date();
        const duration = endTime - HOLState.startTime;
        const minutes = Math.floor(duration / 60000);
        const seconds = Math.floor((duration % 60000) / 1000);
        
        const totalTimeEl = document.getElementById('totalTime');
        if (totalTimeEl) {
            totalTimeEl.textContent = `${minutes}m ${seconds}s`;
        }
        
        // Confetti opcional
        if (typeof confetti === 'function') {
            confetti({
                particleCount: 100,
                spread: 70,
                origin: { y: 0.6 }
            });
        }
    }
}

// ============================================
// Utilities
// ============================================
function formatDuration(ms) {
    const seconds = Math.floor(ms / 1000);
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);
    
    if (hours > 0) {
        return `${hours}h ${minutes % 60}m`;
    } else if (minutes > 0) {
        return `${minutes}m ${seconds % 60}s`;
    } else {
        return `${seconds}s`;
    }
}

function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}

// ============================================
// Export para uso externo
// ============================================
window.HOL = {
    markStepComplete,
    scrollToStep,
    resetProgress,
    copyCode,
    openInSnowsight,
    getState: () => ({ ...HOLState })
};
```

## Funciones Auxiliares

### Validación de Código SQL

```javascript
/**
 * Valida sintaxis básica de SQL antes de enviar a Snowsight
 */
function validateSQL(sql) {
    const errors = [];
    
    // Verificar paréntesis balanceados
    const openParens = (sql.match(/\(/g) || []).length;
    const closeParens = (sql.match(/\)/g) || []).length;
    if (openParens !== closeParens) {
        errors.push('Paréntesis desbalanceados');
    }
    
    // Verificar comillas simples
    const singleQuotes = (sql.match(/'/g) || []).length;
    if (singleQuotes % 2 !== 0) {
        errors.push('Comillas simples desbalanceadas');
    }
    
    // Verificar punto y coma final
    if (!sql.trim().endsWith(';')) {
        errors.push('Falta punto y coma al final');
    }
    
    return {
        isValid: errors.length === 0,
        errors
    };
}
```

### Generador de URLs Snowsight

```javascript
/**
 * Genera URL para abrir query en Snowsight
 */
function generateSnowsightURL(sql, options = {}) {
    const baseUrl = options.account 
        ? `https://${options.account}.snowflakecomputing.com` 
        : 'https://app.snowflake.com';
    
    const params = new URLSearchParams();
    params.set('query', sql);
    
    if (options.database) {
        params.set('database', options.database);
    }
    if (options.schema) {
        params.set('schema', options.schema);
    }
    if (options.warehouse) {
        params.set('warehouse', options.warehouse);
    }
    
    return `${baseUrl}/worksheet?${params.toString()}`;
}
```

### Timer de Step

```javascript
/**
 * Timer para tracking de tiempo por step
 */
class StepTimer {
    constructor() {
        this.timers = new Map();
    }
    
    start(stepNumber) {
        this.timers.set(stepNumber, {
            start: Date.now(),
            end: null
        });
    }
    
    stop(stepNumber) {
        const timer = this.timers.get(stepNumber);
        if (timer && !timer.end) {
            timer.end = Date.now();
        }
    }
    
    getDuration(stepNumber) {
        const timer = this.timers.get(stepNumber);
        if (!timer) return 0;
        
        const end = timer.end || Date.now();
        return end - timer.start;
    }
    
    getTotalDuration() {
        let total = 0;
        this.timers.forEach((timer) => {
            if (timer.end) {
                total += timer.end - timer.start;
            }
        });
        return total;
    }
    
    getReport() {
        const report = [];
        this.timers.forEach((timer, step) => {
            report.push({
                step,
                duration: this.getDuration(step),
                completed: !!timer.end
            });
        });
        return report.sort((a, b) => a.step - b.step);
    }
}

// Instancia global
window.stepTimer = new StepTimer();
```

### Analytics Events

```javascript
/**
 * Tracking de eventos para analytics
 */
const HOLAnalytics = {
    events: [],
    
    track(event, data = {}) {
        const entry = {
            event,
            data,
            timestamp: new Date().toISOString(),
            step: HOLState.currentStep
        };
        
        this.events.push(entry);
        
        // Enviar a analytics si está configurado
        if (window.gtag) {
            gtag('event', event, {
                'hol_id': document.body.dataset.holId,
                'step': HOLState.currentStep,
                ...data
            });
        }
        
        // Console log en desarrollo
        if (window.location.hostname === 'localhost') {
            console.log('HOL Event:', entry);
        }
    },
    
    getEvents() {
        return [...this.events];
    },
    
    exportEvents() {
        return JSON.stringify(this.events, null, 2);
    }
};

// Auto-tracking de eventos comunes
document.addEventListener('click', (e) => {
    if (e.target.closest('.btn-copy')) {
        HOLAnalytics.track('code_copied');
    }
    if (e.target.closest('.btn-run')) {
        HOLAnalytics.track('open_in_snowsight');
    }
    if (e.target.closest('.btn-check')) {
        HOLAnalytics.track('step_completed', { step: HOLState.currentStep });
    }
});

window.HOLAnalytics = HOLAnalytics;
```

### Print Friendly

```javascript
/**
 * Preparar página para impresión
 */
function preparePrint() {
    // Expandir todos los steps
    document.querySelectorAll('.step-content').forEach(content => {
        content.classList.remove('collapsed');
    });
    
    document.querySelectorAll('.step-toggle').forEach(toggle => {
        toggle.setAttribute('aria-expanded', 'true');
    });
    
    // Abrir diálogo de impresión
    setTimeout(() => {
        window.print();
    }, 100);
}

// Añadir botón de impresión si no existe
document.addEventListener('DOMContentLoaded', () => {
    const printBtn = document.createElement('button');
    printBtn.className = 'print-btn';
    printBtn.innerHTML = '🖨️ Imprimir';
    printBtn.onclick = preparePrint;
    printBtn.style.cssText = `
        position: fixed;
        bottom: 20px;
        right: 20px;
        padding: 10px 20px;
        background: var(--sf-blue-primary);
        color: white;
        border: none;
        border-radius: 8px;
        cursor: pointer;
        z-index: 1000;
        font-weight: 500;
    `;
    document.body.appendChild(printBtn);
});
```

## Atajos de Teclado

| Atajo | Acción |
|-------|--------|
| `Alt + 1-9` | Ir al step N |
| `Alt + C` | Marcar step actual como completado |
| `Alt + N` | Ir al siguiente step |
| `Alt + P` | Ir al step anterior |
| `Ctrl + P` | Imprimir HOL |

## Eventos Disponibles

| Evento | Descripción | Datos |
|--------|-------------|-------|
| `hol:initialized` | HOL cargado | `{totalSteps, savedProgress}` |
| `hol:step_completed` | Step marcado completo | `{step, totalCompleted}` |
| `hol:all_completed` | Todos los steps completados | `{duration}` |
| `hol:code_copied` | Código copiado | `{step, language}` |
| `hol:progress_reset` | Progreso reiniciado | `{}` |

## Uso del API

```javascript
// Marcar step como completado programáticamente
window.HOL.markStepComplete(3);

// Ir a un step específico
window.HOL.scrollToStep(5);

// Obtener estado actual
const state = window.HOL.getState();
console.log('Progreso:', state.completedSteps.size, '/', state.totalSteps);

// Reiniciar progreso
window.HOL.resetProgress();

// Ver eventos de analytics
console.log(window.HOLAnalytics.getEvents());
```
