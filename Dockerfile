# ===== RUNTIME =====
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app

# Porta padr�o (ajuste conforme sua infra: 80/5000/etc.)
ENV ASPNETCORE_URLS=http://+:7234 \
    ASPNETCORE_ENVIRONMENT=Production

# Se preferir n�o-root, descomente o bloco abaixo (pode exigir utilit�rios no base image)
# RUN adduser --disabled-password --gecos "" appuser \
#  && chown -R appuser:appuser /app
# USER appuser

EXPOSE 7234

# ===== BUILD/PUBLISH =====
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Opcional: permite informar o caminho do .csproj na hora do build
# Ex.: --build-arg PROJECT=src/MyApp/MyApp.csproj
ARG PROJECT=./ProjetoAplicadoIII.csproj
ARG BUILD_CONFIGURATION=Release

# Copia tudo (para suportar restaura��o de projetos com m�ltiplas pastas)
COPY . .

# Restaura e publica. For�amos AssemblyName=app para simplificar o ENTRYPOINT.
RUN dotnet restore "$PROJECT" \
 && dotnet publish "$PROJECT" -c $BUILD_CONFIGURATION -o /app/publish \
    -p:UseAppHost=false \
    -p:PublishReadyToRun=true

# ===== FINAL =====
FROM runtime AS final
WORKDIR /app
COPY --from=build /app/publish ./

ENTRYPOINT ["dotnet", "ProjetoAplicadoIII.dll"]
