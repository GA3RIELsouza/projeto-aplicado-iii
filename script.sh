#!/bin/bash

set -e

PROJECT_PATH="./deploy"
OUTPUT_DIR="./build-output"
CONFIGURATION="Release"
DOTNET_VERSION="8.0.302"  # Versão válida e existente
INSTALL_DIR="$HOME/dotnet"

# ------------------------
# Instala o .NET SDK 8.0 localmente, se necessário
# ------------------------
install_dotnet_sdk() {
  echo "🔧 Instalando .NET SDK $DOTNET_VERSION..."

  mkdir -p "$INSTALL_DIR"

  curl -sSL https://dot.net/v1/dotnet-install.sh | bash /dev/stdin --version "$DOTNET_VERSION" --install-dir "$INSTALL_DIR"

  export PATH="$INSTALL_DIR:$PATH"

  echo "✅ .NET SDK $DOTNET_VERSION instalado em $INSTALL_DIR"
}

# ------------------------
# Verifica se o .NET SDK 8.0 está presente
# ------------------------
check_dotnet_sdk() {
  if command -v dotnet >/dev/null 2>&1; then
    VERSION=$(dotnet --version)
    if [[ "$VERSION" == 8.* ]]; then
      echo "✅ .NET SDK $VERSION já está instalado."
      return
    fi
  fi

  echo "⚠️ .NET SDK 8.0 não encontrado. Instalando..."
  install_dotnet_sdk
}

# ------------------------
# Build da aplicação Blazor
# ------------------------
build_app() {
  echo "=============================="
  echo "🚀 Iniciando build da aplicação Blazor (.NET 8)"
  echo "📁 Projeto localizado em: $PROJECT_PATH"
  echo "=============================="

  echo "📦 Restaurando pacotes..."
  dotnet restore "$PROJECT_PATH"

  echo "🔨 Buildando em modo $CONFIGURATION..."
  dotnet build "$PROJECT_PATH" -c "$CONFIGURATION" --no-restore

  echo "📤 Publicando aplicação..."
  dotnet publish "$PROJECT_PATH" -c "$CONFIGURATION" -o "$OUTPUT_DIR" --no-build

  echo "✅ Build e publicação concluídas com sucesso!"
  echo "📁 Artefatos disponíveis em: $OUTPUT_DIR"
}

# ------------------------
# Execução principal
# ------------------------
check_dotnet_sdk
build_app
