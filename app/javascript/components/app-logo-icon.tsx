import type { SVGAttributes } from "react"

export default function AppLogoIcon(props: SVGAttributes<SVGElement>) {
  return (
    <svg
      aria-hidden="true"
      fill="none"
      viewBox="0 0 60 32"
      xmlns="http://www.w3.org/2000/svg"
      {...props}
    >
      <path
        d="M4 16 C 18 16 18 4 28 4 C 40 4 40 28 26 28 C 16 28 20 16 40 16 L 56 16"
        stroke="currentColor"
        strokeLinecap="round"
        strokeWidth="3"
      />
      <circle cx="4" cy="16" fill="currentColor" r="4" />
    </svg>
  )
}
