## 8. Test Azure Stack HCI Performance

### Prerequisites

* Follow Lab 1 - 2 to have a working Azure Stack HCI Clusters
* You will need the following ready in Management Machine:
	* Small Windows Server 2022 Core VHD (30GB size) for VMFleet Image baseline template. We are going to create this in Task 1, yo need to have the original Windows Server 2022 ISO.
	* CreateParentDisk.ps1 script
	* Convert-WindowsImage.ps1 script
	* CreateVMFleetDisk.ps1 script
* The script above has been created when you hydrated them in Lab 1. Copy them to the Management Machine

### Task 1 - Create Windows Server 2022 Core VHD

Let's create a small Windows Server 2022 Core VHD (30GB Size).

#### Step 1 - Ensure Management Machine has Hyper-V PowerShell Module and Hyper-V itself (to work with VHDs).

```powershell
#install Hyper-V using DISM, run the powershell as Administrator
Enable-WindowsOptionalFeature -FeatureName Microsoft-Hyper-V -Online -All -NoRestart
Install-WindowsFeature -Name "RSAT-Hyper-V-Tools"
```

Ouput of required Hyper-V modules is something like this:

```
PS C:\Windows\system32> get-Windowsfeature -Name "*Hyper-V*"

Display Name                                            Name                       Install State
------------                                            ----                       -------------
[X] Hyper-V                                             Hyper-V                        Installed
        [X] Hyper-V Management Tools                    RSAT-Hyper-V-Tools             Installed
            [X] Hyper-V GUI Management Tools            Hyper-V-Tools                  Installed
            [X] Hyper-V Module for Windows PowerShell   Hyper-V-PowerShell             Installed
```

#### Step 2 - Run CreateParentDisk.ps1 by right-clicking and selecting "Run with PowerShell"
#### Step 3 - Once asked, provide Windows Server 2022 ISO. Hit cancel to skip msu (cummulative update).
#### Step 4 - Select Windows Server 2022 DataCenter (Core or No Desktop Experience)
#### Step 5 - Hit Enter to keep the default name (Win2022Core_G2.vhdx) and Type 30 for 30GB VHD size

#### Expected Result

![Create Small Windows Server 2022 Core VHD](images/Create-SmallWindowsServerTemplate.png)

### Task 2 - Create VMFleet Image

Now, it's time to create VMFleet Image:

#### Step 1 - Run CreateVMFleetDisk.ps1 by right-clicking and selecting run with PowerShell
#### Step 2 - Provide Small Windows Server VHD that we've created in the Task 1
#### Step 3 - Provide Password for VMFleet Image (Please keep this password handy)

#### Expected Result

![Create VMFleet Image](images/Create-VMFleetImage.png)

### Task 3 - Configure VMFleet Prerequisite

> Run all the steps from Management Machine

#### Step 1 - Install required PowerShell Module:

```powershell
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    Install-Module -Name VMFleet -Force
    Install-Module -Name PrivateCloud.DiagnosticInfo -Force
```

#### Step 2 - Defined Variables and create "Collect" Volumes

```powershell
# Defined Variables

$ClusterName="clus02"
$Nodes=(Get-ClusterNode -Cluster $ClusterName).Name
# $size = Get-FleetVolumeEstimate
$CollectVolumeSize=200GB
$VMFleetVolumeSize=1TB
$StoragePool=Get-StoragePool -CimSession $ClusterName | Where-Object OtherUsageDescription -eq "Reserved for S2D"

# Create Volumes for VMs (thin provisioned)
    
Foreach ($Node in $Nodes){
    if (-not (Get-Virtualdisk -CimSession $ClusterName -FriendlyName $Node -ErrorAction Ignore)){
        New-Volume -CimSession $Node -StoragePool $StoragePool -FileSystem CSVFS_ReFS -FriendlyName $Node -Size $VMFleetVolumeSize -ProvisioningType Thin
    }
}

# Create Collect volume (thin provisioned)

if (-not (Get-Virtualdisk -CimSession $ClusterName -FriendlyName Collect -ErrorAction Ignore)){
    New-Volume -CimSession $CLusterName -StoragePool $StoragePool -FileSystem CSVFS_ReFS -FriendlyName Collect -Size $CollectVolumeSize -ProvisioningType Thin


# Show resulting volume

Get-VirtualDisk -CimSession $ClusterName
```
The output would be something like this:

