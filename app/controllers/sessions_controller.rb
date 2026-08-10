# frozen_string_literal: true

class SessionsController < InertiaController
  skip_before_action :authenticate, only: %i[new create]
  before_action :require_no_authentication, only: %i[new create]
  before_action :set_session, only: :destroy

  def new
  end

  def create
    if user = User.authenticate_by(email: params[:email], password: params[:password])
      @session = user.sessions.create!
      cookies.signed.permanent[:session_token] = { value: @session.id, httponly: true, same_site: :lax }

      redirect_to dashboard_path, notice: "Signed in successfully"
    else
      redirect_to sign_in_path, alert: "That email or password is incorrect"
    end
  end

  def destroy
    signing_out = @session == Current.session
    @session.destroy!
    if signing_out
      Current.session = nil
      cookies.delete(:session_token)
      redirect_to root_path, notice: "Signed out successfully", inertia: { clear_history: true }
    else
      redirect_to settings_sessions_path, notice: "That session has been logged out"
    end
  end

  private

  def set_session
    @session = Current.user.sessions.find(params[:id])
  end
end
