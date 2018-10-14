require 'sidekiq2/web'
Sidekiq2::Web.app_url = '/'

Rails.application.routes.draw do
  mount Sidekiq2::Web => '/sidekiq'
  get "work" => "work#index"
  get "work/email" => "work#email"
  get "work/post" => "work#delayed_post"
  get "work/long" => "work#long"
  get "work/crash" => "work#crash"
  get "work/bulk" => "work#bulk"
end
