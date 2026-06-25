import { APP_TITLE, LOGO_SRC } from "@/lib/constants"
import { Dashboard } from "@/components/Dashboard"

export const dynamic = "force-dynamic"

export default function Home() {
  return (
    <main className="min-h-screen">
      {/* Header */}
      <header className="sticky top-0 z-50 w-full border-b border-[var(--border)]" style={{ background: "rgba(10, 14, 26, 0.92)", backdropFilter: "blur(12px)" }}>
        <div className="w-full px-6 h-14 flex items-center gap-4">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={LOGO_SRC}
            alt="SET-ICAP"
            style={{ height: 30 }}
          />
          <span className="text-sm font-semibold tracking-tight text-gradient">
            {APP_TITLE}
          </span>
          <div className="ml-auto flex items-center gap-2">
            <span className="chip">
              <span className="w-2 h-2 rounded-full bg-green-400 animate-pulse" />
              Live
            </span>
          </div>
        </div>
      </header>

      {/* Content */}
      <div className="max-w-[1440px] mx-auto px-4 sm:px-6 py-8">
        <Dashboard />
      </div>
    </main>
  )
}
