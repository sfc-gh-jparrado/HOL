"use client"

import { useState, useRef, useEffect, useCallback } from "react"
import { Sparkles, Send, X, Minus, GripVertical, MessageSquare, FileText } from "lucide-react"
import { theme } from "@/lib/theme"

type ContentItem = { type: "text"; text: string }
type ApiMessage = { role: "user" | "assistant"; content: ContentItem[] }
type Cita = { title: string; text: string }
type UiMsg = { role: "user" | "assistant"; text: string; citations?: Cita[] }
type Agente = { name: string; display_name: string }

const SUGERENCIAS = [
  "¿Cuál fue el VWAP del USD/COP la última semana?",
  "Compara el volumen entre bancos y comisionistas el último mes.",
  "Busca notas que mencionen intervención del Banco de la República.",
  "¿Qué comisionistas de bolsa hay en Medellín?",
]

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

  // Cargar agentes disponibles al abrir
  useEffect(() => {
    if (!open || agentes.length > 0) return
    fetch("/api/agents")
      .then((r) => r.json())
      .then((d) => {
        if (Array.isArray(d.agents) && d.agents.length) {
          setAgentes(d.agents)
          if (!d.agents.find((a: Agente) => a.name === agente)) setAgente(d.agents[0].name)
        }
      })
      .catch(() => {})
  }, [open, agentes.length, agente])

  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: "smooth" })
  }, [msgs, loading])

  const onMouseDown = useCallback(
    (e: React.MouseEvent) => {
      setDragging(true)
      dragStart.current = { x: e.clientX - pos.x, y: e.clientY - pos.y }
      e.preventDefault()
    },
    [pos],
  )
  useEffect(() => {
    if (!dragging) return
    const onMove = (e: MouseEvent) => setPos({ x: e.clientX - dragStart.current.x, y: e.clientY - dragStart.current.y })
    const onUp = () => setDragging(false)
    window.addEventListener("mousemove", onMove)
    window.addEventListener("mouseup", onUp)
    return () => {
      window.removeEventListener("mousemove", onMove)
      window.removeEventListener("mouseup", onUp)
    }
  }, [dragging])

  async function enviar(q: string) {
    const pregunta = q.trim()
    if (!pregunta || loading) return
    setInput("")
    const history = [...msgs, { role: "user" as const, text: pregunta }]
    setMsgs(history)
    setLoading(true)
    try {
      const apiMessages: ApiMessage[] = history.map((m) => ({
        role: m.role,
        content: [{ type: "text", text: m.text }],
      }))
      const res = await fetch("/api/agent", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ agent: agente, messages: apiMessages }),
      })
      const data = await res.json()
      if (!res.ok) {
        setMsgs((m) => [...m, { role: "assistant", text: "Error: " + (data.error || "no se pudo responder") }])
      } else {
        setMsgs((m) => [...m, { role: "assistant", text: data.text || "Sin respuesta.", citations: data.citations || [] }])
      }
    } catch (e) {
      setMsgs((m) => [...m, { role: "assistant", text: "Error: " + (e instanceof Error ? e.message : "fallo de red") }])
    } finally {
      setLoading(false)
    }
  }

  // Botón flotante (FAB) cuando está cerrado
  if (!open) {
    return (
      <button
        onClick={() => setOpen(true)}
        title="Preguntar al agente SET-FX CoWork"
        style={{
          position: "fixed",
          bottom: 24,
          right: 24,
          zIndex: 1000,
          height: 56,
          borderRadius: 999,
          padding: "0 20px",
          display: "inline-flex",
          alignItems: "center",
          gap: 10,
          color: "#fff",
          fontWeight: 700,
          fontSize: 14,
          border: "none",
          cursor: "pointer",
          background: `linear-gradient(135deg, ${theme.primary}, ${theme.primarySoft})`,
          boxShadow: "0 10px 30px rgba(41,181,232,.45)",
        }}
      >
        <Sparkles size={18} /> Pregúntale al agente
      </button>
    )
  }

  const containerStyle: React.CSSProperties = {
    position: "fixed",
    bottom: 24 - pos.y,
    right: 24 - pos.x,
    width: minimized ? 280 : 440,
    maxHeight: minimized ? "auto" : "78vh",
    zIndex: 1000,
    borderRadius: 16,
    border: `1px solid ${theme.border}`,
    background: theme.bgPanel,
    boxShadow: "0 12px 48px rgba(0,0,0,.55)",
    display: "flex",
    flexDirection: "column",
    overflow: "hidden",
    transition: dragging ? "none" : "width .2s ease, max-height .2s ease",
  }

  return (
    <div style={containerStyle}>
      {/* Header */}
      <div
        onMouseDown={onMouseDown}
        style={{
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          padding: "10px 12px",
          cursor: "grab",
          userSelect: "none",
          borderBottom: minimized ? "none" : `1px solid ${theme.border}`,
          background: `linear-gradient(135deg, ${theme.primarySoft}33, transparent)`,
        }}
      >
        <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
          <GripVertical size={14} color={theme.textFaint} />
          <div
            style={{
              width: 26,
              height: 26,
              borderRadius: 8,
              display: "grid",
              placeItems: "center",
              background: `linear-gradient(135deg, ${theme.primary}, ${theme.primarySoft})`,
            }}
          >
            <Sparkles size={13} color="#fff" />
          </div>
          <span style={{ fontWeight: 700, color: theme.text, fontSize: 13 }}>SET-FX CoWork</span>
        </div>
        <div style={{ display: "flex", gap: 2 }}>
          <button onClick={() => setMinimized(!minimized)} title={minimized ? "Expandir" : "Minimizar"}
            style={{ background: "none", border: "none", color: theme.textMuted, padding: 4, cursor: "pointer" }}>
            <Minus size={16} />
          </button>
          <button onClick={() => setOpen(false)} title="Cerrar"
            style={{ background: "none", border: "none", color: theme.textMuted, padding: 4, cursor: "pointer" }}>
            <X size={16} />
          </button>
        </div>
      </div>

      {!minimized && (
        <>
          {/* Selector de agente */}
          {agentes.length > 0 && (
            <div style={{ padding: "8px 12px", borderBottom: `1px solid ${theme.borderSoft}` }}>
              <select
                value={agente}
                onChange={(e) => setAgente(e.target.value)}
                style={{
                  width: "100%",
                  background: theme.bgPanelSoft,
                  color: theme.text,
                  border: `1px solid ${theme.border}`,
                  borderRadius: 8,
                  padding: "6px 8px",
                  fontSize: 12,
                }}
              >
                {agentes.map((a) => (
                  <option key={a.name} value={a.name}>
                    {a.display_name} ({a.name})
                  </option>
                ))}
              </select>
            </div>
          )}

          {/* Mensajes */}
          <div style={{ flex: 1, overflowY: "auto", padding: "12px 14px", display: "flex", flexDirection: "column", gap: 10 }}>
            {msgs.length === 0 && (
              <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
                <div style={{ color: theme.textMuted, fontSize: 13, display: "flex", alignItems: "center", gap: 6 }}>
                  <MessageSquare size={14} /> Pregúntame sobre el mercado SET-FX.
                </div>
                <div style={{ display: "flex", flexWrap: "wrap", gap: 6 }}>
                  {SUGERENCIAS.map((s) => (
                    <button key={s} className="chip" style={{ cursor: "pointer", fontSize: 11.5 }} onClick={() => enviar(s)}>
                      {s}
                    </button>
                  ))}
                </div>
              </div>
            )}

            {msgs.map((m, i) => (
              <div key={i} style={{ display: "flex", justifyContent: m.role === "user" ? "flex-end" : "flex-start" }}>
                <div
                  style={{
                    maxWidth: "85%",
                    padding: "9px 12px",
                    borderRadius: 12,
                    fontSize: 13,
                    lineHeight: 1.5,
                    whiteSpace: "pre-wrap",
                    color: m.role === "user" ? "#fff" : theme.text,
                    background: m.role === "user" ? `linear-gradient(135deg, ${theme.primary}, ${theme.primarySoft})` : theme.bgPanelSoft,
                    border: m.role === "user" ? "none" : `1px solid ${theme.border}`,
                  }}
                >
                  {m.text}
                  {m.citations && m.citations.length > 0 && (
                    <div style={{ marginTop: 8, display: "flex", flexDirection: "column", gap: 4 }}>
                      <div style={{ fontSize: 10, fontWeight: 700, color: theme.textFaint }}>FUENTES</div>
                      {m.citations.slice(0, 4).map((c, j) => (
                        <div key={j} style={{ fontSize: 11, color: theme.textMuted, display: "flex", gap: 6 }}>
                          <FileText size={12} color={theme.primary} style={{ flexShrink: 0, marginTop: 2 }} />
                          <span>{c.title}</span>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              </div>
            ))}

            {loading && (
              <div style={{ color: theme.textMuted, fontSize: 12.5, padding: "4px 2px" }}>El agente está pensando…</div>
            )}
            <div ref={endRef} />
          </div>

          {/* Input */}
          <div style={{ display: "flex", gap: 8, padding: "10px 12px", borderTop: `1px solid ${theme.border}` }}>
            <input
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyDown={(e) => { if (e.key === "Enter") enviar(input) }}
              placeholder="Escribe tu pregunta…"
              disabled={loading}
              style={{
                flex: 1,
                background: theme.bgPanelSoft,
                color: theme.text,
                border: `1px solid ${theme.border}`,
                borderRadius: 10,
                padding: "9px 12px",
                fontSize: 13,
                outline: "none",
              }}
            />
            <button
              onClick={() => enviar(input)}
              disabled={loading || !input.trim()}
              style={{
                background: `linear-gradient(135deg, ${theme.primary}, ${theme.primarySoft})`,
                border: "none",
                borderRadius: 10,
                color: "#fff",
                padding: "0 14px",
                cursor: loading || !input.trim() ? "default" : "pointer",
                opacity: loading || !input.trim() ? 0.5 : 1,
              }}
            >
              <Send size={15} />
            </button>
          </div>
        </>
      )}
    </div>
  )
}
