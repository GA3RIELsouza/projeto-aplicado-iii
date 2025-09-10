#!/usr/bin/env bash
set -euo pipefail

APP_USER="ec2-user"
HOME_DIR="/home/${APP_USER}"
APP_DIR="${HOME_DIR}/deploy"
PUBLISH_DIR="${APP_DIR}/publish"
SERVICE_NAME="blazorapp"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
PORT="7234"

# === Ambiente para NuGet/dotnet ===
export HOME="${HOME_DIR}"
export DOTNET_CLI_HOME="${HOME_DIR}"
export NUGET_PACKAGES="${HOME_DIR}/.nuget/packages"
install -d -m 0755 -o "${APP_USER}" -g "${APP_USER}" "${HOME_DIR}/.nuget" "${NUGET_PACKAGES}"

# Localiza dotnet
DOTNET_BIN="$(command -v dotnet || true)"
[ -z "${DOTNET_BIN}" ] && [ -x "${HOME_DIR}/.dotnet/dotnet" ] && DOTNET_BIN="${HOME_DIR}/.dotnet/dotnet"
[ -z "${DOTNET_BIN}" ] && [ -x "/root/.dotnet/dotnet" ] && DOTNET_BIN="/root/.dotnet/dotnet"
if [ -z "${DOTNET_BIN}" ]; then
  echo "ERRO: dotnet não encontrado. Verifique o pre-deploy."
  exit 1
fi
export DOTNET_ROOT="$(dirname "${DOTNET_BIN}")"
export PATH="${DOTNET_ROOT}:${DOTNET_ROOT}/tools:${PATH}"

echo "==> [deploy] Procurando .csproj em ${APP_DIR}..."
PROJECT_FILE="$(find "${APP_DIR}" -maxdepth 3 -name "*.csproj" | head -n 1 || true)"
if [ -z "${PROJECT_FILE}" ]; then
  echo "ERRO: .csproj não encontrado em ${APP_DIR}."
  exit 1
fi
APP_DLL="$(basename "${PROJECT_FILE}" .csproj).dll"
echo "==> Projeto: ${PROJECT_FILE}"

echo "==> Preparando pasta de publish..."
rm -rf "${PUBLISH_DIR}"
install -d -m 0755 -o "${APP_USER}" -g "${APP_USER}" "${PUBLISH_DIR}"

# Executa restore/publish como ec2-user (com HOME/NuGet corretos)
echo "==> dotnet --info (resumo)"
sudo -H -u "${APP_USER}" env HOME="${HOME_DIR}" DOTNET_CLI_HOME="${HOME_DIR}" NUGET_PACKAGES="${NUGET_PACKAGES}" PATH="${PATH}" "${DOTNET_BIN}" --info | sed -n '1,25p' || true

echo "==> dotnet restore..."
sudo -H -u "${APP_USER}" env HOME="${HOME_DIR}" DOTNET_CLI_HOME="${HOME_DIR}" NUGET_PACKAGES="${NUGET_PACKAGES}" PATH="${PATH}" \
  "${DOTNET_BIN}" restore "${PROJECT_FILE}" --nologo --verbosity minimal

echo "==> dotnet publish (Release)..."
sudo -H -u "${APP_USER}" env HOME="${HOME_DIR}" DOTNET_CLI_HOME="${HOME_DIR}" NUGET_PACKAGES="${NUGET_PACKAGES}" PATH="${PATH}" \
  "${DOTNET_BIN}" publish "${PROJECT_FILE}" -c Release -o "${PUBLISH_DIR}" --nologo

# Reconfere donos da pasta publicada
chown -R "${APP_USER}:${APP_USER}" "${PUBLISH_DIR}"

echo "==> Escrevendo unit ${SERVICE_FILE}..."
cat > "${SERVICE_FILE}" <<EOF
[Unit]
Description=Blazor Server (.NET 8) - ${SERVICE_NAME}
After=network.target

[Service]
User=${APP_USER}
WorkingDirectory=${PUBLISH_DIR}
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=ASPNETCORE_URLS=http://0.0.0.0:${PORT}
ExecStart=${DOTNET_BIN} ${PUBLISH_DIR}/${APP_DLL}
Restart=always
RestartSec=5
KillSignal=SIGINT
SyslogIdentifier=${SERVICE_NAME}
UMask=0022

[Install]
WantedBy=multi-user.target
EOF

echo "==> systemctl daemon-reload + enable + restart..."
systemctl daemon-reload
systemctl enable "${SERVICE_NAME}.service"
systemctl restart "${SERVICE_NAME}.service"

sleep 2
systemctl is-active --quiet "${SERVICE_NAME}.service" || {
  echo "ERRO: serviço não está ativo após restart."
  journalctl -u "${SERVICE_NAME}.service" -n 100 --no-pager || true
  exit 1
}
echo "==> [deploy] OK: ${SERVICE_NAME} ativo."
