import { Link } from "@inertiajs/react"
import type { ReactNode } from "react"

import LewpBrand from "@/components/lewp-brand"

interface LewpAuthShellProps {
  children: ReactNode
  description: string
  title: string
}

export default function LewpAuthShell({
  children,
  description,
  title,
}: LewpAuthShellProps) {
  return (
    <main className="auth-page">
      <header className="auth-header">
        <LewpBrand />
        <Link className="mono-link" href="/">
          Back home
        </Link>
      </header>

      <section className="auth-panel" aria-labelledby="auth-title">
        <div className="auth-intro">
          <p className="auth-kicker">Lewp Reader</p>
          <h1 id="auth-title">{title}</h1>
          <p>{description}</p>
        </div>
        {children}
      </section>
    </main>
  )
}
