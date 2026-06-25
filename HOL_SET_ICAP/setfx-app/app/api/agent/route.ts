import { getServiceToken, getAccountHost } from "@/lib/snowflake"

export const dynamic = "force-dynamic"

const DB = "DB_HOL_SETICAP"
const SCHEMA = "PUBLIC"

// POST /api/agent  { agent?: string, messages: Message[] }
// Llama al Cortex Agent REST API (no-streaming) y devuelve { text, citations, chartSpec, tables }.
export async function POST(req: Request) {
  try {
    const { agent, messages } = await req.json()
    const agentName = String(agent || "AGT_SETICAP").replace(/[^A-Za-z0-9_]/g, "")
    if (!Array.isArray(messages) || messages.length === 0) {
      return Response.json({ error: "Faltan mensajes" }, { status: 400 })
    }

    const token = getServiceToken()
    const host = getAccountHost()
    if (!token || !host) {
      return Response.json(
        { error: "La Agent API solo está disponible cuando la app corre en SPCS (no hay token/host en local)." },
        { status: 503 },
      )
    }

    const url = `https://${host}/api/v2/databases/${DB}/schemas/${SCHEMA}/agents/${agentName}:run`
    const controller = new AbortController()
    const timeout = setTimeout(() => controller.abort(), 120_000)

    let res: Response
    try {
      res = await fetch(url, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "X-Snowflake-Authorization-Token-Type": "OAUTH",
          "Content-Type": "application/json",
          Accept: "application/json",
        },
        body: JSON.stringify({ messages, stream: false }),
        signal: controller.signal,
      })
    } finally {
      clearTimeout(timeout)
    }

    const raw = await res.text()
    if (!res.ok) {
      console.error(new Date().toISOString(), "[/api/agent] HTTP", res.status, raw.slice(0, 500))
      return Response.json({ error: `Agent API ${res.status}: ${raw.slice(0, 300)}` }, { status: 502 })
    }

    let data: any = null
    try {
      data = JSON.parse(raw)
    } catch {
      // Algunas respuestas pueden venir como SSE aunque pidamos JSON: tomar el último "data:" parseable
      const lines = raw.split("\n").filter((l) => l.startsWith("data:"))
      for (let i = lines.length - 1; i >= 0 && !data; i--) {
        try {
          data = JSON.parse(lines[i].slice(5).trim())
        } catch {
          /* sigue */
        }
      }
    }

    const content: any[] = data?.content ?? []
    let text = ""
    const citations: { title: string; text: string }[] = []
    let chartSpec: any = null
    const tables: any[] = []

    for (const item of content) {
      if (item?.type === "text" && typeof item.text === "string") {
        text += item.text
        for (const a of item.annotations ?? []) {
          if (a?.type === "cortex_search_citation") {
            citations.push({ title: a.doc_title ?? "Documento", text: a.text ?? "" })
          }
        }
      } else if (item?.type === "chart" && item.chart?.chart_spec) {
        try {
          chartSpec = JSON.parse(item.chart.chart_spec)
        } catch {
          /* spec inválido */
        }
      } else if (item?.type === "table" && item.table?.result_set) {
        tables.push(item.table)
      }
    }

    if (!text.trim()) text = "El agente no devolvió texto. Revisa la pregunta o reformúlala."
    return Response.json({ text, citations, chartSpec, tables })
  } catch (e) {
    console.error(new Date().toISOString(), "[/api/agent] error", e)
    return Response.json(
      { error: e instanceof Error ? e.message : "Error llamando al agente" },
      { status: 500 },
    )
  }
}
