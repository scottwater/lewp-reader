# frozen_string_literal: true

class HomeController < InertiaController
  skip_before_action :authenticate
  before_action :perform_authentication

  def index
    render inertia: { demo_available: User.exists?(email: DemoSessionsController::DEMO_EMAIL) }
  end
end
