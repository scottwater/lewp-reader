# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Demo sessions", type: :request do
  fixtures :users

  describe "POST /demo_session" do
    it "signs in the seeded demo user and opens the reader" do
      demo_user = User.create!(
        name: "Lewp Reader Demo",
        email: DemoSessionsController::DEMO_EMAIL,
        password: "DemoPassword1!",
        password_confirmation: "DemoPassword1!"
      )

      expect {
        post demo_session_path
      }.to change { demo_user.sessions.count }.by(1)

      expect(response).to redirect_to(dashboard_path)
      expect(flash[:notice]).to eq("Welcome to the Lewp Reader demo")
      expect(cookies[:session_token]).to be_present

      get dashboard_path
      expect(response).to have_http_status(:success)
      expect(inertia).to render_component("reader/index")
      expect(inertia.props.dig(:auth, :user, :id)).to eq(demo_user.id)
    end

    it "returns to sign up when the demo data is missing" do
      expect {
        post demo_session_path
      }.not_to change(Session, :count)

      expect(response).to redirect_to(sign_up_path)
      expect(flash[:alert]).to eq("The demo is not seeded yet. Create an account to start Lewping.")
      expect(cookies[:session_token]).to be_blank
    end

    it "keeps an already authenticated user signed in" do
      demo_user = User.create!(
        name: "Lewp Reader Demo",
        email: DemoSessionsController::DEMO_EMAIL,
        password: "DemoPassword1!",
        password_confirmation: "DemoPassword1!"
      )
      sign_in users(:one)

      expect {
        post demo_session_path
      }.not_to change { demo_user.sessions.count }

      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to eq("You are already signed in")

      get dashboard_path
      expect(inertia.props.dig(:auth, :user, :id)).to eq(users(:one).id)
    end
  end
end
