import { NextResponse } from "next/server"
import { querySnowflake } from "@/lib/snowflake"

export const dynamic = "force-dynamic"

export async function GET() {
  const rows = await querySnowflake("SELECT PLAZO_CURVA, VOLUMEN_MUSD, NUM_OPS FROM DB_HOL_SETICAP.PUBLIC.V_APP_VOL_PLAZO ORDER BY VOLUMEN_MUSD DESC")
  return NextResponse.json(rows)
}
