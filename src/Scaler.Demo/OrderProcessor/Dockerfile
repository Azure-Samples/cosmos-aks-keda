#See https://aka.ms/customizecontainer to learn how to customize your debug container and how Visual Studio uses this Dockerfile to build your images for faster debugging.

FROM mcr.microsoft.com/dotnet/runtime:6.0 AS base
WORKDIR /app

FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build
WORKDIR /src
COPY ["Scaler.Demo/OrderProcessor/Keda.CosmosDb.Scaler.Demo.OrderProcessor.csproj", "Scaler.Demo/OrderProcessor/"]
COPY ["Scaler.Demo/Shared/Keda.CosmosDb.Scaler.Demo.Shared.csproj", "Scaler.Demo/Shared/"]
RUN dotnet restore "Scaler.Demo/OrderProcessor/Keda.CosmosDb.Scaler.Demo.OrderProcessor.csproj"
COPY . .
WORKDIR "/src/Scaler.Demo/OrderProcessor"
RUN dotnet build "Keda.CosmosDb.Scaler.Demo.OrderProcessor.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "Keda.CosmosDb.Scaler.Demo.OrderProcessor.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "Keda.CosmosDb.Scaler.Demo.OrderProcessor.dll"]