#!/bin/bash
#set variables 

#Connection to Azure with AZ CLI 
echo -e "\n##### 1 - Install az cli #####\n"
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
echo "\n##### 2 - connection to Azure Subscription #####\n"
read -p "Azure account: " AZ_ACCOUNT && read -sp "Azure password: " AZ_PASS && echo && az login -u $AZ_ACCOUNT -p $AZ_PASS < /dev/null

echo -e "\n##### 3 - Validate the variable #####\n"
user=`whoami`
hostname=`hostname`
ACR_ressource_group=acr$hostname
ACR_name=acrname$hostname
ACR_login_server=$ACR_name.azurecr.io
AKS_ressource_group=akscluster
#validate the variables
echo -e "Variables"
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




echo -e "\n##### 4 - Get the docker application Azure-Voting-App-Redis and start the application#####\n"
#git clone https://github.com/JLLormeau/dynatracelab_azure-voting-app-redis.git #already done from bitbuecket
#cd dynatracelab_azure-voting-app-redis
sudo docker-compose up -d
echo -e "\n##### 5 - the image has been created locally, we can stop the docker application#####\n"
sudo docker-compose down
echo -e "\n##### 6 - Create an Azure Container Registry and log in to the container registry#####\n"
az group create --name $ACR_ressource_group --location westeurope
az acr create --resource-group $ACR_ressource_group --name $ACR_name --sku Basic 
az acr login --name $ACR_name
echo -e "\n##### 7 - Tag your image azure-vote-front with the acrLoginServer and USER0X#####\n"
docker tag azure-vote-front  $ACR_login_server/azure-vote-front:$user
echo -e "\n##### 8 - Push  the docker image in registry ACR #####\n"
docker push $ACR_login_server/azure-vote-front:$user
echo -e "\n##### 9 - Create a service principal #####\n"
Service_Principal=$(az ad sp create-for-rbac --skip-assignment)
echo -e "\n##### 10 - Get the AppId, the Password and the ACRID#####\n"
AppId=$(echo "$Service_Principal"|grep appId|cut -d '"' -f 4)
Password=$(echo "$Service_Principal"|grep password|cut -d '"' -f 4)
ACRID=$(az acr show --resource-group $ACR_ressource_group --name $ACR_name --query "id" --output tsv)
#wait 2 minutes to be sure the ressource exist
sleep 120
echo -e "\n##### 11 - Update the name of the Registry <acrName> with this of your instance <arcId>#####\n"
az role assignment create --assignee $AppId --scope   "$ACRID" --role acrpull
echo -e "\n##### 12 - UCreate the Kubernetes cluster#####\n"
az aks create --resource-group $ACR_ressource_group --name $AKS_ressource_group  --node-count 1 --service-principal "$AppId" --client-secret "$Password" --generate-ssh-keys
echo -e "\n##### 13 - Install Kubectl #####\n"
sudo az aks install-cli
echo -e "\n##### 14 - Log to the cluster with kubectl#####\n"
az aks get-credentials --resource-group $ACR_ressource_group --name $AKS_ressource_group
echo -e "\n##### 15 - verify the connection to your cluster with kubectl#####\n"
kubectl get nodes
echo -e "\n##### 16 - update the manifeste file#####\n"
sed -i "s/microsoft\/azure-vote-front:v1/$ACR_login_server\/azure-vote-front:$user/" ./azure-vote-all-in-one-redis.yaml
echo -e "\n##### 17 - Deploy the application and validate the deployment#####\n"
kubectl apply -f azure-vote-all-in-one-redis.yaml
kubectl get service azure-vote-front --watch
