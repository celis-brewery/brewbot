source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end

ruby '2.4.1'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 5.1'

# Use Puma as the app server
gem 'puma'

# Generate JWTs with ease
gem 'jwt'

# Arguably the best GitHub API client
gem 'octokit', github: 'octokit/octokit.rb'

# Ugh
gem 'redis'

group :development, :test do
  # Call 'binding.pry' anywhere in the code to get a debugger console
  gem 'pry-suite'
end

group :development do
  gem 'listen', '~> 3.0.5'

  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.0'
end
