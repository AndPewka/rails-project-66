# frozen_string_literal: true

module Web
  class AuthController < ApplicationController
    def auth_request
      redirect_to "/auth/#{params[:provider]}"
    end

    def callback
      auth = omniauth_payload
      user = upsert_user(auth)
      session[:user_id] = user.id
      redirect_to root_path, notice: t('auth.signed_in')
    end

    def destroy
      reset_session
      redirect_to root_path, notice: t('auth.signed_out')
    end

    private

    def omniauth_payload
      payload = request.env['omniauth.auth'] || OmniAuth.config.mock_auth[:github]
      raise 'No auth data' unless payload

      payload
    end

    def upsert_user(auth)
      info = auth['info'] || {}
      credentials = auth['credentials'] || {}

      email = info['email']&.downcase
      nickname = info['nickname']
      name = preferred_name(info['name'], nickname, auth['uid'])
      image_url = info['image']
      token = credentials['token']

      user = User.find_or_initialize_by(email: email)
      user.assign_attributes(
        nickname: nickname,
        name: name,
        image_url: image_url,
        token: token
      )
      user.save!
      user
    end

    def preferred_name(name, nickname, uid)
      name.presence || nickname.presence || "user#{uid}"
    end
  end
end