```
PS C:\Windows\system32> # Defined Variables
>>
>> $ClusterName="clus02"                                                                                                                                                                                                                    
>> $Nodes=(Get-ClusterNode -Cluster $ClusterName).Name                                                                                                                                                                                      
>> # $size = Get-FleetVolumeEstimate                                                                                                                                                                                                        
>> $CollectVolumeSize=200GB                                                                                                                                                                                                                 
>> $VMFleetVolumeSize=1TB                                                                                                                                                                                                                   
>> $StoragePool=Get-StoragePool -CimSession $ClusterName | Where-Object OtherUsageDescription -eq "Reserved for S2D"                                                                                                                        
>> 
>> #Create Volumes for VMs (thin provisioned)
>>
>> Foreach ($Node in $Nodes){
>>     if (-not (Get-Virtualdisk -CimSession $ClusterName -FriendlyName $Node -ErrorAction Ignore)){
>>         New-Volume -CimSession $Node -StoragePool $StoragePool -FileSystem CSVFS_ReFS -FriendlyName $Node -Size $VMFleetVolumeSize -ProvisioningType Thin
>>     }
>> }

DriveLetter FriendlyName FileSystemType DriveType HealthStatus OperationalStatus SizeRemaining       Size
----------- ------------ -------------- --------- ------------ ----------------- -------------       ----
            sg-mc660-1   CSVFS_ReFS     Fixed     Healthy      OK                   1015.21 GB 1023.94 GB
            sg-mc660-2   CSVFS_ReFS     Fixed     Healthy      OK                   1015.21 GB 1023.94 GB

PS C:\Windows\system32> #Create Collect volume (thin provisioned)
>> if (-not (Get-Virtualdisk -CimSession $ClusterName -FriendlyName Collect -ErrorAction Ignore)){
>>     New-Volume -CimSession $CLusterName -StoragePool $StoragePool -FileSystem CSVFS_ReFS -FriendlyName Collect -Size $CollectVolumeSize -ProvisioningType Thin
>> }

DriveLetter FriendlyName FileSystemType DriveType HealthStatus OperationalStatus SizeRemaining      Size
----------- ------------ -------------- --------- ------------ ----------------- -------------      ----
            Collect      CSVFS_ReFS     Fixed     Healthy      OK                    197.17 GB 199.94 GB


PS C:\Windows\system32>
>>  Get-VirtualDisk -CimSession $ClusterName

FriendlyName              ResiliencySettingName FaultDomainRedundancy OperationalStatus HealthStatus    Size FootprintOnPool StorageEfficiency PSComputerName
------------              --------------------- --------------------- ----------------- ------------    ---- --------------- ----------------- --------------
sg-mc660-2                Mirror                1                     OK                Healthy         1 TB           25 GB            48.00% clus02
Infrastructure_1          Mirror                1                     OK                Healthy       252 GB          505 GB            49.90% clus02
UserStorage_2             Mirror                1                     OK                Healthy      5.17 TB          107 GB            49.53% clus02
ClusterPerformanceHistory Mirror                1                     OK                Healthy        24 GB           49 GB            48.98% clus02
sg-mc660-1                Mirror                1                     OK                Healthy         1 TB           25 GB            48.00% clus02
Collect                   Mirror                1                     OK                Healthy       200 GB           39 GB            48.72% clus02
UserStorage_1             Mirror                1                     OK                Healthy      5.17 TB          141 GB            49.65% clus02

``` 

#### Step 3 - Ask for FleetImage VHD and copy it to collect folder using following script. Keep PowerShell window open for next task.
> Note: Script will also copy VMFleet PowerShell module into each cluster node
```powershell
#Ask for VHD
Write-Output "Please select VHD created using CreateVMFleetDisk.ps1"
[reflection.assembly]::loadwithpartialname("System.Windows.Forms")
$openFile = New-Object System.Windows.Forms.OpenFileDialog -Property @{
    Title="Please select VHD created using CreateVMFleetDisk.ps1"
}
$openFile.Filter = "vhdx files (*.vhdx)|*.vhdx|All files (*.*)|*.*"
If($openFile.ShowDialog() -eq "OK"){
    Write-Output "File $($openfile.FileName) selected"
}
$VHDPath=$openfile.FileName

#Copy VHD to collect folder
Copy-Item -Path $VHDPath -Destination \\$ClusterName\ClusterStorage$\Collect\

#Copy VMFleet and PrivateCloud.DiagnosticInfo PowerShell Modules to cluster nodes
$Sessions=New-PSSession -ComputerName $Nodes
Foreach ($Session in $Sessions){
    Copy-Item -Recurse -Path "C:\Program Files\WindowsPowerShell\Modules\VMFleet" -Destination "C:\Program Files\WindowsPowerShell\Modules\" -ToSession $Session -Force
    Copy-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\PrivateCloud.DiagnosticInfo' -Destination 'C:\Program Files\WindowsPowerShell\Modules\' -ToSession $Session -Recurse -Force
}


```

