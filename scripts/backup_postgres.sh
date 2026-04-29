#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="${BACKUP_DIR:-${ROOT_DIR}/backups/postgres}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"

cd "${ROOT_DIR}"

if [ -f ".env" ]; then
  set -a
  # shellcheck disable=SC1091
  . ".env"
  set +a
fi

POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_DB="${POSTGRES_DB:-ecall_prod}"

mkdir -p "${BACKUP_DIR}"

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup_file="${BACKUP_DIR}/ecall_${POSTGRES_DB}_${timestamp}.dump"

docker compose exec -T postgres pg_dump \
  -U "${POSTGRES_USER}" \
  -d "${POSTGRES_DB}" \
  -Fc \
  > "${backup_file}"

find "${BACKUP_DIR}" -type f -name "ecall_${POSTGRES_DB}_*.dump" -mtime "+${RETENTION_DAYS}" -delete

printf 'Created backup: %s\n' "${backup_file}"
