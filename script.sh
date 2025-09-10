#!/bin/bash

# Diretório atual onde o script está rodando
CURRENT_DIR=$(pwd)

echo "Garantindo permissões para ec2-user na pasta $CURRENT_DIR"

# Ajusta dono e grupo para ec2-user na pasta atual (recursivamente)
sudo chown -R ec2-user:ec2-user "$CURRENT_DIR"

# Dá permissão total na pasta atual (recursivamente)
sudo chmod -R 777 "$CURRENT_DIR"

echo "Permissões ajustadas."

# Atualiza o sistema
sudo yum update -y

# Instala pacotes necessários
sudo yum install -y wget tar

# Variável para versão do .NET SDK
DOTNET_SDK_URL="https://builds.dotnet.microsoft.com/dotnet/Sdk/8.0.414/dotnet-sdk-8.0.414-linux-x64.tar.gz"

# Diretório para instalação do .NET
INSTALL_DIR=$HOME/dotnet

# Cria diretório para instalação se não existir
mkdir -p $INSTALL_DIR

# Baixa o SDK do .NET
wget -O dotnet-sdk.tar.gz $DOTNET_SDK_URL

# Extrai o SDK no diretório de instalação
tar -zxf dotnet-sdk.tar.gz -C $INSTALL_DIR

# Remove o arquivo baixado
rm dotnet-sdk.tar.gz

# Exporta as variáveis para o PATH temporariamente para essa sessão
export DOTNET_ROOT=$INSTALL_DIR
export PATH=$INSTALL_DIR:$PATH

# Publica o projeto na pasta ./publish
dotnet publish ProjetoAplicadoIII.csproj -c Release -o ./publish

echo "Publicação concluída em ./publish"

# Opcional: Para tornar as variáveis permanentes, pode adicionar as linhas abaixo no ~/.bashrc ou ~/.bash_profile
# echo "export DOTNET_ROOT=$INSTALL_DIR" >> ~/.bashrc
# echo "export PATH=\$DOTNET_ROOT:\$PATH" >> ~/.bashrc
