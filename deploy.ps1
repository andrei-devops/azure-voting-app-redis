
$resourceGroupName = 'cloud-h2t-rg'
$location = 'eastus2'
$keyVaultName = 'cloud-h2t-kv'
$acrName = 'cloudh2tacr'
$pipName = 'cloud-h2t-pip'
$aksName = 'cloud-h2t-aks'
$vmResourceGroupName = 'MC_cloud-h2t-rg_cloud-h2t-aks_eastus2'
$vmScaleSetName = 'aks-nodepool1-36487519-vmss'

# Deploy infra
az group create `
  --name $resourceGroupName `
  --location $location

az acr create `
  --resource-group $resourceGroupName `
  --name $acrName  `
  --sku Basic

az network public-ip create `
  --resource-group $resourceGroupName `
  --name $pipName `
  --sku Standard `
  --allocation-method static

az keyvault create `
  -n $keyVaultName `
  -g $resourceGroupName `
  -l $location

az extension add --name aks-preview

az keyvault secret set `
  --vault-name $keyVaultName `
  -n 'andrei-lipinski-1' `
  --value 'Qwe12345678'

az keyvault secret set `
  --vault-name $keyVaultName `
  -n 'andrei-lipinski-2' `
  --value 'Qwe12345678'

az aks create `
  --resource-group $resourceGroupName `
  --name $aksName `
  --node-count 1 `
  --generate-ssh-keys `
  --attach-acr $acrName `
  --location $location `
  --enable-addons azure-keyvault-secrets-provider `
  --enable-managed-identity `
  --enable-oidc-issuer

# acr steps
# https://learn.microsoft.com/en-us/azure/aks/tutorial-kubernetes-prepare-app

az acr list `
  --resource-group $resourceGroupName `
  --query "[].{acrLoginServer:loginServer}" `
  --output table

az acr login --name $acrName
docker tag mcr.microsoft.com/azuredocs/azure-vote-front:v1 cloudh2tacr.azurecr.io/azure-vote-front:v1
docker push cloudh2tacr.azurecr.io/azure-vote-front:v1
az acr repository list --name $acrName --output table
docker images

# network steps
# https://learn.microsoft.com/en-us/azure/aks/static-ip

$aksClienId = $(az aks show --resource-group $resourceGroupName --name $aksName --query "servicePrincipalProfile.clientId" --output tsv)
$subscriptionId = $(az account show --query "id" --output tsv)

az role assignment create `
  --assignee '7853723a-d49e-4b10-a112-46f4c06de38b' `
  --role "Network Contributor" `
  --scope "/subscriptions/612860ac-3646-49fa-b002-464f8f156655/resourceGroups/cloud-h2t-rg/"

az network public-ip show -g $resourceGroupName -n $pipName --query 'ipAddress' -o tsv

az aks get-credentials `
  --resource-group $resourceGroupName `
  --name $aksName

# https://learn.microsoft.com/en-us/azure/aks/csi-secrets-store-driver
# https://learn.microsoft.com/en-us/azure/aks/csi-secrets-store-identity-access

kubectl get pods -n kube-system -l 'app in (secrets-store-csi-driver,secrets-store-provider-azure)'

az keyvault set-policy `
  -n $keyVaultName `
  --secret-permissions 'get' `
  --spn 'dbc8b27c-028d-419d-961f-4d81e8ad8cd4' # azurekeyvaultsecretsprovider-cloud-h2t-aks

kubectl apply -f secretclass.yaml

$AKS_OIDC_ISSUER="$(az aks show --resource-group $resourceGroupName --name $aksName --query "oidcIssuerProfile.issuerUrl" -o tsv)"
$federatedIdentityName="aksfederatedidentity" # can be changed as needed
az identity federated-credential create --name $federatedIdentityName --identity-name 'azurekeyvaultsecretsprovider-cloud-h2t-aks' --resource-group 'MC_cloud-h2t-rg_cloud-h2t-aks_eastus2' --issuer 'https://eastus2.oic.prod-aks.azure.com/f5ac0f9b-7407-4d23-8587-2940daec5669/d0c0d244-289a-48c1-998c-39926f6184d7/' --subject 'system:serviceaccount:default:workload-identity-sa'

kubectl apply -f serviceaccount.yaml
kubectl apply -f full_azure-vote-all-in-one-redis.yaml

kubectl exec azure-vote-front -- ls /mnt/secrets-store/

