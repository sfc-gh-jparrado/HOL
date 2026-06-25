import { NextRequest, NextResponse } from "next/server"
import { querySnowflakeLongRunning } from "@/lib/snowflake"
import { parseFilters, buildWhere } from "@/lib/filters"

export const dynamic = "force-dynamic"

export async function GET(req: NextRequest) {
  const filters = parseFilters(req.nextUrl.searchParams)
  const where = buildWhere(filters)

  const sqlCompra = `
    SELECT
      COMPRADOR_CLASE AS CLASE,
      SUM(MONTO_USD) / 1e6 AS VOLUMEN
    FROM DB_HOL_SETICAP.PUBLIC.OPERACIONES
    ${where}
    GROUP BY COMPRADOR_CLASE
  `
  const sqlVenta = `
    SELECT
      VENDEDOR_CLASE AS CLASE,
      SUM(MONTO_USD) / 1e6 AS VOLUMEN
    FROM DB_HOL_SETICAP.PUBLIC.OPERACIONES
    ${where}
    GROUP BY VENDEDOR_CLASE
  `

  const [compraRows, ventaRows] = await Promise.all([
    querySnowflakeLongRunning(sqlCompra),
    querySnowflakeLongRunning(sqlVenta),
  ])

  const compraMap = new Map<string, number>()
  for (const r of compraRows) compraMap.set(r.CLASE, r.VOLUMEN)

  const ventaMap = new Map<string, number>()
  for (const r of ventaRows) ventaMap.set(r.CLASE, r.VOLUMEN)

  const allClases = new Set([...compraMap.keys(), ...ventaMap.keys()])
  const result = [...allClases]
    .filter(Boolean)
    .map((clase) => ({
      familia: clase,
      propio: compraMap.get(clase) ?? 0,
      sector: ventaMap.get(clase) ?? 0,
    }))
    .sort((a, b) => (b.propio + b.sector) - (a.propio + a.sector))

  return NextResponse.json(result)
}
