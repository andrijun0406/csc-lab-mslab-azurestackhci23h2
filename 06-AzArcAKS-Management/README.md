## 6. Azure Arc AKS Management

One of the cool capabilities of Azure Arc enabled-AKS or AKS Hybrid is that now, you can create AKS cluster from Azure Portal, CLI and also ARM template. 
In this section I will describe in detail my experience deploying Azure Arc enabled AKS on Azure Stack HCI using Portal and CLI

* You need to have a working Azure Stack HCI version 23H3 cluster
* You need to have Kubernetes Cluster Administrator access (member of Microsoft Entra group)
* Noted down your Subscription ID and Custom Location ID
* You already created Logical Network, noted down the logical network ID. Please check this [step](../05-AzArcVM-Management/) if you have not.

### Task 1 - Create AKS cluster from Azure Portal

#### Step 1 - Go to your Azure Stack HCI Cluster in the portal and click Resources > Virtual Machines

![Create Kubernetes Cluster](images/Create-Kubernetes-Cluster.png)

#### Step 2 - Basics

On The Basics page, configure the following options and click *Next: Node pools*

```
Basics:
    
    Project details

    Subscription:               <use-your-subscription>
    Resource Group:             <use-your-resource-group>

    Cluster details

    Virtual machine name:       th-clus03-aks01
    Custom location:            Choose custom location which aligned to the cluster where you want the AKS cluster to run (you need Contributor access to custom location)
    Kubernetes version:         Leave as Default (1.26.6)
    
    Primary node pool         
    
    Node size:                  Leave as Default (Standard_A4_v2 2vCPUs, 8 GiB RAM)
    Node count:                 2

    Administrator account

    Username:                   clouduser (default, can not changed)
    SSH public key source:      <Generate new key pair>
    key pair name:              th-clus03-aks01-key
    
```
> Note: There is always a primary linux node pool required which at least contained Azure arc agents containers

![Create Kubernetes Cluster - Basics](images/Create-Kubernetes-Cluster-Basics.png)

#### Step 3 - Node pools

On The Node pools page, configure the following options and click *Next: Access*

```
Node pools:
    
    Control plane nodes

    Control plane node size:     Leave as Default (Standard_A4_v2 2vCPUs, 8 GiB RAM)
    Control plane node count:    1 (if production choose 3 for HA)

    Node pools

    Virtual machine name:       th-clus03-aks01
    Custom location:            Choose custom location which aligned to the cluster where you want the AKS cluster to run (you need Contributor access to custom location)
    Kubernetes version:         Leave as Default (1.26.6)
    
    Primary node pool         
    
    Node size:                  Leave as Default (Standard_A4_v2 2vCPUs, 8 GiB RAM)
    Node count:                 2

    Node pools

    add aditional node pools if required (for example windows node pool for windows container)
    at this stage we just enough with 1 linux node pool.
  
```
![Create Kubernetes Cluster - Nodepools](images/Create-Kubernetes-Cluster-Nodepools.png)

#### Step 4a - Access

On The Access page, configure the following options and click *Next: Networking*

```
Access:
    
    Authentication and Authorization

    Authentication and Authorization:     Leave as Default (Local accounts with K8s RBAC)
```
> Note: if you choose Entra ID for Authentication you need to assigned entra ID group to cluster admin role and add your user to the group

![Create Kubernetes Cluster - Access](images/Create-Kubernetes-Cluster-Access.png)

#### Step 4b - Access

On The Access page, configure the following options and click *Next: Networking*

```
Access:
    
    Authentication and Authorization

    Authentication and Authorization:   Microsoft Entra authentication with Kubernetes RBAC
    Cluster admin ClusterRoleBinding:   Choose Entra group: <aks-admins>          
```
> Note: This will enable you to connect to AKS arc anywhere without requiring to have connectivity to on-premise

![Create Kubernetes Cluster - Access](images/Create-Kubernetes-Cluster-Access2.png)

#### Step 5 - Networking

On The Networking page, configure the following options and click *Next: Integration*

