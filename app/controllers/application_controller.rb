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

  def octokit
    return @octokit if defined?(@octokit)

    @octokit = Octokit::Client.new(bearer_token: installation_token)
  end

  def installation_token
    return @installation_token if defined?(@installation_token)

    client = Octokit::Client.new(bearer_token: jwt)
    id = params.dig(:installation, :id)

    @installation_token = client.create_integration_installation_access_token(id)
  end

  def jwt
    return @jwt if defined?(@jwt)

    payload = {
      iat: Time.now.to_i,
      exp: 10.minutes.from_now.to_i,
      iss: 1822
    }

    @jwt = JWT.encode(payload, github_integration_private_key, 'RS256')
  end

  def github_integration_private_key
    return @private_key if defined?(@private_key)

    @private_key = OpenSSL::PKey::RSA.new(ENV["GITHUB_INTEGRATION_PRIVATE_KEY"])
  end

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
