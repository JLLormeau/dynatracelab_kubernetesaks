#!/bin/bash
#design by JLLormeau Dynatrace


#set variables 
APPID=$1
PASSWORD=$2
TENANT=$3
TIME=`date +%Y%m%d%H%M%S`
log=deploy-aks-cluster-voting-app-with-service-principa-$TIME.log
{
#test APPID, PASSWORD and TENANT not empty
if [ -z "$APPID" ] || [ -z "$PASSWORD" ] || [ -z "$TENANT" ];
	then APPLY="N";APPID="APPID";PASSWORD="PASSWORD";TENANT="TENANT" 
	else APPLY="Y";fi

while [ "$APPLY" !=  "Y" ]
do
        clear
        echo "CONFIGURE your Service Principal from your Azure Subscription"
		echo "####  to create a Service Principal, open your Azure Cli and entry the az command"
		echo "####  \"az ad sp create-for-rbac --name MyServicePrincipalNameforLabKube\""
		echo "####  more information on the Service Principal  : https://docs.microsoft.com/en-us/cli/azure/create-an-azure-service-principal-azure-cli"
		echo "####  you can use the same Service Principal for all the lab environment"
		echo "####  more information on Azure Vote App : https://docs.microsoft.com/en-us/azure/aks/tutorial-kubernetes-prepare-app"
		echo "####"
		echo "####  silent mode installation :"
		echo "####  \"/bin/sh deploy-aks-cluster-voting-app-with-service-principal.sh "$APPID" "$PASSWORD" "$TENANT"\""
		echo "####"
		echo ""
		echo ""
        echo "1) APPID(Serveice Principal)                     ="$APPID
        echo "2) PASSWORD (Serveice Principal)                 ="$PASSWORD
        echo "3) TENANT (Serveice Principal)                   ="$TENANT
		echo "A) Apply configuration and deploy the Kubernetes Azure Vote App on your Azure Subscription" 
        echo ""
        sleep 1
        read  -p "Input Selection (1, 2, 3 or A): " reponse

        case "$reponse" in
                "1") read  -p "1) APPID(Serveice Principal)   " APPID
                ;;
                "2") read  -p "2) PASSWORD (Serveice Principal)   " PASSWORD
                ;;
                "3") read  -p "3) TENANT (Serveice Principal)   " TENANT
                ;;
               "A") APPLY="Y"
        esac
done



#define the region if odd  eastus, if even eastus2
if $( printf `hostname` | tail -c 1 | fgrep -wq -e 0 -e 2 -e 4 -e 6 -e 8) ; then
    REGION="eastus2"
else
	REGION="eastus"
fi

#Connection to Azure with AZ CLI 
echo -e "\n##### 1 - Installation of AZ CLI #####\n"
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
echo -e "\n##### 2 - Connection to Azure Subscription #####\n"
#read -p "Azure account: " AZ_ACCOUNT && read -sp "Azure password: " AZ_PASS && echo && az login -u $AZ_ACCOUNT -p $AZ_PASS < /dev/null
az login --service-principal --username $APPID --password $PASSWORD --tenant $TENANT


echo -e "\n##### 3 - Validation of the variables #####\n"
USER=`whoami`
HOSTNAME=`hostname`
VM_RESOURCE_GROUP=$HOSTNAME
ACR_RESOURCE_GROUP=acr$HOSTNAME
ACR_NAME=acrname$HOSTNAME
ACR_LOGIN_SERVER=$ACR_NAME.azurecr.io
AKS_CLUSTER_NAME=akscluster
DEPLOY_DIRECTORY=/home/dynatracelab_kubernetesaks
DELETE_FILE=$DEPLOY_DIRECTORY/delete_resourcegroup_labkubernetes.sh
#validate the variables
echo -e "Variables"
echo ""
echo -e "\nHOSTNAME="$HOSTNAME"\nUSER="$USER"\nAZ_ACCOUNT="$AZ_ACCOUNT"\nVM_RESOURCE_GROUP="$VM_RESOURCE_GROUP"\nACR_RESOURCE_GROUP="$ACR_RESOURCE_GROUP"\nAKS_CLUSTER_NAME="$AKS_CLUSTER_NAME"\nAKS_RESOURCE_GROUP="MC_$ACR_RESOURCE_GROUP"_"$AKS_CLUSTER_NAME"_"$REGION
#echo "continue (Y/N)"
#read Response
#if [ $Response = "N" ] || [ $Response = "n" ]
#then
#	exit
#fi

echo -e "\n##### 4 - Get the docker application Azure-Voting-App-Redis and start the docker application#####\n"
cd $DEPLOY_DIRECTORY
sudo docker-compose up -d
echo -e "\n##### 5 - the image has been created locally, docker application is stopped#####\n"
sudo docker-compose down
echo -e "\n##### 6 - Create a resource group ACR #####\n"
az group create --name $ACR_RESOURCE_GROUP --location "$REGION"
##create the script shell to delete the resource groups of this lab
echo "##Training : "$ACR_RESOURCE_GROUP > $DELETE_FILE
chmod +x $DELETE_FILE
echo "echo "$ACR_RESOURCE_GROUP >> $DELETE_FILE
echo "az group delete --name "$ACR_RESOURCE_GROUP" --y" >> $DELETE_FILE
echo -e "\n##### 6 - Create an Azure Container Registry ACR and log in to the container registry#####\n"
az acr create --resource-group $ACR_RESOURCE_GROUP --name $ACR_NAME --sku Basic 
az acr login --name $ACR_NAME
echo -e "\n##### 7 - Tag your image azure-vote-front with the acrLoginServer and "$USER"#####\n"
docker tag azure-vote-front  $ACR_LOGIN_SERVER/azure-vote-front:$USER
echo -e "\n##### 8 - Push  the docker image in registry ACR #####\n"
docker push $ACR_LOGIN_SERVER/azure-vote-front:$USER
echo -e "\n##### 9 - Create a service principal #####\n"
#SERVICE_PRINCIPAL=$(az ad sp create-for-rbac --skip-assignment)
#echo -e "\n##### 10 - Get the APPID, the PASSWORD and the ACRID #####\n"
#APPID=$(echo "$SERVICE_PRINCIPAL"|grep appId|cut -d '"' -f 4)
#PASSWORD=$(echo "$SERVICE_PRINCIPAL"|grep password|cut -d '"' -f 4)
ACRID=$(az acr show --resource-group $ACR_RESOURCE_GROUP --name $ACR_NAME --query "id" --output tsv)
#echo "$PASSWORD"
#wait 2 minutes to be sure the resource exist
#sleep 120
#echo -e "\n##### 11 - Update the name of the Registry <acrName> with this of your instance <arcId>#####\n"
#az role assignment create --assignee $APPID --scope   "$ACRID" --role acrpull
echo -e "\n##### 12 - Create the Kubernetes cluster#####\n"
az aks create --resource-group $ACR_RESOURCE_GROUP --name $AKS_CLUSTER_NAME  --node-count 1 --service-principal "$APPID" --client-secret "$PASSWORD" --generate-ssh-keys
##create the script shell to delete the resource groups of this lab
echo "echo MC_"$ACR_RESOURCE_GROUP"_"$AKS_CLUSTER_NAME"_"$REGION >> $DELETE_FILE
echo "az group delete --name MC_"$ACR_RESOURCE_GROUP"_"$AKS_CLUSTER_NAME"_"$REGION" --y" >> $DELETE_FILE
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
} | tee $log
