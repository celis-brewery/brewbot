if ENV['GITHUB_API_ENDPOINT']
  Octokit.configure do |c|
    c.api_endpoint = ENV['GITHUB_API_ENDPOINT']
  end
end
