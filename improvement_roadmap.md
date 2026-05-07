# 🗺️ ECall Backend — План улучшений

> **Принцип:** сначала безопасность и стабильность, потом новые фичи.  
> Фазы идут строго по порядку — каждая следующая опирается на предыдущую.

---

## Фаза 0 — Критические фиксы (1–2 дня)
> Это надо сделать **до** любых новых фич. Дыры в безопасности.

### 0.1 Убрать небезопасную аутентификацию WebSocket
```elixir
# УДАЛИТЬ из user_socket.ex:
user_id = params["user_id"] ->
  connect_insecure(user_id, socket)
```
Пока эта ветка существует — любой знающий user_id может подключиться без токена.

### 0.2 Подключить RateLimitPlug к роутеру
```elixir
# router.ex
pipeline :api do
  plug :accepts, ["json"]
  plug EcallWeb.RateLimitPlug   # ← добавить
end
```

### 0.3 Закрыть /metrics от публичного доступа
```elixir
# router.ex — добавить Basic Auth
pipeline :internal do
  plug :accepts, ["json"]
  plug Plug.BasicAuth, username: "metrics", password: System.get_env("METRICS_PASSWORD", "change-me")
end

scope "/" do
  pipe_through :internal
  get "/metrics", EcallWeb.MetricsController, :show
end
```

### 0.4 Убрать DB-запрос из AuthPlug (производительность + безопасность)
Хранить `disabled: true/false` в JWT payload. При блокировке пользователя — инвалидировать refresh-токены (уже есть `revoke_all_user_tokens`).
```elixir
# Добавить в JWT payload при выдаче токена:
Token.generate(user.id, %{
  "typ" => "access",
  "email" => user.email,
  "active" => is_nil(user.disabled_at)   # ← добавить
})

# AuthPlug — убрать DB-запрос, проверять claims:
with {:ok, raw_token} <- fetch_bearer_token(conn),
     {:ok, user_id, claims} <- Token.verify_with_claims(raw_token),
     true <- claims["active"] do
  assign(conn, :current_user_id, user_id)
```

### 0.5 Исправить FCM Access Token (обновляться каждый час)
```elixir
# mix.exs — добавить Goth
{:goth, "~> 1.4"}

# push/fcm_client.ex — получать токен динамически
defp get_access_token do
  {:ok, token} = Goth.fetch(Ecall.Goth)
  token.token
end
```

---

## Фаза 1 — Производительность и масштабирование (3–5 дней)

### 1.1 Заменить Registry GenServer на per-call процессы
Сейчас один GenServer на все звонки = bottleneck.

**Новая архитектура:**
```
Ecall.Calls.Supervisor (DynamicSupervisor)
  └── Ecall.Calls.CallProcess (pid per call_id)
        ├── хранит: статус, участники, таймер
        └── умирает сам когда звонок завершён
```

```elixir
# calls/call_process.ex
defmodule Ecall.Calls.CallProcess do
  use GenServer, restart: :temporary

  def start_link({call_id, caller_id, callee_id, timeout_ms}) do
    GenServer.start_link(__MODULE__, ..., name: via(call_id))
  end

  defp via(call_id), do: {:via, Registry, {Ecall.CallRegistry, call_id}}
end
```

Преимущества:
- Параллельная обработка всех звонков
- Крах одного звонка не затрагивает остальные
- Готово к распределённому кластеру

### 1.2 Заменить самописную push-очередь на Oban
```elixir
# mix.exs
{:oban, "~> 2.18"}

# workers/push_worker.ex
defmodule Ecall.Workers.PushWorker do
  use Oban.Worker, queue: :push, max_attempts: 8

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"token_id" => token_id, "type" => type, "payload" => payload}}) do
    # ...
  end
end
```

Плюсы: Web UI, cron, dead letter queue, метрики из коробки.

### 1.3 Пагинация курсором вместо LIMIT
```elixir
# messaging.ex — вместо обрезания по limit:
def sync_for_user(user_id, after_id, limit \\ 50) do
  Message
  |> where([m], m.sender_id == ^user_id or m.recipient_id == ^user_id)
  |> where([m], m.id > ^after_id)   # ← cursor по UUID (монотонный)
  |> order_by([m], asc: m.inserted_at)
  |> limit(^min(limit, 200))
  |> Repo.all()
end
```

### 1.4 Абстрактный Push Adapter
```elixir
defmodule Ecall.Push.Adapter do
  @callback deliver(token :: map(), type :: String.t(), payload :: map()) ::
    :ok | {:error, :invalid_token} | {:error, term()}
end

# Реализации:
# - Ecall.Push.FcmAdapter    (Android)
# - Ecall.Push.ApnsAdapter   (iOS/macOS)
# - Ecall.Push.WebPushAdapter (браузер/ПК)
# - Ecall.Push.LogAdapter    (dev/test)
```

