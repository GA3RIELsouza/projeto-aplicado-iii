#!/usr/bin/env bash
set -euo pipefail

APP_USER="ec2-user"
HOME_DIR="/home/${APP_USER}"
APP_DIR="${HOME_DIR}/deploy"
PUBLISH_DIR="${APP_DIR}/publish"
DOTNET_DIR="${HOME_DIR}/.dotnet"
SERVICE_NAME="blazorapp"
PORT="7234"

# Localiza dotnet onde quer que esteja
DOTNET_BIN="$(command -v dotnet || true)"
[ -z "${DOTNET_BIN}" ] && [ -x "/home/ec2-user/.dotnet/dotnet" ] && DOTNET_BIN="/home/ec2-user/.dotnet/dotnet"
[ -z "${DOTNET_BIN}" ] && [ -x "/root/.dotnet/dotnet" ] && DOTNET_BIN="/root/.dotnet/dotnet"

if [ -z "${DOTNET_BIN}" ]; then
  echo "ERRO: dotnet não encontrado. Verifique o hook BeforeInstall (pre-deploy.sh)."
  exit 1
fi

# Exporte PATH/ROOT apenas para consistência (opcional)
export DOTNET_ROOT="$(dirname "${DOTNET_BIN}")"
export PATH="${DOTNET_ROOT}:${DOTNET_ROOT}/tools:${PATH}"

echo "==> [deploy] Iniciando publish no ${APP_DIR}..."

# Encontra o .csproj (assume 1 projeto principal no diretório)
PROJECT_FILE="$(find "${APP_DIR}" -maxdepth 2 -name "*.csproj" | head -n 1 || true)"
if [ -z "${PROJECT_FILE}" ]; then
  echo "Arquivo .csproj não encontrado em ${APP_DIR}."
  exit 1
fi
APP_DLL="$(basename "${PROJECT_FILE}" .csproj).dll"

# Limpa/cria pasta de publish
rm -rf "${PUBLISH_DIR}"
mkdir -p "${PUBLISH_DIR}"

# Restaura e publica (framework-dependent)
echo "==> Restaurando pacotes..."
"${DOTNET_BIN}" restore "${PROJECT_FILE}" --nologo

echo "==> Publicando em modo Release..."
"${DOTNET_BIN}" publish "${PROJECT_FILE}" -c Release -o "${PUBLISH_DIR}" --nologo

# Ajusta permissões do publish
chown -R "${APP_USER}:${APP_USER}" "${PUBLISH_DIR}"

echo "==> Configurando serviço systemd (${SERVICE_NAME}.service) para rodar na porta ${PORT}..."
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

# Cria/atualiza o unit file
sudo bash -c "cat > '${SERVICE_FILE}'" <<EOF
[Unit]
Description=Blazor Server (.NET 8) - ${SERVICE_NAME}
After=network.target

[Service]
User=${APP_USER}
WorkingDirectory=${PUBLISH_DIR}
# Variáveis de ambiente para execução
Environment=DOTNET_ROOT=${DOTNET_DIR}
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=ASPNETCORE_URLS=http://0.0.0.0:${PORT}
# Garante que o binário dotnet do usuário será usado
ExecStart=${DOTNET_BIN} ${PUBLISH_DIR}/${APP_DLL}
Restart=always
RestartSec=5
KillSignal=SIGINT
SyslogIdentifier=${SERVICE_NAME}
# Evita problemas de criação de arquivos/logs
UMask=0022

[Install]
WantedBy=multi-user.target
EOF

# Aplica e (re)inicia o serviço
sudo systemctl daemon-reload
sudo systemctl enable "${SERVICE_NAME}.service"
sudo systemctl restart "${SERVICE_NAME}.service"

echo "==> Aguardando o serviço iniciar..."
sleep 3
sudo systemctl --no-pager --full status "${SERVICE_NAME}.service" || true

echo "==> [deploy] Publish e (re)start do serviço concluídos."
echo "Artefatos em: ${PUBLISH_DIR}"