```
Networking:

    Logical network:                    subnet3 (this is using Static)
    Control plane IP:                   10.0.3.9 (need to be outside of IP pool 10.0.3.10-10.0.3.255)     
```
> Note: This settings can not be changed after created. You must also use Static Logical Network, Dynamic (using DHCP) is not supported today.

> Note: Network Load-Balancer will be configured later after cluster is created if required.

![Create Kubernetes Cluster - Networking](images/Create-Kubernetes-Cluster-Networking.png)

#### Step 6 - Integration

On The Integration page, configure the following options and click *Next: Tags*

```
Azure Monitor:

    Container monitoring:               Leave this as Disabled
   
```
> Note: We will do it later once the cluster is created if required (this will add some costs)

![Create Kubernetes Cluster - Integration](images/Create-Kubernetes-Cluster-Integration.png)

#### Step 7 - Tags

On The Tags page, skip this and click *Next: Review + create*

Configuration will be validated click *Create*
![Create Kubernetes Cluster - Validation](images/Create-Kubernetes-Cluster-Validation.png)

>You can also download a Template for automation later

#### Expected Results

**Deployment Progress**:

![AKS Deployment Progress](images/AKS-Deployment-Progress.png)
![AKS Deployment Progress](images/AKS-Deployment-Progress2.png)
![AKS Deployment Progress](images/AKS-Deployment-Result.png)

**Check on Windows Admin Center**

![AKS Deployment Progress](images/AKS-Deployment-Result2.png)

> You can see the deployment create 3 VMs: 1 Control Plane and 2 Worker Node from NodePool1

### Task 2 - Create AKS cluster from Azure CLI

Now let's try to create AKS clusters from Azure CLI.

#### Step 1 - Make sure you have all the prerequisite

* Azure Subscription ID
* Custom Location ID of your cluster
* Logical NetworkID, make sure you use Static Logical network

Run the following Script on Management machine to get CustomLocationID
```powershell

$subscription = "368ac09c-01c9-4b47-9142-a7581c6694a3"
$resource_group = "dcoffee-rg"
$customLocationName = "dcoffee-clus01-cl"
$location = "eastus"

# login first if you haven't already
az login --use-device-code

# install required azure cli extensions
az extension add -n aksarc --upgrade
az extension add -n customlocation --upgrade
az extension add -n stack-hci-vm --upgrade
az extension add -n connectedk8s --upgrade

$customLocationID = (az customlocation show --name $customLocationName --resource-group $resource_group --query "id" -o tsv)
```
![Check Custom Location ID](images/Check-CustomLocationID.png)

Run the following Script on Management machine to get Logical Network ID

```powershell
$lnetName = "subnet1"
$lnetid = (az stack-hci-vm network lnet show --name $lnetName --resource-group $resource_group --query "id" -o tsv)
```

![Check Logical Network ID](images/Check-LogicalNetworkID.png)

#### Step 2 - Install Kubectl on your machine

Follow this to install and setup kubectl on Windows
> [Install and Set up kubectl on Windows](https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/)

I am going to use scoop here:

```powershell

# don't run Powershell as admin (RunAs) use regular PowerShell

Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
```
The output would be something like this:

```
Execution Policy Change
The execution policy helps protect you from scripts that you do not trust. Changing the execution policy might expose you to the security risks described in the about_Execution_Policies help topic at
https:/go.microsoft.com/fwlink/?LinkID=135170. Do you want to change the execution policy?
[Y] Yes  [A] Yes to All  [N] No  [L] No to All  [S] Suspend  [?] Help (default is "N"): A
Initializing...
Downloading...
Extracting...
Creating shim...
Adding ~\scoop\shims to your path.
Scoop was installed successfully!
Type 'scoop help' for instructions.
PS C:\Users\LabAdmin>
```

