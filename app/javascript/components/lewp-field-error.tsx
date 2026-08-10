export default function LewpFieldError({ messages }: { messages?: string[] }) {
  if (!messages?.length) return null

  return (
    <p className="field-error" role="alert">
      {messages.join(" ")}
    </p>
  )
}
