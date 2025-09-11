#!/bin/bash

CONTAINER_NAME="ProjetoAplicadoIIIDocker"
IMAGE_NAME="ProjetoAplicadoIIIDocker"
PORT=7234

# Verifica se já existe um container com esse nome
if [ "$(docker ps -aq -f name=^${CONTAINER_NAME}$)" ]; then
    echo "Removendo container existente: $CONTAINER_NAME"
    docker rm -f $CONTAINER_NAME
fi

# Cria o novo container com mapeamento de porta e restart automático
echo "Criando novo container: $CONTAINER_NAME"
docker run -d \
  --name $CONTAINER_NAME \
  -p $PORT:$PORT \
  --restart always \
  $IMAGE_NAME
