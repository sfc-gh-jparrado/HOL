import { NextResponse } from "next/server"
import { querySnowflakeLongRunning } from "@/lib/snowflake"

export const dynamic = "force-dynamic"

export async function GET() {
  const sql = `
    SELECT
      ARRAY_AGG(DISTINCT MERCADO_NOMBRE) AS MERCADOS,
      ARRAY_AGG(DISTINCT PLAZO_CURVA) AS PLAZOS,
      MIN(FECHA) AS MIN_FECHA,
      MAX(FECHA) AS MAX_FECHA
    FROM DB_HOL_SETICAP.PUBLIC.OPERACIONES
    WHERE ANULADA = FALSE
  `
  const rows = await querySnowflakeLongRunning(sql)
  const row = rows[0] ?? {}

  const mercados: string[] = typeof row.MERCADOS === "string"
    ? JSON.parse(row.MERCADOS)
    : (row.MERCADOS ?? [])

  const plazos: string[] = typeof row.PLAZOS === "string"
    ? JSON.parse(row.PLAZOS)
    : (row.PLAZOS ?? [])

  return NextResponse.json({
    mercados: mercados.filter(Boolean).sort(),
    plazos: plazos.filter(Boolean).sort(),
    min_fecha: row.MIN_FECHA ?? null,
    max_fecha: row.MAX_FECHA ?? null,
  })
}