---

## Фаза 2 — Комнаты и групповые звонки (7–14 дней)
> Это большая фича. Discord-style: войти в комнату = начать слышать всех.

### 2.1 Новая схема БД

```sql
-- Комнаты (голосовые каналы, как в Discord)
CREATE TABLE rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  owner_id TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'voice',   -- 'voice' | 'video' | 'text'
  max_participants INTEGER DEFAULT 50,
  status TEXT NOT NULL DEFAULT 'active', -- 'active' | 'archived'
  metadata JSONB DEFAULT '{}',
  inserted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Члены комнаты (постоянные участники/права)
CREATE TABLE room_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID REFERENCES rooms(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'member',  -- 'owner' | 'moderator' | 'member'
  inserted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(room_id, user_id)
);

-- Активные участники в комнате прямо сейчас
CREATE TABLE room_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID REFERENCES rooms(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  left_at TIMESTAMPTZ,
  muted BOOLEAN DEFAULT false,
  video_enabled BOOLEAN DEFAULT false,
  UNIQUE(room_id, user_id)
);
```

### 2.2 Контекст Rooms

```elixir
defmodule Ecall.Rooms do
  # Создать комнату
  def create(owner_id, attrs)

  # Войти в комнату (upsert room_session)
  def join(room_id, user_id)

  # Выйти из комнаты
  def leave(room_id, user_id)

  # Список присутствующих прямо сейчас
  def active_participants(room_id)

  # Heartbeat (как в calls)
  def heartbeat(room_id, user_id)

  # Обновить состояние (muted, video)
  def update_session(room_id, user_id, attrs)
end
```

### 2.3 WebRTC для групп — SFU vs Mesh

**Проблема:** WebRTC p2p (mesh) не масштабируется на группы.

```
Mesh (текущий подход):        SFU (нужен для комнат):
A ←→ B                        A → SFU → B
A ←→ C          vs            B → SFU → A, C
B ←→ C                        C → SFU → A, B
```

При mesh 5 человек = 10 соединений на каждого. При SFU — 1 вход + 1 выход.

**Рекомендуемое решение:** добавить **mediasoup** или **LiveKit** как media-сервер:

```yaml
# docker-compose.yml
livekit:
  image: livekit/livekit-server:latest
  ports:
    - "7880:7880"   # HTTP/WS API
    - "7881:7881"   # RTC
    - "7882:7882/udp"
  environment:
    LIVEKIT_KEYS: "APIKey: secret"
```

Бекенд генерирует JWT-токены для LiveKit, клиент подключается напрямую к LiveKit.

```elixir
# Новый эндпоинт:
# GET /api/rooms/:id/join_token
# Возвращает LiveKit JWT для входа в комнату
defmodule Ecall.Rooms.TokenGenerator do
  def generate(room_id, user_id, permissions) do
    # HMAC-signed JWT для LiveKit
    claims = %{
      "video" => %{
        "roomJoin" => true,
        "room" => room_id,
        "canPublish" => permissions.can_publish,
        "canSubscribe" => permissions.can_subscribe
      }
    }
    Joken.generate_and_sign(claims, livekit_signer())
  end
end
```

### 2.4 RoomChannel

```elixir
defmodule EcallWeb.RoomChannel do
  use EcallWeb, :channel

  # События
  # room:join        — войти (broadcast всем: "user X вошёл")
  # room:leave       — выйти
  # room:heartbeat   — я ещё здесь
  # room:mute        — включить/выключить микрофон
  # room:video       — включить/выключить камеру
  # room:raise_hand  — поднять руку
  # room:kick        — кикнуть (только модератор)
  # room:members     — список присутствующих

  def join("room:" <> room_id, _payload, socket) do
    with true <- Ecall.Rooms.member?(room_id, socket.assigns.user_id),
         {:ok, session} <- Ecall.Rooms.join(room_id, socket.assigns.user_id) do
      broadcast!(socket, "room:user_joined", %{user_id: socket.assigns.user_id})
      {:ok, %{participants: Ecall.Rooms.active_participants(room_id)}, assign(socket, :room_id, room_id)}
    else
      false -> {:error, %{reason: "not_a_member"}}
      {:error, reason} -> {:error, %{reason: inspect(reason)}}
    end
  end
end
```

### 2.5 Роутер — новые эндпоинты

