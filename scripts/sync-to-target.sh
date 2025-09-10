#!/usr/bin/env bash
set -euo pipefail

APP_USER="ec2-user"
TARGET="/home/${APP_USER}/deploy"

echo "==> [sync] Copiando artefato para ${TARGET} ..."
mkdir -p "${TARGET}"

# estamos rodando a partir da raiz do artefato extra�do em /tmp/codepipeline/<exec>/
# copia tudo, preservando estrutura, exceto a pr�pria pasta temp do pipeline.
rsync -a --delete ./ "${TARGET}/"

# garante que os scripts s�o execut�veis
chmod +x "${TARGET}/scripts/"*.sh || true

# ownership para o ec2-user (c�digo e scripts)
chown -R "${APP_USER}:${APP_USER}" "${TARGET}"

echo "==> [sync] OK."
