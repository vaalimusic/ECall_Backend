#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/vaalimusic/ECall_Backend.git}"
INSTALL_DIR="${INSTALL_DIR:-/opt/ecall-backend}"
DOMAIN="${DOMAIN:-ecall.everty.ru}"
BRANCH="${BRANCH:-main}"

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo bash scripts/install_ubuntu.sh"
  exit 1
fi

log() {
  printf "\n[%s] %s\n" "$(date +%H:%M:%S)" "$*"
}

random_secret() {
  openssl rand -hex 48
}

install_docker() {
  apt-get update
  apt-get install -y ca-certificates curl gnupg git openssl

  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    log "Docker is already installed"
    return
  fi

  log "Installing Docker Engine and Compose plugin"
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  . /etc/os-release
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list

  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
}

fetch_repo() {
  log "Fetching repository into ${INSTALL_DIR}"
  if [ -d "${INSTALL_DIR}/.git" ]; then
    git -C "${INSTALL_DIR}" fetch origin
    git -C "${INSTALL_DIR}" checkout "${BRANCH}"
    git -C "${INSTALL_DIR}" pull --ff-only origin "${BRANCH}"
  else
    mkdir -p "$(dirname "${INSTALL_DIR}")"
    git clone --branch "${BRANCH}" "${REPO_URL}" "${INSTALL_DIR}"
  fi
}

write_env() {
  local env_file="${INSTALL_DIR}/.env"

  if [ -f "${env_file}" ]; then
    log ".env already exists, keeping current secrets"
    return
  fi

  log "Creating ${env_file}"
  cat > "${env_file}" <<EOF_ENV
POSTGRES_USER=postgres
POSTGRES_PASSWORD=$(random_secret)
POSTGRES_DB=ecall_prod
SECRET_KEY_BASE=$(random_secret)$(random_secret)
JWT_SECRET=$(random_secret)
PHX_HOST=${DOMAIN}
PORT=4000
TURN_USER=ecall
TURN_PASSWORD=$(random_secret)
FCM_PROJECT_ID=
FCM_ACCESS_TOKEN=
ALLOW_INSECURE_SOCKET_AUTH=false
EOF_ENV
  chmod 600 "${env_file}"
}

write_caddy_config() {
  log "Writing Caddy config for ${DOMAIN}"
  mkdir -p "${INSTALL_DIR}/deploy/caddy"
  cat > "${INSTALL_DIR}/deploy/caddy/Caddyfile" <<EOF_CADDY
${DOMAIN} {
  encode gzip

  reverse_proxy app:4000 {
    header_up Host {host}
    header_up X-Real-IP {remote_host}
    header_up X-Forwarded-For {remote_host}
    header_up X-Forwarded-Proto {scheme}
  }
}
EOF_CADDY
}

open_firewall_ports() {
  if command -v ufw >/dev/null 2>&1; then
    log "Opening UFW ports"
    ufw allow 80/tcp || true
    ufw allow 443/tcp || true
    ufw allow 3478/tcp || true
    ufw allow 3478/udp || true
    ufw allow 49160:49200/udp || true
  fi
}

start_stack() {
  log "Building and starting services"
  cd "${INSTALL_DIR}"
  docker compose up -d --build

  log "Running database migrations"
  docker compose exec -T app /app/bin/ecall eval "Ecall.Release.migrate()"

  log "Health check"
  for _ in $(seq 1 30); do
    if curl -fsS "http://127.0.0.1/api/health" >/dev/null; then
      log "Installed successfully: https://${DOMAIN}/api/health"
      return
    fi
    sleep 2
  done

  echo "Services started, but health check did not pass yet. Check: docker compose logs -f app"
}

install_docker
fetch_repo
write_env
write_caddy_config
open_firewall_ports
start_stack
