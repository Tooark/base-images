#!/bin/sh
set -e

# ── Configuração automática de acesso ao socket do Docker ───────────────
# Quando um socket do Docker do host é montado no contêiner,
# ajuste o GID do grupo "docker" para corresponder ao grupo
# proprietário do socket.
# Isso permite que qualquer usuário no grupo "docker" (por exemplo, "app")
# se comunique com o daemon do Docker, independentemente do GID do host.
if [ "$(id -u)" = "0" ] && [ -S /var/run/docker.sock ]; then
  SOCK_GID=$(stat -c '%g' /var/run/docker.sock)
  if [ "$SOCK_GID" != "0" ]; then
    CUR_GID=$(getent group docker 2>/dev/null | cut -d: -f3 || echo "")
    if [ -n "$CUR_GID" ] && [ "$SOCK_GID" != "$CUR_GID" ]; then
      sed -i "s/^docker:x:${CUR_GID}:/docker:x:${SOCK_GID}:/" /etc/group
    fi
  fi
fi

exec "$@"
