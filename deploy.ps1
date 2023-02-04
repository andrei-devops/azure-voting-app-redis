
$resourceGroupName = 'cloud-h2t-rg'
$location = 'eastus2'
$keyVaultName = 'cloud-h2t-kv'
$acrName = 'cloud-h2t-acr'
$pipName = 'cloud-h2t-pip'
$aksName = 'cloud-h2t-aks'

az group create `
  --name $resourceGroupName `
  --location $location

az acr create `
  --resource-group $resourceGroupName `
  --name $acrName  `
  --sku Basic