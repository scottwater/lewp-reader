import { Form, Link } from "@inertiajs/react"

import LewpAuthShell from "@/components/lewp-auth-shell"
import LewpFieldError from "@/components/lewp-field-error"
import LewpHead from "@/components/lewp-head"
import { sessions, users } from "@/routes"

export default function Register() {
  return (
    <>
      <LewpHead title="Create your reader" />
      <LewpAuthShell
        title="Make a quiet place to read."
        description="Your feeds, newest first, with no recommendations sneaking in."
      >
        <Form
          action={users.create()}
          resetOnSuccess={["password", "password_confirmation"]}
          disableWhileProcessing
          className="auth-form"
        >
          {({ processing, errors }) => (
            <>
              <div className="form-field">
                <label htmlFor="name">Name</label>
                <input
                  id="name"
                  name="name"
                  type="text"
                  required
                  autoFocus
                  autoComplete="name"
                  disabled={processing}
                  placeholder="Your name"
                />
                <LewpFieldError messages={errors.name} />
              </div>

              <div className="form-field">
                <label htmlFor="email">Email address</label>
                <input
                  id="email"
                  name="email"
                  type="email"
                  required
                  autoComplete="email"
                  disabled={processing}
                  placeholder="you@example.com"
                />
                <LewpFieldError messages={errors.email} />
              </div>

              <div className="form-field">
                <label htmlFor="password">Password</label>
                <input
                  id="password"
                  name="password"
                  type="password"
                  required
                  minLength={12}
                  autoComplete="new-password"
                  disabled={processing}
                  placeholder="At least 12 characters"
                />
                <LewpFieldError messages={errors.password} />
              </div>

              <div className="form-field">
                <label htmlFor="password_confirmation">Confirm password</label>
                <input
                  id="password_confirmation"
                  name="password_confirmation"
                  type="password"
                  required
                  minLength={12}
                  autoComplete="new-password"
                  disabled={processing}
                  placeholder="Type it once more"
                />
                <LewpFieldError messages={errors.password_confirmation} />
              </div>

              <button className="paper-button auth-submit" type="submit">
                {processing ? "Making your reader…" : "Create my reader"}
              </button>
            </>
          )}
        </Form>

        <p className="auth-switch">
          Already have a reader? <Link href={sessions.new()}>Log in</Link>
        </p>
      </LewpAuthShell>
    </>
  )
}
