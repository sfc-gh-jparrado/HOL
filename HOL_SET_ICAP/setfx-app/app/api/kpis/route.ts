import { NextRequest, NextResponse } from "next/server"
import { querySnowflakeLongRunning } from "@/lib/snowflake"
import { parseFilters, buildWhere } from "@/lib/filters"

export const dynamic = "force-dynamic"

export async function GET(req: NextRequest) {
  const filters = parseFilters(req.nextUrl.searchParams)
  const where = buildWhere(filters)
  const whereAll = buildWhere(filters, { includeAnuladas: true })

  const sql = `
    WITH rango AS (
      SELECT MAX(FECHA) AS max_fecha FROM DB_HOL_SETICAP.PUBLIC.OPERACIONES ${where}
    ),
    ult_dia AS (
      SELECT
        SUM(PRECIO * MONTO_USD) / NULLIF(SUM(MONTO_USD), 0) AS VWAP_ULT_DIA
      FROM DB_HOL_SETICAP.PUBLIC.OPERACIONES o
      ${where}${where ? ' AND' : ' WHERE'} FECHA = (SELECT max_fecha FROM rango)
    ),
    totales AS (
      SELECT
        SUM(MONTO_USD) / 1e6 AS VOLUMEN_TOTAL_MUSD,
        COUNT(*) AS TOTAL_OPS
      FROM DB_HOL_SETICAP.PUBLIC.OPERACIONES
      ${where}
    ),
    anuladas AS (
      SELECT
        COUNT(CASE WHEN ANULADA = TRUE THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0) AS PCT_ANULADAS
      FROM DB_HOL_SETICAP.PUBLIC.OPERACIONES
      ${whereAll}
    )
    SELECT
      ROUND(u.VWAP_ULT_DIA, 2) AS VWAP_ULT_DIA,
      ROUND(t.VOLUMEN_TOTAL_MUSD, 1) AS VOLUMEN_TOTAL_MUSD,
      t.TOTAL_OPS,
      ROUND(a.PCT_ANULADAS, 2) AS PCT_ANULADAS
    FROM ult_dia u, totales t, anuladas a
  `
  const rows = await querySnowflakeLongRunning(sql)
  return NextResponse.json(rows[0] ?? {})
}
