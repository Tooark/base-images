#!/bin/sh
set -e

# ── Auto-configure Docker socket access ──────────────────────────
# When a host Docker socket is bind-mounted into the container,
# adjust the "docker" group GID to match the socket's owning group.
# This allows any user in the "docker" group (e.g. "app") to
# communicate with the Docker daemon regardless of the host GID.
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
