# Quickstart que muestra un flujo de trabajo ML de extremo a extremo en Snowflake
 - Usar Feature Store para rastrear características diseñadas
     - Almacenar definiciones de características en feature store para cómputo reproducible de características ML
 - Entrenar dos modelos SnowML
     - XGboost de línea base
     - XGboost con hiperparámetros óptimos identificados mediante métodos HPO distribuidos de Snowflake ML
 - Registrar ambos modelos en el model registry de Snowflake
     - Explorar capacidades del model registry como seguimiento de metadatos, inferencia y explicabilidad
     - Comparar métricas del modelo en conjuntos de entrenamiento/prueba para identificar problemas de rendimiento del modelo o sobreajuste
     - Etiquetar la versión del modelo con mejor rendimiento como versión 'default'
 - Configurar Model Monitor para rastrear 1 año de pagos de préstamos predichos y reales
     - Calcular métricas de rendimiento como F1, Precision, Recall
     - Inspeccionar model drift (es decir, cuánto ha cambiado la tasa de reembolso promedio predicha día a día)
     - Comparar modelos lado a lado para entender qué modelo debe usarse en producción
     - Identificar y comprender problemas de datos
 - Rastrear el linaje de datos y modelos a lo largo del proceso
     - Ver y comprender
       - El origen de los datos utilizados para características calculadas
       - Los datos utilizados para entrenamiento del modelo
       - Las versiones de modelo disponibles que están siendo monitoreadas
 - Los componentes adicionales también incluyen
     - Ejemplo de entrenamiento de modelo GPU distribuido
     - Despliegue SPCS para inferencia
         - [WIP] Ejemplo de scoring con REST API
 
 
 INSTRUCCIONES:
## Guía Paso a Paso
Para prerrequisitos, configuración del entorno, guía paso a paso e instrucciones, por favor consulte la [QuickStart Guide](https://quickstarts.snowflake.com/guide/end-to-end-ml-workflow).
 

