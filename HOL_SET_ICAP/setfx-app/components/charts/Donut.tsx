"use client"
import { useMemo, useState } from "react"
import * as d3 from "d3"
import { motion } from "framer-motion"
import { useChartSize } from "./useChartSize"
import { theme, catColor } from "@/lib/theme"
import { formatPct, formatNumberShort } from "@/lib/format"
import type { VolPlazo } from "@/lib/types"

interface Props {
  data: VolPlazo[]
  accent?: string
}

export function Donut({ data, accent = theme.primary }: Props) {
  const height = 300
  const { ref, width } = useChartSize(height)
  const [hoverIdx, setHoverIdx] = useState<number | null>(null)
  const [mouse, setMouse] = useState<{ x: number; y: number } | null>(null)

  const total = useMemo(() => data.reduce((s, d) => s + d.VOLUMEN_MUSD, 0), [data])

  const { arcs, outerR, innerR } = useMemo(() => {
    if (!data.length || width === 0) return { arcs: [] as d3.PieArcDatum<VolPlazo>[], outerR: 0, innerR: 0 }
    const donutSize = Math.min(width * 0.38, height * 0.40)
    const outerR = donutSize
    const innerR = outerR * 0.62

    const pie = d3.pie<VolPlazo>()
      .value((d) => d.VOLUMEN_MUSD)
      .sort(null)
      .padAngle(0.02)

    const arcs = pie(data)
    return { arcs, outerR, innerR }
  }, [data, width])

  const handleMouseMove = (e: React.MouseEvent<SVGPathElement>, i: number) => {
    const rect = (e.currentTarget.ownerSVGElement as SVGSVGElement).getBoundingClientRect()
    setMouse({ x: e.clientX - rect.left, y: e.clientY - rect.top })
    setHoverIdx(i)
  }

  if (!data.length) {
    return (
      <div ref={ref} className="relative w-full grid place-items-center text-sm text-[var(--muted-foreground)]" style={{ height }}>
        Sin datos
      </div>
    )
  }

  const legendOnRight = width > 420
  const cx = legendOnRight ? Math.min(width * 0.38, outerR + 40) : width / 2
  const cy = height / 2

  return (
    <div ref={ref} className="relative w-full" style={{ height }}>
      {width > 0 && arcs.length > 0 && (
        <svg width={width} height={height}>
          <g transform={`translate(${cx},${cy})`}>
            {arcs.map((arc, i) => {
              const isHovered = hoverIdx === i
              const arcGen = d3.arc<d3.PieArcDatum<VolPlazo>>()
                .innerRadius(innerR)
                .outerRadius(isHovered ? outerR + 8 : outerR)
                .cornerRadius(3)
              return (
                <motion.path
                  key={arc.data.PLAZO_CURVA}
                  d={arcGen(arc)!}
                  fill={catColor(i)}
                  stroke={theme.bg}
                  strokeWidth={2}
                  initial={{ scale: 0, opacity: 0 }}
                  animate={{ scale: 1, opacity: 1 }}
                  transition={{ delay: i * 0.08, type: "spring", stiffness: 180, damping: 16 }}
                  style={{ transformOrigin: "0 0", cursor: "pointer", filter: isHovered ? "brightness(1.2)" : undefined }}
                  onMouseMove={(e) => handleMouseMove(e, i)}
                  onMouseLeave={() => { setHoverIdx(null); setMouse(null) }}
                />
              )
            })}

            <text textAnchor="middle" dominantBaseline="middle" fill={theme.text} fontSize={20} fontWeight={700} dy={-6}>
              ${total.toFixed(0)} MUSD
            </text>
            <text textAnchor="middle" dominantBaseline="middle" fill="var(--muted-foreground)" fontSize={11} dy={14}>
              volumen total
            </text>
          </g>
        </svg>
      )}

      {legendOnRight && (
        <div className="absolute right-3 top-1/2 -translate-y-1/2 flex flex-col gap-1.5 text-[11px]" style={{ maxWidth: width * 0.4 }}>
          {data.map((d, i) => (
            <div key={d.PLAZO_CURVA} className="flex items-center gap-2">
              <span className="inline-block w-2.5 h-2.5 rounded-sm shrink-0" style={{ background: catColor(i) }} />
              <span className="truncate" style={{ color: theme.text }}>{d.PLAZO_CURVA}</span>
              <span className="ml-auto tabular-nums" style={{ color: theme.textMuted }}>{total > 0 ? formatPct((d.VOLUMEN_MUSD / total) * 100) : "—"}</span>
            </div>
          ))}
        </div>
      )}
      {!legendOnRight && width > 0 && (
        <div className="absolute bottom-2 left-1/2 -translate-x-1/2 flex flex-wrap justify-center gap-x-4 gap-y-1 text-[10px]">
          {data.map((d, i) => (
            <span key={d.PLAZO_CURVA} className="flex items-center gap-1">
              <span className="inline-block w-2 h-2 rounded-sm" style={{ background: catColor(i) }} />
              <span style={{ color: theme.textMuted }}>{d.PLAZO_CURVA}</span>
            </span>
          ))}
        </div>
      )}

      {hoverIdx != null && mouse && (
        <div
          className="pointer-events-none absolute z-20 panel px-3 py-2 text-xs"
          style={{ left: Math.min(mouse.x + 14, width - 170), top: mouse.y - 60 }}
        >
          <div className="font-semibold" style={{ color: catColor(hoverIdx) }}>{data[hoverIdx].PLAZO_CURVA}</div>
          <div style={{ color: theme.textMuted }}>${data[hoverIdx].VOLUMEN_MUSD.toFixed(1)} MUSD · {formatNumberShort(data[hoverIdx].NUM_OPS)} ops</div>
        </div>
      )}
    </div>
  )
}
