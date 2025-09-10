#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="blazorapp"
PORT="7234"

echo "==> [post-deploy] Verificando servi�o e porta ${PORT}..."

# Garante curl (se n�o houver)
if ! command -v curl >/dev/null 2>&1; then
  echo "curl n�o encontrado. Instalando..."
  if command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y curl
  elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y curl
  elif command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -y && sudo apt-get install -y curl
  else
    echo "Gerenciador de pacotes n�o reconhecido. Instale o curl manualmente."
    exit 1
  fi
fi

# Se existir systemd, checa estado (tentando iniciar se n�o ativo)
if command -v systemctl >/dev/null 2>&1; then
  if ! systemctl is-active --quiet "${SERVICE_NAME}.service"; then
    echo "Servi�o ${SERVICE_NAME} n�o est� ativo. Tentando iniciar..."
    sudo systemctl start "${SERVICE_NAME}.service" || true
    sleep 2
  fi
  systemctl is-active --quiet "${SERVICE_NAME}.service" && echo "Servi�o ${SERVICE_NAME} est� ativo." || echo "Servi�o ${SERVICE_NAME} ainda n�o est� ativo."
fi

# Tenta por at� ~30s acessar a porta local
ATTEMPTS=30
for i in $(seq 1 ${ATTEMPTS}); do
  if curl -fsS -m 2 "http://127.0.0.1:${PORT}/" >/dev/null 2>&1; then
    echo "==> [post-deploy] OK: aplica��o respondeu em http://127.0.0.1:${PORT}/"
    exit 0
  fi

  # Se curl falhar, tenta checar se a porta est� 'LISTEN'
  if command -v ss >/dev/null 2>&1 && ss -lntp | grep -q ":${PORT}"; then
    echo "==> [post-deploy] OK: porta ${PORT} est� em LISTEN (sem resposta HTTP ainda)."
    exit 0
  fi

  sleep 1
done

echo "==> [post-deploy] FALHA: n�o foi poss�vel confirmar a aplica��o na porta ${PORT}."
# Mostra logs se poss�vel
if command -v journalctl >/dev/null 2>&1; then
  echo "---- �ltimos logs do servi�o (${SERVICE_NAME}) ----"
  sudo journalctl -u "${SERVICE_NAME}.service" -n 100 --no-pager || true
fi
exit 1
