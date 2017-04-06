Rails.application.routes.draw do
  get :setup, to: 'application#setup'

  post :hook, to: 'application#hook'
end
