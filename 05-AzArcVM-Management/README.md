## 4. Azure Arc VM Management

Now that you have deployed your 23H2 cluster you are ready to create Arc VM from Portal. 
There are other way though, you can use Azure CLI, or Azure Resource Manager template too.
> make sure your entra user has at least **Contributor** level access at the subscription level

> make sure you are on supported region as per [Azure requirement](https://learn.microsoft.com/en-us/azure-stack/hci/concepts/system-requirements-23h2#azure-requirements)

> make sure your user has **"Azure Stack HCI Administrator"** Role

For more detail please check documentation [here](https://learn.microsoft.com/en-us/azure-stack/hci/manage/create-arc-virtual-machines?tabs=azureportal).

### Task 1 - Create VM Images from Azure Marketplace

This task will focus more on creating VM Images from Azure Marketplace. 
There are other way to create VM Images though: 1) using existing Image in Azure Storage Account or 2) using existing image in local share on your cluster.
> make sure you have storage path already created (deployment on Lab 02 already created 2 storage path)

#### Step 1 - Go to Resources > VM Images and Add VM Image from Azure MarketPlace
![Add VM Images from Marketplace](images/AddVMImages-Marketplace.png)
We are going to add Windows 2022 Data Center Azure Edition Hotpatch images
> remember your cluster custom location from cluster overview

Use the following options:
```
Basics:
    Subscription:       <use-your-subscription>
    Resource Group:     dcoffee-rg
    
    Save image as:      MarketPlaceWin22DCAzure-Hotpatch
    Custom Location:    dcoffee-clus03-cl
    Storage path:       Choose Automatically

Tags:
    <keep default>
```
![Add VM Images from Marketplace - Validate](images/AddVMImages-Marketplace-Validate.png)
![Add VM Images from Marketplace - Deploy](images/AddVMImages-Marketplace-Deploy.png)
![Add VM Images from Marketplace - Complete](images/AddVMImages-Marketplace-Complete.png)
#### Step 2 - Go to Resources > VM Images and List VM Images
![List VM Images](images/ListVMImages.png)
> When image download is complete, the VM image shows up in the list of images and the **Status** shows as **Available**.

#### Step 3 (optional) - Create Linux Image from Azure CLI
On this step we are going to create linux Image from Azure CLI. Linux images are not yet available from Marketplace for Azure Stack HCI
* Download the latest supported Ubuntu server image [here](https://ubuntu.com/download/server).  
* The supported OS versions are Ubuntu 18.04, 20.04, and 22.04 LTS
* Prepare VM image from Ubuntu Image from your azure stack cluster (using powershell)
> This will enable guest management on the VMs
Run the following script from Management Machine
```powershell
# Copy downloaded Ubuntu file to ClusterSharedVolume
copy-item -path .\ubuntu-24.04-live-server-amd64.iso -Destination '\\th-mc660-1\c$\ClusterStorage\UserStorage_1\'

# Create new Ubuntu VM
$server = "th-mc660-1"

Invoke-Command -ComputerName $servers -ScriptBlock {
    $vmname = "ubuntu-vm"
    $vmram = [int64]4GB
    $vmboot = "CD"
    $isopath="C:\ClusterStorage\UserStorage_1\ubuntu-24.04-live-server-amd64.iso"
    $vmvhdpath= "C:\ClusterStorage\UserStorage_1\$vmname\$vmname.vhdx"
    $vmpath="C:\ClusterStorage\UserStorage_1\$vmname"
    $vmswitch="ConvergedSwitch(compute_management_storage)"

    New-VM -Name $vmname -MemoryStartupBytes $vmram -NewVHDPath $vmvhdpath -NewVHDSizeBytes 40GB -Path $vmpath -Generation 2 -SwitchName $vmswitch
    Add-VMDvdDrive -VMName $vmname -Path $isopath
    Set-VMFirmware –VMName $vmname –EnableSecureBoot On -SecureBootTemplate "MicrosoftUEFICertificateAuthority"
    $vmfirmware = Get-VMFirmware -VMname $vmname
    Set-VMFirmware -VMName $vmname -BootOrder $vmfirmware.BootOrder[2],$vmfirmware.BootOrder[1],$vmfirmware.BootOrder[0]
    Set-VMProcessor $vmname -Count 2
    Start-VM $vmname
}
```
* Go to Windows admin center and connect to single hosts "th-mc660-1" using RDP (Choose download RDP file)
> the VM is not part of clustergroup yet so you can not use cluster view in Windows Admin Center
* Setup the Ubuntu OS and enter your admin username and password
![Setup Ubuntu OS](images/setup-ubuntuOS.png)
* Configure and clean up the VM

```bash
sudo apt update && sudo apt upgrade
sudo apt install linux-azure -y
sudo apt install openssh-server openssh-client -y
# configure passwordless sudo. add the following command at the end of /etc/sudoers file by using visudo
# sudo visudo
# ALL ALL=(ALL) NOPASSWD:ALL

sudo rm -f /etc/cloud/cloud.cfg.d/50-curtin-networking.cfg /etc/cloud/cloud.cfg.d/curtin-preserve-sources.cfg /etc/cloud/cloud.cfg.d/99-installer.cfg /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg
sudo rm -f /etc/cloud/ds-identify.cfg
sudo rm -f /etc/netplan/*.yaml

sudo cloud-init clean --logs --seed
sudo rm -rf /var/lib/cloud/ /var/log/* /tmp/*
sudo apt-get clean

rm -f ~/.bash_history 
export HISTSIZE=0 
logout
```
* Shutdown the VM
```powershell
$server = "th-mc660-1"
$vmname = "ubuntu-vm"
Invoke-Command -ComputerName $servers -ScriptBlock {
Stop-VM $vmname
}
```
* Create the VM Image using Azure CLI

```powershell
$ResourceGroupName="dcoffee-rg"
$Location="eastus" #make sure location is lowercase
$CustomLocation = "dcoffee-clus01-cl"
$OsType = "Linux"
$tenantID = "2fc994a3-81d2-4ba3-ad3e-c1d68b3aaf6b"
$AdminSPNAppID="d329535d-0cf4-473a-8646-8c612949142a"
$AdminPlainSecret="-WO8Q~P_CQVmZROiLSLptFaIuTxVXCf51hq5scLL"
$AdminSecuredSecret = ConvertTo-SecureString $AdminPlainSecret -AsPlainText -Force
$AdminSPNCred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $AdminSPNAppID, $AdminSecuredSecret
if (-not (Get-AzContext)){
	Connect-AzAccount -ServicePrincipal -TenantId $tenantID -Credential $AdminSPNCred
}
$SubscriptionID=(Get-AzContext).Subscription.ID
$ImagePath ="C:\ClusterStorage\UserStorage_1\ubuntu-vm\ubuntu-vm.vhdx"
$ImageName="Ubuntu-VM"
az stack-hci-vm image create --subscription $subscription -g $resource_group --custom-location $CustomLocation --location $location --image-path $ImagePath --name $ImageName --debug --os-type 'Linux'
```
![Ubuntu VM list](images/UbuntuVM-List.png)
### Task 2 - Create Logical Networks

This task will 