> Note: scoop has problem using 7zip binary from www.7-zip.org use from sourceforge instead
```
notepad C:\Users\LabAdmin\scoop\buckets\main\bucket\7zip.json

# Change the following Version, URL and Hash with
"version": "24.06",
"architecture": {
        "64bit": {
            "url": "https://sourceforge.net/projects/sevenzip/files/7-Zip/24.06/7z2406-x64.msi",
            "hash": "946e32bf1eb545146ad47287d0837b01de86329c20f7081fc171d543a8578ec9",
            "extract_dir": "Files\\7-Zip"
        }

Leave other as default, then run:

scoop install 7zip
```

Now, install kubectl using scoop

```powershell
scoop install kubectl
kubectl version --client
```

The output would be something like this

```
PS C:\Users\LabAdmin> scoop install kubectl
Installing 'kubectl' (1.30.2) [64bit] from 'main' bucket
kubernetes-client-windows-amd64.tar.gz (30.3 MB) [========================================================================================================================================================================================================================================================================] 100%
Checking hash of kubernetes-client-windows-amd64.tar.gz ... ok.
Extracting kubernetes-client-windows-amd64.tar.gz ... done.
Linking ~\scoop\apps\kubectl\current => ~\scoop\apps\kubectl\1.30.2
Creating shim for 'kubectl'.
Creating shim for 'kubectl-convert'.
'kubectl' (1.30.2) was installed successfully!
PS C:\Users\LabAdmin> kubectl version --client
Client Version: v1.30.2
Kustomize Version: v5.0.4-0.20230601165947-6ce0bf390ce3
PS C:\Users\LabAdmin>
```

#### Step 3 - Create a AKS cluster
```powershell

# define parameters for az aksarc

$subscription = "368ac09c-01c9-4b47-9142-a7581c6694a3"
$resource_group = "dcoffee-rg"
$customLocationName = "dcoffee-clus01-cl"
$location = "eastus"
$aksclustername = "th-clus01-aks01"
$controlplaneIP = "10.0.1.9"
$aadgroupID = "4b5d705d-7c47-4731-b1ee-58c52165da1f"
$lnetName = "subnet1"

# login first if you haven't already
az login --use-device-code

$customLocationID = (az customlocation show --name $customLocationName --resource-group $resource_group --query "id" -o tsv)
$lnetid = (az stack-hci-vm network lnet show --name $lnetName --resource-group $resource_group --query "id" -o tsv)

# provision AKS cluster
az aksarc create -n $aksclustername -g $resource_group --custom-location $customlocationID --vnet-ids $lnetid --aad-admin-group-object-ids $aadgroupID --generate-ssh-keys --load-balancer-count 0  --control-plane-ip $controlplaneIP

```

#### Expected Results

The output would be something like this:

