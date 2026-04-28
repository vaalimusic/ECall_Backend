defmodule EcallWeb.Router do
  use EcallWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :authenticated do
    plug EcallWeb.AuthPlug
  end

  get "/metrics", EcallWeb.MetricsController, :show

  scope "/api", EcallWeb do
    pipe_through :api

    get "/health", HealthController, :show
    post "/auth/register", AuthController, :register
    post "/auth/login", AuthController, :login
    post "/auth/refresh", AuthController, :refresh
    post "/auth/logout", AuthController, :logout
  end

  scope "/api", EcallWeb do
    pipe_through [:api, :authenticated]

    get "/auth/me", AuthController, :me
    get "/conversations/:user_id/:peer_id/messages", MessageController, :index
    post "/messages", MessageController, :create
    get "/users/:user_id/calls", CallController, :index
    post "/users/:user_id/device_tokens", DeviceTokenController, :create
  end
end
