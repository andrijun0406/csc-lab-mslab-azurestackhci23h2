## 6. Azure Arc AKS Manaagement

One of the cool capabilities of Azure Arc enabled-AKS or AKS Hybrid is that now, you can create AKS cluster from Azure Portal, CLI and also ARM template. 
In this section I will describe in detail my experience deploying Azure Arc enabled AKS on Azure Stack HCI using Portal and CLI

* You need to have a working Azure Stack HCI version 23H3 cluster
* You need to have Kubernetes Cluster Administrator access (member of Microsoft Entra group)
* Noted down your Subscription ID and Custom Location ID
* You already created Logical Network, noted down the logical network ID. Please check this [step](../05-AzArcVM-Management/) if you have not.

### Task 1 - Create AKS cluster from Azure Portal

#### Go to your Azure Stack HCI Cluster in the portal and click Resources > Virtual Machines

![Create Kubernetes Cluster](images/Create-Kubernetes-Cluster.png)

### Task 2 - Create AKS cluster from Azure CLI

* MSLab scripts : [MSLab](https://aka.ms/mslab) make sure you are using the latest (currently its v24.05.1)
* latest Windows Server ISO: [MSDN Download](https://my.visualstudio.com/downloads) requires Visual Studio users.
* latest Azure Stack HCI ISO: [23H2](https://azure.microsoft.com/en-us/products/azure-stack/hci/hci-download/) requires login to azure portal.

