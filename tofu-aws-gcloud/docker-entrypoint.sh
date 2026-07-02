#!/bin/sh
set -eu

# docker-entrypoint.sh
# 1) Se existir docker.sock e o processo estiver como root, sincroniza o grupo do socket.
# 2) Opcionalmente prefixa um comando padrão via ARK_ENTRYPOINT_CMD.
# 3) Se estiver como root, faz drop de privilégio para ARK_RUNTIME_USER (default: app) usando gosu.

RUNTIME_USER="${ARK_RUNTIME_USER:-app}"
DOCKER_SOCKET="${ARK_DOCKER_SOCKET_PATH:-/var/run/docker.sock}"

# Ajusta acesso ao docker.sock para o usuário de runtime sem hardcode de GID.
if [ "$(id -u)" = "0" ] && [ -S "$DOCKER_SOCKET" ]; then
  SOCK_GID="$(stat -c '%g' "$DOCKER_SOCKET")"

  # GID 0 já é root; não há ajuste necessário.
  if [ "$SOCK_GID" != "0" ] && id "$RUNTIME_USER" >/dev/null 2>&1; then
    SOCK_GROUP="$(getent group "$SOCK_GID" 2>/dev/null | cut -d: -f1 || true)"

    # Se não houver grupo com esse GID, cria um grupo dedicado para o socket.
    if [ -z "$SOCK_GROUP" ]; then
      SOCK_GROUP="docker-host"

      # Evita conflito de nome caso "docker-host" já exista, adicionando o GID ao nome do grupo.
      if getent group "$SOCK_GROUP" >/dev/null 2>&1; then
        SOCK_GROUP="docker-host-$SOCK_GID"
      fi

      groupadd -g "$SOCK_GID" "$SOCK_GROUP"
    fi

    # Garante que o usuário de runtime pertença ao grupo dono do socket.
    if ! id -nG "$RUNTIME_USER" | tr ' ' '\n' | grep -Fx "$SOCK_GROUP" >/dev/null 2>&1; then
      usermod -aG "$SOCK_GROUP" "$RUNTIME_USER"
    fi
  fi
fi

# Permite fixar um binário padrão no entrypoint (ex.: ARK_ENTRYPOINT_CMD=/usr/local/bin/ark-tools).
if [ -n "${ARK_ENTRYPOINT_CMD:-}" ]; then
  set -- "$ARK_ENTRYPOINT_CMD" "$@"
fi

# Se iniciado como root, exige gosu para executar como usuário menos privilegiado.
if [ "$(id -u)" = "0" ] && id "$RUNTIME_USER" >/dev/null 2>&1; then
  # Verifica se gosu está disponível para fazer drop de privilégio.
  if command -v gosu >/dev/null 2>&1; then
    exec gosu "$RUNTIME_USER" "$@"
  fi

  echo "[entrypoint] error: container started as root but 'gosu' is not installed." >&2
  exit 127
fi

exec "$@"
