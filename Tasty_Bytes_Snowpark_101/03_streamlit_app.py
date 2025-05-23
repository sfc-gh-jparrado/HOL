""" ************************************************************************************************
  __               _   _           _       
 / _|             | | | |         | |      
| |_ _ __ ___  ___| |_| |__  _   _| |_ ___ 
|  _| '__/ _ \/ __| __| '_ \| | | | __/ _ \
| | | | | (_) \__ \ |_| |_) | |_| | ||  __/
|_| |_|  \___/|___/\__|_.__/ \__, |\__\___|
                              __/ |        
                             |___/         
Descripción: 
  Aplicación en Streamlit para mostrar las ventas por turno predichas para las ubicaciones 
  donde los conductores de food trucks pueden estacionarse.
****************************************************************************************************

IMPORTANTE: Este streamlit debió ser creado en la siguiente ubicación. Si no lo hiciste, borralo y vuelvelo a cargar.
  Database: FROSTBYTE_TASTY_BYTES_DEV
  Schema: ANALYTICS

ANTES DE EJECUTAR
  Agrega los siguientes paquetes en el menú desplegable Paquetes en la parte superior de la interfaz de usuario:
  plotly, matplotlib, pydeck, snowflake-ml-python, nbformat

************************************************************************************************* """

# Import Python packages
import streamlit as st
import plotly.express as px
import json
import pydeck as pdk
import math

# Import Snowflake modules
from snowflake.snowpark import Session
import snowflake.snowpark.functions as F
from snowflake.snowpark import Window
from snowflake.ml.registry import Registry
from snowflake.ml.modeling.metrics import (
    mean_squared_error,
    mean_absolute_error,
    mean_absolute_percentage_error,
)
from snowflake.snowpark.context import get_active_session

# Set Streamlit page config
st.set_page_config(
    page_title="Streamlit App: Snowpark 101",
    page_icon=":truck:",
    layout="wide",
)

# Add header and a subheader
st.image("https://imgnew.megazone.com/2024/06/newsletter_202406_image03-768x432.jpg")

st.header("Ventas por Turno Predichas por Ubicación")
st.subheader(" ")
st.subheader("Recomendaciones basadas en datos para los conductores de food trucks :oncoming_bus:", divider="gray")


# Connect to Snowflake
session = get_active_session()

# Create input widgets for cities and shift
with st.container():
    col1, col2 = st.columns(2)
    with col1:
        # Drop down to select city
        city = st.selectbox(
            "Ciudad:",
            session.table("frostbyte_tasty_bytes_dev.analytics.shift_sales_v")
            .select("city")
            .distinct()
            .sort("city"),
        )

    with col2:
        # Select AM/PM Shift
        shift = st.radio("Horario:", ("AM", "PM"), horizontal=True)


# Get predictions for city and shift time
def get_predictions(city, shift):
    # Get data and filter by city and shift
    snowpark_df = session.table(
        "frostbyte_tasty_bytes_dev.analytics.shift_sales_v"
    ).filter((F.col("shift") == shift) & (F.col("city") == city))

    # Get rolling average
    window_by_location_all_days = (
        Window.partition_by("location_id")
        .order_by("date")
        .rows_between(Window.UNBOUNDED_PRECEDING, Window.CURRENT_ROW - 1)
    )

    snowpark_df = snowpark_df.with_column(
        "avg_location_shift_sales",
        F.avg("shift_sales").over(window_by_location_all_days),
    ).cache_result()

    # Get tomorrow's date
    date_tomorrow = (
        snowpark_df.filter(F.col("shift_sales").is_null())
        .select(F.min("date"))
        .collect()[0][0]
    )

    # Filter to tomorrow's date
    snowpark_df = snowpark_df.filter(F.col("date") == date_tomorrow).drop("date")

    # Grab model from model registry
    reg = Registry(session)

    # Call the inference user-defined function
    snowpark_df = reg.get_model("SHIFT_SALES_FORECASTER").default.run(
        X=snowpark_df, function_name="predict"
    )

    return snowpark_df.to_pandas()


# Update predictions and plot when the "Update" button is clicked
if st.button("Actualizar"):
    # Get predictions
    with st.spinner("Obteniendo predicciones..."):
        predictions = get_predictions(city, shift)

    # Plot on a map
    predictions["FORECASTED_SHIFT_SALES"].clip(0, inplace=True)
    predictions["radius"] = predictions["FORECASTED_SHIFT_SALES"].apply(
        lambda x: math.sqrt(x / 100)
    )

    # map the neighborhood
    view_state = pdk.ViewState(
        latitude=predictions["LATITUDE"].mean(),
        longitude=predictions["LONGITUDE"].mean(),
        zoom=10,
        bearing=0,
        pitch=0,
    )

    st.pydeck_chart(
        pdk.Deck(
            map_style=None,
            initial_view_state=view_state,
            layers=[
                pdk.Layer(
                    "ScatterplotLayer",
                    data=predictions,
                    get_position="[LONGITUDE, LATITUDE]",
                    get_radius="FORECASTED_SHIFT_SALES",
                    get_fill_color="[0,0,128,25]",
                    pickable=True,
                ),
            ],
            tooltip={
                "text": "{LOCATION_NAME}\n las ventas por turno predichas son {FORECASTED_SHIFT_SALES} y\n el id de la ubicación es {LOCATION_ID}"
            },
        )
    )

    # Output a table of the predictions
    st.write(predictions)
