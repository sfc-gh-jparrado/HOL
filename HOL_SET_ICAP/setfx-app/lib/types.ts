export interface KpisData {
  VWAP_ULT_DIA: number
  VOLUMEN_TOTAL_MUSD: number
  TOTAL_OPS: number
  PCT_ANULADAS: number
}

export interface VwapDiario {
  FECHA: string
  VWAP: number
  VOLUMEN_MUSD: number
  NUM_OPS: number
}

export interface TopEntidad {
  COMPRADOR_SIGLA: string
  COMPRADOR_NOMBRE: string
  COMPRADOR_CLASE: string
  VOLUMEN_MUSD: number
  NUM_OPS: number
}

export interface VolPlazo {
  PLAZO_CURVA: string
  VOLUMEN_MUSD: number
  NUM_OPS: number
}

export interface OpReciente {
  ID: number
  FECHA: string
  HORA: string
  MERCADO_NOMBRE: string
  PLAZO_CURVA: string
  COMPRADOR_SIGLA: string
  VENDEDOR_SIGLA: string
  MONTO_USD: number
  PRECIO: number
}
