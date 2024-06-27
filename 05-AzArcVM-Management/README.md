## 5. Azure Arc VM Management

Now that you have deployed your 23H2 cluster you are ready to create Arc VM from Portal. 
There are other way though, you can use Azure CLI, or Azure Resource Manager template too.
> make sure your entra user has at least **Contributor** level access at the subscription level

> make sure you are on supported region as per [Azure requirement](https://learn.microsoft.com/en-us/azure-stack/hci/concepts/system-requirements-23h2#azure-requirements)

> make sure your user has **"Azure Stack HCI Administrator"** Role

> for naming resourcse please consider [Azure naming best practice](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming#example-names-networking)

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
    Resource Group:     <use-your-resource-group>
    
    Save image as:      MarketPlaceWin22DCAzure-Hotpatch
    Custom Location:    <use-your-custom-location>
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
    Restart-Service DHCPServer
}
```
#### Expected Result

Got to DHCP MMC console
![DHCP Scope](images/DHCP-Scope.png)
> you might need to authorize the DHCP servers if it is suddenly de-authorized

* Test add new NIC in Management VM using Hyper-V Manager and set VLAN ID to 2 for example and see if it gets DHCP leased

#### Step - 2 Configure Logical Networks using PowerShell

Use the following PowerShell script which uses ARM template (json).
> Somehow for static logical networks we could not use -TemplateParamterObject in New-AzResourceGroupDeployment command
so we use -TemplateParameterFile instead and create new temporary parameter file in JSON.

```powershell
#define variables

$ClusterName="clus01"
$ClusterNodes=(Get-ClusterNode -Cluster $ClusterName).Name
$VirtualSwitchName=(Get-VMSwitch -CimSession $ClusterNodes[0]).Name
$Location="EastUS"
$ResourceGroupName=""
$CustomLocationName=""
$CustomLocationID=(Get-AzCustomLocation -ResourceGroupName $ResourceGroupName -Name $CustomLocationName).ID

# define networks manually

$Networks=@()
$Networks+= @{ Name='Management'; ipAllocationMethod="Dynamic"; vlan=0 ; tags=[PSCustomObject]@{}}
$Networks+= @{ Name='subnet1'; ipAllocationMethod="Static"; addressPrefix="10.0.1.0/24" ; vlan=1 ; ipPools=@("10.0.1.10","10.0.1.255") ; dnsServers=@("10.0.1.1") ; defaultGateway="10.0.1.1" ; tags=[PSCustomObject]@{}}
$Networks+= @{ Name='subnet2'; ipAllocationMethod="Dynamic"; vlan=2 ; tags=[PSCustomObject]@{}}
$Networks+= @{ Name='subnet3'; ipAllocationMethod="Static"; addressPrefix="10.0.3.0/24" ; vlan=3 ; ipPools=@("10.0.3.10","10.0.3.255") ; dnsServers=@("10.0.3.1") ; defaultGateway="10.0.3.1" ; tags=[PSCustomObject]@{}}
$Networks+= @{ Name='subnet4'; ipAllocationMethod="Dynamic"; vlan=4 ; tags=[PSCustomObject]@{}}


#create templates
$staticTemplate = @"
{
    "`$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "name": {
            "type": "String"
        },
        "ipAllocationMethod": {
            "type": "String"
        },
        "addressPrefix": {
            "type": "String"
        },
        "vlan": {
            "type": "Int"
        },
        "location": {
            "type": "String"
        },
        "customLocationId": {
            "type": "String"
        },
        "vmSwitchName": {
            "type": "String"
        },
        "tags": {
            "type": "Object"
        },
        "ipPools": {
            "type": "Array"
        },
        "dnsServers": {
            "type": "Array"
        },
        "defaultGateway": {
            "type": "String"
        }
    },
    "resources": [
        {
            "type": "microsoft.azurestackhci/logicalnetworks",
            "apiVersion": "2023-09-01-preview",
            "name": "[parameters('name')]",
            "location": "[parameters('location')]",
            "extendedLocation": {
                "type": "CustomLocation",
                "name": "[parameters('customLocationId')]"
            },
            "tags": {},
            "properties": {
                "subnets": [
                    {
                        "name": "[parameters('name')]",
                        "properties": {
                            "ipAllocationMethod": "[parameters('ipAllocationMethod')]",
                            "addressPrefix": "[parameters('addressPrefix')]",
                            "vlan": "[parameters('vlan')]",
                            "ipPools": "[parameters('ipPools')]",
                            "routeTable": {
                                "properties": {
                                    "routes": [
                                        {
                                            "name": "[parameters('name')]",
                                            "properties": {
                                                "addressPrefix": "0.0.0.0/0",
                                                "nextHopIpAddress": "[parameters('defaultGateway')]"
                                            }
                                        }
                                    ]
                                }
                            }
                        }
                    }
                ],
                "vmSwitchName": "[parameters('vmSwitchName')]",
                "dhcpOptions": {
                    "dnsServers": "[parameters('dnsServers')]"
                }
            }
        }
    ],
    "outputs": {}
}
"@