```elixir
scope "/api", EcallWeb do
  pipe_through [:api, :authenticated]

  # Комнаты
  resources "/rooms", RoomController, only: [:create, :show, :index, :delete]
  post "/rooms/:id/members", RoomController, :add_member
  delete "/rooms/:id/members/:user_id", RoomController, :remove_member
  get "/rooms/:id/join_token", RoomController, :join_token   # LiveKit JWT
  get "/rooms/:id/participants", RoomController, :participants
end
```

---

## Фаза 3 — Безопасность (параллельно с Фазой 2)

### 3.1 Security Headers
```elixir
# endpoint.ex — добавить plug
plug Plug.Head
plug :put_secure_browser_headers, %{
  "x-content-type-options" => "nosniff",
  "x-frame-options" => "DENY",
  "x-xss-protection" => "1; mode=block",
  "strict-transport-security" => "max-age=31536000; includeSubDomains"
}
```

### 3.2 Rate-limit по эндпоинту (не только по IP)
```elixir
# Разные лимиты для разных операций:
# /auth/login     — 5 попыток / минута (брутфорс-защита)
# /auth/register  — 3 раза / час
# /messages       — 60 / минута
# /calls          — 10 / минута
# /rooms          — 20 / минута

plug EcallWeb.RateLimitPlug, key: :login, scale: 60_000, limit: 5
```

### 3.3 Валидация входных данных (защита от инъекций)
```elixir
# Добавить максимальные длины везде:
defmodule Ecall.Rooms.Room do
  def changeset(room, attrs) do
    room
    |> cast(attrs, [:name, :type, :max_participants])
    |> validate_required([:name, :type])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_number(:max_participants, greater_than: 0, less_than_or_equal_to: 500)
    |> validate_inclusion(:type, ["voice", "video", "text"])
  end
end
```

### 3.4 Проверка прав в Room
```elixir
# Только owner/moderator может кикать
defp ensure_can_moderate(room_id, user_id) do
  case get_member_role(room_id, user_id) do
    role when role in [:owner, :moderator] -> :ok
    _ -> {:error, :forbidden}
  end
end
```

### 3.5 Аудит-лог критических действий
```elixir
# Логировать с user_id и IP:
Logger.info("room_kick", room_id: room_id, kicked_by: moderator_id,
            kicked_user: user_id, ip: conn.remote_ip)
```

---

## Фаза 4 — Полировка (2–3 дня)

### 4.1 Presence — онлайн-статус пользователей
`EcallWeb.Presence` уже подключён, но не используется:
```elixir
# user_channel.ex — при подключении:
EcallWeb.Presence.track(socket, socket.assigns.user_id, %{
  online_at: System.system_time(:second),
  status: "online"
})
```

### 4.2 Web Push для браузера/ПК
```elixir
# mix.exs
{:web_push_encryption, "~> 0.3"}

# Новые эндпоинты:
post "/users/:id/web_push_subscriptions", WebPushController, :create
delete "/users/:id/web_push_subscriptions/:sub_id", WebPushController, :delete
```

### 4.3 Структурированное логирование
```elixir
# Добавить request_id, user_id, call_id во все логи
Logger.metadata(request_id: conn.assigns[:request_id], user_id: user_id)
Logger.info("call_initiated", caller_id: caller_id, callee_id: callee_id)
```

### 4.4 Тесты на каналы и контроллеры
```elixir
# test/ecall_web/channels/room_channel_test.exs
defmodule EcallWeb.RoomChannelTest do
  use EcallWeb.ChannelCase

  test "join room as member" do
    {:ok, _, socket} = socket(EcallWeb.UserSocket, "user", %{user_id: "1"})
      |> subscribe_and_join(EcallWeb.RoomChannel, "room:#{room.id}")
    assert_broadcast "room:user_joined", %{user_id: "1"}
  end
end
```

---

## 📅 Итоговая дорожная карта

```
Неделя 1:  Фаза 0 (security фиксы) + Фаза 1 (производительность)
Неделя 2–3: Фаза 2 (комнаты) + Фаза 3 (безопасность параллельно)
Неделя 4:  Фаза 4 (полировка) + тесты + деплой
```

| Фаза | Приоритет | Сложность | Что даёт |
|---|---|---|---|
| 0 — Security фиксы | 🔴 Критично | Низкая | Закрывает дыры |
| 1 — Производительность | 🟠 Высокий | Средняя | Масштабируемость |
| 2 — Комнаты | 🟡 Средний | Высокая | Discord-фича |
| 3 — Безопасность | 🟠 Высокий | Средняя | Защита данных |
| 4 — Полировка | 🟢 Низкий | Низкая | Качество продукта |

---

> **Самое важное решение:** для групповых звонков нужен **SFU** (LiveKit / mediasoup).  
> Без него mesh-топология убьёт качество уже при 4+ участниках.  
> Это не опционально — это архитектурное требование.
