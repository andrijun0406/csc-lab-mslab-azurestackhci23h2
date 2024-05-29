# csc-lab-mslab-azurestackhci23h2
My hands-on Lab on Azure Stack HCI version 23H2 using MSLab

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
```
$LabConfig=@{ 
    DomainAdminName='LabAdmin'; 
    AdminPassword='LS1setup!'; 
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

