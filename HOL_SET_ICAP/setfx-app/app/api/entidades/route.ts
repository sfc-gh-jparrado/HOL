import { NextRequest, NextResponse } from "next/server"
import { querySnowflakeLongRunning } from "@/lib/snowflake"
import { parseFilters, buildWhere } from "@/lib/filters"

export const dynamic = "force-dynamic"

export async function GET(req: NextRequest) {
  const filters = parseFilters(req.nextUrl.searchParams)
  const where = buildWhere(filters)

  const sql = `
    SELECT
      COMPRADOR_SIGLA,
      COMPRADOR_NOMBRE,
      COMPRADOR_CLASE,
      SUM(MONTO_USD) / 1e6 AS VOLUMEN_MUSD,
      COUNT(*) AS NUM_OPS
    FROM DB_HOL_SETICAP.PUBLIC.OPERACIONES
    ${where}
    GROUP BY COMPRADOR_SIGLA, COMPRADOR_NOMBRE, COMPRADOR_CLASE
    ORDER BY VOLUMEN_MUSD DESC
    LIMIT 10
  `
  const rows = await querySnowflakeLongRunning(sql)
  return NextResponse.json(rows)
}
