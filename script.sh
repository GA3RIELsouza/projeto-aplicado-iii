#!/bin/bash

set -e

# Define variável HOME para dotnet/NuGet funcionar
export HOME=/home/ec2-user

# Caminho do projeto
PROJETO_DIR="/deploy"
PROJETO_CSPROJ="ProjetoAplicadoIII.csproj"

# Verifica se dotnet está instalado e versão 8.x
if ! command -v dotnet >/dev/null 2>&1 || ! dotnet --list-sdks | grep -q '^8\.'
then
  echo "⚠️ .NET SDK 8 não encontrado. Instalando..."

  # Baixa e instala o dotnet SDK 8 localmente em /usr/share/dotnet
  curl -sSL https://dotnet.microsoft.com/download/dotnet/scripts/v1/dotnet-install.sh -o dotnet-install.sh
  bash ./dotnet-install.sh --channel 8.0 --install-dir /usr/share/dotnet --no-path

  # Adiciona dotnet no PATH para sessão atual
  export PATH=/usr/share/dotnet:$PATH

  echo ".NET SDK 8 instalado."
else
  echo "dotnet já está instalado: $(dotnet --version)"
fi

cd "$PROJETO_DIR"

echo "Restaurando pacotes..."
dotnet restore "$PROJETO_CSPROJ"

echo "Buildando projeto..."
dotnet build "$PROJETO_CSPROJ" -c Release --no-restore

echo "Publicando projeto..."
dotnet publish "$PROJETO_CSPROJ" -c Release -o "$PROJETO_DIR/publish" --no-build

echo "Aplicação publicada em $PROJETO_DIR/publish"
