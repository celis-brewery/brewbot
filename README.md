# brewbot

![](public/brewbot.jpg)

Brewbot is a little Rails app that I wrote to test GitHub Apps in production. It's called brewbot because it lives in my test organization, [celis-brewery](https://github.com/celis-brewery), where I make dumb little beer-related repositories to test things at GitHub.

## Installation

Brewbot is simple to set up and requires only configuring several environment variables.

### Create the Heroku application

1. Clone the repository (`git clone https://github.com/celis-brewery/brewbot.git`)
2. Initialize a Heroku application (`heroku apps:create my-test-app`)
3. Note the URL of your application (e.g. https://my-test-app.herokuapp.com/)

### Setting up your GitHub App

1. Register a new GitHub App [as a user](https://github.com/settings/apps/new) or [as an organization](https://github.com/organizations/ORG_LOGIN/settings/apps/new).
2. Fill in the required fields, making sure to enter the "Webhook URL" as your app's `/hook` path (e.g. https://my-test-app.herokuapp.com/hook).
3. When you hit the optional "Webhook secret" field, run `rake secret` from Brewbot's directory and copy the resulting hexadecimal string.
4. Paste the secret into the "Webhook secret" field.
5. Run `heroku config:set GITHUB_WEBHOOK_SECRET=$(pbpaste)`
6. Continue registering the app, granting it the permissions you need for testing. You can change these later, but I simply gave mine Read & Write permissions for everything.

### Configuring the Heroku application with your app's keys

1. Generate a private key for your app and note where it was downloaded.
2. Set your heroku application's `GITHUB_APP_PRIVATE_KEY` to be the contents of the file: `heroku config:set GITHUB_APP_PRIVATE_KEY="$(cat ~/Downloads/brewbot.pem)"`
3. Set your heroku application's `GITHUB_APP_ID` to be your app's database identifier, found on the new app's settings page (`heroku config:set GITHUB_APP_ID=1234`)
4. Add the free RedisToGo addon: `heroku addons:create redistogo:nano`
5. Finally, create one more secret (`rake secret`) and assign it to the `SECRET_KEY_BASE` variable: `heroku config:set SECRET_KEY_BASE=$(rake secret)`

### Deploy to Heroku

That should be it. When you `git push heroku master` to deploy the application, you should have an app up and running. Simply install it on repositories to begin receiving webhook POSTs

### Receiving events

The application will receive events based on the permissions you grant it. To handle these events, just define a method named `handle_EVENT_ACTION` in Brewbot's ApplicationController. For example, if you were testing an app's ability to handle when an pull request is opened, you could define `ApplicationController#handle_pull_request_opened` and place any logic within:

```ruby
def handle_pull_request_opened
  # Do some stuff
end
```

For your disposal is an `octokit` method which will construct an Octokit client that hits the API as the installation on whatever repository sent the event. For example, we could use `octokit` to auto-merge any pull request that is opened on the repository:

```ruby
# Auto-merge any pull request opened on the target repository
def handle_pull_request_opened
  repo = payload.dig(:pull_request, :base, :repo, :full_name)
  head = payload.dig(:pull_request, :head, :sha)
  base = payload.dig(:pull_request, :base, :ref)

  octokit.update_ref(repo, "heads/#{base}", head)
end
```