The output would be something like this:

```
Please select VHD created using CreateVMFleetDisk.ps1

GAC    Version        Location
---    -------        --------
True   v4.0.30319     C:\Windows\Microsoft.Net\assembly\GAC_MSIL\System.Windows.Forms\v4.0_4.0.0.0__b77a5c561934e089\System.Windows.Forms.dll
File C:\Users\LabAdmin\Documents\FleetImage.vhdx selected


PS C:\Windows\system32> dir '\\sg-mc660-1\c$\ClusterStorage\Collect\'


    Directory: \\sg-mc660-1\c$\ClusterStorage\Collect


Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
-a----          7/8/2024   2:04 PM     5950668800 FleetImage.vhdx

PS C:\Windows\system32> dir '\\sg-mc660-1\c$\Program Files\WindowsPowerShell\Modules\VMFleet\'


    Directory: \\sg-mc660-1\c$\Program Files\WindowsPowerShell\Modules\VMFleet


Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
d-----          7/8/2024   3:43 PM                2.1.0.0


PS C:\Windows\system32> dir '\\sg-mc660-2\c$\Program Files\WindowsPowerShell\Modules\VMFleet\'


    Directory: \\sg-mc660-2\c$\Program Files\WindowsPowerShell\Modules\VMFleet


Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
d-----          7/8/2024   3:43 PM                2.1.0.0


PS C:\Windows\system32> dir "\\sg-mc660-2\c`$\Program Files\WindowsPowerShell\Modules\PrivateCloud.DiagnosticInfo\"


    Directory: \\sg-mc660-2\c$\Program Files\WindowsPowerShell\Modules\PrivateCloud.DiagnosticInfo


Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
d-----          7/8/2024   6:35 PM                1.1.38
-a----          3/6/2023  10:28 PM          18167 PrivateCloud.DiagnosticInfo.psd1
-a----          3/6/2023  10:28 PM         247777 PrivateCloud.DiagnosticInfo.psm1


PS C:\Windows\system32> dir "\\sg-mc660-1\c`$\Program Files\WindowsPowerShell\Modules\PrivateCloud.DiagnosticInfo\"


    Directory: \\sg-mc660-1\c$\Program Files\WindowsPowerShell\Modules\PrivateCloud.DiagnosticInfo


Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
d-----          7/8/2024   6:35 PM                1.1.38
-a----          3/6/2023  10:28 PM          18167 PrivateCloud.DiagnosticInfo.psd1
-a----          3/6/2023  10:28 PM         247777 PrivateCloud.DiagnosticInfo.psm1

```

### Task 4 - Deploy VMFleet and Measure Performance

#### Step 1 - Generate Variables
> Enter your domain admin password and VHD admin password

```powershell
#generate variables
#generate VHD Name from path (path was created when you were asked for VHD)

$VHDName=$VHDPath | Split-Path -Leaf

#domain account credentials

$AdminUsername="sg\LabAdmin"
$AdminPassword=""
$securedpassword = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
$Credentials = New-Object System.Management.Automation.PSCredential ($AdminUsername, $securedpassword)

#Or simply ask for credentials
#$Credentials=Get-Credential
#credentials for local admin located in FleetImage VHD

$VHDAdminPassword=""
 
```

#### Step 2 - Enable CreadSSP and Install VMFleet
> Note: CredSSP has to be enabled, as command to install VMFleet does not (yet) work correctly against Cluster. Therefore command Install-Fleet has to be invoked to one of the nodes.

> Note: Installing VMFLeet will create folder structure (and copy diskspd and few scripts) in Cluster Shared Volume "Collect" that was created before.

```powershell
#Enable CredSSP
# Temporarily enable CredSSP delegation to avoid double-hop issue

foreach ($Node in $Nodes){
    Enable-WSManCredSSP -Role "Client" -DelegateComputer $Node -Force
}
Invoke-Command -ComputerName $Nodes -ScriptBlock { Enable-WSManCredSSP Server -Force }

# Install VMFleet

Invoke-Command -ComputerName $Nodes[0] -Credential $Credentials -Authentication Credssp -ScriptBlock {
    Install-Fleet
}

```

### Task 5 - Cleanup VMFleet