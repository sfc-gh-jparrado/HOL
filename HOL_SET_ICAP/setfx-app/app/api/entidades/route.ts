import { NextResponse } from "next/server"
import { querySnowflake } from "@/lib/snowflake"

export const dynamic = "force-dynamic"

export async function GET() {
  const rows = await querySnowflake("SELECT COMPRADOR_SIGLA, COMPRADOR_NOMBRE, COMPRADOR_CLASE, VOLUMEN_MUSD, NUM_OPS FROM DB_HOL_SETICAP.PUBLIC.V_APP_TOP_ENTIDADES ORDER BY VOLUMEN_MUSD DESC LIMIT 10")
  return NextResponse.json(rows)
}
