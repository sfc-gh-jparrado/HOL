import { querySnowflake } from "@/lib/snowflake"

export const dynamic = "force-dynamic"

const DB = "DB_HOL_SETICAP"
const SCHEMA = "PUBLIC"

// GET /api/agents -> lista de agentes Cortex disponibles en DB_HOL_SETICAP.PUBLIC
export async function GET() {
  try {
    const rows = await querySnowflake(`SHOW AGENTS IN SCHEMA ${DB}.${SCHEMA}`)
    const agents = rows.map((r) => {
      let display = r.name
      try {
        const profile = r.profile ? JSON.parse(r.profile) : null
        if (profile?.display_name) display = profile.display_name
      } catch {
        /* profile may not be JSON */
      }
      return { name: r.name as string, display_name: display as string }
    })
    return Response.json({ agents })
  } catch (e) {
    console.error(new Date().toISOString(), "[/api/agents] error", e)
    return Response.json(
      { error: e instanceof Error ? e.message : "No se pudieron listar los agentes", agents: [] },
      { status: 500 },
    )
  }
}
