import { Link } from "@inertiajs/react"

import LewpLogo from "@/components/lewp-logo"

interface LewpBrandProps {
  href?: string
  suffix?: string
}

export default function LewpBrand({ href = "/", suffix }: LewpBrandProps) {
  return (
    <Link className="lewp-brand" href={href} aria-label="Lewp Reader home">
      <LewpLogo compact className="lewp-brand-mark" />
      <span>lewp</span>
      {suffix && <span className="lewp-brand-suffix">/{suffix}</span>}
    </Link>
  )
}
