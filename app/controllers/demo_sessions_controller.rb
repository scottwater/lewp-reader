# frozen_string_literal: true

class DemoSessionsController < InertiaController
  DEMO_EMAIL = "demo@lewpreader.test"

  skip_before_action :authenticate
  before_action :require_no_authentication

  def create
    user = User.find_by(email: DEMO_EMAIL)

    unless user
      redirect_to sign_up_path, alert: "The demo is not seeded yet. Create an account to start Lewping."
      return
    end

    session_record = user.sessions.create!
    cookies.signed.permanent[:session_token] = { value: session_record.id, httponly: true, same_site: :lax }

    redirect_to dashboard_path, notice: "Welcome to the Lewp Reader demo"
  end
end
