class ApplicationController < ActionController::API
  before_action :verify_signature, only: [:hook]

  def hook
    event = request.headers['X-GitHub-Event']
    action = payload[:action]

    send("handle_#{event}_#{action}")
  rescue NoMethodError
    Rails.logger.info "We don't handle #{event}.#{action} events yet. Sorry!"
  end

  def handle_pull_request_opened
    repo = payload.dig(:pull_request, :base, :repo, :full_name)
    head = payload.dig(:pull_request, :head, :sha)
    base = payload.dig(:pull_request, :base, :ref)

    octokit.update_ref(repo, base, head)
  end

  private

  def octokit
    return @octokit if defined?(@octokit)

    @octokit = Octokit::Client.new(bearer_token: installation_token)
  end

  def installation_token
    token, expires_at = redis.hmget(installation_id, 'token', 'expires_at')

    return token if expires_at && Time.iso8601(expires_at).future?

    response = Octokit::Client.new(bearer_token: jwt).
                 create_integration_installation_access_token(installation_id, {
                   accept: 'application/vnd.github.machine-man-preview+json'
                 })

    token = response["token"]
    expires_at = response["expires_at"]

    redis.hmset(installation_id, 'token', token, 'expires_at', expires_at.iso8601)

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

    @private_key = OpenSSL::PKey::RSA.new(ENV['GITHUB_INTEGRATION_PRIVATE_KEY'])
  end

  def verify_signature
    webhook_secret = Rails.application.secrets.github_webhook_secret
    digest = OpenSSL::Digest.new('sha1')
    hexdigest = OpenSSL::HMAC.hexdigest(digest, webhook_secret, payload.to_json)
    signature = "sha1=#{hexdigest}"
    hub_signature = request.headers['X-Hub-Signature']

    unless Rack::Utils.secure_compare(signature, hub_signature)
      render json: { error: 'Signature did not match.' }, status: 401
    end
  end

  def payload
    return @payload if defined?(@payload)

    request.body.rewind

    @payload = JSON.parse(request.body.read).with_indifferent_access
  end

  def redis
    return @redis if defined?(@redis)

    uri = URI.parse(ENV['REDISTOGO_URL'])

    @redis = Redis.new(host: uri.host, port: uri.port, password: uri.password)
  end
end
