class ApplicationController < ActionController::API
  before_action :verify_signature, only: [:hook]

  def hook
    event = request.headers['X-GitHub-Event']

    Rails.logger.info "Received an event of type: #{event}"

    send("handle_#{event}")
  rescue NoMethodError
    Rails.logger.info "We don't handle that type of event yet."
  end

  private

  def verify_signature
    request.body.rewind

    body = request.body.read
    webhook_secret = Rails.application.secrets.github_webhook_secret
    digest = OpenSSL::Digest.new('sha1')
    hexdigest = OpenSSL::HMAC.hexdigest(digest, webhook_secret, body)
    signature = "sha1=#{hexdigest}"
    hub_signature = request.headers['X-Hub-Signature']

    unless Rack::Utils.secure_compare(signature, hub_signature)
      render json: { error: "Signature did not match." }, status: 401
    end
  end
end
