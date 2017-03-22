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
    token, expires_at = redis.hmget(installation_id, 'token', 'expires_at')
    expires_at = Time.iso8601(expires_at)

    return token if expires_at.future?

    response = Octokit::Client.new(bearer_token: jwt).
                 create_integration_installation_access_token(installation_id)

    token = response["token"]
    expires_at = response["expires_at"]

    redis.hmset(installation_id, 'token', token, 'expires_at', expires_at)

    token
  end

  def installation_id
    params.dig(:installation, :id)
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

  def redis
    return @redis if defined?(@redis)

    uri = URI.parse(ENV['REDISTOGO_URL'])

    @redis = Redis.new(host: uri.host, port: uri.port, password: uri.password)
  end
end
