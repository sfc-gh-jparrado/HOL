import type { Metadata } from "next"
import type React from "react"
import { APP_TITLE } from "@/lib/constants"
import "./globals.css"

export const metadata: Metadata = {
  title: APP_TITLE,
  description: "Dashboard del mercado de divisas SET-FX — Sistema Electrónico de Transacción de Moneda Extranjera",
  icons: { icon: "/icon.svg" },
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <html lang="es" suppressHydrationWarning>
      <body className="antialiased">
        {children}
      </body>
    </html>
  )
}