$DynamicTemplate=@"
{
    "`$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "name": {
            "type": "String"
        },
        "ipAllocationMethod": {
            "type": "String"
        },
        "vlan": {
            "type": "Int"
        },
        "location": {
            "type": "String"
        },
        "customLocationId": {
            "type": "String"
        },
        "vmSwitchName": {
            "type": "String"
        },
        "tags": {
            "type": "Object"
        }
    },
    "resources": [
        {
            "type": "microsoft.azurestackhci/logicalnetworks",
            "apiVersion": "2023-09-01-preview",
            "name": "[parameters('name')]",
            "location": "[parameters('location')]",
            "extendedLocation": {
                "type": "CustomLocation",
                "name": "[parameters('customLocationId')]"
            },
            "tags": {},
            "properties": {
                "subnets": [
                    {
                        "name": "[parameters('name')]",
                        "properties": {
                            "ipAllocationMethod": "[parameters('ipAllocationMethod')]",
                            "vlan": "[parameters('vlan')]"
                        }
                    }
                ],
                "vmSwitchName": "[parameters('vmSwitchName')]"
            }
        }
    ],
    "outputs": {}
}

"@

$templateFileStatic = New-TemporaryFile
Set-Content -Path $templateFileStatic.FullName -Value $staticTemplate

$templateFileDynamic = New-TemporaryFile
Set-Content -Path $templateFileDynamic.FullName -Value $DynamicTemplate

$ExistingNetworks=Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType microsoft.azurestackhci/logicalNetworks

foreach ($Network in $Networks){
    if (-not ($ExistingNetworks.Name -Contains $Network.Name)){
        if ($Network.ipAllocationMethod -eq "Dynamic"){
            $templateParameterObject = @{
                name = $network.name
                ipAllocationMethod = "Dynamic"
                vlan=$Network.VLAN
                location=$Location
                customLocationId=$CustomLocationID
                vmSwitchName=$VirtualSwitchName
                tags=$Network.Tags
            }
            New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile $templateFileDynamic.FullName -TemplateParameterObject $templateParameterObject
        }else{
            #this dows not work
            <#
            $TemplateParameterObject = @{
                name = $network.name
                ipAllocationMethod = "Static"
                addressPrefix = $Network.addressPrefix
                vlan=$Network.VLAN
                location=$Location
                customLocationId=$CustomLocationID
                vmSwitchName=$VirtualSwitchName
                ipPools=$Network.IPPools
                dnsServers=$Network.DNSServers
                defaultGateway=$Network.DefaultGateway
                tags=$Network.Tags
            }
            New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile $templateFileStatic.FullName -TemplateParameterObject $templateParameterObject
            #>
            #Create parameter file
            $ParamFile=@"
{
    "`$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "name": {
            "value": "$($network.name)"
        },
        "ipAllocationMethod": {
            "value": "Static"
        },
        "addressPrefix": {
            "value": "$($Network.addressPrefix)"
        },
        "vlan": {
            "value": $($Network.VLAN)
        },
        "location": {
            "value": "$Location"
        },
        "customLocationId": {
            "value": "$CustomLocationID"
        },
        "vmSwitchName": {
            "value": "$VirtualSwitchName"
        },
        "tags": {
            "value": {}
        },
        "ipPools": {
            "value": [
                {
                    "start": "$($Network.IPPools[0])",
                    "end": "$($Network.IPPools[1])"
                }
            ]
        },
        "dnsServers": {
            "value": [
                "$($Network.DNSServers)"
            ]
        },
        "defaultGateway": {
            "value": "$($Network.DefaultGateway)"
        }
    }
}
"@
        $parameterfile = New-TemporaryFile
        Set-Content -Path $parameterfile.FullName -Value $ParamFile
        New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile $templateFileStatic.FullName -TemplateParameterFile $parameterfile.FullName
        Remove-Item $parameterfile.FullName
        }

    }else{
        Write-Output "$($Network.Name) network already exists"
    }
}
Remove-Item $templateFileStatic.FullName
Remove-Item $templateFileDynamic.FullName
```

#### Expected Result
![Logical Networks Result](images/Logical-Networks-Result.png)

### Task 2a - Create Arc VMs (Windows) using DHCP from Portal

Now that you have all Azure resources created (VM Images and Logical Networks) you are ready to create Azure Arc VMs.
In this task, I will create Windows 2022 DC Azure Edition from Images that is created from Azure Marketplace and use Dynamic Network Interface using Dynamic Logical Networks (DHCP assigned).

#### Step 1 - Go to your Azure Stack HCI cluster in the portal and click Resources > Virtual Machines

![Create WinVM 1](images/Create-WinVM-1.png)

Use the following parameters to create Virtual Machine from Portal:
```
Basics:
    
    Project details

    Subscription:               <use-your-subscription>
    Resource Group:             <use-your-resource-group>

    Instance details

    Virtual machine name:       test-win22azure-vm
    Custom location:            <automatically populated and grayed out>
    Virtual machine kind:       <automatically populated and grayed out>
    Security type:              Standard (Choose Trusted launch VM if you want to enable secureboot and vTPM)
    Storage path:               Choose manually (UserStorage2-<id> (TB of TB available))
    Image:                      Win22DCAzure-Hotpatch
    Virtual processor count:    4
    Memory (MB):                8192 
    Memory type:                static

    VM extensions           
    
    Enable guest management:    Yes

    Administrator account

    Username:                   <use-local-administrator>
    Password:                   <use-local-administrator-password>
    Confirm password:           <confirmed-your-password>
    
    Domain join

    Enable domain join:         Leave this un-ticked (no need to have domain joined VM for now)
