#!/bin/bash

set -e

PROJECT_PATH="ProjetoAplicadoIII.csproj"
OUTPUT_DIR="./build-output"
CONFIGURATION="Release"

install_dotnet_sdk() {
  echo "🔍 Detectando sistema operacional..."

  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_NAME=$ID
    OS_VERSION=$VERSION_ID
    echo "Sistema detectado: $OS_NAME $OS_VERSION"
  else
    echo "Não foi possível detectar o sistema operacional."
    exit 1
  fi

  if [[ "$OS_NAME" == "amzn" || "$OS_NAME" == "centos" ]]; then
    echo "Instalando .NET SDK 8 via pacote Microsoft para $OS_NAME..."

    sudo yum update -y

    sudo rpm -Uvh https://packages.microsoft.com/config/centos/7/packages-microsoft-prod.rpm

    sudo yum install -y dotnet-sdk-8.0

    echo "Instalação do .NET SDK concluída."
  else
    echo "Sistema operacional não suportado por esse script automático."
    exit 1
  fi
}

check_dotnet() {
  if ! command -v dotnet > /dev/null 2>&1; then
    echo ".NET SDK não encontrado. Instalando..."
    install_dotnet_sdk
  else
    echo "dotnet já está instalado: $(dotnet --version)"
  fi
}

build_and_publish() {
  echo "Restaurando pacotes..."
  dotnet restore "$PROJECT_PATH"

  echo "Buildando projeto..."
  dotnet build "$PROJECT_PATH" -c "$CONFIGURATION" --no-restore

  echo "Publicando aplicação..."
  dotnet publish "$PROJECT_PATH" -c "$CONFIGURATION" -o "$OUTPUT_DIR" --no-build

  echo "✅ Aplicação publicada em $OUTPUT_DIR"
}

main() {
  check_dotnet
  build_and_publish
}

main
