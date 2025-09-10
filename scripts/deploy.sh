#!/usr/bin/env bash
set -euo pipefail

# === Configuração básica ===
APP_USER="ec2-user"
HOME_DIR="/home/${APP_USER}"
APP_DIR="${HOME_DIR}/deploy"
PUBLISH_DIR="${APP_DIR}/publish"
SERVICE_NAME="blazorapp"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
PORT="7234"

# === Ambiente para NuGet/dotnet (permanente) ===
export HOME="${HOME_DIR}"
export DOTNET_CLI_HOME="${HOME_DIR}"
export NUGET_PACKAGES="${HOME_DIR}/.nuget/packages"

# Garante diretórios e permissões corretas para o ec2-user
install -d -m 0755 -o "${APP_USER}" -g "${APP_USER}" \
  "${HOME_DIR}/.nuget" "${HOME_DIR}/.nuget/NuGet" "${NUGET_PACKAGES}"

# Se existir .nuget com dono errado, corrige
chown -R "${APP_USER}:${APP_USER}" "${HOME_DIR}/.nuget"
chmod -R u+rwX,go+rX "${HOME_DIR}/.nuget"

# Cria um NuGet.Config mínimo se não existir (evita erro de acesso/ausência)
if [ ! -f "${HOME_DIR}/.nuget/NuGet/NuGet.Config" ]; then
  cat > "${HOME_DIR}/.nuget/NuGet/NuGet.Config" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
  </packageSources>
</configuration>
EOF
  chown "${APP_USER}:${APP_USER}" "${HOME_DIR}/.nuget/NuGet/NuGet.Config"
  chmod 0644 "${HOME_DIR}/.nuget/NuGet/NuGet.Config"
fi

# === Localiza o dotnet ===
DOTNET_BIN="$(command -v dotnet || true)"
[ -z "${DOTNET_BIN}" ] && [ -x "${HOME_DIR}/.dotnet/dotnet" ] && DOTNET_BIN="${HOME_DIR}/.dotnet/dotnet"
[ -z "${DOTNET_BIN}" ] && [ -x "/root/.dotnet/dotnet" ] && DOTNET_BIN="/root/.dotnet/dotnet"
if [ -z "${DOTNET_BIN}" ]; then
  echo "ERRO: dotnet não encontrado. Verifique o pre-deploy (instalação do .NET 8 SDK)."
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

echo "==> Preparando pasta de publish em ${PUBLISH_DIR}..."
rm -rf "${PUBLISH_DIR}"
install -d -m 0755 -o "${APP_USER}" -g "${APP_USER}" "${PUBLISH_DIR}"

echo "==> dotnet --info (resumo)"
sudo -H -u "${APP_USER}" env \
  HOME="${HOME_DIR}" DOTNET_CLI_HOME="${HOME_DIR}" NUGET_PACKAGES="${NUGET_PACKAGES}" PATH="${PATH}" \
  "${DOTNET_BIN}" --info | sed -n '1,25p' || true

echo "==> dotnet restore..."
sudo -H -u "${APP_USER}" env \
  HOME="${HOME_DIR}" DOTNET_CLI_HOME="${HOME_DIR}" NUGET_PACKAGES="${NUGET_PACKAGES}" PATH="${PATH}" \
  "${DOTNET_BIN}" restore "${PROJECT_FILE}" --nologo --verbosity minimal

echo "==> dotnet publish (Release)..."
sudo -H -u "${APP_USER}" env \
  HOME="${HOME_DIR}" DOTNET_CLI_HOME="${HOME_DIR}" NUGET_PACKAGES="${NUGET_PACKAGES}" PATH="${PATH}" \
  "${DOTNET_BIN}" publish "${PROJECT_FILE}" -c Release -o "${PUBLISH_DIR}" --nologo

# Garante ownership correto do publish
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
# Usa o caminho absoluto do dotnet detectado
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
systemctl restart "${SERVICE_NAME}.service" || {
  echo "ERRO ao iniciar o serviço. Últimos logs:"
  journalctl -u "${SERVICE_NAME}.service" -n 100 --no-pager || true
  exit 1
}

sleep 2
if ! systemctl is-active --quiet "${SERVICE_NAME}.service"; then
  echo "ERRO: serviço não está ativo após restart."
  journalctl -u "${SERVICE_NAME}.service" -n 100 --no-pager || true
  exit 1
fi

echo "==> [deploy] OK: ${SERVICE_NAME} ativo em http://0.0.0.0:${PORT}"
