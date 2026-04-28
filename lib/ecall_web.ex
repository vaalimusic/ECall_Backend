defmodule EcallWeb do
  def controller do
    quote do
      use Phoenix.Controller, formats: [:json]
      import Plug.Conn
      alias EcallWeb.Router.Helpers, as: Routes
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
      require Logger
      alias EcallWeb.Presence
    end
  end

  def router do
    quote do
      use Phoenix.Router, helpers: true
      import Plug.Conn
      import Phoenix.Controller
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: EcallWeb.Endpoint,
        router: EcallWeb.Router
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
