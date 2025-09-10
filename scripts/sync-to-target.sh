#!/usr/bin/env bash
set -euo pipefail

APP_USER="ec2-user"
TARGET="/home/${APP_USER}/deploy"

echo "==> [sync] Copiando artefato para ${TARGET} ..."
mkdir -p "${TARGET}"

# Preserva .server_state/ (migrations do servidor) e o sqlite.db publicado
rsync -a --delete \
  --exclude '.server_state/' \
  --exclude 'publish/sqlite.db' \
  ./ "${TARGET}/"

# garante que os scripts s�o execut�veis
chmod +x "${TARGET}/scripts/"*.sh || true

# ownership para o ec2-user (c�digo e scripts)
chown -R "${APP_USER}:${APP_USER}" "${TARGET}"

echo "==> [sync] OK."
