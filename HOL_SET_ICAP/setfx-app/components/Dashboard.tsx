"use client"
import { useCallback, useEffect, useState } from "react"
import { KpiCounter } from "@/components/charts/KpiCounter"
import { ChartFrame } from "@/components/charts/ChartFrame"
import { AreaTrend } from "@/components/charts/AreaTrend"
import { TopBars } from "@/components/charts/TopBars"
import { Donut } from "@/components/charts/Donut"
import { DayHourHeatmap } from "@/components/charts/DayHourHeatmap"
import { ClaseCompareBars } from "@/components/charts/ClaseCompareBars"
import { FilterBar, type FilterState } from "@/components/FilterBar"
import { theme } from "@/lib/theme"
import { formatPrice, formatNumber } from "@/lib/format"
import type { KpisData, VwapDiario, TopEntidad, VolPlazo, OpReciente, HoraPunto, ClasePunto, FiltrosData } from "@/lib/types"
import { DollarSign, BarChart3, Activity, XCircle } from "lucide-react"

function computeDateRange(preset: string, maxFecha: string | null): { from: string; to: string } {
  if (!maxFecha) return { from: "", to: "" }
  const to = maxFecha
  if (preset === "all") return { from: "", to: "" }
  const d = new Date(maxFecha)
  if (preset === "30d") d.setDate(d.getDate() - 30)
  else if (preset === "90d") d.setDate(d.getDate() - 90)
  else if (preset === "1y") d.setFullYear(d.getFullYear() - 1)
  const from = d.toISOString().slice(0, 10)
  return { from, to }
}

function buildQs(filters: FilterState, maxFecha: string | null): string {
  const { from, to } = computeDateRange(filters.rangoPreset, maxFecha)
  const params = new URLSearchParams()
  if (from) params.set("from", from)
  if (to) params.set("to", to)
  if (filters.mercado && filters.mercado !== "Todos") params.set("mercado", filters.mercado)
  if (filters.plazo && filters.plazo !== "Todos") params.set("plazo", filters.plazo)
  const s = params.toString()
  return s ? `?${s}` : ""
}

export function Dashboard() {
  const [filters, setFilters] = useState<FilterState>({
    rangoPreset: "90d",
    mercado: "Todos",
    plazo: "Todos",
  })
  const [filtrosData, setFiltrosData] = useState<FiltrosData | null>(null)
  const [loading, setLoading] = useState(true)

  const [kpis, setKpis] = useState<KpisData | null>(null)
  const [vwap, setVwap] = useState<VwapDiario[]>([])
  const [entidades, setEntidades] = useState<TopEntidad[]>([])
  const [plazos, setPlazos] = useState<VolPlazo[]>([])
  const [ops, setOps] = useState<OpReciente[]>([])
  const [heatmap, setHeatmap] = useState<HoraPunto[]>([])
  const [clases, setClases] = useState<ClasePunto[]>([])

  // Fetch filter metadata (once)
  useEffect(() => {
    fetch("/api/filtros")
      .then((r) => r.json())
      .then((d: FiltrosData) => setFiltrosData(d))
  }, [])

  const fetchData = useCallback((qs: string) => {
    setLoading(true)
    Promise.all([
      fetch(`/api/kpis${qs}`).then((r) => r.json()),
      fetch(`/api/vwap${qs}`).then((r) => r.json()),
      fetch(`/api/entidades${qs}`).then((r) => r.json()),
      fetch(`/api/plazos${qs}`).then((r) => r.json()),
      fetch(`/api/operaciones${qs}`).then((r) => r.json()),
      fetch(`/api/heatmap${qs}`).then((r) => r.json()),
      fetch(`/api/clases${qs}`).then((r) => r.json()),
    ]).then(([k, v, e, p, o, h, c]) => {
      setKpis(k)
      setVwap(v)
      setEntidades(e)
      setPlazos(p)
      setOps(o)
      setHeatmap(h)
      setClases(c)
      setLoading(false)
    })
  }, [])

  // Refetch on filter change (after filtrosData loaded)
  useEffect(() => {
    if (!filtrosData) return
    const qs = buildQs(filters, filtrosData.max_fecha)
    fetchData(qs)
  }, [filters, filtrosData, fetchData])

  return (
    <div className="w-full space-y-6">
      {/* Filter Bar */}
      <FilterBar
        filters={filters}
        onChange={setFilters}
        mercados={filtrosData?.mercados ?? []}
        plazos={filtrosData?.plazos ?? []}
      />

      {/* Loading Skeleton */}
      {loading && (
        <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4">
          {[...Array(4)].map((_, i) => (
            <div key={i} className="panel p-5 animate-pulse h-24 rounded-xl" />
          ))}
        </div>
      )}

      {/* KPI Row */}
      {!loading && (
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
      )}

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

      {/* NEW: Heatmap + Clases Compare */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <ChartFrame title="Actividad por Hora y Día" subtitle="Concentración de transacciones (heatmap)">
          <DayHourHeatmap data={heatmap} accent={theme.cyan} />
        </ChartFrame>
        <ChartFrame title="Compra vs Venta por Clase" subtitle="Volumen por clase de entidad (MUSD)">
          <ClaseCompareBars data={clases} accent={theme.primary} />
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
