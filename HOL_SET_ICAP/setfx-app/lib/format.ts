const nf0 = new Intl.NumberFormat("es-CO", { maximumFractionDigits: 0 })
const nf1 = new Intl.NumberFormat("es-CO", { minimumFractionDigits: 1, maximumFractionDigits: 1 })
const nf2 = new Intl.NumberFormat("es-CO", { minimumFractionDigits: 2, maximumFractionDigits: 2 })

export function formatUSD(value: number): string {
  if (value == null || isNaN(value)) return "—"
  const abs = Math.abs(value)
  if (abs >= 1e9) return `$${nf1.format(value / 1e9)} B`
  if (abs >= 1e6) return `$${nf1.format(value / 1e6)} M`
  if (abs >= 1e3) return `$${nf1.format(value / 1e3)} K`
  return `$${nf0.format(value)}`
}

export function formatNumber(value: number): string {
  if (value == null || isNaN(value)) return "—"
  return nf0.format(value)
}

export function formatNumberShort(value: number): string {
  if (value == null || isNaN(value)) return "—"
  const abs = Math.abs(value)
  if (abs >= 1e6) return `${nf1.format(value / 1e6)} M`
  if (abs >= 1e3) return `${nf1.format(value / 1e3)} mil`
  return nf0.format(value)
}

export function formatPct(value: number, decimals = 1): string {
  if (value == null || isNaN(value)) return "—"
  const n = decimals === 0 ? nf0 : nf1
  return `${n.format(value)}%`
}

export function formatDelta(value: number): string {
  if (value == null || isNaN(value)) return "—"
  const sign = value > 0 ? "+" : ""
  return `${sign}${nf1.format(value)}%`
}

export function formatPrice(value: number): string {
  if (value == null || isNaN(value)) return "—"
  return `$${nf2.format(value)}`
}

const MESES = ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"]
export function formatFechaCorta(fecha: string): string {
  if (!fecha) return ""
  const d = new Date(fecha)
  return `${d.getDate()} ${MESES[d.getMonth()]}`
}
