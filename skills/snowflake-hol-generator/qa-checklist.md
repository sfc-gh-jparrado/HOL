# Paso Final de QA - Quality Assurance

**IMPORTANTE**: Este paso es OBLIGATORIO y debe ejecutarse SIEMPRE al finalizar la generación de cualquier HOL. La premisa es: "Asume que cometiste errores y revísalo todo con ojo crítico."

## Mentalidad de QA

> "Si no encontraste ningún error, probablemente no buscaste bien."

El objetivo NO es confirmar que todo está bien, sino **encontrar activamente problemas** antes de entregar.

---

## Checklist de Validación Exhaustiva

### 1. Validación de SQL (CRÍTICO)

#### 1.1 Sintaxis SQL
```
[ ] Todos los statements terminan con punto y coma
[ ] Paréntesis balanceados en todas las queries
[ ] Comillas simples balanceadas en strings
[ ] Aliases definidos correctamente (AS keyword)
[ ] JOINs tienen condiciones ON válidas
[ ] GROUP BY incluye todas las columnas no agregadas del SELECT
```

#### 1.2 Objetos Snowflake
```
[ ] Nombres de tablas/vistas correctos (sin typos)
[ ] Nombres de columnas correctos según el modelo de datos
[ ] Esquema especificado donde es necesario (DB.SCHEMA.TABLE)
[ ] Tipos de datos consistentes en operaciones
[ ] Funciones Snowflake con sintaxis correcta
```

#### 1.3 Funciones Cortex AI
```
[ ] AI_COMPLETE('modelo', prompt) - primer parámetro es string del modelo
[ ] AI_SENTIMENT(texto) - parámetro es texto, retorna float entre -1 y 1
[ ] SNOWFLAKE.CORTEX.SUMMARIZE(texto) - única función que mantiene sintaxis legacy (no tiene AI_ equiv para texto individual)
[ ] AI_TRANSLATE(texto, idioma_origen, idioma_destino)
[ ] AI_CLASSIFY_TEXT(texto, array_categorías)
[ ] NO usar SNOWFLAKE.CORTEX.COMPLETE() — usar AI_COMPLETE()
[ ] NO usar SNOWFLAKE.CORTEX.SENTIMENT() — usar AI_SENTIMENT()
[ ] Modelos válidos: 'mistral-large2', 'llama3.1-70b', 'claude-3-5-sonnet'
```

#### 1.4 Compatibilidad Trial Account
```
[ ] NO usar SYSTEM$CORTEX_ANALYST_FAST_GENERATION (no disponible en trial)
[ ] Semantic Views: instrucciones para crear en Snowsight UI
[ ] Cortex Agents: instrucciones para crear en Snowsight UI
[ ] Warehouses: usar tamaños X-SMALL o SMALL
[ ] NO asumir roles enterprise (solo PUBLIC, SYSADMIN, ACCOUNTADMIN)
```

### 2. Validación de Estructura del HOL

#### 2.1 Flujo de Pasos
```
[ ] Paso 1 siempre es Setup (crear DB, schema, warehouse)
[ ] Cada paso tiene dependencias claras del anterior
[ ] No hay saltos lógicos entre pasos
[ ] Snowflake Intelligence (Semantic View + Agent) es el ÚLTIMO paso funcional antes de Cleanup/Time Travel
[ ] La Semantic View del agente puede ver TODOS los objetos creados en pasos anteriores (vistas, Dynamic Tables, vistas geoespaciales)
[ ] El último paso es cleanup o resumen
[ ] Duración total realista (45-90 min típico)
```

#### 2.2 Contenido de cada Paso
```
[ ] Título claro y descriptivo
[ ] Duración estimada (5-15 min por paso)
[ ] Descripción de qué se va a lograr
[ ] Código SQL completo y ejecutable
[ ] Explicación de lo que hace el código
[ ] Screenshot o resultado esperado (si aplica)
```

#### 2.3 Progresión de Dificultad
```
[ ] Primeros pasos son simples (DDL, INSERT)
[ ] Complejidad aumenta gradualmente
[ ] Conceptos nuevos se introducen de uno en uno
[ ] Features avanzados (Cortex AI) vienen después de fundamentos
```

### 3. Validación de Datos Sintéticos

#### 3.1 Volumen de Datos
```
[ ] Suficientes registros para demostrar el caso (mín 100-500)
[ ] No tantos que hagan lento el lab (máx 10,000)
[ ] Proporciones realistas entre tablas relacionadas
[ ] Fechas dentro de rangos lógicos (últimos 2 años típico)
```

