import { NextResponse } from "next/server"
import { querySnowflake } from "@/lib/snowflake"

export const dynamic = "force-dynamic"

export async function GET() {
  const rows = await querySnowflake("SELECT ID, FECHA, HORA, MERCADO_NOMBRE, PLAZO_CURVA, COMPRADOR_SIGLA, VENDEDOR_SIGLA, MONTO_USD, PRECIO FROM DB_HOL_SETICAP.PUBLIC.V_APP_OPS_RECIENTES LIMIT 50")
  return NextResponse.json(rows)
}
