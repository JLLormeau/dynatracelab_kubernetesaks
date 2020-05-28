#!/bin/bash
#set variables 

#Connection to Azure with AZ CLI 

echo -e "\n##### 3 - Validation of the variables #####\n"
USER=`whoami`
HOSTNAME=`hostname`
VM_RESOURCE_GROUP=$HOSTNAME
ACR_RESOURCE_GROUP=acr$HOSTNAME
ACR_NAME=acrname$HOSTNAME
ACR_LOGIN_SERVER=$ACR_NAME.azurecr.io
AKS_CLUSTER_NAME=akscluster

echo -e "\n##### 9 - Create a service principal #####\n"
SERVICE_PRINCIPAL=$(az ad sp create-for-rbac --skip-assignment)
echo -e "\n##### 10 - Get the APPID, the PASSWORD and the ACRID #####\n"
APPID=$(echo "$SERVICE_PRINCIPAL"|grep appId|cut -d '"' -f 4)
PASSWORD=$(echo "$SERVICE_PRINCIPAL"|grep password|cut -d '"' -f 4)
ACRID=$(az acr show --resource-group $ACR_RESOURCE_GROUP --name $ACR_NAME --query "id" --output tsv)
#wait 2 minutes to be sure the resource exist
sleep 120
echo -e "\n##### 11 - Update the name of the Registry <acrName> with this of your instance <arcId>#####\n"
az role assignment create --assignee $APPID --scope   "$ACRID" --role acrpull
echo -e "\n##### 12 - Create the Kubernetes cluster#####\n"
az aks create --resource-group $ACR_RESOURCE_GROUP --name $AKS_CLUSTER_NAME  --node-count 1 --service-principal "$APPID" --client-secret "$PASSWORD" --generate-ssh-keys
echo -e "\n##### 13 - Install Kubectl #####\n"
sudo az aks install-cli
echo -e "\n##### 14 - Log to the cluster with kubectl#####\n"
az aks get-credentials --resource-group $ACR_RESOURCE_GROUP --name $AKS_CLUSTER_NAME
echo -e "\n##### 15 - verify the connection to your cluster with kubectl#####\n"
kubectl get nodes
echo -e "\n##### 16 - update the manifeste file#####\n"
sed -i "s/microsoft\/azure-vote-front:v1/$ACR_LOGIN_SERVER\/azure-vote-front:$USER/" ./azure-vote-all-in-one-redis.yaml
echo -e "\n##### 17 - Deploy the application #####\n"
kubectl apply -f azure-vote-all-in-one-redis.yaml
echo -e "\n##### 18 - Wait until the application starts #####\n"
IPCLUSTER=$(kubectl get service azure-vote-front| grep azure | cut -d" " -f 10)
echo "EXTERNAL IP : "$IPCLUSTER
while [ $IPCLUSTER = "<pending>" ]
do
        sleep 5
        IPCLUSTER=$(kubectl get service azure-vote-front| grep azure | cut -d" " -f 10)
        echo "EXTERNAL IP : "$IPCLUSTER
done
echo "Your AKS Azure-Voting-App application is started, you can connect to :"
echo "http://$IPCLUSTER"
