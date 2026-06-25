"use client"
import { useEffect, useState } from "react"
import { KpiCounter } from "@/components/charts/KpiCounter"
import { ChartFrame } from "@/components/charts/ChartFrame"
import { AreaTrend } from "@/components/charts/AreaTrend"
import { TopBars } from "@/components/charts/TopBars"
import { Donut } from "@/components/charts/Donut"
import { theme } from "@/lib/theme"
import { formatPrice, formatNumber } from "@/lib/format"
import type { KpisData, VwapDiario, TopEntidad, VolPlazo, OpReciente } from "@/lib/types"
import { DollarSign, BarChart3, Activity, XCircle } from "lucide-react"

export function Dashboard() {
  const [kpis, setKpis] = useState<KpisData | null>(null)
  const [vwap, setVwap] = useState<VwapDiario[]>([])
  const [entidades, setEntidades] = useState<TopEntidad[]>([])
  const [plazos, setPlazos] = useState<VolPlazo[]>([])
  const [ops, setOps] = useState<OpReciente[]>([])

  useEffect(() => {
    fetch("/api/kpis").then(r => r.json()).then(setKpis)
    fetch("/api/vwap").then(r => r.json()).then(setVwap)
    fetch("/api/entidades").then(r => r.json()).then(setEntidades)
    fetch("/api/plazos").then(r => r.json()).then(setPlazos)
    fetch("/api/operaciones").then(r => r.json()).then(setOps)
  }, [])

  return (
    <div className="w-full space-y-6">
      {/* KPI Row */}
      <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4">
        <KpiCounter
          label="VWAP Último Día"
          value={kpis?.VWAP_ULT_DIA ?? 0}
          format="usd"
          sublabel="COP/USD"
          icon={<DollarSign size={18} />}
          accent={theme.primary}
        />
        <KpiCounter
          label="Volumen Total"
          value={kpis?.VOLUMEN_TOTAL_MUSD ?? 0}
          format="num"
          sublabel="MUSD"
          icon={<BarChart3 size={18} />}
          accent={theme.cyan}
        />
        <KpiCounter
          label="Total Operaciones"
          value={kpis?.TOTAL_OPS ?? 0}
          format="num"
          icon={<Activity size={18} />}
          accent={theme.green}
        />
        <KpiCounter
          label="% Anuladas"
          value={kpis?.PCT_ANULADAS ?? 0}
          format="pct"
          icon={<XCircle size={18} />}
          accent={theme.red}
        />
      </div>

      {/* VWAP Trend */}
      <ChartFrame title="VWAP Diario" subtitle="Precio promedio ponderado por volumen (COP/USD)">
        <AreaTrend data={vwap} accent={theme.primary} />
      </ChartFrame>

      {/* Two-col: Top Entidades + Donut */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <ChartFrame title="Top 10 Compradores" subtitle="Por volumen negociado (MUSD)">
          <TopBars data={entidades} accent={theme.cyan} />
        </ChartFrame>
        <ChartFrame title="Volumen por Plazo" subtitle="Distribución SPOT / Forward / mismo día">
          <Donut data={plazos} />
        </ChartFrame>
      </div>

      {/* Ops Table */}
      <ChartFrame title="Operaciones Recientes" subtitle="Últimas 50 transacciones registradas">
        <div className="overflow-x-auto max-h-[400px] overflow-y-auto">
          <table className="w-full text-xs">
            <thead className="sticky top-0" style={{ background: theme.bgPanel }}>
              <tr className="text-left text-[var(--muted-foreground)]">
                <th className="p-2">Fecha</th>
                <th className="p-2">Hora</th>
                <th className="p-2">Mercado</th>
                <th className="p-2">Plazo</th>
                <th className="p-2">Comprador</th>
                <th className="p-2">Vendedor</th>
                <th className="p-2 text-right">Monto USD</th>
                <th className="p-2 text-right">Precio</th>
              </tr>
            </thead>
            <tbody>
              {ops.map((op) => (
                <tr key={op.ID} className="border-t border-[var(--border)] hover:bg-[rgba(41,181,232,0.04)]">
                  <td className="p-2">{op.FECHA}</td>
                  <td className="p-2 tabular-nums">{op.HORA}</td>
                  <td className="p-2">{op.MERCADO_NOMBRE}</td>
                  <td className="p-2">
                    <span className="chip">{op.PLAZO_CURVA}</span>
                  </td>
                  <td className="p-2 font-medium">{op.COMPRADOR_SIGLA}</td>
                  <td className="p-2">{op.VENDEDOR_SIGLA}</td>
                  <td className="p-2 text-right tabular-nums">{formatNumber(op.MONTO_USD)}</td>
                  <td className="p-2 text-right tabular-nums" style={{ color: theme.primary }}>{formatPrice(op.PRECIO)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </ChartFrame>
    </div>
  )
}
