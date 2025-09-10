#!/usr/bin/env bash
set -euo pipefail

APP_USER="ec2-user"
TARGET="/home/${APP_USER}/deploy"

echo "==> [sync] Copiando artefato para ${TARGET} ..."
mkdir -p "${TARGET}"

# Preserva .server_state/ (migrations/estado) e TAMBÉM a pasta publish/ inteira (inclui sqlite.db)
rsync -a --delete \
  --exclude '.server_state/' \
  --exclude 'publish/' \
  ./ "${TARGET}/"

# Garante que os scripts são executáveis
chmod +x "${TARGET}/scripts/"*.sh || true

# Ownership para o ec2-user
chown -R "${APP_USER}:${APP_USER}" "${TARGET}"

echo "==> [sync] OK."
