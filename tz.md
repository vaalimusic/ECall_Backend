🚀 Техническое задание (расширенная версия)
Backend-сервис голосовых, видеовызовов и сообщений

Домен: ecall.everty.ru
ОС: Ubuntu 22.04 LTS

1. 🎯 Цель проекта

Разработать высоконагруженный backend-сервис реального времени для:

аудио- и видеозвонков (1:1 и групповые),
обмена сообщениями,
управления присутствием пользователей.

Сервис должен обеспечивать:

минимальную задержку,
горизонтальное масштабирование,
отказоустойчивость,
безопасную передачу данных.
2. 🧱 Архитектура системы
2.1 Общая схема

Сервис делится на несколько компонентов:

Signaling Server (Phoenix Channels)
Управляет установлением соединений (WebRTC signaling).
Media Layer
P2P (по умолчанию)
SFU (для групповых вызовов через Membrane)
Presence Service
Отслеживание статусов пользователей
Notification Service
Push-уведомления (FCM)
Messaging Service
Обмен текстовыми сообщениями (через WebSockets + fallback REST)
Storage Layer
PostgreSQL (персистентные данные)
Redis / Mnesia (временные состояния)
3. 🧰 Технологический стек
Язык: Elixir (BEAM)
Фреймворк: Phoenix Framework
Реалтайм: WebSockets (Phoenix Channels)
Медиа: WebRTC
SFU: Membrane Framework
БД: PostgreSQL
In-memory: Redis или Mnesia
NAT traversal: CoTURN
Push: Firebase Cloud Messaging
4. 🔑 Функциональные требования
4.1 Signaling (управление звонками)

Поддержка событий:

call:initiate
call:ringing
call:accept
call:reject
call:busy
call:end
call:timeout

Передача:

SDP offer/answer
ICE candidates

Дополнительно:

Retry логика
Таймауты (например, 30 сек на ответ)
4.2 Presence (онлайн-статус)

Использовать Phoenix Presence:

online / offline
last_seen
multi-device поддержка
4.3 Push-уведомления

Условия отправки:

пользователь offline
сокет не активен > N секунд

Типы push:

входящий звонок
пропущенный звонок
новое сообщение
4.4 📞 Аудио/видеозвонки

Поддержка:

1:1 calls (P2P)
групповая связь (SFU)

Функции:

mute/unmute
включение/выключение видео
переключение камеры
адаптация качества (bandwidth adaptation)
4.5 💬 Сообщения (Messaging)

Типы сообщений:

текст
служебные (call started, missed call и т.д.)

Функционал:

отправка/получение в реальном времени
доставка (delivered)
прочитано (read)
история сообщений
4.6 📊 История звонков

Хранить:

caller_id
callee_id
duration
статус
тип (audio/video)
5. 🔄 Workflow (расширенный)
Исходящий звонок:
Клиент A → call:initiate
Сервер:
проверяет Presence
если online → WebSocket
если offline → FCM
Клиент B:
call:ringing
отвечает accept/reject
Сервер:
начинает relay SDP + ICE
Устанавливается WebRTC
6. 🔐 Безопасность
WSS (TLS)
JWT (access + refresh)
Rate limiting
Защита от:
replay атак
spoofing
TURN с аутентификацией (short-term credentials)
7. 📦 API (пример событий)
WebSocket Channels:
user:{id}
call:{call_id}
Пример payload:
{
  "type": "call:initiate",
  "to": "user_id",
  "media": "video"
}
8. 📈 Масштабирование
Erlang Cluster (multi-node)
Horizontal scaling
Sticky sessions (для WebSockets)
Redis Pub/Sub для синхронизации
9. ⚙️ Инфраструктура
Docker + Docker Compose
Reverse proxy: Nginx
SSL: Let's Encrypt
CI/CD:
build → test → deploy
10. 📊 Метрики и мониторинг
Prometheus + Grafana
Метрики:
latency signaling (<100ms)
call setup time
packet loss
jitter
concurrent users
11. 🧪 Тестирование
Unit tests
Load testing (k6)
Chaos testing
12. 📚 Документация (ОБЯЗАТЕЛЬНО)

Должно быть:

12.1 Backend docs
архитектура
API (WebSocket + REST)
схема БД
event flow
12.2 Клиентская интеграция
как подключаться к WebSocket
как работать с WebRTC
примеры SDP/ICE
12.3 DevOps
как развернуть (Ubuntu, Docker)
scaling guide
13. 🚀 KPI
≤ 100ms signaling latency
≥ 10k connections/node
uptime ≥ 99.9%
восстановление после падения < 5 сек
14. 🔮 Roadmap (после MVP)
запись звонков
screen sharing
end-to-end encryption
AI шумоподавление
analytics