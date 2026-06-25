import { NextRequest, NextResponse } from "next/server"
import { querySnowflakeLongRunning } from "@/lib/snowflake"
import { parseFilters, buildWhere } from "@/lib/filters"

export const dynamic = "force-dynamic"

export async function GET(req: NextRequest) {
  const filters = parseFilters(req.nextUrl.searchParams)
  const where = buildWhere(filters)

  const sql = `
    SELECT
      FECHA,
      SUM(PRECIO * MONTO_USD) / NULLIF(SUM(MONTO_USD), 0) AS VWAP,
      SUM(MONTO_USD) / 1e6 AS VOLUMEN_MUSD,
      COUNT(*) AS NUM_OPS
    FROM DB_HOL_SETICAP.PUBLIC.OPERACIONES
    ${where}
    GROUP BY FECHA
    ORDER BY FECHA
  `
  const rows = await querySnowflakeLongRunning(sql)
  return NextResponse.json(rows)
}