#### 3.2 Calidad de Datos
```
[ ] IDs únicos donde corresponde
[ ] Foreign keys referencian registros existentes
[ ] Valores dentro de rangos válidos (%, montos, fechas)
[ ] Distribución realista (no todos los clientes compran igual)
[ ] Incluye casos edge (nulls, valores extremos) para enriquecer análisis
```

#### 3.3 Consistencia de Dominio
```
[ ] Nombres de productos/servicios consistentes con la industria
[ ] Monedas apropiadas para la región
[ ] Métricas con unidades correctas
[ ] Terminología del negocio correcta
```

### 4. Validación de Documentación

#### 4.1 Claridad
```
[ ] Sin jerga técnica no explicada
[ ] Acrónimos definidos en primer uso
[ ] Instrucciones paso a paso claras
[ ] Screenshots actualizados (si se incluyen)
```

#### 4.2 Completitud
```
[ ] Requisitos previos listados
[ ] Tecnologías usadas documentadas
[ ] Objetivos de aprendizaje definidos
[ ] Recursos adicionales incluidos
```

#### 4.3 Formato
```
[ ] Markdown renderiza correctamente
[ ] Code blocks con language tag correcto
[ ] Tablas formateadas correctamente
[ ] Links funcionan (si hay externos)
```

### 5. Validación de Seguridad

```
[ ] NO hay credenciales hardcodeadas
[ ] NO hay datos sensibles reales (PII, financieros)
[ ] Roles y permisos usan principio de mínimo privilegio
[ ] Conexiones usan patrones seguros
[ ] No hay SQL injection posible en ejemplos dinámicos
```

### 6. Validación de UX/Experiencia

```
[ ] Usuario puede completar cada paso sin bloquearse
[ ] Errores comunes anticipados con soluciones
[ ] Puntos de verificación para confirmar éxito
[ ] Tiempo total razonable para el nivel indicado
[ ] El resultado final es satisfactorio y demuestra valor
```

---

## Proceso de QA en 3 Fases

### Fase 1: Auto-revisión Inmediata
Ejecutar inmediatamente después de generar cada sección:

```markdown
## Checklist Rápido (30 segundos)
- [ ] ¿El SQL se ve sintácticamente correcto?
- [ ] ¿Los nombres de objetos son consistentes?
- [ ] ¿El paso tiene sentido en el contexto del lab?
```

### Fase 2: Revisión Cruzada
Al completar el HOL, revisar con perspectiva fresca:

```markdown
## Revisión de Flujo Completo (5 minutos)
1. Leer el HOL de inicio a fin como si fuera la primera vez
2. ¿Cada paso se conecta lógicamente con el anterior?
3. ¿Un usuario novato entendería qué hacer?
4. ¿El resultado final cumple la promesa del título?
```

### Fase 3: Validación Técnica
Verificación profunda de elementos críticos:

```markdown
## Validación Técnica (10 minutos)
1. Ejecutar mentalmente cada query SQL
2. Verificar que las tablas referenciadas existen
3. Confirmar tipos de datos en operaciones
4. Validar funciones Cortex con sintaxis correcta
```

---

## Errores Comunes a Buscar

### SQL
| Error | Ejemplo Malo | Ejemplo Correcto |
|-------|--------------|------------------|
| Columna inexistente | `SELECT customer_name` | `SELECT nombre_cliente` |
| Tipo incorrecto | `WHERE fecha = 2024` | `WHERE fecha = '2024-01-01'` |
| Agregación sin GROUP | `SELECT region, SUM(ventas)` | `SELECT region, SUM(ventas) GROUP BY region` |
| Join sin condición | `FROM A JOIN B` | `FROM A JOIN B ON A.id = B.a_id` |
| Función mal usada | `SNOWFLAKE.CORTEX.COMPLETE(col)` | `AI_COMPLETE('mistral-large2', prompt)` |

### Datos
| Error | Descripción |
|-------|-------------|
| FK huérfano | Referencia a ID que no existe en tabla padre |
| Fecha futura | Fechas más allá de hoy para datos históricos |
| Valores negativos | Cantidades que no pueden ser < 0 |
| Proporciones irreales | 99% de clientes en un solo segmento |

### Documentación
| Error | Descripción |
|-------|-------------|
| Paso sin código | Instrucciones sin SQL ejecutable |
| Referencia inexistente | "Ver paso anterior" cuando no aplica |
| Duración irreal | "5 minutos" para 200 líneas de SQL |
| Objetivo no cumplido | Promete X pero entrega Y |