```
SSH key files 'C:\Users\LabAdmin\.ssh\id_rsa' and 'C:\Users\LabAdmin\.ssh\id_rsa.pub' have been generated under ~/.ssh to allow SSH access to the VM. If using machines without permanent storage like Azure Cloud Shell without an attached file share, back up your keys to a safe location
Please see Microsoft's privacy statement for more information: https://go.microsoft.com/fwlink/?LinkId=521839
Provisioning the AKSArc cluster. This operation might take a while...
{
  "extendedLocation": {
    "name": "/subscriptions/xxx/resourceGroups/dcoffee-rg/providers/Microsoft.ExtendedLocation/customLocations/dcoffee-clus01-cl",
    "type": "CustomLocation"
  },
  "id": "/subscriptions/xxx/resourceGroups/dcoffee-rg/providers/Microsoft.Kubernetes/connectedClusters/th-clus01-aks01/providers/Microsoft.HybridContainerService/provisionedClusterInstances/default",
  "name": "default",
  "properties": {
    "agentPoolProfiles": [
      {
        "count": 1,
        "enableAutoScaling": null,
        "kubernetesVersion": null,
        "maxCount": null,
        "maxPods": null,
        "minCount": null,
        "name": "nodepool1",
        "nodeLabels": null,
        "nodeTaints": null,
        "osSku": "CBLMariner",
        "osType": "Linux",
        "vmSize": "Standard_A4_v2"
      }
    ],
    "autoScalerProfile": null,
    "cloudProviderProfile": {
      "infraNetworkProfile": {
        "vnetSubnetIds": [
          "/subscriptions/xxx/resourceGroups/dcoffee-rg/providers/microsoft.azurestackhci/logicalnetworks/subnet1"
        ]
      }
    },
    "clusterVmAccessProfile": {
      "authorizedIpRanges": null
    },
    "controlPlane": {
      "controlPlaneEndpoint": {
        "hostIp": "10.0.1.9"
      },
      "count": 1,
      "vmSize": "Standard_A4_v2"
    },
    "kubernetesVersion": "1.27.3",
    "licenseProfile": {
      "azureHybridBenefit": "False"
    },
    "linuxProfile": {
      "ssh": {
        "publicKeys": [
          {
            "keyData": "ssh-rsa xxx"
          }
        ]
      }
    },
    "networkProfile": {
      "loadBalancerProfile": {
        "count": 0
      },
      "networkPolicy": "calico",
      "podCidr": "10.244.0.0/16"
    },
    "provisioningState": "Succeeded",
    "status": {
      "controlPlaneStatus": [
        {
          "errorMessage": null,
          "name": "ArcAgent",
          "phase": "provisioned",
          "ready": true
        },
        {
          "errorMessage": null,
          "name": "CloudProvider",
          "phase": "provisioned",
          "ready": true
        },
        {
          "errorMessage": null,
          "name": "Telemetry",
          "phase": "provisioned",
          "ready": true
        },
        {
          "errorMessage": null,
          "name": "CertificateAuthority",
          "phase": "provisioned",
          "ready": true
        },
        {
          "errorMessage": null,
          "name": "ProviderKeyVaultKms",
          "phase": "provisioned",
          "ready": true
        },
        {
          "errorMessage": null,
          "name": "ProviderCsiDriver",
          "phase": "provisioned",
          "ready": true
        },
        {
          "errorMessage": null,
          "name": "NfsCsiDriver",
          "phase": "provisioned",
          "ready": true
        },
        {
          "errorMessage": "Error: AddOnAvailable: csi-smb-controller: Deployment does not have minimum availability. ",
          "name": "SmbCsiDriver",
          "phase": "provisioning",
          "ready": null
        },
        {
          "errorMessage": null,
          "name": "KubeProxy",
          "phase": "provisioned",
          "ready": true
        }
      ],
      "currentState": "Succeeded",
      "errorMessage": null,
      "operationStatus": null
    },
    "storageProfile": {
      "nfsCsiDriver": {
        "enabled": true
      },
      "smbCsiDriver": {
        "enabled": true
      }
    }
  },
  "resourceGroup": "dcoffee-rg",
  "systemData": {
    "createdAt": "2024-06-21T02:22:04.427031+00:00",
    "createdBy": "xxx",
    "createdByType": "User",
    "lastModifiedAt": "2024-06-21T02:35:57.179071+00:00",
    "lastModifiedBy": "xxx",
    "lastModifiedByType": "Application"
  },
  "type": "microsoft.hybridcontainerservice/provisionedclusterinstances"
```

![Create kubernetes through Azure CLI Result1](images/Create-AKSCLI-Result1.png)
> the AKS cluster is running on subnet1 as defined in parameter

**Check on Windows Admin Center**

![Create kubernetes through Azure CLI Result2](images/Create-AKSCLI-Result2.png)
> You can see the deployment create 2 VMs: 1 Control Plane and 1 Worker Node from NodePool1
you also see that all the VMs are running on subnet1 (10.0.1.0/24)

### Task 3 - Connect to the kubernetes clusters

Now you can connect to your Kubernetes cluster by running the az connectedk8s proxy command from your development machine.
Make sure you sign in to Azure before running this command.
This command downloads the kubeconfig of your Kubernetes cluster to your development machine and opens a proxy connection channel to your on-premises Kubernetes cluster. The channel is open for as long as the command runs. Let this command run for as long as you want to access your cluster. 
If it times out, close the CLI window, open a fresh one, then run the command again.
You must have Contributor permissions on the resource group that hosts the Kubernetes cluster in order to run the following command successfully:

