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

Step 1 - Ensure Management Machine has Hyper-V PowerShell Module and Hyper-V itself (to work with VHDs).

```powershell
#install Hyper-V using DISM
Enable-WindowsOptionalFeature -FeatureName Microsoft-Hyper-V -Online -All -NoRestart
```
### Task 2 - Create VMFleet Image
### Task 3 - Deploy VMFleet and Measure Performance
### Task 4 - Cleanup VMFleet