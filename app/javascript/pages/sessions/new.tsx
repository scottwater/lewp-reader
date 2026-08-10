import { Form, Link } from "@inertiajs/react"

import LewpAuthShell from "@/components/lewp-auth-shell"
import LewpFieldError from "@/components/lewp-field-error"
import LewpHead from "@/components/lewp-head"
import { identityPasswordResets, sessions, users } from "@/routes"

export default function Login() {
  return (
    <>
      <LewpHead title="Log in" />
      <LewpAuthShell
        title="Welcome back."
        description="Your feeds have been keeping your place."
      >
        <Form
          action={sessions.create()}
          resetOnSuccess={["password"]}
          disableWhileProcessing
          className="auth-form"
        >
          {({ processing, errors }) => (
            <>
              <div className="form-field">
                <label htmlFor="email">Email address</label>
                <input
                  id="email"
                  name="email"
                  type="email"
                  required
                  autoFocus
                  autoComplete="email"
                  disabled={processing}
                  placeholder="you@example.com"
                />
                <LewpFieldError messages={errors.email} />
              </div>

              <div className="form-field">
                <div className="field-label-row">
                  <label htmlFor="password">Password</label>
                  <Link href={identityPasswordResets.new()}>Forgot it?</Link>
                </div>
                <input
                  id="password"
                  name="password"
                  type="password"
                  required
                  autoComplete="current-password"
                  disabled={processing}
                  placeholder="Your password"
                />
                <LewpFieldError messages={errors.password} />
              </div>

              <button className="paper-button auth-submit" type="submit">
                {processing ? "Opening your reader…" : "Log in"}
              </button>
            </>
          )}
        </Form>

        <p className="auth-switch">
          New to Lewp Reader? <Link href={users.new()}>Create an account</Link>
        </p>
      </LewpAuthShell>
    </>
  )
}
