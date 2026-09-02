# Workshop de Evaluacion Funcional — CredibanCo RFP 10010806

Material del workshop hands-on que decide el 60% de la calificacion tecnica del
RFP 10010806 (Plataforma de Datos, salida de Cloudera).

**Guia del workshop:** https://sfc-gh-jparrado.github.io/HOL/HOL_CREDIBANCO/

## Que es

Ocho tracks de 30 minutos mas un modulo general de 25, con la misma duracion por
track como exige el Anexo 11. Total **4 horas 40 minutos**. Los ejecutan los
equipos de CredibanCo; Snowflake habilita y acompana, salvo en el Track 8 donde
el pliego pide que el proveedor ejecute la muestra de migracion con el equipo.

| Track | Equipo | Cuenta |
|---|---|---|
| T0 Modulo general transversal | Todos | la suya |
| T1 Gobierno y Zero Trust | Seguridad de la Informacion | CTA_SEGURIDAD |
| T2 Ingenieria de datos | Data & Analytics | CTA_INGENIERIA |
| T3 Arquitectura y Data Fabric | Arquitectura | CTA_ARQUITECTURA |
| T4 Analitica, ML e IA | Data & Analytics | CTA_INGENIERIA |
| T5 Monetizacion y exposicion | Arquitectura | CTA_ARQUITECTURA -> CTA_SEGURIDAD |
| T6 Autoservicio y aprovisionamiento | Infraestructura y Experiencia | CTA_INFRA |
| T7 Administracion, DataOps y FinOps | Infraestructura | CTA_INFRA |
| T8 Migracion desde Cloudera | Arquitectura | CTA_ARQUITECTURA |

## Como se instala

Cuatro cuentas, un script por cuenta. Cada cuenta **carga solo las capas que su
track NO produce** y deja vacias las que su track SI produce: por eso el equipo
de seguridad nunca despliega Openflow y el de ingenieria si construye el
pipeline. Cada script tarda menos de 10 minutos y termina con un semaforo.

```
instalacion/00_core.sql              cimiento comun, embebido en los cuatro
instalacion/install_seguridad.sql    T1 + consumidor del share de T5
instalacion/install_ingenieria.sql   T2 y T4
instalacion/install_arquitectura.sql T3, T5 y T8
instalacion/install_infra.sql        T6 y T7
```

### Prerrequisitos por cuenta

1. **Storage integration `SI_HOL_CB`** apuntando a `s3://demosjparrado/hol_credibanco/`,
   con el rol de IAM confiando en el ARN y el external id que emite Snowflake.
2. **Openflow: el deployment aprovisionado** (solo CTA_INGENIERIA). Es la unica
   pieza pre-hecha del T2: levantar el runtime toma mas que el track completo.
   Verificar con `SHOW OPENFLOW DATA PLANE INTEGRATIONS`.
3. **Volumen externo `EV_HOL_CB`** (solo CTA_ARQUITECTURA) para las tablas
   Iceberg del T3.
4. **Usuarios nominales** para cada participante. No usuarios compartidos: el
   criterio 1 exige demostrar trazabilidad por persona.

## El dato

Adquirencia sintetica: **40,4 millones de autorizaciones** de 24 meses sobre
**180.000 comercios**, **607.119 terminales** y **2,5 millones de
tarjetahabientes**, mas 45.000 operaciones de CDC, 300.000 eventos de
autorizacion, 400 vouchers y 120 expedientes SARLAFT.

El PAN es sintetico con digito de verificacion Luhn valido y esta **en claro a
proposito**: el consolidado de respuestas de CredibanCo confirmo que la
plataforma debe contemplar dato de tarjeta en claro, asi que el control se
demuestra sobre el caso real y no sobre un token.

**Sin PCI real, sin datos personales reales y sin informacion productiva de
CredibanCo.**

Senales implantadas para que los labs de analitica tengan de donde agarrarse:

- 7,7% de los comercios pierde volumen de forma **progresiva** desde un mes de
  quiebre repartido en la segunda mitad del historico. Si la caida fuera
  constante, la tendencia de los ultimos tres meses no separaria churn de
  no-churn.
- El fraude se concentra donde de verdad se concentra: 2,26% en transacciones
  internacionales contra 0,15% nacionales; 0,57% en ecommerce contra 0,04% con
  chip.
- La tasa de declinacion sube a fin de mes por fondos insuficientes.

## Generacion de los datos

```
python3 gen_data.py --out ./data --meses 24 --autz-por-mes 1700000 \
                    --comercios 180000 --tarjetahabientes 2500000
python3 gen_cloudera_sample.py    # muestra HiveQL, Impala, PySpark y Oozie del T8
```

Despues se sube a `s3://demosjparrado/hol_credibanco/` conservando la estructura
de carpetas (`raw/`, `cdc/`, `kafka_sim/`, `silver/`, `gold/`, `docs/`,
`cloudera_sample/`).

## Como se construye el material

Las guias no se escriben a mano: se componen, para que el SQL que muestra el HTML
y el que entrega el boton de descarga sean el mismo archivo.

```
python3 build_installs.py     # los 4 scripts de instalacion
python3 spec_t1_t7.py         # labs T1 y T7
python3 spec_t2_t4.py         # labs T2 y T4
python3 spec_t3_t5_t8.py      # labs T3, T5 y T8
python3 spec_t6_general.py    # modulo general y lab T6
python3 build_indice.py       # indice, runbook y one-pager competitivo
```

