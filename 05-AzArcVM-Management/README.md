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
* Configure and clean up the VM (you can ssh or RDP)

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
* Shutdown the VM (run from Management Machine)
```powershell
$server = "th-mc660-1"
$vmname = "ubuntu-vm"
Invoke-Command -ComputerName $servers -ScriptBlock {
Stop-VM $vmname
}
```
* Create the VM Image using Azure CLI on one of the cluster node

```powershell
$ResourceGroupName="dcoffee-rg"
$Location="eastus"
$CustomLocation = "/subscriptions/368ac09c-01c9-4b47-9142-a7581c6694a3/resourcegroups/dcoffee-rg/providers/microsoft.extendedlocation/customlocations/dcoffee-clus01-cl"
$OsType = "Linux"
$SubscriptionID="368ac09c-01c9-4b47-9142-a7581c6694a3"
$ImagePath ="C:\ClusterStorage\UserStorage_1\ubuntu-vm\ubuntu-vm.vhdx"
$ImageName="Ubuntu-VM"
az login --use-device-code
az stack-hci-vm image create --subscription $SubscriptionID -g $ResourceGroupName --custom-location $CustomLocation --location $Location --image-path $ImagePath --name $ImageName --debug --os-type $OsType
```
#### Expected Result
![Ubuntu VM list](images/UbuntuVM-List.png)

### Task 2 - Create Logical Networks

This task will create multiple subnet that you can add as logical networks via portal to the clusters.
Please check detail documentation [here](https://learn.microsoft.com/en-us/azure-stack/hci/manage/create-logical-networks?tabs=azurecli).

#### Step - 1 Add New DHCP Scope in DHCP server (DC machine) 

Remember that in the Labconfig we have created Additional 4 networks in DC with corresponding VLAN 1-4
```powershell
# Additional Networks configuration in DC
$LABConfig.AdditionalNetworksConfig += @{ NetName = 'subnet1'; NetAddress='10.0.1.'; NetVLAN='1'; Subnet='255.255.255.0'}
$LABConfig.AdditionalNetworksConfig += @{ NetName = 'subnet2'; NetAddress='10.0.2.'; NetVLAN='2'; Subnet='255.255.255.0'}
$LABConfig.AdditionalNetworksConfig += @{ NetName = 'subnet3'; NetAddress='10.0.3.'; NetVLAN='3'; Subnet='255.255.255.0'}
$LABConfig.AdditionalNetworksConfig += @{ NetName = 'subnet4'; NetAddress='10.0.4.'; NetVLAN='4'; Subnet='255.255.255.0'}
```
We need to add the DHCP scopes to provide DHCP for those networks (I will activate DHCP for only Even Number networks, the Odd one should be inactive, hence client IP address will use static )
Run the following script on Management machine:
```powershell
#define networks, Odd number DHCP True, Even Number DHCP false
$domain="th.dcoffee.com"
$Server="DC"
$Networks=@()
1..4 | ForEach-Object{
    If ($_ % 2 -eq 0) {
        $dhcp=$True
    } else {
        $dhcp=$False
    }
    $Networks+= @{ Name="subnet$_"; VLANID=$_; NICIP="10.0.$_.1"; PrefixLength=24; ScopeID = "10.0.$_.0"; StartRange="10.0.$_.10"; EndRange="10.0.$_.254"; SubnetMask='255.255.255.0'; DomainName=$domain; DHCPEnabled=$dhcp }  
}

# add dhcp scope for all networks
foreach ($Network in $Networks){
    #Add DHCP Scope
    if (-not (Get-DhcpServerv4Scope -CimSession $Server -ScopeId $network.ScopeID -ErrorAction Ignore)){
        Add-DhcpServerv4Scope -CimSession $Server -StartRange $Network.StartRange -EndRange $Network.EndRange -Name $Network.Name -State Active -SubnetMask $Network.SubnetMask
    }
    #disable/enable
    if ($Network.DHCPEnabled){
        Set-DhcpServerv4Scope -CimSession $Server -ScopeId $Network.ScopeID -State Active
    }else{
        Set-DhcpServerv4Scope -CimSession $Server -ScopeId $Network.ScopeID -State InActive
    }

    #Configure dhcp options
    #6 - Domain Name Server
    Set-DhcpServerv4OptionValue -CimSession $Server -OptionId 6 -Value $Network.NICIP -ScopeId $Network.ScopeID
    #3 - Gateway
    Set-DhcpServerv4OptionValue -CimSession $Server -OptionId 3 -Value $Network.NICIP -ScopeId $Network.ScopeID
    #15 - Domain Name
    Set-DhcpServerv4OptionValue -CimSession $Server -OptionId 15 -Value $Network.DomainName -ScopeId $Network.ScopeID
}

#make sure routing is enabled on DC
Invoke-Command -ComputerName $Server -ScriptBlock {
    #restart routing... just to make sure
    Restart-Service RemoteAccess
}
```