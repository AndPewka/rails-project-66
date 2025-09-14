# frozen_string_literal: true

module Web
  class AuthController < ApplicationController
    def auth_request
      redirect_to "/auth/#{params[:provider]}"
    end

    def callback
      auth = request.env['omniauth.auth'] || OmniAuth.config.mock_auth[:github]
      raise 'No auth data' unless auth

      info = auth['info'] || {}
      credentials = auth['credentials'] || {}

      email = info['email']&.downcase
      nickname = info['nickname']
      name = info['name'] || nickname || "user#{auth['uid']}"
      image_url = info['image']
      token = credentials['token']

      user = User.find_or_initialize_by(email: email)
      user.nickname = nickname
      user.name = name
      user.image_url = image_url
      user.token = token
      user.save!

      session[:user_id] = user.id
      redirect_to root_path, notice: t('auth.signed_in')
    end

    def destroy
      reset_session
      redirect_to root_path, notice: t('auth.signed_out')
    end
  end
end