```powershell

$resource_group = "dcoffee-rg"
$aksclustername = "th-clus01-aks01"

# login first if you haven't already
az login --use-device-code

az connectedk8s proxy --name $aksclustername --resource-group $resource_group --file "~\.kube\config"

```

The output would be something like this:

```
PS C:\Users\LabAdmin> az connectedk8s proxy --name $aksclustername --resource-group $resource_group --file "~\.kube\config"
Proxy is listening on port 47011
Merged "th-clus01-aks01" as current context in C:\Users\LabAdmin\.kube\config
Start sending kubectl requests on 'th-clus01-aks01' context using kubeconfig at C:\Users\LabAdmin\.kube\config
Press Ctrl+C to close proxy.

```

Now open another terminal to use kubectl

```
PS C:\Users\LabAdmin> kubectl get nodes
NAME              STATUS   ROLES           AGE     VERSION
moc-ldg8d1iqwb3   Ready    control-plane   3d23h   v1.27.3
moc-lk3oqtsyffz   Ready    <none>          3d23h   v1.27.3
PS C:\Users\LabAdmin> kubectl get namespaces
NAME              STATUS   AGE
azure-arc         Active   3d23h
default           Active   3d23h
kube-node-lease   Active   3d23h
kube-public       Active   3d23h
kube-system       Active   3d23h
```

### Task 4 - Deploy Sample Application

#### Step 1 - Create a MetalLB load balancer from Azure Portal

The main purpose of a load balancer is to distribute traffic across multiple nodes in a Kubernetes cluster. 
This can help prevent downtime and improve overall performance of applications. 
AKS enabled by Azure Arc supports creating MetalLB load balancer instance on your Kubernetes cluster using the Arc Networking k8s-extension.

Prerequisite:
1. A Kubernetes cluster with at least one Linux node (created through portal or cli)
2. Assign IP Address for Load Balancer with the same subnet as the kubernetes logical networks. 
> Make sure it is outside of the pool and not overlapped with control plane IP address.

**Go to your AKS cluster and Navigate to Networking**

![Deploy MetalLB load balancer 1](images/Deploy-MetalLB1.png)
> Click Install to install the ArcNetworking k8s-extension

![Deploy MetalLB load balancer 2](images/Deploy-MetalLB2.png)

After the extension is successfully installed, you can create a load balancer service to the AKS cluster.

![Deploy MetalLB load balancer 3](images/Deploy-MetalLB3.png)
> Choose ARP for Adversite Mode since in this environment we don't have any BGP peers

**still failed**

![Deploy MetalLB load balancer Result](images/Deploy-MetalLB-Result.png)

#### Step 1a - Create a MetalLB load balancer from Azure CLI

**Install Azure CLI extensions**

```powershell
az extension add -n k8s-runtime --upgrade
az extension list
```

the output would be something like this:

```
PS C:\Users\LabAdmin> az extension add -n k8s-runtime --upgrade
Default enabled including preview versions for extension installation now. Disabled in future release. Use '--allow-preview true' to enable it specifically if needed. Use '--allow-preview false' to install stable version only.
PS C:\Users\LabAdmin> az extension list
[
  <snippets>
  {
    "experimental": false,
    "extensionType": "whl",
    "name": "k8s-runtime",
    "path": "C:\\Users\\LabAdmin\\.azure\\cliextensions\\k8s-runtime",
    "preview": false,
    "version": "1.0.1"
  },
<snippets>
]
```

**Install Load Balancer Arc extensions**

```powershell
$resource_group = "dcoffee-rg"
$aksclustername = "th-clus03-aks01"
$subscriptionID=""

az k8s-runtime load-balancer enable --resource-uri subscriptions/$subscriptionID/resourceGroups/$resource_group/providers/Microsoft.Kubernetes/connectedClusters/$aksclustername
```

the output would be something like this:

![Deploy AKS arc load balancer extensions](images/Deploy-arclb-extension.png)

**Deploy MetalLB load balancer**

