## 6. Azure Arc AKS Manaagement

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

![Create Kubernetes Cluster - Networking](images/Create-Kubernetes-Networking.png)

#### Step 6 - Integration

On The Integration page, configure the following options and click *Next: Tags*

```
Azure Monitor:

    Container monitoring:               Leave this as Disabled
   
```
> Note: We will do it later once the cluster is created if required (this will add some costs)

![Create Kubernetes Cluster - Integration](images/Create-Kubernetes-Integration.png)

#### Step 7 - Tags

On The Tags page, skip this and click *Next: Review + create*

Configuration will be validated click *Create*
![Create Kubernetes Cluster - Validation](images/Create-Kubernetes-Validation.png)

>You can aslo download a Template for automation later

### Task 2 - Create AKS cluster from Azure CLI

* MSLab scripts : [MSLab](https://aka.ms/mslab) make sure you are using the latest (currently its v24.05.1)
* latest Windows Server ISO: [MSDN Download](https://my.visualstudio.com/downloads) requires Visual Studio users.
* latest Azure Stack HCI ISO: [23H2](https://azure.microsoft.com/en-us/products/azure-stack/hci/hci-download/) requires login to azure portal.

