#!/usr/bin/env bash
set -euo pipefail

APP_USER="ec2-user"
HOME_DIR="/home/${APP_USER}"
APP_DIR="${HOME_DIR}/deploy"
PUBLISH_DIR="${APP_DIR}/publish"
DOTNET_DIR="${HOME_DIR}/.dotnet"
SERVICE_NAME="blazorapp"
PORT="7234"

export DOTNET_ROOT="${DOTNET_DIR}"
export PATH="${DOTNET_ROOT}:${DOTNET_ROOT}/tools:${PATH}"

echo "==> [deploy] Iniciando publish no ${APP_DIR}..."

# Encontra o .csproj (assume 1 projeto principal no diret�rio)
PROJECT_FILE="$(find "${APP_DIR}" -maxdepth 2 -name "*.csproj" | head -n 1 || true)"
if [ -z "${PROJECT_FILE}" ]; then
  echo "Arquivo .csproj n�o encontrado em ${APP_DIR}."
  exit 1
fi
APP_DLL="$(basename "${PROJECT_FILE}" .csproj).dll"

# Limpa/cria pasta de publish
rm -rf "${PUBLISH_DIR}"
mkdir -p "${PUBLISH_DIR}"

# Restaura e publica (framework-dependent)
echo "==> Restaurando pacotes..."
"${DOTNET_DIR}/dotnet" restore "${PROJECT_FILE}" --nologo

echo "==> Publicando em modo Release..."
"${DOTNET_DIR}/dotnet" publish "${PROJECT_FILE}" -c Release -o "${PUBLISH_DIR}" --nologo

# Ajusta permiss�es do publish
chown -R "${APP_USER}:${APP_USER}" "${PUBLISH_DIR}"

echo "==> Configurando servi�o systemd (${SERVICE_NAME}.service) para rodar na porta ${PORT}..."
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

# Cria/atualiza o unit file
sudo bash -c "cat > '${SERVICE_FILE}'" <<EOF
[Unit]
Description=Blazor Server (.NET 8) - ${SERVICE_NAME}
After=network.target

[Service]
User=${APP_USER}
WorkingDirectory=${PUBLISH_DIR}
# Vari�veis de ambiente para execu��o
Environment=DOTNET_ROOT=${DOTNET_DIR}
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=ASPNETCORE_URLS=http://0.0.0.0:${PORT}
# Garante que o bin�rio dotnet do usu�rio ser� usado
ExecStart=${DOTNET_DIR}/dotnet ${PUBLISH_DIR}/${APP_DLL}
Restart=always
RestartSec=5
KillSignal=SIGINT
SyslogIdentifier=${SERVICE_NAME}
# Evita problemas de cria��o de arquivos/logs
UMask=0022

[Install]
WantedBy=multi-user.target
EOF

# Aplica e (re)inicia o servi�o
sudo systemctl daemon-reload
sudo systemctl enable "${SERVICE_NAME}.service"
sudo systemctl restart "${SERVICE_NAME}.service"

echo "==> Aguardando o servi�o iniciar..."
sleep 3
sudo systemctl --no-pager --full status "${SERVICE_NAME}.service" || true

echo "==> [deploy] Publish e (re)start do servi�o conclu�dos."
echo "Artefatos em: ${PUBLISH_DIR}"
