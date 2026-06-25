"use client"

import { useState, useRef, useEffect, useCallback } from "react"
import { Sparkles, Send, X, Minus, GripVertical, MessageSquare, FileText } from "lucide-react"
import ReactMarkdown from "react-markdown"
import remarkGfm from "remark-gfm"
import dynamic from "next/dynamic"
import { theme } from "@/lib/theme"

const VegaLite = dynamic(() => import("react-vega").then((m) => m.VegaLite), { ssr: false })

type ContentItem = { type: "text"; text: string }
type ApiMessage = { role: "user" | "assistant"; content: ContentItem[] }
type Cita = { title: string; text: string }
// eslint-disable-next-line @typescript-eslint/no-explicit-any
type UiMsg = { role: "user" | "assistant"; text: string; citations?: Cita[]; chartSpec?: any; tables?: any[] }
type Agente = { name: string; display_name: string }

const SUGERENCIAS = [
  "¿Cuál fue el VWAP del USD/COP la última semana?",
  "Compara el volumen entre bancos y comisionistas el último mes.",
  "Busca notas que mencionen intervención del Banco de la República.",
  "¿Qué comisionistas de bolsa hay en Medellín?",
]

/** Parse the "Preguntas sugeridas" section from assistant text. Returns body (without that section) and the question chips. */
function parseSuggestions(text: string): { body: string; questions: string[] } {
  const lines = text.split("\n")
  let splitIdx = -1
  for (let i = 0; i < lines.length; i++) {
    if (/preguntas?\s+sugeridas?/i.test(lines[i])) { splitIdx = i; break }
  }
  if (splitIdx === -1) return { body: text, questions: [] }
  const body = lines.slice(0, splitIdx).join("\n").trimEnd()
  const questions: string[] = []
  for (let i = splitIdx + 1; i < lines.length && questions.length < 3; i++) {
    const line = lines[i].trim()
    const m = line.match(/^(?:[-*]|\d+[.)]\s*)(.+)/)
    if (m) questions.push(m[1].trim())
  }
  return { body, questions }
}

