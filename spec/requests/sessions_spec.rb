# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sessions", type: :request do
  fixtures :users

  describe "GET /sign_in" do
    it "renders the sign in page" do
      get sign_in_path
      expect(response).to have_http_status(:success)
    end

    it "redirects authenticated users" do
      sign_in users(:one)
      get sign_in_path
      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /sign_in" do
    context "with valid credentials" do
      it "signs in and sets a session cookie" do
        post sign_in_path, params: { email: users(:one).email, password: "Secret1*3*5*" }
        expect(response).to redirect_to(dashboard_path)
        expect(cookies[:session_token]).to be_present

        get dashboard_path
        expect(response).to have_http_status(:success)
        expect(inertia).to render_component("reader/index")
      end
    end

    context "with invalid credentials" do
      it "redirects back with an alert" do
        post sign_in_path, params: { email: users(:one).email, password: "wrongpassword" }
        expect(response).to redirect_to(sign_in_path)
        expect(flash[:alert]).to eq("That email or password is incorrect")

        get dashboard_path
        expect(response).to redirect_to(sign_in_path)
      end
    end
  end

  describe "DELETE /sessions/:id" do
    it "signs out when destroying the current session" do
      sign_in users(:one)
      session_record = users(:one).sessions.last

      delete session_path(session_record)

      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to eq("Signed out successfully")
      expect(Session.exists?(session_record.id)).to be(false)
      expect(cookies[:session_token]).to be_blank

      get dashboard_path
      expect(response).to redirect_to(sign_in_path)
    end

    it "revokes another session without signing out the current one" do
      sign_in users(:one)
      current_session = users(:one).sessions.last
      other_session = users(:one).sessions.create!

      delete session_path(other_session)

      expect(response).to redirect_to(settings_sessions_path)
      expect(flash[:notice]).to eq("That session has been logged out")
      expect(Session.exists?(other_session.id)).to be(false)
      expect(Session.exists?(current_session.id)).to be(true)

      get dashboard_path
      expect(response).to have_http_status(:success)
    end
  end
end
