#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Construye el WORKSHOP SET-ICAP: índice + 3 labs HTML self-contained.
Reutiliza el mismo branding y los pasos del HOL único, repartidos en 3 labs.
  Lab 1: Ingesta y Snowpipe        (pasos 1-4)
  Lab 2: AI Analytics              (pasos 5-8)
  Lab 3: Intelligence              (pasos 9-12)
Uso: ~/miniforge3/bin/python build_workshop.py
"""
import os, re

HERE = os.path.dirname(os.path.abspath(__file__))
SINGLE = os.path.join(HERE, "..", "set_icap_hol.html")

# Extraer el array STEPS y el bloque CSS del HOL único para no duplicar contenido
with open(SINGLE, encoding="utf-8") as f:
    single = f.read()

CSS = re.search(r"<style>(.*?)</style>", single, re.S).group(1)
STEPS_JS = re.search(r"const STEPS = (\[.*?\];)\n", single, re.S).group(1)

LABS = [
    {"id": 1, "slug": "ingesta_snowpipe", "title": "Ingesta y Snowpipe",
     "subtitle": "Carga histórica desde S3 e ingesta en tiempo real",
     "steps": [1, 2, 3, 4], "dur": "32 min",
     "desc": "Configura el ambiente, carga un año de operaciones FX desde S3 y activa la ingesta en tiempo real con Snowpipe.",
     "dep": "Ninguno (punto de partida)"},
    {"id": 2, "slug": "ai_analytics", "title": "AI Analytics",
     "subtitle": "Time Travel, Masking, Cortex AI y Dynamic Tables",
     "steps": [5, 6, 7, 8], "dur": "37 min",
     "desc": "Recupera datos con Time Travel, protege contrapartes con masking, analiza el mercado con Cortex AI y crea métricas que se refrescan solas.",
     "dep": "Lab 1 (requiere DB_HOL_SETICAP y las tablas cargadas)"},
    {"id": 3, "slug": "intelligence_agent", "title": "Intelligence",
     "subtitle": "Streamlit, Cortex Analyst y Snowflake Intelligence",
     "steps": [9, 10, 11, 12], "dur": "41 min",
     "desc": "Despliega un tablero Streamlit, crea una Semantic View para Cortex Analyst y un agente conversacional con Snowflake Intelligence.",
     "dep": "Lab 1 y Lab 2 (requiere Dynamic Tables y vistas)"},
]

LAB_TMPL = """<!DOCTYPE html>
<html lang="es"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Lab {id} · {title} · Workshop SET-ICAP</title>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@600;700;800&family=Lato:wght@400;700&family=Space+Mono&display=swap" rel="stylesheet">
<style>{css}
.backlink{{display:inline-block;margin:18px 0 0 24px;color:var(--sf-blue);text-decoration:none;font-weight:700;font-size:.85rem}}
.labtag{{display:inline-block;background:var(--sf-blue);color:#fff;padding:3px 12px;border-radius:20px;font-size:.75rem;font-weight:700;margin-bottom:10px}}
</style></head><body>
<div class="layout">
  <aside class="sidebar">
    <div class="logo">
      <img src="https://www.snowflake.com/wp-content/themes/snowflake/assets/img/logo-blue.svg" alt="Snowflake">
      <div class="sub">Workshop SET-ICAP · Lab {id}</div>
    </div>
    <a class="backlink" href="set_icap_workshop_index.html">&larr; Volver al índice</a>
    <div class="progress-wrap">
      <div class="progress-bar"><div class="progress-fill" id="pf"></div></div>
      <div class="progress-txt"><span id="pdone">0</span>/{nsteps} pasos completados</div>
    </div>
    <nav class="nav" id="nav"></nav>
  </aside>
  <main class="main">
    <section class="hero">
      <div style="display:flex;align-items:center;gap:14px;margin-bottom:14px">
        <img src="https://www.snowflake.com/wp-content/themes/snowflake/assets/img/logo-white.svg" alt="Snowflake" style="height:34px;opacity:.95">
        <span style="width:1px;height:26px;background:rgba(255,255,255,.3)"></span>
        <img src="https://set-icap.com/wp-content/uploads/2018/06/logo-set-icap-n.png" alt="SET-ICAP" style="height:34px;filter:brightness(0) invert(1);opacity:.95">
      </div>
      <span class="labtag">LAB {id} DE 3</span>
      <h1>{title}</h1>
      <div class="tagline">{subtitle}</div>
      <div class="meta"><div><span class="v">{nsteps}</span> pasos</div><div><span class="v">{dur}</span></div></div>
    </section>
    <div class="warning"><span class="icon">&#9888;&#65039;</span><div><strong>Datos de prueba</strong>
      <p>Datos sintéticos demostrativos. No representan operaciones reales de SET-ICAP.</p></div></div>
    {depnote}
    <div class="content"><div id="steps"></div>
      <div style="text-align:center;margin-top:32px">{navbtns}</div>
    </div>
    <div class="footer">© 2026 Snowflake Inc. All Rights Reserved. · Workshop SET-ICAP · Lab {id}</div>
  </main>
</div>
<script>
const ALL_STEPS = {steps_js}
const LAB_STEPS = {lab_steps};
const STEPS = ALL_STEPS.filter(s=>LAB_STEPS.includes(s.n));
const KEY="seticap_ws_lab{id}";
let done = JSON.parse(localStorage.getItem(KEY)||"[]");
function render(){{
  const nav=document.getElementById('nav'), steps=document.getElementById('steps');
  nav.innerHTML=''; steps.innerHTML='';
  STEPS.forEach(s=>{{
    const a=document.createElement('a'); a.href='#step-'+s.n; a.dataset.step=s.n;
    a.className=done.includes(s.n)?'done':'';
    a.innerHTML=`<span>${{s.n}}. ${{s.title}}</span><span class="nav-time">${{s.t}}</span>`;
    nav.appendChild(a);
    const d=document.createElement('div'); d.className='step'; d.id='step-'+s.n;
    d.innerHTML=`<div class="step-header" onclick="toggleStep(${{s.n}})">
      <div class="step-num">${{s.n}}</div><h3>${{s.title}}</h3><span class="t">${{s.t}}</span>
      <div class="chk ${{done.includes(s.n)?'on':''}}" onclick="event.stopPropagation();markStepComplete(${{s.n}})">${{done.includes(s.n)?'\\u2713':''}}</div>
      </div><div class="step-body" id="body-${{s.n}}">${{s.body}}</div>`;
    steps.appendChild(d);
  }});
  updateProgress();
}}
function toggleStep(n){{document.getElementById('body-'+n).classList.toggle('open');}}
function markStepComplete(n){{if(done.includes(n))done=done.filter(x=>x!==n);else done.push(n);
  localStorage.setItem(KEY,JSON.stringify(done));render();}}
function updateProgress(){{const pct=Math.round(done.length/STEPS.length*100);
  document.getElementById('pf').style.width=pct+'%';
  document.getElementById('pdone').textContent=done.length;}}
function copyCode(btn){{const pre=btn.parentElement.querySelector('pre');
  navigator.clipboard.writeText(pre.innerText).then(()=>{{btn.textContent='\\u2713 Copiado';setTimeout(()=>btn.textContent='Copiar',1500);}});}}
render();
if(STEPS.length) document.getElementById('body-'+STEPS[0].n).classList.add('open');
</script></body></html>"""


def build_lab(lab):
    depnote = ""
    if lab["id"] > 1:
        depnote = (f'<div class="note" style="max-width:var(--content-max);margin:0 auto 16px">'
                   f'<strong>Prerrequisito:</strong> {lab["dep"]}. Verifica que existan los objetos antes de empezar '
                   f'(<code>USE DATABASE DB_HOL_SETICAP;</code>).</div>')
    nav = []
    if lab["id"] > 1:
        prev = LABS[lab["id"] - 2]
        nav.append(f'<a class="tag" style="text-decoration:none;padding:10px 22px" href="set_icap_workshop_lab{prev["id"]}_{prev["slug"]}.html">&larr; Lab {prev["id"]}</a>')
    nav.append('<a class="tag" style="text-decoration:none;padding:10px 22px" href="set_icap_workshop_index.html">Índice</a>')
    if lab["id"] < 3:
        nxt = LABS[lab["id"]]
        nav.append(f'<a class="tag" style="text-decoration:none;padding:10px 22px" href="set_icap_workshop_lab{nxt["id"]}_{nxt["slug"]}.html">Lab {nxt["id"]} &rarr;</a>')
    html = LAB_TMPL.format(
        id=lab["id"], title=lab["title"], subtitle=lab["subtitle"],
        css=CSS, nsteps=len(lab["steps"]), dur=lab["dur"],
        steps_js=STEPS_JS, lab_steps=str(lab["steps"]),
        depnote=depnote, navbtns=" ".join(nav))
    path = os.path.join(HERE, f'set_icap_workshop_lab{lab["id"]}_{lab["slug"]}.html')
    with open(path, "w", encoding="utf-8") as f:
        f.write(html)
    return path


INDEX_TMPL = """<!DOCTYPE html>
<html lang="es"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Workshop SET-ICAP · Mercado de Divisas SET-FX</title>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@600;700;800&family=Lato:wght@400;700&family=Space+Mono&display=swap" rel="stylesheet">
<style>{css}
.wrap{{max-width:1000px;margin:0 auto;padding:40px 32px}}
.cards{{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:20px;margin-top:24px}}
.card{{background:#fff;border:1px solid var(--border);border-radius:var(--radius-lg);padding:24px;text-decoration:none;color:var(--body);transition:.2s;display:block}}
.card:hover{{transform:translateY(-4px);box-shadow:0 12px 28px rgba(17,86,127,.12);border-color:var(--sf-blue)}}
.card .num{{width:44px;height:44px;border-radius:50%;background:linear-gradient(180deg,var(--sf-blue),var(--sf-navy));color:#fff;font-family:var(--font-h);font-weight:800;font-size:1.2rem;display:flex;align-items:center;justify-content:center;margin-bottom:14px}}
.card h3{{font-family:var(--font-h);color:var(--sf-navy);font-size:1.2rem;margin-bottom:6px}}
.card .sub{{font-size:.9rem;color:var(--sf-blue);font-weight:700;margin-bottom:10px}}
.card .dur{{font-size:.78rem;color:#9AB;margin-top:12px}}
.card .dep{{font-size:.75rem;color:#9AB;margin-top:4px;font-style:italic}}
</style></head><body>
<section class="hero">
  <div class="wrap" style="padding:0">
  <div style="display:flex;align-items:center;gap:16px;margin-bottom:20px">
    <img src="https://www.snowflake.com/wp-content/themes/snowflake/assets/img/logo-white.svg" alt="Snowflake" style="height:36px;opacity:.95">
    <span style="width:1px;height:28px;background:rgba(255,255,255,.3)"></span>
    <img src="https://set-icap.com/wp-content/uploads/2018/06/logo-set-icap-n.png" alt="SET-ICAP" style="height:36px;filter:brightness(0) invert(1);opacity:.95">
  </div>
  <h1>Workshop SET-ICAP</h1>
  <div class="tagline">Mercado de Divisas SET-FX · De S3 a Snowflake Intelligence, en tiempo real</div>
  <div class="meta"><div><span class="v">3</span> labs</div><div><span class="v">~110</span> min</div>
    <div><span class="v">12</span> pasos</div><div><span class="v">118K+</span> operaciones FX</div></div>
  </div>
</section>
<div class="warning"><span class="icon">&#9888;&#65039;</span><div><strong>Datos de prueba</strong>
  <p>Datos sintéticos demostrativos. No representan operaciones reales de SET-ICAP.</p></div></div>
<div class="wrap">
  <div class="overview">
    <h2>Sobre el workshop</h2>
    <p><strong>SET-ICAP</strong> opera el sistema electrónico <strong>SET-FX</strong>, la principal fuente de
    información del dólar en Colombia. En este workshop de 3 labs construyes una plataforma analítica completa
    del mercado de divisas: ingesta en tiempo real con Snowpipe, análisis con IA generativa y un agente
    conversacional con Snowflake Intelligence.</p>
    <p style="margin-top:10px"><strong>Orden recomendado:</strong> Lab 1 → Lab 2 → Lab 3 (los labs comparten la base de datos <code>DB_HOL_SETICAP</code>).</p>
  </div>
  <div class="cards">{cards}</div>
  <div class="community" style="margin-top:32px">
    <h3>Comunidad Snowflake Colombia</h3>
    <p>Conecta con profesionales de datos e IA en el país.</p>
    <a href="https://www.snowflake.com/es/webinars/thought-leadership/comunidad-snowflake-colombia/" target="_blank">Registrarme &rarr;</a>
  </div>
</div>
<div class="footer">© 2026 Snowflake Inc. All Rights Reserved. · Workshop SET-ICAP (datos sintéticos)</div>
</body></html>"""


def build_index():
    cards = []
    for lab in LABS:
        cards.append(
            f'<a class="card" href="set_icap_workshop_lab{lab["id"]}_{lab["slug"]}.html">'
            f'<div class="num">{lab["id"]}</div>'
            f'<h3>{lab["title"]}</h3>'
            f'<div class="sub">{lab["subtitle"]}</div>'
            f'<p>{lab["desc"]}</p>'
            f'<div class="dur">⏱ {lab["dur"]} · {len(lab["steps"])} pasos</div>'
            f'<div class="dep">Prerrequisito: {lab["dep"]}</div></a>')
    html = INDEX_TMPL.format(css=CSS, cards="\n".join(cards))
    path = os.path.join(HERE, "set_icap_workshop_index.html")
    with open(path, "w", encoding="utf-8") as f:
        f.write(html)
    return path


if __name__ == "__main__":
    for lab in LABS:
        print("Lab:", build_lab(lab))
    print("Index:", build_index())
