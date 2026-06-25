export const theme = {
  bg: "#0A0E1A",
  bgPanel: "#121A2E",
  bgPanelSoft: "#0F1626",
  border: "#23304D",
  borderSoft: "#1A2540",
  text: "#EAF0FF",
  textMuted: "#8FA0C2",
  textFaint: "#5B6B8C",

  primary: "#29B5E8",
  primarySoft: "#11567F",
  cyan: "#22D3EE",
  green: "#16C784",
  greenSoft: "#0E9E68",
  amber: "#F5A623",
  red: "#FF5670",
  violet: "#A78BFA",
  pink: "#F472B6",
  teal: "#2DD4BF",
} as const

export const CATEGORICAL = [
  "#29B5E8",
  "#22D3EE",
  "#16C784",
  "#F5A623",
  "#A78BFA",
  "#F472B6",
  "#2DD4BF",
  "#FF8A5B",
]

export function catColor(i: number): string {
  return CATEGORICAL[i % CATEGORICAL.length]
}

export const CHORO_RAMP = ["#0F1B3A", "#16336E", "#1E54B8", "#2E6BFF", "#22D3EE", "#7BE8FF"]