```powershell
$resource_group = "dcoffee-rg"
$aksclustername = "th-clus03-aks01"
$subscriptionID=""

$lbName="aks01-lb"
$advertiseMode="ARP"
$ipRange="10.0.3.8/32"

az k8s-runtime load-balancer create --load-balancer-name $lbName --resource-uri "subscriptions/$subscriptionID/resourceGroups/$resource_group/providers/Microsoft.Kubernetes/connectedClusters/$aksclustername" --addresses $ipRange --advertise-mode $advertiseMode
```

**still failed**

![Deploy MetalLB load balancer Failed](images/Deploy-MetalLB-failed.png)

#### Step 1c - Create a MetalLB load balancer using Helmchart

This time we directly work with the given kubernetes cluster and use Helmchart to install MetalLB load balancer.

> remove any arcnetworking extensions first in the kubernetes cluster

**Install helmchart on Management Machine**

```powershell
scoop install helm
```

the output would be something like this:

```
PS C:\Users\LabAdmin> scoop install helm
Scoop uses Git to update itself. Run 'scoop install git' and try again.
Installing 'helm' (3.15.2) [64bit] from 'main' bucket
helm-v3.15.2-windows-amd64.zip (16.2 MB) [=============================================================================================] 100%
Checking hash of helm-v3.15.2-windows-amd64.zip ... ok.
Extracting helm-v3.15.2-windows-amd64.zip ... done.
Linking ~\scoop\apps\helm\current => ~\scoop\apps\helm\3.15.2
Creating shim for 'helm'.
'helm' (3.15.2) was installed successfully!
PS C:\Users\LabAdmin>
```

**Add MetalLB in the helmchart repo**

```powershell
helm repo list
helm repo add stable https://charts.helm.sh/stable
helm repo list
helm repo add metallb https://metallb.github.io/metallb
helm repo list
```

now you would have 2 repo including the metallb repo:

```
PS C:\Users\LabAdmin> helm repo list
Error: no repositories to show
PS C:\Users\LabAdmin> helm repo add stable https://charts.helm.sh/stable
"stable" has been added to your repositories
PS C:\Users\LabAdmin> helm repo list
NAME    URL
stable  https://charts.helm.sh/stable
PS C:\Users\LabAdmin> helm repo add metallb https://metallb.github.io/metallb
"metallb" has been added to your repositories
PS C:\Users\LabAdmin> helm repo list
NAME    URL
stable  https://charts.helm.sh/stable
metallb https://metallb.github.io/metallb
```

**Connect to the kubernetes and create new namespaces for metallb**

```powershell
$resource_group = "dcoffee-rg"
$aksclustername = "th-clus01-aks01"
az connectedk8s proxy --name $aksclustername --resource-group $resource_group --file "~\.kube\config"

# go to other terminal 
kubectl get namespaces
kubectl create namespace metallb-system
helm install metallb metallb/metallb --namespace metallb-system
```

the output would be something like this:
```
PS C:\Users\LabAdmin> kubectl create namespace metallb-system
namespace/metallb-system created

PS C:\Users\LabAdmin> kubectl get namespaces
NAME              STATUS   AGE
azure-arc         Active   4d4h
default           Active   4d4h
kube-node-lease   Active   4d4h
kube-public       Active   4d4h
kube-system       Active   4d4h
metallb-system    Active   7m11s
PS C:\Users\LabAdmin> helm install metallb metallb/metallb --namespace metallb-system
NAME: metallb
LAST DEPLOYED: Tue Jun 25 14:42:35 2024
NAMESPACE: metallb-system
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
MetalLB is now running in the cluster.

Now you can configure it via its CRs. Please refer to the metallb official docs
on how to use the CRs.
```

**Configure CR for Metallb**

Create the following yaml manifest and save as metallb.yaml in ~\Documents

```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: ippool
  namespace: metallb-system
spec:
  addresses:
  - 10.0.1.4-10.0.1.8
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2adv
  namespace: metallb-system
spec:
  ipAddressPools:
  - ippool
```

