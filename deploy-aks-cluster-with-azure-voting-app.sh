#!/bin/bash
#set variables 

sudo apt-get install -qq git < /dev/null
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
read -p "Azure account: " AZ_ACCOUNT && read -sp "Azure password: " AZ_PASS && echo && az login -u $AZ_ACCOUNT -p $AZ_PASS < /dev/null


#Script
#################################################
#apply the other variables
user=`whoami`
hostname=`hostname`
ACR_ressource_group=acr$hostname
ACR_name=acrname$hostname
ACR_login_server=$ACR_name.azurecr.io
AKS_ressource_group=akscluster$hostname
#validate the variables
echo "Variables"
echo ""
echo -e "\nhostname="$hostname"\nuser="$user"\nAZ_ACCOUNT="$AZ_ACCOUNT"\nACR_ressource_group="$ACR_ressource_group"\nACR_login_server="$ACR_login_server"\nAKS_ressource_group="$AKS_ressource_group"\n"
echo "validate (Y/N)"
read Response
if [ $Response = "N" ] || [ $Response = "n" ]
then
	echo "ACR_ressource_group"; read ACR_ressource_group
	echo "ACR_name"; read ACR_name
	echo "ACR_login_server"; read ACR_login_server
	echo "AKS_ressource_group"; read AKS_ressource_group
fi


#connection to azure subscription
#
git clone https://github.com/JLLormeau/dynatracelab_azure-voting-app-redis.git
cd dynatracelab_azure-voting-app-redis
sudo docker-compose up -d
sudo docker-compose down
az group create --name $ACR_ressource_group --location westeurope
az acr create --resource-group $ACR_ressource_group --name $ACR_name --sku Basic 
az acr login --name $ACR_name
docker tag azure-vote-front  $ACR_login_server/azure-vote-front:$user
docker push $ACR_login_server/azure-vote-front:$user
Service_Principal=$(az ad sp create-for-rbac --skip-assignment)
AppId=$(echo "$Service_Principal"|grep appId|cut -d '"' -f 4)
Password=$(echo "$Service_Principal"|grep password|cut -d '"' -f 4)
ACRID=$(az acr show --resource-group $ACR_ressource_group --name $ACR_name --query "id" --output tsv)
sleep 300
az role assignment create --assignee $AppId --scope   "$ACRID" --role acrpull
az aks create --resource-group $ACR_ressource_group --name $AKS_ressource_group  --node-count 1 --service-principal "$AppId" --client-secret "$Password" --generate-ssh-keys
sudo az aks install-cli
az aks get-credentials --resource-group $ACR_ressource_group --name $AKS_ressource_group
kubectl get nodes
sed -i "s/microsoft\/azure-vote-front:v1/$ACR_login_server\/azure-vote-front:$user/" ./azure-voting-app-redis/azure-vote-all-in-one-redis.yaml
kubectl apply -f azure-vote-all-in-one-redis.yaml
kubectl get service azure-vote-front --watch
