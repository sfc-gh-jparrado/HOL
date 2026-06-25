"use client"
import { useMemo, useState } from "react"
import { motion } from "framer-motion"
import { useChartSize } from "./useChartSize"
import { theme } from "@/lib/theme"
import { formatUSD } from "@/lib/format"
import type { ClasePunto } from "@/lib/types"

interface Props {
  data: ClasePunto[]
  accent?: string
}

export function ClaseCompareBars({ data, accent = theme.primary }: Props) {
  const height = 330
  const { ref, width } = useChartSize(height)
  const [hoverIdx, setHoverIdx] = useState<number | null>(null)

  const sorted = useMemo(
    () => [...data].sort((a, b) => (b.propio + b.sector) - (a.propio + a.sector)),
    [data]
  )

  const maxVal = useMemo(
    () => Math.max(...sorted.map((d) => Math.max(d.propio, d.sector)), 1),
    [sorted]
  )

  const marginLeft = 120
  const marginRight = 70
  const marginTop = 28
  const marginBottom = 20
  const barGroupH = Math.min(42, (height - marginTop - marginBottom) / Math.max(sorted.length, 1))
  const barH = (barGroupH - 6) / 2
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
          {/* Legend */}
          <circle cx={marginLeft} cy={12} r={4} fill={accent} />
          <text x={marginLeft + 8} y={12} dominantBaseline="middle" fill="var(--muted-foreground)" fontSize={10}>Compra</text>
          <circle cx={marginLeft + 70} cy={12} r={4} fill={theme.textMuted} />
          <text x={marginLeft + 78} y={12} dominantBaseline="middle" fill="var(--muted-foreground)" fontSize={10}>Venta</text>

          {sorted.map((d, i) => {
            const y = marginTop + i * barGroupH
            const wCompra = chartW > 0 ? (d.propio / maxVal) * chartW : 0
            const wVenta = chartW > 0 ? (d.sector / maxVal) * chartW : 0
            const isHovered = hoverIdx === i

            return (
              <g
                key={d.familia}
                onMouseEnter={() => setHoverIdx(i)}
                onMouseLeave={() => setHoverIdx(null)}
                style={{ cursor: "pointer" }}
              >
                {isHovered && (
                  <rect
                    x={0}
                    y={y - 2}
                    width={width}
                    height={barGroupH}
                    fill={accent}
                    opacity={0.05}
                    rx={4}
                  />
                )}

                <text
                  x={marginLeft - 8}
                  y={y + barGroupH / 2}
                  textAnchor="end"
                  dominantBaseline="middle"
                  fill={isHovered ? theme.text : "var(--muted-foreground)"}
                  fontSize={11}
                >
                  {d.familia.length > 16 ? d.familia.slice(0, 15) + "…" : d.familia}
                </text>

                <motion.rect
                  x={marginLeft}
                  y={y}
                  height={barH}
                  rx={3}
                  fill={accent}
                  initial={{ width: 0 }}
                  animate={{ width: Math.max(wCompra, 2) }}
                  transition={{ duration: 0.6, delay: i * 0.05, ease: "easeOut" }}
                />
                <text
                  x={marginLeft + wCompra + 4}
                  y={y + barH / 2}
                  dominantBaseline="middle"
                  fill={accent}
                  fontSize={10}
                  fontWeight={600}
                >
                  {formatUSD(d.propio * 1e6)}
                </text>

                <motion.rect
                  x={marginLeft}
                  y={y + barH + 3}
                  height={barH}
                  rx={3}
                  fill={theme.textMuted}
                  fillOpacity={0.5}
                  initial={{ width: 0 }}
                  animate={{ width: Math.max(wVenta, 2) }}
                  transition={{ duration: 0.6, delay: i * 0.05 + 0.1, ease: "easeOut" }}
                />
                <text
                  x={marginLeft + wVenta + 4}
                  y={y + barH + 3 + barH / 2}
                  dominantBaseline="middle"
                  fill={theme.textMuted}
                  fontSize={10}
                >
                  {formatUSD(d.sector * 1e6)}
                </text>
              </g>
            )
          })}
        </svg>
      )}

      {hoverIdx != null && sorted[hoverIdx] && (
        <div
          className="pointer-events-none absolute z-20 panel px-3 py-2 text-xs"
          style={{
            left: Math.min(marginLeft + 60, width - 200),
            top: marginTop + hoverIdx * barGroupH + barGroupH + 4,
          }}
        >
          <div className="font-semibold" style={{ color: accent }}>{sorted[hoverIdx].familia}</div>
          <div className="text-[var(--muted-foreground)]">
            Compra: {formatUSD(sorted[hoverIdx].propio * 1e6)} · Venta: {formatUSD(sorted[hoverIdx].sector * 1e6)}
          </div>
        </div>
      )}
    </div>
  )
}
