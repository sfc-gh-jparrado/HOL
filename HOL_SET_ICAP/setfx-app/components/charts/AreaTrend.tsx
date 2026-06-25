"use client"
import { useMemo, useState } from "react"
import * as d3 from "d3"
import { motion } from "framer-motion"
import { useChartSize } from "./useChartSize"
import { theme } from "@/lib/theme"
import { formatPrice, formatFechaCorta } from "@/lib/format"
import type { VwapDiario } from "@/lib/types"

interface Props {
  data: VwapDiario[]
  accent?: string
}

export function AreaTrend({ data, accent = theme.primary }: Props) {
  const height = 300
  const { ref, width } = useChartSize(height)
  const [hover, setHover] = useState<{ x: number; y: number; idx: number } | null>(null)

  const margin = { top: 20, right: 20, bottom: 36, left: 70 }

  const { xScale, yScale, areaD, lineD, ticks } = useMemo(() => {
    if (!data.length || width === 0) return { xScale: null, yScale: null, areaD: "", lineD: "", ticks: [] as number[] }
    const innerW = width - margin.left - margin.right
    const innerH = height - margin.top - margin.bottom

    const xScale = d3.scalePoint<string>()
      .domain(data.map((d) => d.FECHA))
      .range([0, innerW])
      .padding(0.1)

    const vals = data.map((d) => d.VWAP)
    const yMin = d3.min(vals) ?? 0
    const yMax = d3.max(vals) ?? 1
    const padding = (yMax - yMin) * 0.1 || 1
    const yScale = d3.scaleLinear().domain([yMin - padding, yMax + padding]).nice().range([innerH, 0])

    const area = d3.area<VwapDiario>()
      .x((d) => xScale(d.FECHA)!)
      .y0(innerH)
      .y1((d) => yScale(d.VWAP))
      .curve(d3.curveMonotoneX)

    const line = d3.line<VwapDiario>()
      .x((d) => xScale(d.FECHA)!)
      .y((d) => yScale(d.VWAP))
      .curve(d3.curveMonotoneX)

    const ticks = yScale.ticks(5)

    return { xScale, yScale, areaD: area(data) ?? "", lineD: line(data) ?? "", ticks }
  }, [data, width, margin.left, margin.right, margin.top, margin.bottom])

  const handleMouseMove = (e: React.MouseEvent<SVGRectElement>) => {
    if (!xScale || !data.length) return
    const rect = (e.currentTarget.ownerSVGElement as SVGSVGElement).getBoundingClientRect()
    const mx = e.clientX - rect.left - margin.left
    const step = xScale.step()
    let idx = Math.round(mx / step)
    idx = Math.max(0, Math.min(data.length - 1, idx))
    setHover({ x: e.clientX - rect.left, y: e.clientY - rect.top, idx })
  }

  if (!data.length) {
    return (
      <div ref={ref} className="relative w-full grid place-items-center text-sm text-[var(--muted-foreground)]" style={{ height }}>
        Sin datos
      </div>
    )
  }

  const gradId = "area-grad-vwap"

  return (
    <div ref={ref} className="relative w-full" style={{ height }}>
      {width > 0 && xScale && yScale && (
        <svg width={width} height={height}>
          <defs>
            <linearGradient id={gradId} x1="0" x2="0" y1="0" y2="1">
              <stop offset="0%" stopColor={accent} stopOpacity={0.45} />
              <stop offset="100%" stopColor={accent} stopOpacity={0} />
            </linearGradient>
          </defs>
          <g transform={`translate(${margin.left},${margin.top})`}>
            {ticks.map((t) => (
              <line
                key={t}
                x1={0}
                x2={width - margin.left - margin.right}
                y1={yScale(t)}
                y2={yScale(t)}
                stroke={theme.borderSoft}
                strokeDasharray="2,3"
              />
            ))}

            {ticks.map((t) => (
              <text key={`yl-${t}`} x={-10} y={yScale(t)} textAnchor="end" dominantBaseline="middle" fill="var(--muted-foreground)" fontSize={11}>
                {formatPrice(t)}
              </text>
            ))}

            {data.map((d, i) => {
              const show = data.length <= 14 || i % Math.ceil(data.length / 8) === 0
              if (!show) return null
              return (
                <text key={d.FECHA} x={xScale(d.FECHA)!} y={height - margin.top - margin.bottom + 22} textAnchor="middle" fill="var(--muted-foreground)" fontSize={10}>
                  {formatFechaCorta(d.FECHA)}
                </text>
              )
            })}

            <motion.path
              d={areaD}
              fill={`url(#${gradId})`}
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ duration: 0.8, delay: 0.3 }}
            />

            <motion.path
              d={lineD}
              fill="none"
              stroke={accent}
              strokeWidth={2}
              initial={{ pathLength: 0 }}
              animate={{ pathLength: 1 }}
              transition={{ duration: 1.2, ease: "easeOut" }}
            />

            {hover != null && (() => {
              const d = data[hover.idx]
              const cx = xScale(d.FECHA)!
              const cy = yScale(d.VWAP)
              return (
                <>
                  <line x1={cx} x2={cx} y1={0} y2={height - margin.top - margin.bottom} stroke={accent} strokeWidth={1} strokeDasharray="3,3" opacity={0.5} />
                  <circle cx={cx} cy={cy} r={5} fill={accent} stroke={theme.bg} strokeWidth={2} />
                </>
              )
            })()}

            <rect
              x={0}
              y={0}
              width={width - margin.left - margin.right}
              height={height - margin.top - margin.bottom}
              fill="transparent"
              onMouseMove={handleMouseMove}
              onMouseLeave={() => setHover(null)}
            />
          </g>
        </svg>
      )}

      {hover != null && (
        <div
          className="pointer-events-none absolute z-20 panel px-3 py-2 text-xs"
          style={{ left: Math.min(hover.x + 14, width - 150), top: hover.y - 50 }}
        >
          <div className="font-semibold">{formatFechaCorta(data[hover.idx].FECHA)}</div>
          <div className="text-[var(--muted-foreground)]">VWAP: {formatPrice(data[hover.idx].VWAP)}</div>
          <div className="text-[var(--muted-foreground)]">Vol: ${data[hover.idx].VOLUMEN_MUSD.toFixed(1)} MUSD</div>
        </div>
      )}
    </div>
  )
}
