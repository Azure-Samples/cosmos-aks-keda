# Deploy Azure Environment
deploymentName=CosmosAksKedaDemo
location=eastus
az deployment sub create --name $deploymentName --location $location --template-file main.bicep --parameters @param.json

# Setup KEDA  and external scaler
aksName=$(az deployment sub show --name $deploymentName --query 'properties.outputs.aksName.value' -o tsv)
rgName=$(az deployment sub show --name $deploymentName --query 'properties.outputs.resourceGroup.value' -o tsv)
acrName=$(az deployment sub show --name $deploymentName --query 'properties.outputs.acrName.value' -o tsv)
cosmosName=$(az deployment sub show --name $deploymentName --query 'properties.outputs.cosmosName.value' -o tsv)
clientId=$(az deployment sub show --name $deploymentName --query 'properties.outputs.workloadIdentity.value' -o tsv)
az aks get-credentials -n $aksName -g $rgName --admin --overwrite-existing

helm repo add kedacore https://kedacore.github.io/charts
helm repo update
helm install keda kedacore/keda --namespace keda --create-namespace
helm install external-scaler-azure-cosmos-db kedacore/external-scaler-azure-cosmos-db --namespace keda --create-namespace

# Build and Deploy Scalar Container Image
pushd ..
az acr build --registry $acrName -f ./src/Scaler/Dockerfile -t cosmosdb/scaler:latest ./src
popd

# Create the service account for AKS Workload Identity
sed -i "s/{Workload Identity Client ID}/${clientId}/g" ./service_account.yaml
kubectl apply -f service_account.yaml

# Deploy the scaler to AKS
sed -i "s/{ACR Name}/${acrName}/g" ./scaler_deploy.yaml
kubectl apply -f scaler_deploy.yaml

# Build and Deploy the Order Processor
pushd ..
az acr build --registry $acrName -f ./src/Scaler.Demo/OrderProcessor/Dockerfile -t cosmosdb/order-processor:latest ./src
popd

sed -i "s/{ACR Name}/${acrName}/g" ./orderprocessor_deploy.yaml
sed -i "s/{Cosmos DB Account Name}/${cosmosName}/g" ./orderprocessor_deploy.yaml
kubectl apply -f orderprocessor_deploy.yaml

# Deploy scaledobject to configure KEDA
sed -i "s/{Cosmos DB Account Name}/${cosmosName}/g" ./deploy-scaledobject.yaml
kubectl apply -f deploy-scaledobject.yaml

# Build and Deploy the Single Partition Order Generator
pushd ..
az acr build --registry $acrName -f ./src/Scaler.Demo/OrderGenerator/Dockerfile -t cosmosdb/order-generator:latest ./src
popd

sed -i "s/{ACR Name}/${acrName}/g" ./ordergenerator_sp_deploy.yaml
sed -i "s/{Cosmos DB Account Name}/${cosmosName}/g" ./ordergenerator_sp_deploy.yaml
# kubectl apply -f ordergenerator_sp_deploy.yaml

# Deploy the Multi Partition Order Generator
sed -i "s/{ACR Name}/${acrName}/g" ./ordergenerator_mp_deploy.yaml
sed -i "s/{Cosmos DB Account Name}/${cosmosName}/g" ./ordergenerator_mp_deploy.yaml
# kubectl apply -f ordergenerator_mp_deploy.yaml

kubectl get pods --namespace cosmosdb-order-processor

echo "The AKS and Cosmos environment is ready."
echo 'Deploy the single partition order generator with `kubectl apply -f ordergenerator_sp_deploy.yaml`'
echo 'Deploy the multi partition order generator with `kubectl apply -f ordergenerator_mp_deploy.yaml`'