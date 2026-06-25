import { NextResponse } from "next/server"
import { querySnowflake } from "@/lib/snowflake"

export const dynamic = "force-dynamic"

export async function GET() {
  const rows = await querySnowflake("SELECT FECHA, VWAP, VOLUMEN_MUSD, NUM_OPS FROM DB_HOL_SETICAP.PUBLIC.V_APP_VWAP_DIARIO ORDER BY FECHA")
  return NextResponse.json(rows)
}
