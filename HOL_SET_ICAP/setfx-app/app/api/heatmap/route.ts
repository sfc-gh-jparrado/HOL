import { NextRequest, NextResponse } from "next/server"
import { querySnowflakeLongRunning } from "@/lib/snowflake"
import { parseFilters, buildWhere } from "@/lib/filters"

export const dynamic = "force-dynamic"

const DIA_NOMBRES = ["", "Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"]

export async function GET(req: NextRequest) {
  const filters = parseFilters(req.nextUrl.searchParams)
  const where = buildWhere(filters)

  const sql = `
    SELECT
      DAYOFWEEKISO(FECHA) AS DIA_SEMANA,
      TRY_TO_NUMBER(LEFT(HORA, 2)) AS HORA,
      COUNT(*) AS NUM_TX,
      SUM(MONTO_USD) AS MONTO
    FROM DB_HOL_SETICAP.PUBLIC.OPERACIONES
    ${where}
    GROUP BY DAYOFWEEKISO(FECHA), TRY_TO_NUMBER(LEFT(HORA, 2))
    ORDER BY DIA_SEMANA, HORA
  `
  const rows = await querySnowflakeLongRunning(sql)
  const result = rows.map((r) => ({
    dia_semana: r.DIA_SEMANA,
    dia: DIA_NOMBRES[r.DIA_SEMANA] ?? `D${r.DIA_SEMANA}`,
    hora: r.HORA,
    num_tx: r.NUM_TX,
    monto: r.MONTO,
  }))
  return NextResponse.json(result)
}
