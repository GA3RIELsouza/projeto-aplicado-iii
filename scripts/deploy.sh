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

# === Pastas de estado do servidor (persistem entre deploys) ===
SERVER_STATE="${APP_DIR}/.server_state"
SERVER_DB="${SERVER_STATE}/sqlite.db"
SERVER_MIGRATIONS="${SERVER_STATE}/Migrations"
SERVER_SQL="${SERVER_STATE}/ef_migrate.sql"
install -d -m 0755 -o "${APP_USER}" -g "${APP_USER}" "${SERVER_STATE}"

# === Ambiente para NuGet/dotnet (permanente) ===
export HOME="${HOME_DIR}"
export DOTNET_CLI_HOME="${HOME_DIR}"
export NUGET_PACKAGES="${HOME_DIR}/.nuget/packages"
install -d -m 0755 -o "${APP_USER}" -g "${APP_USER}" \
  "${HOME_DIR}/.nuget" "${HOME_DIR}/.nuget/NuGet" "${NUGET_PACKAGES}"
chown -R "${APP_USER}:${APP_USER}" "${HOME_DIR}/.nuget"
chmod -R u+rwX,go+rX "${HOME_DIR}/.nuget"
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
export PATH="${DOTNET_ROOT}:${DOTNET_ROOT}/tools:${HOME_DIR}/.dotnet/tools:${PATH}"

# === Dependências do host ===
# sqlite3 CLI (para aplicar o script idempotente)
if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "==> Instalando sqlite3..."
  if command -v dnf >/dev/null 2>&1; then
    dnf install -y sqlite
  elif command -v yum >/dev/null 2>&1; then
    yum install -y sqlite
  elif command -v apt-get >/dev/null 2>&1; then
    apt-get update -y && apt-get install -y sqlite3
  else
    echo "ERRO: não foi possível instalar sqlite3 (gerenciador não reconhecido)."
    exit 1
  fi
fi

# Para o serviço para evitar lock do DB
if command -v systemctl >/dev/null 2>&1; then
  systemctl stop "${SERVICE_NAME}.service" || true
fi

echo "==> [deploy] Procurando .csproj em ${APP_DIR}..."
PROJECT_FILE="$(find "${APP_DIR}" -maxdepth 3 -name "*.csproj" | head -n 1 || true)"
if [ -z "${PROJECT_FILE}" ]; then
  echo "ERRO: .csproj não encontrado em ${APP_DIR}."
  exit 1
fi
APP_DLL="$(basename "${PROJECT_FILE}" .csproj).dll"
echo "==> Projeto: ${PROJECT_FILE}"

# === Preserva o sqlite.db antes de limpar o publish ===
LIVE_DB="${PUBLISH_DIR}/sqlite.db"
if [ -f "${LIVE_DB}" ]; then
  echo "==> Preservando banco: movendo ${LIVE_DB} -> ${SERVER_DB}"
  mv -f "${LIVE_DB}" "${SERVER_DB}"
fi

echo "==> Preparando pasta de publish em ${PUBLISH_DIR}..."
rm -rf "${PUBLISH_DIR}"
install -d -m 0755 -o "${APP_USER}" -g "${APP_USER}" "${PUBLISH_DIR}"

echo "==> dotnet --info (resumo)"
sudo -H -u "${APP_USER}" env \
  HOME="${HOME_DIR}" DOTNET_CLI_HOME="${HOME_DIR}" NUGET_PACKAGES="${NUGET_PACKAGES}" PATH="${PATH}" \
  "${DOTNET_BIN}" --info | sed -n '1,25p' || true

# === Garante dotnet-ef instalado para o ec2-user ===
if ! sudo -H -u "${APP_USER}" env PATH="${PATH}" "${DOTNET_BIN}" tool list -g | grep -q 'dotnet-ef'; then
  echo "==> Instalando dotnet-ef (global) para ${APP_USER}..."
  sudo -H -u "${APP_USER}" env PATH="${PATH}" "${DOTNET_BIN}" tool install --global dotnet-ef
fi

# === Gera/atualiza migrations no servidor (persistem em .server_state) ===
install -d -m 0755 -o "${APP_USER}" -g "${APP_USER}" "${SERVER_MIGRATIONS}"
MIG_NAME="DeployAuto_$(date +%Y%m%d_%H%M%S)"
echo "==> dotnet ef migrations add ${MIG_NAME} (saída em ${SERVER_MIGRATIONS})"
# Se não houver mudanças, o EF apenas informa e retorna 0
sudo -H -u "${APP_USER}" env \
  HOME="${HOME_DIR}" DOTNET_CLI_HOME="${HOME_DIR}" NUGET_PACKAGES="${NUGET_PACKAGES}" PATH="${PATH}" \
  "${DOTNET_BIN}" ef migrations add "${MIG_NAME}" \
    --project "${APP_DIR}" --startup-project "${APP_DIR}" -o ".server_state/Migrations" || true

echo "==> dotnet restore..."
sudo -H -u "${APP_USER}" env \
  HOME="${HOME_DIR}" DOTNET_CLI_HOME="${HOME_DIR}" NUGET_PACKAGES="${NUGET_PACKAGES}" PATH="${PATH}" \
  "${DOTNET_BIN}" restore "${PROJECT_FILE}" --nologo --verbosity minimal

echo "==> dotnet publish (Release)..."
sudo -H -u "${APP_USER}" env \
  HOME="${HOME_DIR}" DOTNET_CLI_HOME="${HOME_DIR}" NUGET_PACKAGES="${NUGET_PACKAGES}" PATH="${PATH}" \
  "${DOTNET_BIN}" publish "${PROJECT_FILE}" -c Release -o "${PUBLISH_DIR}" --nologo

# === Restaura o sqlite.db preservado para a pasta publicada ===
if [ -f "${SERVER_DB}" ]; then
  echo "==> Restaurando banco: movendo ${SERVER_DB} -> ${LIVE_DB}"
  mv -f "${SERVER_DB}" "${LIVE_DB}"
  chown "${APP_USER}:${APP_USER}" "${LIVE_DB}"
fi

# === Gera script idempotente e aplica no sqlite.db publicado ===
echo "==> dotnet ef migrations script --idempotent"
sudo -H -u "${APP_USER}" env \
  HOME="${HOME_DIR}" DOTNET_CLI_HOME="${HOME_DIR}" NUGET_PACKAGES="${NUGET_PACKAGES}" PATH="${PATH}" \
  "${DOTNET_BIN}" ef migrations script --idempotent \
    --project "${APP_DIR}" --startup-project "${APP_DIR}" -o "${SERVER_SQL}"

# Se o DB ainda não existir, será criado ao aplicar o script
echo "==> Aplicando migrations no ${LIVE_DB} (sqlite3)"
sqlite3 "${LIVE_DB}" < "${SERVER_SQL}"

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
