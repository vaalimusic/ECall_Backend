defmodule EcallWeb.Router do
  use EcallWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  get "/metrics", EcallWeb.MetricsController, :show

  scope "/api", EcallWeb do
    pipe_through :api

    get "/health", HealthController, :show
    get "/conversations/:user_id/:peer_id/messages", MessageController, :index
    post "/messages", MessageController, :create
    get "/users/:user_id/calls", CallController, :index
    post "/users/:user_id/device_tokens", DeviceTokenController, :create
  end
end
