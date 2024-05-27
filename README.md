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
* latest Azure Stack HCI ISO: [23H2](https://azure.microsoft.com/en-us/products/azure-stack/hci/hci-download/)

### Task 3 - Hydrate Lab

* Unzip files from MSLab zip folder into D:\MSLAB (volume from MSLAB VHDX where you have enough space here ~5TB)
* Replace content of LabConfig.ps1 with the following:
```
$LabConfig=@{ DomainAdminName='LabAdmin'; AdminPassword='LS1setup!'; Prefix = 'adani-' ; DCEdition='4'; Internet=$true ; AdditionalNetworksConfig=@(); VMs=@(); DomainNetbiosName="ports"; DomainName="ports.adani.com";}
```
> this will create custom Domain Controller built on top of Windows Server Datacenter with GUI
* Right-click 1_Prereq.ps1 and select *Run with PowerShell*_
