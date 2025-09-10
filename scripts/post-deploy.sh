#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="blazorapp"
PORT="7234"

echo "==> [post-deploy] Verificando serviço e porta ${PORT}..."

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

# Se existir systemd, checa estado (tentando iniciar se não ativo)
if command -v systemctl >/dev/null 2>&1; then
  if ! systemctl is-active --quiet "${SERVICE_NAME}.service"; then
    echo "Serviço ${SERVICE_NAME} não está ativo. Tentando iniciar..."
    sudo systemctl start "${SERVICE_NAME}.service" || true
    sleep 2
  fi
  systemctl is-active --quiet "${SERVICE_NAME}.service" && echo "Serviço ${SERVICE_NAME} está ativo." || echo "Serviço ${SERVICE_NAME} ainda não está ativo."
fi

# Tenta por até ~30s acessar a porta local
ATTEMPTS=30
for i in $(seq 1 ${ATTEMPTS}); do
  if curl -fsS -m 2 "http://127.0.0.1:${PORT}/" >/dev/null 2>&1; then
    echo "==> [post-deploy] OK: aplicação respondeu em http://127.0.0.1:${PORT}/"
    exit 0
  fi

  # Se curl falhar, tenta checar se a porta está 'LISTEN'
  if command -v ss >/dev/null 2>&1 && ss -lntp | grep -q ":${PORT}"; then
    echo "==> [post-deploy] OK: porta ${PORT} está em LISTEN (sem resposta HTTP ainda)."
    exit 0
  fi

  sleep 1
done

echo "==> [post-deploy] FALHA: não foi possível confirmar a aplicação na porta ${PORT}."
# Mostra logs se possível
if command -v journalctl >/dev/null 2>&1; then
  echo "---- Últimos logs do serviço (${SERVICE_NAME}) ----"
  sudo journalctl -u "${SERVICE_NAME}.service" -n 100 --no-pager || true
fi
exit 1
