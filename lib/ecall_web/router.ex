defmodule EcallWeb.Router do
  use EcallWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug EcallWeb.RateLimitPlug
  end

  pipeline :authenticated do
    plug EcallWeb.AuthPlug
  end

  pipeline :internal do
    plug EcallWeb.MetricsAuthPlug
  end

  scope "/" do
    pipe_through :internal

    get "/metrics", EcallWeb.MetricsController, :show
  end

  scope "/api", EcallWeb do
    pipe_through :api

    get "/health", HealthController, :show
    get "/health/live", HealthController, :live
    get "/health/ready", HealthController, :ready
    get "/health/turn", HealthController, :turn
    post "/auth/register", AuthController, :register
    post "/auth/login", AuthController, :login
    post "/auth/refresh", AuthController, :refresh
    post "/auth/logout", AuthController, :logout
  end

  scope "/api", EcallWeb do
    pipe_through [:api, :authenticated]

    get "/auth/me", AuthController, :me
    get "/webrtc/ice_servers", IceServerController, :index
    get "/users/:user_id/messages/sync", MessageController, :sync
    get "/conversations/:user_id/:peer_id/messages", MessageController, :index
    post "/messages", MessageController, :create
    get "/calls/:id", CallController, :show
    get "/users/:user_id/calls/active", CallController, :active
    get "/users/:user_id/calls", CallController, :index
    post "/users/:user_id/device_tokens", DeviceTokenController, :create
  end
end
