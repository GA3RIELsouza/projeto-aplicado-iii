#!/usr/bin/env bash
set -euo pipefail

APP_USER="ec2-user"
HOME_DIR="/home/${APP_USER}"
DOTNET_DIR="${HOME_DIR}/.dotnet"

echo "==> [pre-deploy] Verificando pré-requisitos e .NET 8 SDK..."

# Garante curl (se não houver)
if ! command -v curl >/dev/null 2>&1; then
  echo "curl não encontrado. Instalando..."
  if command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y curl
  elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y curl
  elif command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -y && sudo apt-get install -y curl
  else
    echo "Gerenciador de pacotes não reconhecido. Instale o curl manualmente."
    exit 1
  fi
fi

# Exporta para a sessão atual
export DOTNET_ROOT="${DOTNET_DIR}"
export PATH="${DOTNET_ROOT}:${DOTNET_ROOT}/tools:${PATH}"

# Função: tem SDK 8.x?
has_sdk8() {
  command -v dotnet >/dev/null 2>&1 && dotnet --list-sdks 2>/dev/null | awk '{print $1}' | grep -qE '^8\.'
}

if has_sdk8; then
  echo "==> .NET 8 SDK já presente:"
  dotnet --list-sdks || true
else
  echo "==> .NET 8 SDK não encontrado. Instalando no ${DOTNET_DIR}..."
  tmp_script="$(mktemp)"
  curl -fsSL https://dot.net/v1/dotnet-install.sh -o "${tmp_script}"
  chmod +x "${tmp_script}"
  # Canal 8.0 instala a linha LTS do .NET 8
  "${tmp_script}" --channel 8.0 --install-dir "${DOTNET_DIR}"
  rm -f "${tmp_script}"

  # Verifica
  if ! "${DOTNET_DIR}/dotnet" --list-sdks | awk '{print $1}' | grep -qE '^8\.'; then
    echo "Falha ao instalar .NET 8 SDK."
    exit 1
  fi

  echo "==> .NET 8 SDK instalado com sucesso."
fi

# Torna PATH/DOTNET_ROOT persistentes para futuras sessões e serviços
PROFILE_SNIPPET=$'# added by pre-deploy.sh\nexport DOTNET_ROOT="$HOME/.dotnet"\nexport PATH="$DOTNET_ROOT:$DOTNET_ROOT/tools:$PATH"\n'
if ! grep -q 'export DOTNET_ROOT="$HOME/.dotnet"' "${HOME_DIR}/.bashrc" 2>/dev/null; then
  echo "${PROFILE_SNIPPET}" >> "${HOME_DIR}/.bashrc"
  chown "${APP_USER}:${APP_USER}" "${HOME_DIR}/.bashrc" || true
fi

# Também adiciona um perfil global (se possível) para systemd
if [ -w /etc/profile.d ] || sudo -n true 2>/dev/null; then
  sudo bash -c "cat >/etc/profile.d/dotnet_path.sh" <<'EOF'
# added by pre-deploy.sh
if [ -d /home/ec2-user/.dotnet ]; then
  export DOTNET_ROOT="/home/ec2-user/.dotnet"
  export PATH="$DOTNET_ROOT:$DOTNET_ROOT/tools:$PATH"
fi
EOF
  sudo chmod 644 /etc/profile.d/dotnet_path.sh
fi

echo "==> dotnet --info (resumo):"
"${DOTNET_DIR}/dotnet" --info | sed -n '1,25p' || true

echo "==> [pre-deploy] OK."