```
* Click Next
> I deliberately use UserStorage2 CSV for my VM just to balance the capacity

![Create WinVM Basics](images/Create-WinVM-Basics.png)

```
Disks:

    Add new disk
    
    <skip this step as we do not require data disk for now>
```
* Click Next

![Create WinVM Disks](images/Create-WinVM-Disks.png)

```
Networking:

    Add network interface (just one for now)
    
    Name:                   test-win22azure-vm-eth01
    Network:                subnet2 (this one use DHCP)
    IPv4 type:              DHCP
```

* Click Add and then Next

![Create WinVM Networking1](images/Create-WinVM-Networking1.png)
![Create WinVM Networking2](images/Create-WinVM-Networking2.png)

* Skip Tags for now

![Create WinVM Tags](images/Create-WinVM-Tags.png)

* Review and Create

![Create WinVM Review](images/Create-WinVM-Review.png)
> you can also download a template for creating with ARM template later

#### Step 2 - Check the Result

![Create WinVM Result1](images/Create-WinVM-Result1.png)
![Create WinVM Result2](images/Create-WinVM-Result2.png)

Let's see them on Windows Admin Center on-premise:

![Create WinVM Result3](images/Create-WinVM-Result3.png)
> After deployment there is always one VM running which is actually Arc Resource Bridge to provide Azure Arc Custom Location object.

Check whether DHCP provides leased IP address to this VM:

![Create WinVM Result4](images/Create-WinVM-Result4.png)

#### Step 3 - Connect to the VM

Now let's try to connect to the VM. First make sure guest management is running (I thought deployment has taken care guest deployment since I set enabled, but looks like it didn't enable it )

* Go to VM > Configuration and Enable Guest Management in VM extensions
![Enable Guest Management](images/Enable-Guest-Management.png)
![Enable Guest Management2](images/Enable-Guest-Management2.png)
![Enable Guest Management2](images/Enable-Guest-Management3.png)
> looks like it does not work enabling from portal, let's try from Azure CLI:
* Run the following script

```powershell
# verify VM is running

$VMname="test-win22azure-vm"
$RGname="dcoffee-rg"

# Install Az CLI module if not exists yet (we have not installed any in Management machine so let's install them)

$ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri https://aka.ms/installazurecliwindowsx64 -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; Remove-Item .\AzureCLI.msi

# you might need to close powershell windows and start a new one
az login --use-device-code
az stack-hci-vm show --name $VMname --resource-group $RGname

# it will ask you to install the stack-hci-vm extension, type Y
```
If the agent is running it will show the result as shown in the following snippets:
```
...
"vmAgent": {
        "statuses": [
          {
            "code": "ProvisioningState/succeeded",
            "displayStatus": "Connected",
            "level": "Info",
            "message": "Successfully established connection with mocguestagent",
            "time": "2024-06-14T00:22:10+00:00"
          },
          {
            "code": "ProvisioningState/succeeded",
            "displayStatus": "Connected",
            "level": "Info",
            "message": "New mocguestagent version detected 'v0.14.0-2-g5c6a4b32'",
            "time": "2024-06-14T00:22:11+00:00"
          }
        ],
        "vmConfigAgentVersion": "v0.14.0-2-g5c6a4b32"
      }
    }
...
```
> Look for **code: ProvisioningState/succeeded** and **displayStatus: Connected** this means the guest agent is running

* Enable guest management on a VM with guest agent running.

```powershell
az stack-hci-vm update --name $VMname --enable-agent true --resource-group $RGname
```
* Now the guest managemet is enabled in the Portal
![Enable Guest Management2](images/Enable-Guest-Management5.png)
* Now let's try to connect

Follow step here to enable SSH on Windows and Arc-enabled Servers:
* [SSH access to Azure Arc-enabled servers](https://learn.microsoft.com/en-us/azure/azure-arc/servers/ssh-arc-overview?tabs=azure-cli)
* [Get Started with OpenSSH for Windows](https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse?tabs=powershell)
> Note: You can also use OpenSSH for Arc-enabled servers extensions (install extension using portal or azure cli)

![Connect to VM1](images/Connect-VM1.png)
![Connect to VM1](images/Connect-ssh.png)
* Connecting VM from Windows Admin Center
![Connect to VM2](images/Connect-VM2.png)

### Task 2b - Create Arc VMs (Windows) using DHCP from Azure CLI

Run the following script from the cluster nodes.
> somehow it doesn't work remotely from Management machine

```powershell