## Validacion

Nada se declara validado sin haberlo ejecutado. El arnes corre cada statement
contra una cuenta real y reporta el resultado de cada uno:

```
python3 validar.py labs/T1_gobierno_y_zero_trust.sql --seguir
python3 validar.py sql/install_seguridad.sql --stage-local --seguir
python3 validar.py labs/T3_arquitectura_y_data_fabric.sql --sesion-unica
```

`--sesion-unica` es obligatorio para los labs que dependen del estado de la
sesion (`SET`, `LAST_QUERY_ID`, `RESULT_SCAN`): statement por statement en
sesiones separadas no los puede validar de forma fiel.

### Errores que son el resultado esperado

Cuatro pasos estan disenados para fallar. Anunciarlos antes de ejecutarlos.

| Donde | Error | Que demuestra |
|---|---|---|
| T1 paso 6 | `090025 Table ... did not exist or was purged` | Borrado seguro verificable (eliminatorio) |
| T3 paso 2 | `003001 Insufficient privileges to operate on schema` | El limite del dominio es real |
| T6 paso 1 | La consulta a `CUSTOMER_360` no devuelve datos | Catalogo y motor dicen lo mismo |
| T4 paso 4 | El agente responde que el dato no esta en el modelo | No inventa |

## Trampas encontradas al construir esto

Todas verificadas ejecutando, no leyendo documentacion.

- **El escaner legado de Parquet corrompe los timestamps sin reportar error.** Un
  timestamp de 2025 aterriza en el ano 39268581 y el `COPY` dice
  `errors_seen = 0`. Las columnas `DATE` cargan bien, asi que el defecto pasa
  inadvertido si solo se revisa la fecha. El file format lleva
  `USE_VECTORIZED_SCANNER = TRUE`. Bajar la precision de ns a us **no** lo
  arregla.
- **El clasificador automatico de caja no detecta el PAN** ni cedula, celular o
  NIT: de una tabla con las cinco columnas solo reconocio el correo. Se resuelve
  con un `CUSTOM_CLASSIFIER` de cuatro reglas, y eso es mejor argumento de venta
  que el clasificador de caja.
- **`PRIVACY_CATEGORY` acepta `QUASI_IDENTIFIER` con guion bajo.** La
  documentacion lo escribe con guion medio y falla.
- **No se puede colgar una politica de la etiqueta compartida**
  `SNOWFLAKE.CORE.SEMANTIC_CATEGORY`, ni siendo ACCOUNTADMIN. Se propaga a una
  etiqueta propia y la politica se cuelga de esa.
- **`IS_ROLE_IN_SESSION` tambien evalua los roles secundarios**: un analista con
  el rol de seguridad concedido veia el PAN en claro. Usar `CURRENT_ROLE()`.
- **`CREATE OR REPLACE MASKING POLICY` falla si la politica ya esta adjunta.**
  Para iterar el cuerpo: `ALTER MASKING POLICY ... SET BODY -> ...`.
- **`SYSTEM$GET_TAG` exige el nombre del objeto como literal**: no sirve dentro
  de un join. Los inventarios por etiqueta se materializan en una vista.
- **Las columnas de pruning y derrame no estan en
  `INFORMATION_SCHEMA.QUERY_HISTORY`**: se leen de `GET_QUERY_OPERATOR_STATS`,
  que es inmediato. `ACCOUNT_USAGE` tiene latencia y no sirve en una sesion de 30
  minutos.
- **Si una tabla tiene politica de fila adjunta, el perfil muestra
  `DynamicSecureView` en vez de `TableScan`** y oculta el detalle del escaneo.
- **Las tablas Iceberg rechazan `NUMBER` sin precision.**
- **En `CREATE PROCEDURE` el `COMMENT` va antes de `EXECUTE AS`.**
- **Dentro del `FOR` de un cursor, las columnas del registro no se pueden usar
  directamente en un statement SQL**: se ligan a variables locales y se
  referencian con dos puntos.
- **`GRANT ... TO USER IDENTIFIER(CURRENT_USER())` no compila.** Hay que pasar por
  una variable de sesion.
- **Las columnas `IDENTITY` no entregan 1, 2, 3: reservan rangos.** La primera
  solicitud del T6 puede quedar con el id 201, asi que ningun nombre derivado de
  un id puede escribirse a mano.
- **En un semantic view el lado izquierdo de una dimension es el NOMBRE y el
  derecho la EXPRESION.** Invertirlo compila mal con `invalid identifier`.
- **No usar `ACCOUNT_USAGE` para semaforos de instalacion**: latencia de hasta
  dos horas sobre objetos recien creados. `SHOW` mas
  `RESULT_SCAN(LAST_QUERY_ID())` es inmediato.

## Estructura

```
index.html            indice del workshop con la agenda y el reparto de cuentas
runbook.html          runbook del facilitador
competitivo.html      preguntas verificables para comparar proveedores
T0..T8_*.html         las nueve guias
T0..T8_*.sql          el script completo de cada track
instalacion/*.sql     los cuatro scripts de instalacion mas el cimiento comun
```