---

## Template de Reporte QA

```markdown
# Reporte QA - [Nombre del HOL]

**Fecha**: YYYY-MM-DD
**Revisor**: [Nombre/Sistema]

## Resumen Ejecutivo
- Total de issues encontrados: X
- Críticos: X | Mayores: X | Menores: X

## Issues Críticos (Bloquean ejecución)
1. [Descripción] - Ubicación: Paso X, Línea Y
   - Problema: ...
   - Solución: ...

## Issues Mayores (Afectan experiencia)
1. [Descripción]
   - Problema: ...
   - Solución: ...

## Issues Menores (Mejoras sugeridas)
1. [Descripción]
   - Sugerencia: ...

## Verificaciones Pasadas
- [x] SQL sintácticamente correcto
- [x] Datos consistentes
- [x] Flujo lógico
- [x] Documentación completa

## Conclusión
[ ] APROBADO para publicación
[ ] REQUIERE CORRECCIONES - ver issues críticos
[ ] RECHAZADO - requiere rediseño
```

---

## Comandos de Validación SQL

Para validar SQL antes de incluirlo en el HOL:

```sql
-- Validar sintaxis sin ejecutar
EXPLAIN <query>;

-- Verificar que objetos existen
SHOW TABLES LIKE '%nombre%';
SHOW COLUMNS IN TABLE nombre_tabla;

-- Validar tipos de datos
DESCRIBE TABLE nombre_tabla;

-- Test con LIMIT
SELECT * FROM tabla LIMIT 5;
```

---

## Automatización de QA

### Script de Validación Básica

```python
# qa_validator.py
import re

def validate_sql_blocks(markdown_content):
    """Extrae y valida bloques SQL del markdown"""
    sql_blocks = re.findall(r'```sql\n(.*?)```', markdown_content, re.DOTALL)
    issues = []
    
    for i, sql in enumerate(sql_blocks):
        # Verificar punto y coma
        if not sql.strip().endswith(';'):
            issues.append(f"Block {i+1}: Missing semicolon")
        
        # Verificar paréntesis
        if sql.count('(') != sql.count(')'):
            issues.append(f"Block {i+1}: Unbalanced parentheses")
        
        # Verificar comillas
        if sql.count("'") % 2 != 0:
            issues.append(f"Block {i+1}: Unbalanced quotes")
        
        # Verificar funciones Cortex (legacy vs current)
        if 'SNOWFLAKE.CORTEX.COMPLETE(' in sql:
            issues.append(f"Block {i+1}: Use AI_COMPLETE() instead of SNOWFLAKE.CORTEX.COMPLETE()")
        if 'SNOWFLAKE.CORTEX.SENTIMENT(' in sql:
            issues.append(f"Block {i+1}: Use AI_SENTIMENT() instead of SNOWFLAKE.CORTEX.SENTIMENT()")
        if 'CORTEX.' in sql and 'SNOWFLAKE.CORTEX.SUMMARIZE' not in sql and 'SNOWFLAKE.CORTEX.' not in sql:
            issues.append(f"Block {i+1}: Cortex function needs SNOWFLAKE. prefix or use AI_ equivalent")
    
    return issues

def validate_data_model(markdown_content):
    """Verifica consistencia del modelo de datos"""
    # Extraer CREATE TABLE
    creates = re.findall(r'CREATE.*?TABLE.*?(\w+)', markdown_content, re.IGNORECASE)
    
    # Extraer referencias en SELECT/JOIN
    references = re.findall(r'FROM\s+(\w+)|JOIN\s+(\w+)', markdown_content, re.IGNORECASE)
    referenced_tables = set(t for pair in references for t in pair if t)
    
    # Verificar que todas las referencias existen
    missing = referenced_tables - set(creates)
    return list(missing)
```

---

## Workshop-Level QA (Multi-HOL Only)

When generating a Workshop (multiple connected labs), run these ADDITIONAL validations after all individual lab QAs pass:

### 8. Cross-Lab Consistency
```
[ ] Database name (e.g., CLIENT_WORKSHOP) is identical in ALL lab HTMLs
[ ] Warehouse name is identical in ALL lab HTMLs
[ ] Schema names (RAW_DATA, ANALYTICS, etc.) are consistent across labs
[ ] Table and view names referenced in Lab N match EXACTLY as created in earlier labs
[ ] No typos or case mismatches in object names across labs
```

