"use client"
import { theme } from "@/lib/theme"

export interface FilterState {
  rangoPreset: string
  mercado: string
  plazo: string
}

interface FilterBarProps {
  filters: FilterState
  onChange: (f: FilterState) => void
  mercados: string[]
  plazos: string[]
}

export function FilterBar({ filters, onChange, mercados, plazos }: FilterBarProps) {
  return (
    <div
      className="panel flex flex-wrap items-center gap-3 px-4 py-3"
      style={{ borderColor: theme.border }}
    >
      <label className="flex items-center gap-2 text-xs text-[var(--muted-foreground)]">
        Período
        <select
          className="chip bg-transparent border border-[var(--border)] rounded-md px-2 py-1 text-xs text-[var(--foreground)] outline-none focus:border-[#29B5E8]"
          value={filters.rangoPreset}
          onChange={(e) => onChange({ ...filters, rangoPreset: e.target.value })}
        >
          <option value="30d">Últimos 30 días</option>
          <option value="90d">Últimos 90 días</option>
          <option value="1y">Último año</option>
          <option value="all">Todo</option>
        </select>
      </label>

      <label className="flex items-center gap-2 text-xs text-[var(--muted-foreground)]">
        Mercado
        <select
          className="chip bg-transparent border border-[var(--border)] rounded-md px-2 py-1 text-xs text-[var(--foreground)] outline-none focus:border-[#29B5E8]"
          value={filters.mercado}
          onChange={(e) => onChange({ ...filters, mercado: e.target.value })}
        >
          <option value="Todos">Todos</option>
          {mercados.map((m) => (
            <option key={m} value={m}>{m}</option>
          ))}
        </select>
      </label>

      <label className="flex items-center gap-2 text-xs text-[var(--muted-foreground)]">
        Plazo
        <select
          className="chip bg-transparent border border-[var(--border)] rounded-md px-2 py-1 text-xs text-[var(--foreground)] outline-none focus:border-[#29B5E8]"
          value={filters.plazo}
          onChange={(e) => onChange({ ...filters, plazo: e.target.value })}
        >
          <option value="Todos">Todos</option>
          {plazos.map((p) => (
            <option key={p} value={p}>{p}</option>
          ))}
        </select>
      </label>
    </div>
  )
}
