/**
 * Shared filter utilities for API routes.
 * Sanitizes and builds WHERE clauses from query params.
 */

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/

function escapeStr(val: string): string {
  return val.replace(/'/g, "''")
}

export interface FilterParams {
  from?: string
  to?: string
  mercado?: string
  plazo?: string
}

export function parseFilters(searchParams: URLSearchParams): FilterParams {
  const from = searchParams.get("from") ?? ""
  const to = searchParams.get("to") ?? ""
  const mercado = searchParams.get("mercado") ?? ""
  const plazo = searchParams.get("plazo") ?? ""
  return { from, to, mercado, plazo }
}

/**
 * Builds WHERE conditions for OPERACIONES table.
 * Always includes ANULADA = FALSE unless `includeAnuladas` is true.
 */
export function buildWhere(filters: FilterParams, options?: { includeAnuladas?: boolean }): string {
  const clauses: string[] = []

  if (!options?.includeAnuladas) {
    clauses.push("ANULADA = FALSE")
  }

  if (filters.from && DATE_RE.test(filters.from)) {
    clauses.push(`FECHA >= '${filters.from}'`)
  }
  if (filters.to && DATE_RE.test(filters.to)) {
    clauses.push(`FECHA <= '${filters.to}'`)
  }
  if (filters.mercado && filters.mercado !== "Todos") {
    clauses.push(`MERCADO_NOMBRE = '${escapeStr(filters.mercado)}'`)
  }
  if (filters.plazo && filters.plazo !== "Todos") {
    clauses.push(`PLAZO_CURVA = '${escapeStr(filters.plazo)}'`)
  }

  return clauses.length > 0 ? `WHERE ${clauses.join(" AND ")}` : ""
}