/** Render a compact data table */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
function DataTable({ table }: { table: any }) {
  const rs = table?.result_set
  if (!rs) return null
  const headers: string[] = (rs.resultSetMetaData?.rowType || []).map((c: { name: string }) => c.name)
  const rows: string[][] = (rs.data || []).slice(0, 8)
  if (!headers.length || !rows.length) return null
  return (
    <div style={{ overflowX: "auto", marginTop: 8 }}>
      <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 11 }}>
        <thead>
          <tr>
            {headers.map((h, i) => (
              <th key={i} style={{ padding: "4px 6px", borderBottom: `1px solid ${theme.border}`, color: theme.textMuted, fontWeight: 600, textAlign: "left", whiteSpace: "nowrap" }}>{h}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row, ri) => (
            <tr key={ri}>
              {row.map((cell, ci) => (
                <td key={ci} style={{ padding: "3px 6px", borderBottom: `1px solid ${theme.borderSoft}`, color: theme.text, whiteSpace: "nowrap" }}>{cell}</td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

export function AgentChat() {
  const [open, setOpen] = useState(false)
  const [minimized, setMinimized] = useState(false)
  const [agentes, setAgentes] = useState<Agente[]>([])
  const [agente, setAgente] = useState<string>("AGT_SETICAP")
  const [input, setInput] = useState("")
  const [msgs, setMsgs] = useState<UiMsg[]>([])
  const [loading, setLoading] = useState(false)
  const [pos, setPos] = useState({ x: 0, y: 0 })
  const [dragging, setDragging] = useState(false)
  const dragStart = useRef({ x: 0, y: 0 })
  const endRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (!open || agentes.length > 0) return
    fetch("/api/agents").then((r) => r.json()).then((d) => {
      if (Array.isArray(d.agents) && d.agents.length) {
        setAgentes(d.agents)
        if (!d.agents.find((a: Agente) => a.name === agente)) setAgente(d.agents[0].name)
      }
    }).catch(() => {})
  }, [open, agentes.length, agente])

  useEffect(() => { endRef.current?.scrollIntoView({ behavior: "smooth" }) }, [msgs, loading])

  const onMouseDown = useCallback((e: React.MouseEvent) => {
    setDragging(true); dragStart.current = { x: e.clientX - pos.x, y: e.clientY - pos.y }; e.preventDefault()
  }, [pos])
  useEffect(() => {
    if (!dragging) return
    const onMove = (e: MouseEvent) => setPos({ x: e.clientX - dragStart.current.x, y: e.clientY - dragStart.current.y })
    const onUp = () => setDragging(false)
    window.addEventListener("mousemove", onMove); window.addEventListener("mouseup", onUp)
    return () => { window.removeEventListener("mousemove", onMove); window.removeEventListener("mouseup", onUp) }
  }, [dragging])

  async function enviar(q: string) {
    const pregunta = q.trim(); if (!pregunta || loading) return
    setInput("")
    const history = [...msgs, { role: "user" as const, text: pregunta }]
    setMsgs(history); setLoading(true)
    try {
      const apiMessages: ApiMessage[] = history.map((m) => ({ role: m.role, content: [{ type: "text", text: m.text }] }))
      const res = await fetch("/api/agent", {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ agent: agente, messages: apiMessages }),
      })
      const data = await res.json()
      if (!res.ok) {
        setMsgs((m) => [...m, { role: "assistant", text: "Error: " + (data.error || "no se pudo responder") }])
      } else {
        setMsgs((m) => [...m, {
          role: "assistant",
          text: data.text || "Sin respuesta.",
          citations: data.citations || [],
          chartSpec: data.chartSpec || null,
          tables: data.tables || [],
        }])
      }
    } catch (e) {
      setMsgs((m) => [...m, { role: "assistant", text: "Error: " + (e instanceof Error ? e.message : "fallo de red") }])
    } finally { setLoading(false) }
  }

  if (!open) {
    return (
      <button onClick={() => setOpen(true)} title="Preguntar al agente SET-FX CoWork"
        style={{ position: "fixed", bottom: 24, right: 24, zIndex: 1000, height: 56, borderRadius: 999, padding: "0 20px",
          display: "inline-flex", alignItems: "center", gap: 10, color: "#fff", fontWeight: 700, fontSize: 14, border: "none",
          cursor: "pointer", background: `linear-gradient(135deg, ${theme.primary}, ${theme.primarySoft})`, boxShadow: "0 10px 30px rgba(41,181,232,.45)" }}>
        <Sparkles size={18} /> Pregúntale al agente
      </button>
    )
  }

  return (
    <div style={{ position: "fixed", bottom: 24 - pos.y, right: 24 - pos.x, width: minimized ? 280 : 440,
      maxHeight: minimized ? "auto" : "78vh", zIndex: 1000, borderRadius: 16, border: `1px solid ${theme.border}`,
      background: theme.bgPanel, boxShadow: "0 12px 48px rgba(0,0,0,.55)", display: "flex", flexDirection: "column",
      overflow: "hidden", transition: dragging ? "none" : "width .2s ease, max-height .2s ease" }}>
      {/* Header */}
      <div onMouseDown={onMouseDown} style={{ display: "flex", alignItems: "center", justifyContent: "space-between",
        padding: "10px 12px", cursor: "grab", userSelect: "none", borderBottom: minimized ? "none" : `1px solid ${theme.border}`,
        background: `linear-gradient(135deg, ${theme.primarySoft}33, transparent)` }}>
        <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
          <GripVertical size={14} color={theme.textFaint} />
          <div style={{ width: 26, height: 26, borderRadius: 8, display: "grid", placeItems: "center",
            background: `linear-gradient(135deg, ${theme.primary}, ${theme.primarySoft})` }}><Sparkles size={13} color="#fff" /></div>
          <span style={{ fontWeight: 700, color: theme.text, fontSize: 13 }}>SET-FX CoWork</span>
        </div>
        <div style={{ display: "flex", gap: 2 }}>
          <button onClick={() => setMinimized(!minimized)} title={minimized ? "Expandir" : "Minimizar"}
            style={{ background: "none", border: "none", color: theme.textMuted, padding: 4, cursor: "pointer" }}><Minus size={16} /></button>
          <button onClick={() => setOpen(false)} title="Cerrar"
            style={{ background: "none", border: "none", color: theme.textMuted, padding: 4, cursor: "pointer" }}><X size={16} /></button>
        </div>
      </div>
      {!minimized && (
        <>
          {agentes.length > 0 && (
            <div style={{ padding: "8px 12px", borderBottom: `1px solid ${theme.borderSoft}` }}>
              <select value={agente} onChange={(e) => setAgente(e.target.value)}
                style={{ width: "100%", background: theme.bgPanelSoft, color: theme.text, border: `1px solid ${theme.border}`, borderRadius: 8, padding: "6px 8px", fontSize: 12 }}>
                {agentes.map((a) => <option key={a.name} value={a.name}>{a.display_name} ({a.name})</option>)}
              </select>
            </div>
          )}
          <div style={{ flex: 1, overflowY: "auto", padding: "12px 14px", display: "flex", flexDirection: "column", gap: 10 }}>
            {msgs.length === 0 && (
              <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
                <div style={{ color: theme.textMuted, fontSize: 13, display: "flex", alignItems: "center", gap: 6 }}><MessageSquare size={14} /> Pregúntame sobre el mercado SET-FX.</div>
                <div style={{ display: "flex", flexWrap: "wrap", gap: 6 }}>
                  {SUGERENCIAS.map((s) => <button key={s} className="chip" style={{ cursor: "pointer", fontSize: 11.5 }} onClick={() => enviar(s)}>{s}</button>)}
                </div>
              </div>
            )}
            {msgs.map((m, i) => {
              if (m.role === "user") {
                return (
                  <div key={i} style={{ display: "flex", justifyContent: "flex-end" }}>
                    <div style={{ maxWidth: "85%", padding: "9px 12px", borderRadius: 12, fontSize: 13, lineHeight: 1.5, whiteSpace: "pre-wrap",
                      color: "#fff", background: `linear-gradient(135deg, ${theme.primary}, ${theme.primarySoft})` }}>{m.text}</div>
                  </div>
                )
              }
              const { body, questions } = parseSuggestions(m.text)
              return (
                <div key={i} style={{ display: "flex", justifyContent: "flex-start" }}>
                  <div style={{ maxWidth: "85%", padding: "9px 12px", borderRadius: 12, fontSize: 13, lineHeight: 1.5,
                    color: theme.text, background: theme.bgPanelSoft, border: `1px solid ${theme.border}`, overflow: "hidden" }}>
                    <div className="agent-md">
                      <ReactMarkdown remarkPlugins={[remarkGfm]}>{body}</ReactMarkdown>
                    </div>
                    {m.chartSpec && (
                      <div style={{ marginTop: 8 }}>
                        <VegaLite
                          spec={{ ...m.chartSpec, width: 360, background: "transparent",
                            config: { ...m.chartSpec.config, axis: { labelColor: "#8FA0C2", titleColor: "#8FA0C2", gridColor: "#23304D" } } }}
                          actions={false}
                        />
                      </div>
                    )}
                    {m.tables && m.tables.length > 0 && <DataTable table={m.tables[0]} />}
                    {m.citations && m.citations.length > 0 && (
                      <div style={{ marginTop: 8, display: "flex", flexDirection: "column", gap: 4 }}>
                        <div style={{ fontSize: 10, fontWeight: 700, color: theme.textFaint }}>FUENTES</div>
                        {m.citations.slice(0, 4).map((c, j) => (
                          <div key={j} style={{ fontSize: 11, color: theme.textMuted, display: "flex", gap: 6 }}>
                            <FileText size={12} color={theme.primary} style={{ flexShrink: 0, marginTop: 2 }} /><span>{c.title}</span>
                          </div>
                        ))}
                      </div>
                    )}
                    {questions.length > 0 && (
                      <div style={{ marginTop: 10, display: "flex", flexWrap: "wrap", gap: 6 }}>
                        {questions.map((q, qi) => (
                          <button key={qi} className="chip" onClick={() => enviar(q)}
                            style={{ cursor: "pointer", fontSize: 11, padding: "4px 10px", borderRadius: 8,
                              background: theme.borderSoft, color: theme.textMuted, border: `1px solid ${theme.border}` }}>{q}</button>
                        ))}
                      </div>
                    )}
                  </div>
                </div>
              )
            })}
            {loading && <div style={{ color: theme.textMuted, fontSize: 12.5, padding: "4px 2px" }}>El agente está pensando…</div>}
            <div ref={endRef} />
          </div>
          <div style={{ display: "flex", gap: 8, padding: "10px 12px", borderTop: `1px solid ${theme.border}` }}>
            <input value={input} onChange={(e) => setInput(e.target.value)} onKeyDown={(e) => { if (e.key === "Enter") enviar(input) }}
              placeholder="Escribe tu pregunta…" disabled={loading}
              style={{ flex: 1, background: theme.bgPanelSoft, color: theme.text, border: `1px solid ${theme.border}`, borderRadius: 10, padding: "9px 12px", fontSize: 13, outline: "none" }} />
            <button onClick={() => enviar(input)} disabled={loading || !input.trim()}
              style={{ background: `linear-gradient(135deg, ${theme.primary}, ${theme.primarySoft})`, border: "none", borderRadius: 10, color: "#fff", padding: "0 14px",
                cursor: loading || !input.trim() ? "default" : "pointer", opacity: loading || !input.trim() ? 0.5 : 1 }}><Send size={15} /></button>
          </div>
        </>
      )}
      <style jsx global>{`
        .agent-md { color: #EAF0FF; }
        .agent-md p { margin: 0 0 6px 0; }
        .agent-md h1, .agent-md h2, .agent-md h3, .agent-md h4 { margin: 6px 0 4px 0; font-size: 13px; font-weight: 700; color: #EAF0FF; }
        .agent-md h2 { font-size: 12.5px; } .agent-md h3 { font-size: 12px; }
        .agent-md ul, .agent-md ol { margin: 2px 0; padding-left: 16px; }
        .agent-md li { margin-bottom: 2px; }
        .agent-md code { background: rgba(255,255,255,0.07); padding: 1px 4px; border-radius: 4px; font-size: 12px; }
        .agent-md pre { background: rgba(255,255,255,0.05); padding: 8px; border-radius: 6px; overflow-x: auto; margin: 4px 0; }
        .agent-md pre code { background: none; padding: 0; }
        .agent-md a { color: #29B5E8; text-decoration: underline; }
        .agent-md strong { color: #EAF0FF; }
        .agent-md table { border-collapse: collapse; margin: 4px 0; font-size: 11.5px; }
        .agent-md th, .agent-md td { border: 1px solid #23304D; padding: 3px 6px; }
        .agent-md th { background: rgba(255,255,255,0.04); font-weight: 600; }
      `}</style>
    </div>
  )
}