# Define Parameters for Azure CLI

$vmName ="test2-win22azure-vm"
$subscription =  "<your-subscriptions>"
$resource_group = "dcoffee-rg"
$customLocationName = "dcoffee-clus01-cl"
$customLocationID ="/subscriptions/<your-subscriptions>/resourcegroups/dcoffee-rg/providers/microsoft.extendedlocation/customlocations/dcoffee-clus01-cl"
$location = "eastus"
$computerName = "th-mc660-1"
$userName = "LabAdmin"
$password = "<admin-password>"
$imageName ="Win22DCAzure-Hotpatch"
$nicName ="test2-win22azure-vm-eth01"   
$lnetName ="subnet2"

az login --use-device-code
    
# create network interface with dynamic IP(DHCP) - no need to specify ip address - only works for windows

az stack-hci-vm network nic create --subscription $subscription --resource-group $resource_group --custom-location $customLocationID --location $location --name $nicName --subnet-id $lnetName
az stack-hci-vm network nic list --resource-group $resource_group
az stack-hci-vm create --name $vmName --resource-group $resource_group --admin-username $userName --admin-password $password --computer-name $computerName --image $imageName --location $location --authentication-type all --nics $nicName --custom-location $customLocationID --hardware-profile memory-mb="8192" processors="4"
```

#### Expected Result

the network interface creation output would be something like this:

```
PS C:\Users\LabAdmin> az stack-hci-vm network nic create --subscription $subscription --resource-group $resource_group --custom-location $customLocationID --location $location --name $nicName --subnet-id $lnetName
Command group 'stack-hci-vm' is experimental and under development. Reference and support levels: https://aka.ms/CLI_refstatus
{
  "extendedLocation": {
    "name": "/subscriptions/368ac09c-01c9-4b47-9142-a7581c6694a3/resourcegroups/dcoffee-rg/providers/microsoft.extendedlocation/customlocations/dcoffee-clus01-cl",
    "type": "CustomLocation"
  },
  "id": "/subscriptions/368ac09c-01c9-4b47-9142-a7581c6694a3/resourceGroups/dcoffee-rg/providers/Microsoft.AzureStackHCI/networkinterfaces/test2-win22azure-vm-eth01",
  "location": "eastus",
  "name": "test2-win22azure-vm-eth01",
  "properties": {
    "dnsSettings": {
      "dnsServers": null
    },
    "ipConfigurations": [
      {
        "name": null,
        "properties": {
          "gateway": null,
          "prefixLength": null,
          "privateIpAddress": null,
          "privateIpAllocationMethod": null,
          "subnet": {
            "id": "/subscriptions/368ac09c-01c9-4b47-9142-a7581c6694a3/resourceGroups/dcoffee-rg/providers/Microsoft.AzureStackHCI/logicalnetworks/subnet2",
            "resourceGroup": "dcoffee-rg"
          }
        }
      }
    ],
    "macAddress": null,
    "provisioningState": "Succeeded",
    "resourceName": null,
    "status": {}
  },
  "resourceGroup": "dcoffee-rg",
  "systemData": {
    "createdAt": "2024-06-27T12:16:26.324640+00:00",
    "createdBy": "cscadmin@apjcsclocal.onmicrosoft.com",
    "createdByType": "User",
    "lastModifiedAt": "2024-06-27T12:18:06.036299+00:00",
    "lastModifiedBy": "319f651f-7ddb-4fc6-9857-7aef9250bd05",
    "lastModifiedByType": "Application"
  },
  "tags": null,
  "type": "microsoft.azurestackhci/networkinterfaces"
}
PS C:\Users\LabAdmin>
```

the output of VM creation would be something like this:

```
PS C:\Users\LabAdmin> az stack-hci-vm create --name $vmName --resource-group $resource_group --admin-username $userName --admin-password $password --computer-name $computerName --image $imageName --location $location --authentication-type all --nics $nicName --custom-location $customLocationID --hardware-profile memory-mb="8192" processors="4"
Command group 'stack-hci-vm' is experimental and under development. Reference and support levels: https://aka.ms/CLI_refstatus
{
  "extendedLocation": {
    "name": "/subscriptions/368ac09c-01c9-4b47-9142-a7581c6694a3/resourcegroups/dcoffee-rg/providers/microsoft.extendedlocation/customlocations/dcoffee-clus01-cl",
    "type": "CustomLocation"
  },
  "id": "/subscriptions/368ac09c-01c9-4b47-9142-a7581c6694a3/resourceGroups/dcoffee-rg/providers/Microsoft.HybridCompute/machines/test2-win22azure-vm/providers/Microsoft.AzureStackHCI/virtualMachineInstances/default",
  "name": "default",
  "properties": {
    "guestAgentInstallStatus": {
      "errorDetails": [
        {
          "code": "Timeout",
          "message": "Timed out installing ArcForServerAgent. Last error: rpc error: code = Unknown desc = Failed to run command due to error rpc error: code = Unknown desc = RunCommand request [VirtualMachine:<name:\"test2-win22azure-vm-368ac09c-01c9-4b47-9142-a7581c6694a3-dcoffee-rg-0aff56b7\" id:\"DC34A70D-9F7E-4B25-9FF9-718B75F1FE30\" os:<> > Source:<CommandID:\"InstallArcAgent\" > RunCommandInputParameters:<Name:\"AgentConfig\" Value:\"{\\\"cloud\\\":\\\"AzureCloud\\\",\\\"vmid\\\":\\\"d0b6dd9b-f9e1-43d3-8ff7-dc4cfdd3be0d\\\",\\\"kind\\\":\\\"HCI\\\",\\\"private-key\\\":\\\"MIIEpQIBAAKCAQEA1lmk8G4Q1NUdQ+oAkT2yne5L5oCDroaV6zZZLFZWIU6/nN4sflbuj4ozEVhk+o/UmStfv8Ya6dETyF/jFFQrIIHdSSQ4Tq7eIb7lbm159QnmcKf1JZEYOUfVJ3nWQjIsUJTpP1qxGGruax47QfwY/lcI5TzbtLXbZBHJ0fl7Ne1CuYpGUOyKslf46zyDsa5IX6/aT3Wz8nOd5Y90dTpsyueW9mQ07ziPuoa6E81W2ZDNNr3HOTZhbUrge1Qtg55KKelKvFA6mttpbys4rBkp5+FHcywnGUkMeRGe2skHsgoCXiiQqx2G7pO4/4YofZxc6oBzQmYpmW1Zz3XRWjd0fwIDAQABAoIBAF0LTK2RGX1JhQqV6Oki/wXPCuNjpcV8ZldToCG+2GRc6pANYQL2eVeVhdVhqXOaO47BZS65r7UPLKct+EQ6xP23YXb+YfLFtWawlqb4npffVEhSn/dOpFU4+S3JlVfmr5XLDfSSSY1v3U5iMRbTd4XwAcyAPl6TEki97/1VbkZZizaqAfZTjXozIFwjAgFcezmedybyEwGcmQzScBdjcLpcb2wPfF98Y3R+oc4iRCQo3vYsYD7BGYqTW0ToSfrUvEMG0U8YnPqGLUivtAaSGg5sSSxCgMo4sPXpjgZh4a1lFg9psdGBPBGjydCLW76dx+IjxARTHQrpWx4fdcZSxAECgYEA2CkkVsblxL8H5hsjPJkKT9uu4JbGlHHhmNLzB+1zHbBkWA5AEkE4Qduat2MkaEsEEzhBHyiO/PJm/HX3NE2NoAZEaxKUnkDFkXE5b56uIgrD27ttykOAj8l48Mxggg5VVBuM20QvgANG6kWvIDmf9rwpMuBFcygdxIWPGWXlLG8CgYEA/dsT7qwZvqCpZCtaX9JkEs84HRehETb/yDo/JsEyEhMx86v3bNb1DBAlHVsZEshQOdvUSKYYV/4V8Z/3w58u+yGZv4B293bac+9JEWs9PSHhmZI0BcFleIXkF07E4s1mUsqHikAr0TAf7REwxDdfsDBAcmqO/ZZmkObj8qWhYPECgYEAzBbENZ5jUEihN5QFx/Ai+VVMnsYcxglj2/vH9IMvvidOBoml2tZzPFMQl/dmZ4X0WgUyDy4nGxHvRIxIk7xpbF6eeI25flVfdDv347hpZsDNPYiQV3k2SAwMQSZmNEU+MUQ10MxnILF3Yjfa6k0eCEKNj3iKefi1alhDzNIU98cCgYEAz9THqdSeszHn3MmdkOu34KpkX3UT+fsUSEJfp4PuUVwDvmJhDGukbb7eE/2cNoNnIyd10hChx5CPOKXl+/NcTGBC9sTfIVTeHqKeKLOqjF0rzUYkbz3ZrGW5ytdDXAgbqNaFR0uoU/hZewZi7ZIENkQaz1GsRbMXv7Q4lVTDHZECgYEA1m9SB+oaEdU+/hLrqPtV9QMIs6xMjH6Gqthx4Mn+GW7jrRU/BrLeJWVzrXIuGjgH9itEyPp/tCPYTX0rbEpzUIz9Dvblt0z60df1QEwYb6Nl1fm8HrfRupeRhwVDssbvgSawUor0ASGJCWJcdj7ZvK5nVxQz8UBXIRRlEBPOjp8=\\\",\\\"resource-name\\\":\\\"test2-win22azure-vm\\\",\\\"subscription-id\\\":\\\"368ac09c-01c9-4b47-9142-a7581c6694a3\\\",\\\"resource-group\\\":\\\"dcoffee-rg\\\",\\\"resource-namespace\\\":\\\"Microsoft.HybridCompute\\\",\\\"tenant-id\\\":\\\"2fc994a3-81d2-4ba3-ad3e-c1d68b3aaf6b\\\",\\\"location\\\":\\\"eastus\\\",\\\"correlation-id\\\":\\\"eff6a40f-dd47-427a-a13e-e365e18321b2\\\",\\\"msi-cert-retries\\\":26,\\\"proxyurl\\\":\\\"\\\"}\" > OperationID:\"82d838f1-3487-11ef-a5a3-02ec00110008\" ] returned with FAILED execution state: Run Command Failed: Run Command Failed: Run Command Failed"
        }
      ],
      "status": "Failed"
    },
    "hardwareProfile": {
      "dynamicMemoryConfig": {
        "maximumMemoryMb": null,
        "minimumMemoryMb": null,
        "targetMemoryBuffer": null
      },
      "memoryMb": 8192,
      "processors": 4,
      "vmSize": "Custom"
    },
    "httpProxyConfig": null,
    "instanceView": {
      "vmAgent": {
        "statuses": [
          {
            "code": "ProvisioningState/succeeded",
            "displayStatus": "Connected",
            "level": "Info",
            "message": "Successfully established connection with mocguestagent",
            "time": "2024-06-27T12:57:52Z"
          },
          {
            "code": "ProvisioningState/succeeded",
            "displayStatus": "Connected",
            "level": "Info",
            "message": "New mocguestagent version detected 'v0.14.0-2-g5c6a4b32'",
            "time": "2024-06-27T12:57:48Z"
          }
        ],
        "vmConfigAgentVersion": "v0.14.0-2-g5c6a4b32"
      }
    },
    "networkProfile": {
      "networkInterfaces": [
        {
          "id": "/subscriptions/368ac09c-01c9-4b47-9142-a7581c6694a3/resourceGroups/dcoffee-rg/providers/Microsoft.AzureStackHCI/networkinterfaces/test2-win22azure-vm-eth01",
          "resourceGroup": "dcoffee-rg"
        }
      ]
    },
    "osProfile": {
      "adminPassword": null,
      "adminUsername": "LabAdmin",
      "computerName": "th-mc660-1",
      "linuxConfiguration": {
        "disablePasswordAuthentication": false,
        "provisionVmAgent": true,
        "provisionVmConfigAgent": true,
        "ssh": {
          "publicKeys": null
        }
      },
      "windowsConfiguration": {
        "enableAutomaticUpdates": null,
        "provisionVmAgent": true,
        "provisionVmConfigAgent": true,
        "ssh": {
          "publicKeys": null
        },
        "timeZone": null
      }
    },
    "provisioningState": "Succeeded",
    "securityProfile": {
      "enableTpm": false,
      "securityType": null,
      "uefiSettings": {
        "secureBootEnabled": true
      }
    },
    "status": {
      "errorCode": "",
      "errorMessage": "",
      "powerState": "Running"
    },
    "storageProfile": {
      "dataDisks": [],
      "imageReference": {
        "id": "/subscriptions/368ac09c-01c9-4b47-9142-a7581c6694a3/resourceGroups/dcoffee-rg/providers/microsoft.azurestackhci/marketplacegalleryimages/Win22DCAzure-Hotpatch",
        "resourceGroup": "dcoffee-rg"
      },
      "osDisk": {
        "id": null,
        "osType": "Windows"
      },
      "storagepathId": "/subscriptions/368ac09c-01c9-4b47-9142-a7581c6694a3/resourceGroups/dcoffee-rg/providers/Microsoft.AzureStackHCI/storagecontainers/UserStorage2-ffb0cb403cc44734b9f4ad113a7f9d4c"
    },
    "vmId": "d0b6dd9b-f9e1-43d3-8ff7-dc4cfdd3be0d"
  },
  "resourceGroup": "dcoffee-rg",
  "systemData": {
    "createdAt": "2024-06-27T12:42:13.594634+00:00",
    "createdBy": "cscadmin@apjcsclocal.onmicrosoft.com",
    "createdByType": "User",
    "lastModifiedAt": "2024-06-27T13:19:34.318660+00:00",
    "lastModifiedBy": "319f651f-7ddb-4fc6-9857-7aef9250bd05",
    "lastModifiedByType": "Application"
  },
  "tags": null,
  "type": "microsoft.azurestackhci/virtualmachineinstances"
}
PS C:\Users\LabAdmin>
```
> Note: arcAgent is failed to install with the following error:

```
Timed out installing ArcForServerAgent. 
Last error: rpc error: code = Unknown desc = Failed to run command due to error rpc error: code = Unknown desc = RunCommand request [VirtualMachine:<name:\"test2-win22azure-vm-368ac09c-01c9-4b47-9142-a7581c6694a3-dcoffee-rg-0aff56b7\" id:\"DC34A70D-9F7E-4B25-9FF9-718B75F1FE30\" os:<> > Source:<CommandID:\"InstallArcAgent\" > RunCommandInputParameters:<Name:\"AgentConfig\" Value:\"{\\\"cloud\\\":\\\"AzureCloud\\\",\\\"vmid\\\":\\\"d0b6dd9b-f9e1-43d3-8ff7-dc4cfdd3be0d\\\",\\\"kind\\\":\\\"HCI\\\",\\\"private-key\\\":\\\"MIIEpQIBAAKCAQEA1lmk8G4Q1NUdQ+oAkT2yne5L5oCDroaV6zZZLFZWIU6/nN4sflbuj4ozEVhk+o/UmStfv8Ya6dETyF/jFFQrIIHdSSQ4Tq7eIb7lbm159QnmcKf1JZEYOUfVJ3nWQjIsUJTpP1qxGGruax47QfwY/lcI5TzbtLXbZBHJ0fl7Ne1CuYpGUOyKslf46zyDsa5IX6/aT3Wz8nOd5Y90dTpsyueW9mQ07ziPuoa6E81W2ZDNNr3HOTZhbUrge1Qtg55KKelKvFA6mttpbys4rBkp5+FHcywnGUkMeRGe2skHsgoCXiiQqx2G7pO4/4YofZxc6oBzQmYpmW1Zz3XRWjd0fwIDAQABAoIBAF0LTK2RGX1JhQqV6Oki/wXPCuNjpcV8ZldToCG+2GRc6pANYQL2eVeVhdVhqXOaO47BZS65r7UPLKct+EQ6xP23YXb+YfLFtWawlqb4npffVEhSn/dOpFU4+S3JlVfmr5XLDfSSSY1v3U5iMRbTd4XwAcyAPl6TEki97/1VbkZZizaqAfZTjXozIFwjAgFcezmedybyEwGcmQzScBdjcLpcb2wPfF98Y3R+oc4iRCQo3vYsYD7BGYqTW0ToSfrUvEMG0U8YnPqGLUivtAaSGg5sSSxCgMo4sPXpjgZh4a1lFg9psdGBPBGjydCLW76dx+IjxARTHQrpWx4fdcZSxAECgYEA2CkkVsblxL8H5hsjPJkKT9uu4JbGlHHhmNLzB+1zHbBkWA5AEkE4Qduat2MkaEsEEzhBHyiO/PJm/HX3NE2NoAZEaxKUnkDFkXE5b56uIgrD27ttykOAj8l48Mxggg5VVBuM20QvgANG6kWvIDmf9rwpMuBFcygdxIWPGWXlLG8CgYEA/dsT7qwZvqCpZCtaX9JkEs84HRehETb/yDo/JsEyEhMx86v3bNb1DBAlHVsZEshQOdvUSKYYV/4V8Z/3w58u+yGZv4B293bac+9JEWs9PSHhmZI0BcFleIXkF07E4s1mUsqHikAr0TAf7REwxDdfsDBAcmqO/ZZmkObj8qWhYPECgYEAzBbENZ5jUEihN5QFx/Ai+VVMnsYcxglj2/vH9IMvvidOBoml2tZzPFMQl/dmZ4X0WgUyDy4nGxHvRIxIk7xpbF6eeI25flVfdDv347hpZsDNPYiQV3k2SAwMQSZmNEU+MUQ10MxnILF3Yjfa6k0eCEKNj3iKefi1alhDzNIU98cCgYEAz9THqdSeszHn3MmdkOu34KpkX3UT+fsUSEJfp4PuUVwDvmJhDGukbb7eE/2cNoNnIyd10hChx5CPOKXl+/NcTGBC9sTfIVTeHqKeKLOqjF0rzUYkbz3ZrGW5ytdDXAgbqNaFR0uoU/hZewZi7ZIENkQaz1GsRbMXv7Q4lVTDHZECgYEA1m9SB+oaEdU+/hLrqPtV9QMIs6xMjH6Gqthx4Mn+GW7jrRU/BrLeJWVzrXIuGjgH9itEyPp/tCPYTX0rbEpzUIz9Dvblt0z60df1QEwYb6Nl1fm8HrfRupeRhwVDssbvgSawUor0ASGJCWJcdj7ZvK5nVxQz8UBXIRRlEBPOjp8=\\\",\\\"resource-name\\\":\\\"test2-win22azure-vm\\\",\\\"subscription-id\\\":\\\"368ac09c-01c9-4b47-9142-a7581c6694a3\\\",\\\"resource-group\\\":\\\"dcoffee-rg\\\",\\\"resource-namespace\\\":\\\"Microsoft.HybridCompute\\\",\\\"tenant-id\\\":\\\"2fc994a3-81d2-4ba3-ad3e-c1d68b3aaf6b\\\",\\\"location\\\":\\\"eastus\\\",\\\"correlation-id\\\":\\\"eff6a40f-dd47-427a-a13e-e365e18321b2\\\",\\\"msi-cert-retries\\\":26,\\\"proxyurl\\\":\\\"\\\"}\" > OperationID:\"82d838f1-3487-11ef-a5a3-02ec00110008\" ] returned with FAILED execution state: Run Command Failed: Run Command Failed: Run Command Failed"
```

![Create Windows VM with CLI 1](images/Create-WinVM-Result5.png)
![Create Windows VM with CLI 1](images/Create-WinVM-Result6.png)

### Task 3 - Create Arc VMs (Linux) using Static from Azure CLI

Run the following script from the cluster nodes.
> somehow it doesn't work remotely from Management machine

```powershell

# Define parameters for Azure CLI

$vmName ="test-ubuntu-vm"
$subscription = "<your-subscriptions>"
$resource_group = "dcoffee-rg"
$customLocationName = "dcoffee-clus01-cl"
$customLocationID ="/subscriptions/<your-subscriptions>/resourcegroups/dcoffee-rg/providers/microsoft.extendedlocation/customlocations/dcoffee-clus01-cl"
$location = "eastus"
$userName = "labadmin"
$password = "<admin-password>"
$imageName ="Ubuntu-VM"
$nicName ="test-ubuntu-vm-eth01"
$storagePathName = "UserStorage2-ffb0cb403cc44734b9f4ad113a7f9d4c"
$storagePathId = "/subscriptions/<your-subscriptions>/resourceGroups/dcoffee-rg/providers/Microsoft.AzureStackHCI/storagecontainers/UserStorage2-ffb0cb403cc44734b9f4ad113a7f9d4c"
$lnetName = "subnet1"
$gateway ="10.0.1.1"
$ipAddress ="10.0.1.10"
$computerName = "th-mc660-1"


az login --use-device-code

# create network interface with static IP

az stack-hci-vm network nic create --subscription $subscription --resource-group $resource_group --custom-location $customLocationID --location $location --name $nicName --subnet-id $lnetName --ip-address $ipAddress
az stack-hci-vm network nic list --resource-group $resource_group
az stack-hci-vm create --name $vmName --resource-group $resource_group --admin-username $userName --admin-password $password --computer-name $computerName --image $imageName --location $location --authentication-type all --nics $nicName --custom-location $customLocationID --hardware-profile memory-mb="8192" processors="4" --storage-path-id $storagePathId
```

#### Expected Result

so far no luck:

```
moc-operator virtualmachine serviceClient returned an error while reconciling: 
rpc error: code = Unknown desc = Could not establish HyperV connection for VM ID [B1BF4AE9-ECA6-4AE8-ABEF-C64581E3FCFB] within [900] seconds, 
error: [<nil>] (Code: moc-operator virtualmachine serviceClient returned an error while reconciling: rpc error: 
code = Unknown desc = Could not establish HyperV connection for VM ID [B1BF4AE9-ECA6-4AE8-ABEF-C64581E3FCFB] within [900] seconds, error: [<nil>])
```

### Task 3b - Create Arc VMs (Linux) using Static from Portal

* Basics
```
Basics:
    
    Project details

    Subscription:               <use-your-subscription>
    Resource Group:             <use-your-resource-group>

    Instance details

    Virtual machine name:       test-ubuntu1-vm
    Custom location:            <automatically populated and grayed out>
    Virtual machine kind:       <automatically populated and grayed out>
    Security type:              Standard (Choose Trusted launch VM if you want to enable secureboot and vTPM)
    Storage path:               Choose automatically
    Image:                      Ubuntu-VM
    Virtual processor count:    4
    Memory (MB):                8192 
    Memory type:                static

    VM extensions           
    
    Enable guest management:    Yes

    Root user

    Username:                   labadmin (not azureuser)
    Password:                   <use-local-administrator-password>
    Confirm password:           <confirmed-your-password>
    SSH public key resources:   Generate new key pair
    Key pair name:              test-ubuntu1-vm_key_
```
![Create Linux VM - Basics](images/Create-UbuntuVM-Basics.png)

* Disks
```
Disks:

    Add new disk
    
    <skip this step as we do not require data disk for now>
```
![Create Linux VM - Disks](images/Create-UbuntuM-Disks.png)

* Networking
```
Networking:

    Add network interface (just one for now)
    
    Name:                   test-ubuntu1-vm-eth01
    Network:                subnet1 (this one use Static)
    IPv4 type:              Static
    Allocation Method       Automatic (let it be assigned from pool)
```
![Create Linux VM - Networking1](images/Create-UbuntuVM-Networking1.png)
![Create Linux VM - Networking2](images/Create-UbuntuVM-Networking2.png)

* Tags
![Create Linux VM - Tags](images/Create-UbuntuVM-Tags.png)

* Review and Create
![Create Linux VM - Tags](images/Create-UbuntuVM-Review.png)

#### Expected Result

So far no luck too the same error as when creating azure CLI:

![Create Linux VM - Error](images/Create-UbuntuVM-Error.png)