### 9. Dependency Correctness
```
[ ] No forward references (Lab 2 doesn't reference objects created in Lab 3)
[ ] All objects in verification queries (Lab 2+) were actually created in prior labs
[ ] Progressive labs never DROP objects that later labs need
[ ] If Lab 1 creates TABLE_X, Lab 2+ only SELECTs from it (no re-CREATE)
[ ] Cleanup step only appears in the LAST lab (or as optional in each)
```

### 10. Index Page Validation
```
[ ] All href links in index point to actual generated lab filenames
[ ] Lab count in index hero matches actual number of lab HTML files
[ ] Lab titles in index match the hero titles inside each lab HTML
[ ] Lab durations in index cards match the hero durations in each lab
[ ] Total duration in index = sum of all lab durations
[ ] Dependency/prerequisite text is accurate per the actual lab structure
```

### 11. Progress Tracking
```
[ ] Each lab uses a UNIQUE localStorage key: workshop_{client}_lab{N}_progress
[ ] No key collisions between labs
[ ] Index page reads ALL per-lab keys to compute global progress
[ ] totalSteps in each lab's JS is correct for THAT lab (not the total workshop)
[ ] markStepComplete in each lab writes to the correct lab-specific key
```

### 12. File System
```
[ ] All generated files are in the same directory (relative links work)
[ ] Filenames follow convention: {client}_workshop_lab{N}_{topic_slug}.html
[ ] Index filename: {client}_workshop_index.html
[ ] No spaces in filenames (underscores only)
[ ] All filenames are lowercase
[ ] No duplicate filenames
```

### 13. Shared Setup Verification
```
[ ] Lab 1 includes full CREATE DATABASE/WAREHOUSE/SCHEMA setup
[ ] Labs 2+ start with verification queries (SELECT COUNT, SHOW TABLES)
[ ] Labs 2+ have a clear info-box: "Prerequisite: Complete Lab N first"
[ ] If a lab is marked independent, it has its own full setup (no dependency)
```

### Workshop QA Automation Script
```python
import os, re

def validate_workshop(directory):
    """Cross-validate all lab HTMLs in a workshop directory"""
    files = sorted([f for f in os.listdir(directory) if f.endswith('.html')])
    index_file = [f for f in files if 'index' in f]
    lab_files = [f for f in files if 'lab' in f and 'index' not in f]
    
    issues = []
    
    # Check index exists
    if not index_file:
        issues.append("CRITICAL: No index file found")
    
    # Check lab count
    if index_file:
        with open(os.path.join(directory, index_file[0])) as f:
            index_html = f.read()
        # Count lab cards
        card_count = index_html.count('class="lab-card"')
        if card_count != len(lab_files):
            issues.append(f"Index has {card_count} cards but found {len(lab_files)} lab files")
    
    # Check cross-lab object references
    all_creates = {}  # {object_name: lab_number}
    all_references = {}  # {object_name: [lab_numbers]}
    
    for i, lab_file in enumerate(lab_files, 1):
        with open(os.path.join(directory, lab_file)) as f:
            content = f.read()
        
        # Extract CREATE statements
        creates = re.findall(r'CREATE\s+(?:OR\s+REPLACE\s+)?(?:TABLE|VIEW|DYNAMIC TABLE|SEMANTIC VIEW)\s+(?:\w+\.)*(\w+)', content, re.IGNORECASE)
        for obj in creates:
            all_creates[obj.upper()] = i
        
        # Extract FROM/JOIN references
        refs = re.findall(r'(?:FROM|JOIN)\s+(?:\w+\.)*(\w+)', content, re.IGNORECASE)
        for ref in refs:
            if ref.upper() not in all_references:
                all_references[ref.upper()] = []
            all_references[ref.upper()].append(i)
    
    # Check for forward references
    for obj, labs in all_references.items():
        if obj in all_creates:
            created_in = all_creates[obj]
            for lab in labs:
                if lab < created_in:
                    issues.append(f"Forward reference: {obj} used in Lab {lab} but created in Lab {created_in}")
    
    return issues
```

---

## Recordatorio Final

> **NUNCA** entregues un HOL sin pasar por QA.
> 
> **SIEMPRE** asume que hay errores.
> 
> **REVISA** con la mentalidad de encontrar problemas, no de confirmar éxito.

El paso de QA no es opcional. Es la diferencia entre un HOL profesional y uno que frustra al usuario.

> **WORKSHOP EXTRA**: Para workshops, la QA individual de cada lab NO es suficiente.
> La QA cross-lab (secciones 8-13) es OBLIGATORIA para detectar inconsistencias entre labs.
