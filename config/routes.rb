require 'sidekiq/web'
class SubdomainConstraint
  def self.matches?(request)
    # plug in exclusions model here
    restricted_subdomains = []
    !restricted_subdomains.include?(request.subdomain)
  end
end

Rails.application.routes.draw do
  # analytics dashboard
  get 'dashboard', controller: 'comfy/admin/dashboard'
  resources :signup_wizard
  resources :signin_wizard
  constraints SubdomainConstraint do
    devise_for :users, controllers: {
      confirmations: 'users/confirmations',
      #omniauth_callbacks: 'users/omniauth_callbacks',
      registrations: 'users/registrations',
      passwords: 'users/passwords',
      sessions: 'users/sessions',
      unlocks: 'users/unlocks',
      invitations: 'devise/invitations'
    }
  end

  resource :mailbox, only: [:show], controller: 'mailbox/mailbox' do
    resources :message_threads, controller: 'mailbox/message_threads' do
      resources :messages
      member do
        post 'send_message'
      end
    end
  end

  resource :web_settings, controller: 'comfy/admin/web_settings', only: [:edit, :update]
  resources :users, controller: 'comfy/admin/users', as: :admin_users, except: [:create, :show] do
    collection do 
      post 'invite'
    end
  end
  resources :call_to_actions, controller: 'comfy/admin/call_to_actions' do
    member do
      post 'respond', to: 'call_to_action_responses#respond'
    end
  end

  # api admin
  resources :api_namespaces, controller: 'comfy/admin/api_namespaces' do
    resources :resources, controller: 'comfy/admin/api_resources' 
    resources :api_clients, controller: 'comfy/admin/api_clients' 
  end

  # system admin panel login
  devise_scope :user do
    get 'sign_in', to: 'users/sessions#new', as: :new_global_admin_session
    post 'users/sign_in', to: 'users/sessions#create'
    delete 'global_login', to: 'users/sessions#destroy'
  end
  # system admin panel authentication (ensure public schema as well)
  get 'sysadmin', to: 'admin/subdomain_requests#index'
  namespace :admin do
    authenticate :user, lambda { |u| u.global_admin? } do
      mount Sidekiq::Web => '/sidekiq'
    end
    resources :subdomain_requests, except: [:new, :create] do
      member do
        get 'approve'
        get 'disapprove'
      end
    end
    resources :subdomains
  end

  namespace 'api' do
    scope ':version' do
      scope ':api_namespace' do
        get '/', to: 'resource#index'
        get '/show/:api_resource_id', to: 'resource#show', as: :show_resource
        get '/describe', to: 'resource#describe'
        post '/query', to: 'resource#query'
        post '/', to: 'resource#create', as: :create_resource
        patch '/edit/:api_resource_id', to: 'resource#update', as: :update_resource
        delete '/destroy/:api_resource_id', to: 'resource#destroy', as: :destroy_resource
      end
    end
  end
  
  comfy_route :cms_admin, path: "/admin"
  comfy_route :blog, path: "blog"
  comfy_route :blog_admin, path: "admin"
  mount SimpleDiscussion::Engine => "/forum"
  # cms comes last because its a catch all
  comfy_route :cms, path: "/"
  
  root to: 'content#index'
  

  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end
