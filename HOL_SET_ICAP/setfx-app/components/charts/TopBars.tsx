"use client"
import { useMemo, useState } from "react"
import { motion } from "framer-motion"
import { useChartSize } from "./useChartSize"
import { theme } from "@/lib/theme"
import { formatUSD, formatNumberShort } from "@/lib/format"
import type { TopEntidad } from "@/lib/types"

interface Props {
  data: TopEntidad[]
  accent?: string
}

export function TopBars({ data, accent = theme.primary }: Props) {
  const height = 380
  const { ref, width } = useChartSize(height)
  const [hoverIdx, setHoverIdx] = useState<number | null>(null)

  const sorted = useMemo(
    () => [...data].sort((a, b) => b.VOLUMEN_MUSD - a.VOLUMEN_MUSD).slice(0, 10),
    [data]
  )

  const maxVal = useMemo(
    () => Math.max(...sorted.map((d) => d.VOLUMEN_MUSD), 1),
    [sorted]
  )

  const marginLeft = 80
  const marginRight = 40
  const marginTop = 8
  const marginBottom = 8
  const barH = Math.min(30, (height - marginTop - marginBottom) / Math.max(sorted.length, 1) - 6)
  const gap = 6
  const chartW = width - marginLeft - marginRight

  if (!data || data.length === 0) {
    return (
      <div ref={ref} className="relative w-full" style={{ height }}>
        <div className="absolute inset-0 grid place-items-center text-sm text-[var(--muted-foreground)]">Sin datos</div>
      </div>
    )
  }

  return (
    <div ref={ref} className="relative w-full" style={{ height }}>
      {width > 0 && (
        <svg width={width} height={height}>
          {sorted.map((d, i) => {
            const y = marginTop + i * (barH + gap)
            const barW = (d.VOLUMEN_MUSD / maxVal) * chartW
            const isHovered = hoverIdx === i

            return (
              <g
                key={d.COMPRADOR_SIGLA}
                onMouseEnter={() => setHoverIdx(i)}
                onMouseLeave={() => setHoverIdx(null)}
                style={{ cursor: "pointer" }}
              >
                {isHovered && (
                  <rect x={0} y={y - 2} width={width} height={barH + 4} fill={accent} opacity={0.06} rx={4} />
                )}

                <text
                  x={marginLeft - 8}
                  y={y + barH / 2}
                  textAnchor="end"
                  dominantBaseline="middle"
                  fill={isHovered ? theme.text : "var(--muted-foreground)"}
                  fontSize={11}
                >
                  {d.COMPRADOR_SIGLA.length > 10 ? d.COMPRADOR_SIGLA.slice(0, 9) + "…" : d.COMPRADOR_SIGLA}
                </text>

                <motion.rect
                  x={marginLeft}
                  y={y}
                  height={barH}
                  rx={4}
                  fill={accent}
                  fillOpacity={isHovered ? 1 : 0.8}
                  initial={{ width: 0 }}
                  animate={{ width: Math.max(barW, 2) }}
                  transition={{ duration: 0.6, delay: i * 0.04, ease: "easeOut" }}
                />

                <text
                  x={marginLeft + barW + 6}
                  y={y + barH / 2}
                  dominantBaseline="middle"
                  fill="var(--muted-foreground)"
                  fontSize={10}
                >
                  ${d.VOLUMEN_MUSD.toFixed(0)} M
                </text>
              </g>
            )
          })}
        </svg>
      )}

      {hoverIdx != null && sorted[hoverIdx] && (
        <div
          className="pointer-events-none absolute z-20 panel px-3 py-2 text-xs"
          style={{ left: marginLeft + 40, top: marginTop + hoverIdx * (barH + gap) + barH + 8 }}
        >
          <div className="font-semibold" style={{ color: accent }}>{sorted[hoverIdx].COMPRADOR_NOMBRE}</div>
          <div className="text-[var(--muted-foreground)]">
            Clase: {sorted[hoverIdx].COMPRADOR_CLASE} · {formatNumberShort(sorted[hoverIdx].NUM_OPS)} ops
          </div>
        </div>
      )}
    </div>
  )
}
