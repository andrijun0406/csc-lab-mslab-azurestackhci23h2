# csc-lab-mslab-azurestackhci23h2
My hands-on Lab on Azure Stack HCI version 23H2 using MSLab
> Note: Password and Secrets are removed from scripts

## 1. Hydrating MSLab Files

I am creating a folder with a dummy domain name I use throughout the Lab. After hydrating MSLab files, this folder will contain Domain Controller - ready to be imported and parent disks: Windows Server 2022 and Azure Stack HCI 23H2. 
Please note that the Domain controller here is unique to this Lab and can not be changed later (I use the specific Domain Name and also DC admin password). If you want to change domain name and password, you must re-hydrate MSLAB files again from fresh.

### Task 1 - Check hardware requirement

* I'm using a large Hyper-V host VM with 48 vCPU and 384 GB of RAM. Just to make sure I can run all services like AKS and Azure Arc Enabled Data/App Services with ease
* I'm also using Windows Server 2022 Datacenter Edition. This Hyper-V hosts will run a nested VM for azure stack HCI cluster nodes
* This Hyper-V host VM also has two VHDX one is for OS (127GB) and another one is for MSLAB (5TB)

### Task 2 - Download all neccessary files

* MSLab scripts : [MSLab](https://aka.ms/mslab)
* latest Windows Server ISO: [MSDN Download](https://my.visualstudio.com/downloads) requires Visual Studio users.
* latest Azure Stack HCI ISO: [23H2](https://azure.microsoft.com/en-us/products/azure-stack/hci/hci-download/) requires login to azure portal.

### Task 3 - Hydrate Lab

1. Unzip files from MSLab zip folder into D:\MSLAB (volume from MSLAB VHDX where you have enough space here ~5TB)
![Initial MSLAB folder](images/MSLAB-folder-initial.png)
2. Replace content of LabConfig.ps1 with the following:
```powershell
$LabConfig=@{ 
    DomainAdminName=''; 
    AdminPassword=''; 
    Prefix = 'dcoffee-' ; 
    DCEdition='4'; 
    Internet=$true ;
    DomainNetbiosName="th"; 
    DomainName="th.dcoffee.com";
    AdditionalNetworksConfig=@(); 
    VMs=@()
}
```
> This will create custom Domain Controller (AD) built on top of Windows Server Datacenter with GUI. Some explanation of the parameters are the following:

- **DomainAdminName** : used during 2_CreateParentDisks (no affect if changed after this step)
- **AdminPassword** : used 2_CreateParentDisks. If changed after, it will break the functionality of 3_Deploy.ps1
- **Prefix** : All VMs and vSwitch are created with this prefix, so you can identify the lab. If not specified, Lab folder name is use
- **DCEdition** : 4 for DataCenter or 3 for DataCenterCore. We want a full GUI for DC so we choose 4.
- **Internet** : if $true it will use External vSwitch from MSLAB Hyper-V hosts and create vNIC to the DC and configure NAT with some Open DNS servers in DNS forwarder (8.8.8.8 and 1.1.1.1)
> Note: Make sure you enable MAC address spoofing in MSLAB Hyper-V hosts, and you might want to setup static IP address for your DC if you are using static in your environment otherwise DHCP would also work. You also might need to add DNS forwarders using your environment DNS servers.
- **DomainNetbiosName** : custom NetBios will be used instead default "Corp"
- **DomainName** : custom DomainName will be used instead of default "Corp.Contoso.Com"
- **AdditionalNetworksConfig** : empty array for additional network config later (not used in this step)
- **VMs** : empty array for specifying Lab VMs (not used in this step)
3. Right-click 1_Prereq.ps1 and select **Run with PowerShell**, the script will automatically elevate and run as administrator
4. The script will finish. it will download necessary files and create folders. Close PowerShell Window by pressing enter.
![1_Prereq.ps1 Result](images/1_Prereq.ps1-result.png)
5. Save as LabConfig.ps1 as [LabConfig.hydrate.ps1](LabConfig.hydrate.ps1) for documentation as we are going to use another version of LabConfig.ps1 in later step.
6. Right-click 2_CreateParentDisks.ps1 and select **Run with PowerShell**.
7. When asked for ISO image, choose Windows Server 2022 image.
8. When asked for Windows Server Update (msu), click **cancel**
> Script will now create Domain Controller and Windows Server 2022 parent disks. It will take 15-30 minutes to finish. Once Finished, press Enter to close window (it will cleanup unnecessary files and folders).

### Expected Result

in MSLAB folder you should see LAB and ParentDisks folder along with three PowerShell scripts and log files.
![MSLAB folder hydrated](images/MSLAB-folder-hydrate.png)

### Task 4 - Create Azure Stack HCI parent disk

1. Navigate to MSLAB folder and open ParentDisks folder
2. Right-click on CreateParentDisk.ps1 and select **Run with PowerShell**
3. When asked for ISO image, choose Azure Stack HCI 23H2 image. Hit Cancel when asked for MSU package.
4. When asked for VHD name and size, just hit enter (it will use default AzSHCI23H2_G2.vhdx and 127GB size) 
> Script will finish in few minutes. When done, press enter to close PowerShell window. Azure Stack HCI image will be created.
![Azure Stack HCI Parent Disk](images/AzureStackHCI-ParentDisk.png)

### Expected Result

Azure Stack HCI 23H2 image will be created in ParentDisks folder. Hydrating is done


## 2. Deploy Azure Stack HCI Cluster 23H2 using Cloud Based Deployment (Azure Portal)

Now, after MSLAB is hydrated we are ready to build 2 node of Azure Stack HCI clusters 23H2 (in nested VM) using cloud based deployment (Azure Portal). Read the microsoft document [here](https://learn.microsoft.com/en-us/azure-stack/hci/deploy/deploy-via-portal) for more detail.
> Note: Cloud Deployment is not yet supported from any OEM. Here we can get away to work nested VM with disabling bitlocker for OS and disabling WDAC (WDAC policy is distributed as part of Solution Builder Extensions)

### Task 1 - Customize deployment LabConfig and Deploy

1. Below LabConfig will deploy a large 2 virtual nodes (with 24 vCPU and 96GB RAM each) and also DC VM, Windows Admin Center Gateway (WAC GW) VM and Management VM. We will use range of VLAN for different subnets later on (for Storage traffic, Network ATC will use 711-712, for VM and AKS logical networks we can use Vlan 1-10),these VLANs are all internal, if require connection to Azure it will be routed and NATed from DC VM as the gateway.
```powershell
$LabConfig=@{
    AllowedVLANs="1-10,711-723"; 
    ManagementSubnetIDs=0..4; 
    DomainAdminName=''; 
    AdminPassword=''; 
    Prefix = 'dcoffee-' ; 
    DCEdition='4'; 
    Internet=$true ;
    UseHostDnsAsForwarder=$true; 
    #MGMTNICsInDC=4;
    AdditionalNetworksInDC=$true; 
    AdditionalNetworksConfig=@(); 
    VMs=@(); 
    DomainNetbiosName="th";
    DomainName="th.dcoffee.com";
    TelemetryLevel='Full' ; 
    TelemetryNickname='csc'
}

#pre-domain joined
1..2 | ForEach-Object {
    $VMNames="th-mc660-" ; 
    $LABConfig.VMs += @{ 
        VMName = "$VMNames$_" ; 
        Configuration = 'S2D' ; 
        ParentVHD = 'azshci23h2_g2.vhdx' ; 
        HDDNumber = 4; 
        HDDSize= 2TB ; 
        MemoryStartupBytes= 96GB; 
        VMProcessorCount="24"; 
        MGMTNICs=5 ; 
        NestedVirt=$true; 
        vTPM=$true;
        Unattend="NoDjoin"
    }
}

#add subnet 1-3

$LABConfig.AdditionalNetworksConfig += @{ 
        NetName = 'subnet1';                        # Network Name
        NetAddress='10.0.1.';                      # Network Addresses prefix. (starts with 1), therefore first VM with Additional network config will have IP 172.16.1.1
        NetVLAN='721';                                 # VLAN tagging
        Subnet='255.255.255.0'                       # Subnet Mask
    }
    $LABConfig.AdditionalNetworksConfig += @{ NetName = 'subnet2'; NetAddress='10.0.2.'; NetVLAN='722'; Subnet='255.255.255.0'}
    $LABConfig.AdditionalNetworksConfig += @{ NetName = 'subnet3'; NetAddress='10.0.3.'; NetVLAN='723'; Subnet='255.255.255.0'}

#Windows Admin Center gateway
$LabConfig.VMs += @{ VMName = 'WACGW' ; ParentVHD = 'Win2022Core_G2.vhdx' ; MGMTNICs=1 }

#Management machine
$LabConfig.VMs += @{ VMName = 'Management' ; ParentVHD = 'Win2022_G2.vhdx'; MGMTNICs=1 ; AddToolsVHD=$True }
```
2. Right-click on Deploy.ps1 and select **Run with PowerShell**

### Expected Result

Here are screenshot of successfull powershell script and view on Hyper-V Manager
![Deploy.ps1 Result1](images/Deploy.ps1-result-1.png)
![Deploy.ps1 Result2](images/Deploy.ps1-result-2.png)
> Make sure to start all VMs before going to the next task.

### Task 2 - Prepare Active Directory

These steps are inspired from Microsoft Documentation [here](https://learn.microsoft.com/en-us/azure-stack/hci/deploy/deployment-prep-active-directory). Please run the following PowerShell Script [PrepareAd.ps1](PrepareAD.ps1) from Management VM's PowerShell in elevated mode (Run As Administrator).
Adjust the script if necessary:
```powershell
$AsHCIOUName="OU=clus01,DC=th,DC=dcoffee,DC=com"
$LCMUserName=""
$LCMPassword=""
$SecuredPassword = ConvertTo-SecureString $LCMpassword -AsPlainText -Force
$LCMCredentials= New-Object System.Management.Automation.PSCredential ($LCMUserName,$SecuredPassword)

#install posh module for prestaging Active Directory
Install-PackageProvider -Name NuGet -Force
Install-Module AsHciADArtifactsPreCreationTool -Repository PSGallery -Force

#make sure active directory module and GPMC is installed
Install-WindowsFeature -Name RSAT-AD-PowerShell,GPMC

#populate objects
New-HciAdObjectsPreCreation -AzureStackLCMUserCredential  $LCMCredentials -AsHciOUName $AsHCIOUName

#install management features to explore cluster,settings...
Install-WindowsFeature -Name "RSAT-ADDS","RSAT-Clustering"
```
### Expected Result

![PrepareAD.ps1 Result1](images/PrepareAD.ps1-result-1.png)
![PrepareAD.ps1 Result2](images/PrepareAD.ps1-result-2.png)

### Task 3 - Prepare Azure

At this step make sure you have Azure Subscription and you have user that are a user access administrator and a contributor role, since we are going to create some resources like resource group.
Here I'm using ServicePrincipal because it's convinient to code and from security perspective you can use time limited secrets or certificates. If you use regular user, you need to interactively login with browser and finish the MFA (MultiFactorAuthentication) step.
Basically we are going to create a Resource Group to hold all the resources. Please run the following PowerShell Script [PrepareAzure.ps1](PrepareAzure.ps1) from Management VM's PowerShell in elevated mode (Run As Administrator).
Adjust the script if necessary:
```powershell
# Setup some variables
$ResourceGroupName="dcoffee-rg"
$Location="eastus" #make sure location is lowercase

# Make sure User or SPN is contributor and user access administrator in Azure Subscriptions
# We are using SPN here:
# fill out the following variable to your environment
$tenantID = ""
$AdminSPNAppID=""
$AdminPlainSecret=""
$AdminSecuredSecret = ConvertTo-SecureString $AdminPlainSecret -AsPlainText -Force
$AdminSPNCred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $AdminSPNAppID, $AdminSecuredSecret

#login to azure
#download and install Azure module

#Set PSGallery as a trusted repo
Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted

if (!(Get-InstalledModule -Name az.accounts -ErrorAction Ignore)){
	Install-Module -Name Az.Accounts -Force
}
if (-not (Get-AzContext)){
	Connect-AzAccount -ServicePrincipal -TenantId $tenantID -Credential $AdminSPNCred
}

#install az resources module
if (!(Get-InstalledModule -Name "az.resources" -ErrorAction Ignore)){
	Install-Module -Name "az.resources" -Force
}

#create resource group
if (-not(Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction Ignore)){
	New-AzResourceGroup -Name $ResourceGroupName -Location $location
}
```

### Expected Result

![PrepareAzure.ps1 Result](images/PrepareAzure.ps1-result.png)





