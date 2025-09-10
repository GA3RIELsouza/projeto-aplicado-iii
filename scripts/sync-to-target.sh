#!/usr/bin/env bash
set -euo pipefail

APP_USER="ec2-user"
TARGET="/home/${APP_USER}/deploy"

echo "==> [sync] Copiando artefato para ${TARGET} ..."
mkdir -p "${TARGET}"

# Importante:
# - '/publish/' e '/.server_state/' ANCORADOS ao topo do artefato
# - Ignora 'bin/' e 'obj/' (evita "cannot delete non-empty directory")
rsync -a --delete \
  --exclude='/.server_state/' \
  --exclude='/publish/' \
  --exclude='/bin/' \
  --exclude='/obj/' \
  ./ "${TARGET}/"

# Permissões e execução dos scripts
chmod +x "${TARGET}/scripts/"*.sh || true
chown -R "${APP_USER}:${APP_USER}" "${TARGET}"

echo "==> [sync] OK."
