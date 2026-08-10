import type { SVGAttributes } from "react"

interface LewpLogoProps extends SVGAttributes<SVGSVGElement> {
  animated?: boolean
  compact?: boolean
}

export default function LewpLogo({
  animated = false,
  compact = false,
  className,
  ...props
}: LewpLogoProps) {
  if (compact) {
    return (
      <svg
        aria-hidden="true"
        className={className}
        fill="none"
        viewBox="0 0 60 32"
        {...props}
      >
        <path
          d="M4 16 C 18 16 18 4 28 4 C 40 4 40 28 26 28 C 16 28 20 16 40 16 L 56 16"
          fill="none"
          stroke="currentColor"
          strokeLinecap="round"
          strokeWidth="3"
        />
        <circle cx="4" cy="16" fill="currentColor" r="4" />
      </svg>
    )
  }

  return (
    <svg
      aria-hidden="true"
      className={className}
      fill="none"
      viewBox="0 0 240 120"
      {...props}
    >
      <path
        className={animated ? "lewp-logo-path" : undefined}
        d="M16 62 C 66 62 66 20 100 20 C 142 20 142 100 96 100 C 62 100 76 62 152 62 L 224 62"
        fill="none"
        pathLength="1"
        stroke="currentColor"
        strokeLinecap="round"
        strokeWidth="4.5"
      />
      <circle
        className={animated ? "lewp-logo-dot" : undefined}
        cx="16"
        cy="62"
        fill="currentColor"
        r="8"
      />
      <circle
        className={animated ? "lewp-logo-tip" : undefined}
        cx="224"
        cy="62"
        fill="currentColor"
        r="6"
      />
    </svg>
  )
}
