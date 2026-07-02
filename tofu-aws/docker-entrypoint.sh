#!/bin/sh
set -eu

# docker-entrypoint.sh
# 1) Se existir docker.sock e o processo estiver como root, sincroniza o grupo do socket.
# 2) Opcionalmente prefixa um comando padrão via ARK_ENTRYPOINT_CMD.
# 3) Se estiver como root, faz drop de privilégio para ARK_RUNTIME_USER (default: app) usando gosu.

RUNTIME_USER="${ARK_RUNTIME_USER:-app}"
DOCKER_SOCKET="${ARK_DOCKER_SOCKET_PATH:-/var/run/docker.sock}"

if [ "$(id -u)" = "0" ] && [ -S "$DOCKER_SOCKET" ]; then
  SOCK_GID="$(stat -c '%g' "$DOCKER_SOCKET")"

  if [ "$SOCK_GID" != "0" ] && id "$RUNTIME_USER" >/dev/null 2>&1; then
    SOCK_GROUP="$(getent group "$SOCK_GID" 2>/dev/null | cut -d: -f1 || true)"

    if [ -z "$SOCK_GROUP" ]; then
      SOCK_GROUP="docker-host"

      if getent group "$SOCK_GROUP" >/dev/null 2>&1; then
        SOCK_GROUP="docker-host-$SOCK_GID"
      fi

      groupadd -g "$SOCK_GID" "$SOCK_GROUP"
    fi

    if ! id -nG "$RUNTIME_USER" | tr ' ' '\n' | grep -Fx "$SOCK_GROUP" >/dev/null 2>&1; then
      usermod -aG "$SOCK_GROUP" "$RUNTIME_USER"
    fi
  fi
fi

if [ -n "${ARK_ENTRYPOINT_CMD:-}" ]; then
  set -- "$ARK_ENTRYPOINT_CMD" "$@"
fi

if [ "$(id -u)" = "0" ] && id "$RUNTIME_USER" >/dev/null 2>&1; then
  if command -v gosu >/dev/null 2>&1; then
    exec gosu "$RUNTIME_USER" "$@"
  fi

  echo "[entrypoint] error: container started as root but 'gosu' is not installed." >&2
  exit 127
fi

exec "$@"
