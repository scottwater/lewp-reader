import { Head } from "@inertiajs/react"

export default function LewpHead({ title }: { title: string }) {
  return (
    <Head title={title}>
      <link rel="preconnect" href="https://fonts.bunny.net" />
      <link
        href="https://fonts.bunny.net/css?family=geist:400,500,600|geist-mono:400,500,600"
        rel="stylesheet"
      />
    </Head>
  )
}
