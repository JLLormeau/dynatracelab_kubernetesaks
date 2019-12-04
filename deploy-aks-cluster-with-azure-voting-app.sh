#!/bin/bash
#set variables 

#Connection to Azure with AZ CLI 
echo -e "\n##### 1 - Installation of AZ CLI #####\n"
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
echo "\n##### 2 - Connection to Azure Subscription #####\n"
read -p "Azure account: " AZ_ACCOUNT && read -sp "Azure password: " AZ_PASS && echo && az login -u $AZ_ACCOUNT -p $AZ_PASS < /dev/null

echo -e "\n##### 3 - Validation of the variables #####\n"
USER=`whoami`
HOSTNAME=`hostname`
VM_RESSOURCE_GROUP=$HOSTNAME"_"$USER
ACR_RESSOURCE_GROUP=acr$HOSTNAME
ACR_NAME=acrname$HOSTNAME
ACR_LOGIN_SERVER=$ACR_NAME.azurecr.io
AKS_RESSOURCE_GROUP=akscluster
#validate the variables
echo -e "Variables"
echo ""
echo -e "\nHOSTNAME="$HOSTNAME"\nUSER="$USER"\nAZ_ACCOUNT="$AZ_ACCOUNT"\nVM_RESSOURCE_GROUP="$VM_RESSOURCE_GROUP"\nACR_RESSOURCE_GROUP="$ACR_RESSOURCE_GROUP"\nAKS_RESSOURCE_GROUP="MC_$ACR_RESSOURCE_GROUP"_"$AKS_RESSOURCE_GROUP"_westeurope\n"
echo "continue (Y/N)"
read Response
if [ $Response = "N" ] || [ $Response = "n" ]
then
	exit
fi

echo -e "\n##### 4 - Get the docker application Azure-Voting-App-Redis and start the docker application#####\n"
#git clone https://github.com/JLLormeau/dynatracelab_azure-voting-app-redis.git #already done from bitbuecket
#cd dynatracelab_azure-voting-app-redis
sudo docker-compose up -d
echo -e "\n##### 5 - the image has been created locally, docker application is stopped#####\n"
sudo docker-compose down
echo -e "\n##### 6 - Create an Azure Container Registry ACR and log in to the container registry#####\n"
az group create --name $ACR_RESSOURCE_GROUP --location westeurope
az acr create --resource-group $ACR_RESSOURCE_GROUP --name $ACR_NAME --sku Basic 
az acr login --name $ACR_NAME
echo -e "\n##### 7 - Tag your image azure-vote-front with the acrLoginServer and "$USER"#####\n"
docker tag azure-vote-front  $ACR_LOGIN_SERVER/azure-vote-front:$USER
echo -e "\n##### 8 - Push  the docker image in registry ACR #####\n"
docker push $ACR_LOGIN_SERVER/azure-vote-front:$USER
echo -e "\n##### 9 - Create a service principal #####\n"
SERVICE_PRINCIPAL=$(az ad sp create-for-rbac --skip-assignment)
echo -e "\n##### 10 - Get the APPID, the PASSWORD and the ACRID #####\n"
APPID=$(echo "$SERVICE_PRINCIPAL"|grep appId|cut -d '"' -f 4)
PASSWORD=$(echo "$SERVICE_PRINCIPAL"|grep password|cut -d '"' -f 4)
ACRID=$(az acr show --resource-group $ACR_RESSOURCE_GROUP --name $ACR_NAME --query "id" --output tsv)
#wait 2 minutes to be sure the ressource exist
sleep 120
echo -e "\n##### 11 - Update the name of the Registry <acrName> with this of your instance <arcId>#####\n"
az role assignment create --assignee $APPID --scope   "$ACRID" --role acrpull
echo -e "\n##### 12 - Create the Kubernetes cluster#####\n"
az aks create --resource-group $ACR_RESSOURCE_GROUP --name $AKS_RESSOURCE_GROUP  --node-count 1 --service-principal "$APPID" --client-secret "$PASSWORD" --generate-ssh-keys
echo -e "\n##### 13 - Install Kubectl #####\n"
sudo az aks install-cli
echo -e "\n##### 14 - Log to the cluster with kubectl#####\n"
az aks get-credentials --resource-group $ACR_RESSOURCE_GROUP --name $AKS_RESSOURCE_GROUP
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
