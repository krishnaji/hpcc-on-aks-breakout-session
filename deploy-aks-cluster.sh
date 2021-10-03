#!/bin/bash
# Set Env Variables
export RG=AKS11
export LOC=eastus
export CLUSTER_NAME=hpcc-test-10
export VNET_NAME=hpcc-vnet-10
export SANAME=thortestprem10
export SATYPE=Standard_LRS
export SAKIND=StorageV2
export SA_CONTAINER_NAME=hpcc-data
# Create the RG
az group create -n $RG -l $LOC
# Create the Vnet
az network vnet create \
-g $RG \
-n $VNET_NAME \
-l $LOC \
--address-prefix 10.40.0.0/16 \
--subnet-name aks --subnet-prefix 10.40.0.0/21
# Create Storage Subnet
az network vnet subnet create \
    --resource-group $RG \
    --vnet-name $VNET_NAME \
    --name storage \
    --address-prefix 10.40.8.0/24
# Create Azure Storage Endpoings
az network vnet subnet update --resource-group $RG --vnet-name "$VNET_NAME" --name "aks" --service-endpoints "Microsoft.Storage"
az network vnet subnet update --resource-group $RG --vnet-name "$VNET_NAME" --name "storage" --service-endpoints "Microsoft.Storage"
# Get the subnet id
AKS_SUBNET_ID=$(az network vnet show -g $RG -n $VNET_NAME -o tsv --query "subnets[?name=='aks'].id")    
STORAGE_SUBNET_ID=$(az network vnet show -g $RG -n $VNET_NAME -o tsv --query "subnets[?name=='storage'].id")    
# Create the Cluster with the CSI Driver enabled
az aks create -g $RG \
-n $CLUSTER_NAME \
--enable-managed-identity \
--network-plugin azure \
--vnet-subnet-id $AKS_SUBNET_ID \
--location $LOC \
--aks-custom-headers EnableAzureDiskFileCSIDriver=true
# Add Thor Nodepool
az aks nodepool add -g $RG --cluster-name $CLUSTER_NAME --name thorpool --node-count 2 --node-vm-size Standard_L8s_v2 --mode User --node-taints=nvme=true:NoSchedule
CLUSTER_RESOURCE_GROUP=$(az aks show --resource-group $RG --name $CLUSTER_NAME --query nodeResourceGroup -o tsv)
# Create Blob NFS Storage Account
az deployment group create \
  --resource-group $CLUSTER_RESOURCE_GROUP \
  --template-file blob_nfs_arm.json \
  --parameters location="$LOC" \
  storageAccountName="$SANAME" \
  accountType="$SATYPE" \
  kind="$SAKIND" \
  aksSubnetID="$AKS_SUBNET_ID" \
  storageSubnetID="$STORAGE_SUBNET_ID"
# Get Cluster Creds
az aks get-credentials -g $RG -n $CLUSTER_NAME
# Deploy the NVME drive mount daemonset
kubectl apply -f aks-nvme-ssd-provisioner.yaml
# Install Blob CSI Driver
curl -skSL https://raw.githubusercontent.com/kubernetes-sigs/blob-csi-driver/master/deploy/install-driver.sh | bash -s master --
# Get Storage Account Access Key
SA_KEY=$(az storage account keys list -g $RESOURCE_GROUP -n $SANAME -o tsv --query "[?keyName=='key1']".value)
# Create blob access secret
kubectl create secret generic azure-blob-secret --from-literal=azurestorageaccountname="$SANAME" --from-literal azurestorageaccountkey="$SA_KEY" --type=Opaque
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-blob
  labels: 
    storage-tier: blobnfs 
spec:
  capacity:
    storage: 10T
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain  # "Delete" is not supported in static provisioning
  csi:
    driver: blob.csi.azure.com
    readOnly: false
    volumeHandle: $(uuidgen)  # make sure this volumeid is unique in the cluster
    volumeAttributes:
      resourceGroup: $RG
      storageAccount: $SANAME
      containerName: $SA_CONTAINER_NAME
      protocol: nfs
    nodeStageSecretRef:
      name: azure-blob-secret
      namespace: default    
EOF
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-blob-nfs 
spec:
  selector: 
    matchLabels:
      storage-tier: blobnfs
  accessModes:
    - ReadWriteMany
  storageClassName: ""
  resources:
    requests:
      storage: 10T
EOF

