#!/bin/bash

echo "Retrieving cluster credentials"
az aks get-credentials --resource-group ${AZURE_RESOURCE_GROUP} --name ${AZURE_AKS_CLUSTER_NAME}

# Add required Helm repos
helm repo add aso2 https://raw.githubusercontent.com/Azure/azure-service-operator/main/v2/charts
helm repo add kedacore https://kedacore.github.io/charts
helm repo update

echo "Checking if Azure Service Operator is installed"
aso2Status=$(helm status aso2 -n azureserviceoperator-system 2>&1)
if [[ $aso2Status == *"Error: release: not found"* ]]; then
     echo "Azure Service Operator not installed, installing"
     kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.8.2/cert-manager.yaml
     helm upgrade --install --devel aso2 aso2/azure-service-operator \
          --create-namespace \
          --namespace=azureserviceoperator-system \
          --set azureSubscriptionID=${AZURE_SUBSCRIPTION_ID} \
          --set azureTenantID=${AZURE_TENANT_ID} \
          --set azureClientID=${ASO_WORKLOADIDENTITY_CLIENT_ID} \
          --set useWorkloadIdentityAuth=true
else
  echo "Azure Service Operator installed, skipping"
fi

# Temporary until KEDA add-on is updated to 2.10 which is needed for workload identity support in Prometheus scaler
echo "Checking if KEDA is installed"
kedatatus=$(helm status keda -n kube-system 2>&1)
if [[ $kedatatus == *"Error: release: not found"* ]]; then
     echo "KEDA not installed, installing"
     helm upgrade --install keda kedacore/keda \
          --namespace kube-system \
          --set podIdentity.azureWorkload.enabled=true
else
  echo "KEDA installed, skipping"
fi
