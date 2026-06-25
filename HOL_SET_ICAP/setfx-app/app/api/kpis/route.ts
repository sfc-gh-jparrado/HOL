import { NextResponse } from "next/server"
import { querySnowflake } from "@/lib/snowflake"

export const dynamic = "force-dynamic"

export async function GET() {
  const rows = await querySnowflake("SELECT * FROM DB_HOL_SETICAP.PUBLIC.V_APP_KPIS")
  return NextResponse.json(rows[0] ?? {})
}
