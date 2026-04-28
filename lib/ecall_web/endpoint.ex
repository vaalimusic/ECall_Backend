defmodule EcallWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :ecall

  socket "/socket", EcallWeb.UserSocket,
    websocket: [connect_info: [:peer_data, :x_headers], log: false],
    longpoll: false

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]
  plug CORSPlug
  plug Plug.Parsers, parsers: [:urlencoded, :multipart, :json], json_decoder: Phoenix.json_library()
  plug EcallWeb.RateLimitPlug
  plug EcallWeb.Router
end
