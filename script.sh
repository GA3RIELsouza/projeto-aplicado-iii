#!/bin/bash

set -e  # Para o script em caso de erro

PROJECT_PATH="ProjetoAplicadoIII.csproj"
OUTPUT_DIR="./build-output"
CONFIGURATION="Release"
DOTNET_VERSION="8.0"
INSTALL_DIR="$HOME/.dotnet"

install_dotnet_sdk() {
  echo "🔧 Instalando .NET SDK $DOTNET_VERSION..."
  mkdir -p "$INSTALL_DIR"
  curl -sSL https://dot.net/v1/dotnet-install.sh | bash /dev/stdin --channel "$DOTNET_VERSION" --install-dir "$INSTALL_DIR"
}

setup_path() {
  export PATH="$INSTALL_DIR:$INSTALL_DIR/tools:$PATH"
}

check_dotnet_sdk() {
  if ! command -v dotnet > /dev/null 2>&1; then
    echo "⚠️ .NET SDK não encontrado. Instalando..."
    install_dotnet_sdk
    setup_path
  else
    echo "✅ dotnet já está instalado."
    setup_path
  fi
}

build_and_publish() {
  echo "📦 Restaurando pacotes..."
  dotnet restore "$PROJECT_PATH"

  echo "🔨 Buildando projeto..."
  dotnet build "$PROJECT_PATH" -c "$CONFIGURATION" --no-restore

  echo "📤 Publicando aplicação..."
  dotnet publish "$PROJECT_PATH" -c "$CONFIGURATION" -o "$OUTPUT_DIR" --no-build

  echo "✅ Aplicação publicada em: $OUTPUT_DIR"
}

# Executa as funções
check_dotnet_sdk
build_and_publish