After that apply in kubectl and verified the metallb pods are deployed in metallb-system namespaces

```
dir .\Documents\
kubectl apply -f .\Documents\metallb.yaml
kubectl get pods -n metallb-system
```

the output should be something like this:
```
PS C:\Users\LabAdmin> kubectl apply -f .\Documents\metallb.yaml
ipaddresspool.metallb.io/ippool created
l2advertisement.metallb.io/l2adv created
PS C:\Users\LabAdmin> kubectl get pods -n metallb-system
NAME                                  READY   STATUS    RESTARTS   AGE
metallb-controller-57c69844b9-v5s6c   1/1     Running   0          12m
metallb-speaker-5944t                 4/4     Running   0          12m
metallb-speaker-kmzc7                 4/4     Running   0          12m
PS C:\Users\LabAdmin>
```

#### Step 2 - Deploy sample application

Now that we have load balancer in place, we could deploy sample application.

Create a file named azure-vote.yaml, and copy in the following manifest:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: azure-vote-back
spec:
  replicas: 1
  selector:
    matchLabels:
      app: azure-vote-back
  template:
    metadata:
      labels:
        app: azure-vote-back
    spec:
      nodeSelector:
        "kubernetes.io/os": linux
      containers:
      - name: azure-vote-back
        image: mcr.microsoft.com/oss/bitnami/redis:6.0.8
        env:
        - name: ALLOW_EMPTY_PASSWORD
          value: "yes"
        ports:
        - containerPort: 6379
          name: redis
---
apiVersion: v1
kind: Service
metadata:
  name: azure-vote-back
spec:
  ports:
  - port: 6379
  selector:
    app: azure-vote-back
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: azure-vote-front
spec:
  replicas: 1
  selector:
    matchLabels:
      app: azure-vote-front
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  minReadySeconds: 5 
  template:
    metadata:
      labels:
        app: azure-vote-front
    spec:
      nodeSelector:
        "kubernetes.io/os": linux
      containers:
      - name: azure-vote-front
        image: mcr.microsoft.com/azuredocs/azure-vote-front:v1
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 250m
          limits:
            cpu: 500m
        env:
        - name: REDIS
          value: "azure-vote-back"
---
apiVersion: v1
kind: Service
metadata:
  name: azure-vote-front
spec:
  type: LoadBalancer
  ports:
  - port: 80
  selector:
    app: azure-vote-front
```

Deploy the application using kubectl apply:

```
kubectl apply -f .\Documents\azure-vote.yaml
```

the output would be something like this:

```
PS C:\Users\LabAdmin> kubectl apply -f .\Documents\azure-vote.yaml
deployment.apps/azure-vote-back created
service/azure-vote-back created
deployment.apps/azure-vote-front created
service/azure-vote-front created
PS C:\Users\LabAdmin>
```

Check deployments and services in default namespace
```
PS C:\Users\LabAdmin> kubectl get all
NAME                                    READY   STATUS    RESTARTS   AGE
pod/azure-vote-back-8fd8d8db4-hplpq     1/1     Running   0          2m11s
pod/azure-vote-front-5698dd7765-bg92x   1/1     Running   0          2m9s

NAME                       TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
service/azure-vote-back    ClusterIP      10.100.123.236   <none>        6379/TCP       2m11s
service/azure-vote-front   LoadBalancer   10.98.67.239     10.0.1.4      80:30578/TCP   2m9s
service/kubernetes         ClusterIP      10.96.0.1        <none>        443/TCP        4d5h

NAME                               READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/azure-vote-back    1/1     1            1           2m13s
deployment.apps/azure-vote-front   1/1     1            1           2m11s

NAME                                          DESIRED   CURRENT   READY   AGE
replicaset.apps/azure-vote-back-8fd8d8db4     1         1         1       2m14s
replicaset.apps/azure-vote-front-5698dd7765   1         1         1       2m12s
```

Test by opening web browser from Management machine (you need to add new interface with the Vlan 1 and subnet 10.0.1.0/24 first)

![Sample Application Azure Vote](images/azure-vote-app.png)
