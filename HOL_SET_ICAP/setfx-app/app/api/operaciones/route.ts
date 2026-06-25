import { NextRequest, NextResponse } from "next/server"
import { querySnowflakeLongRunning } from "@/lib/snowflake"
import { parseFilters, buildWhere } from "@/lib/filters"

export const dynamic = "force-dynamic"

export async function GET(req: NextRequest) {
  const filters = parseFilters(req.nextUrl.searchParams)
  const where = buildWhere(filters)

  const sql = `
    SELECT
      FECHA, HORA, MERCADO_NOMBRE, PLAZO_CURVA,
      COMPRADOR_SIGLA, VENDEDOR_SIGLA, MONTO_USD, PRECIO
    FROM DB_HOL_SETICAP.PUBLIC.OPERACIONES
    ${where}
    ORDER BY FECHA DESC, HORA DESC
    LIMIT 50
  `
  const rows = await querySnowflakeLongRunning(sql)
  // Add synthetic ID
  const withId = rows.map((r, i) => ({ ID: i + 1, ...r }))
  return NextResponse.json(withId)
}
