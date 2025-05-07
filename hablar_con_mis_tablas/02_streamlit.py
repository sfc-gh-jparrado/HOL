import _snowflake
import json
import streamlit as st
from snowflake.snowpark.context import get_active_session


DATABASE = "CORTEX_ANALYST_DEMO"
SCHEMA = "REVENUE_TIMESERIES"
STAGE = "RAW_DATA"
FILE = "revenue_timeseries.yaml"

def detect_language(text: str) -> str:
    """Detecta el idioma del texto y retorna el codigo del idioma"""
    session = get_active_session()
    cmd = """
        SELECT TRIM(snowflake.cortex.complete('mistral-large',
            'Detect the language of this text and return the language code (e.g. en, es, fr). Do not return anything else.
            Text: ### {text} ### '),'\n') as language 
    """
    df = session.sql(cmd.format(text=text.replace("'","''"))).collect()
    return df[0].LANGUAGE

def translate_text(text:str,source_lang: str,target_lang:str) -> str:
    """Traducir el texto de un idioma a otro"""
    if "target_lang" == source_lang:
        return text
    session = get_active_session()
    cmd = """
        SELECT snowflake.cortex.translate(?, ?, ?) as translation
    """
    df = session.sql(cmd, params=[text,source_lang,target_lang]).collect()
    return df[0].TRANSLATION

def send_message(prompt: str, language: str) -> dict:
    """Llamada al API REST y retornar la respuesta."""
    request_body = {
        "messages": [{"role": "user", "content": [{"type": "text", "text": prompt}]}],
        "semantic_model_file": f"@{DATABASE}.{SCHEMA}.{STAGE}/{FILE}",
    }
    resp = _snowflake.send_snow_api_request(
        "POST",f"/api/v2/cortex/analyst/message",{},{},request_body,{},30000,
    )
    if resp["status"] < 400:
        response = json.loads(resp["content"])
        response["language"]=language
        return response
    else:
        raise Exception(
            f"Failed request ( with status {resp.status_code}: {resp.text}"
        )

def process_message(prompt: str) -> None:
    """Procesar mensaje y agregar la respuesta al chat. """
    language = detect_language(prompt)
    st.session_state.messages.append(
        {"role": "user", "content": [{"type": "text", "text": prompt}]}
    )
    with st.chat_message("user"):
        st.markdown(prompt)
    with st.chat_message("assistant"):
        with st.spinner("Generado respuesta..."):
            response = send_message(prompt=prompt, language=language)
            content = response["message"]["content"]
            content_translated = translate_answer(content,response["language"])
            display_content(content=content_translated)
    st.session_state.messages.append({"role": "assistant", "content": content_translated})

def display_content(content: list, message_index: int = None,) -> None:
    """Displays a content item for a message."""
    message_index = message_index or len(st.session_state.messages)
    for item in content:
        if item["type"] == "text":
            st.markdown(item["text"])
        elif item["type"] == "suggestions":
            with st.expander("Sugerencias", expanded=True):
                for suggestion_index, suggestion in enumerate(item["suggestions"]):
                    if st.button(suggestion, key=f"{message_index}_{suggestion_index}"):
                        st.session_state.active_suggestion = suggestion
        elif item["type"] == "sql":
            with st.expander("Consulta SQL", expanded=False):
                st.code(item["statement"], language="sql")
            with st.expander("Resultado", expanded=True):
                with st.spinner("Ejecutando SQL..."):
                    session = get_active_session()
                    df = session.sql(item["statement"]).to_pandas()
                    if len(df.index) > 1:
                        data_tab, line_tab, bar_tab = st.tabs(
                            ["Datos", "Gráfico Lineal", "Gráfico Barras"]
                        )
                        data_tab.dataframe(df)
                        if len(df.columns) > 1:
                            df = df.set_index(df.columns[0])
                        with line_tab:
                            st.line_chart(df)
                        with bar_tab:
                            st.bar_chart(df)
                    else:
                        st.dataframe(df)

def translate_answer(content: list, language: str) -> str:
    """Traducir la respuesta al idioma del usuario"""
    if language == 'en':
        return content
    translated_content = []
    for item in content:
            if item["type"] == "text":
                translated_text = translate_text(item["text"],'en','es')
                translated_content.append({"type":"text","text":translated_text})
            elif item["type"] == "suggestions":
                translated_suggestions = [translate_text(s,'en','es') for s in item["suggestions"]]
                translated_content.append({"type":"suggestions","suggestions":translated_suggestions})
            elif item["type"] == "sql":
                translated_content.append(item)
    return translated_content

st.title("Usando Cortex Analyst")
st.image('https://help.sumologic.com/img/integrations/security-threat-detection/snowflake.png')

st.title("   ")
st.markdown(f"Modelo Semántico: `{FILE}`")
st.title("   ")

if "messages" not in st.session_state:
    st.session_state.messages = []
    st.session_state.suggestions = []
    st.session_state.active_suggestion = None

for message_index, message in enumerate(st.session_state.messages):
    with st.chat_message(message["role"]):
        display_content(content=message["content"],message_index=message_index)

if user_input := st.chat_input("Cual es tu pregunta?"):
    process_message(prompt=user_input)

if st.session_state.active_suggestion:
    process_message(prompt=st.session_state.active_suggestion)
    st.session_state.active_suggestion = None

