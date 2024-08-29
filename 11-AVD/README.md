## 11. Azure Virtual Desktop on Azure Stack HCI

### About the lab

In this Lab, we are going to deploy Azure Virtual Desktop on Azure Stack HCI 23H2 by using PowerShell.

References:
Learn.microsoft.com [Deploy Azure Virtual Desktop](https://learn.microsoft.com/en-us/azure/virtual-desktop/deploy-azure-virtual-desktop)
https://learn.microsoft.com/en-us/azure/virtual-desktop/azure-stack-hci-overview

### Prerequisites

References:
Learn.microsoft.com [Prerequisites for Azure Virtual Desktop](https://learn.microsoft.com/en-us/azure/virtual-desktop/prerequisite)

at high-level, you need:

* An Azure account with an active subscription
* A supported identity provider
* A supported operating system for session host virtual machines
* Appropriate licenses
* Network connectivity
* A Remote Desktop client

#### Step 1 - Register Microsoft.DesktopVirtualization resource provider for your subscriptions.

> You must have permission to register a resource provider, which requires the */register/action operation. This is included if your account is assigned the **contributor** or **owner role** on your subscription.

Use the following powershell script to check and register if not exists the resource provider. Run from the Management Machine:

```powershell
# Setup some variables
$ResourceGroupName=""
$Location="southeastasia" #make sure location is lowercase

# Make sure User or SPN is contributor and user access administrator in Azure Subscriptions
# We are using SPN here:
# fill out the following variable to your environment
$tenantID = ""
$AdminSPNAppID=""
$AdminSPNName=""
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

# Step 1 - Check if Microsoft.DesktopVirtualization resource provider is registered, create if it isn't.
if (!(Get-AzResourceProvider -ProviderNamespace Microsoft.DesktopVirtualization -ErrorAction Ignore)){
    Register-AzResourceProvider -ProviderNamespace Microsoft.DesktopVirtualization 
} else {
    Write-Output "Registered"
}
```

#### Step 2 - Check if your SPN account has correct Azure RBAC

```powershell
# Step 2 - Check if the SPN has sufficient RBAC roles/permissions on the resource group:
$Subscription = Get-AzSubscription
$SubscriptionID = $Subscription.Id
$adminSPNObject = Get-AzADServicePrincipal -DisplayNameBeginsWith $AdminSPNName
$adminSPNObjID = $adminSPNObject.Id

# Check if the ROle should have Desktop Virtualization Contributor and Virtual Machine Contributor or just Contributor

$adminSPNRoles = Get-AzRoleAssignment -ObjectId $adminSPNObjID -Scope "/subscriptions/$SubscriptionID/resourceGroups/$ResourceGroupName" | Select-Object -Property RoleDefinitionName
$prerequisiteRoles = @('Desktop Virtualization Contributor','Virtual Machine Contributor','Contributor')
#$prerequisiteRoles = @('Desktop Virtualization Contributor','Virtual Machine Contributor')
$sufficient = $adminSPNRoles| Where-Object RoleDefinitionName -in $prerequisiteRoles
if (!($sufficient)){
    Write-Output "SPN has insufficient roles: $sufficient"
} else {
    Write-Output "SPN has sufficient roles: $sufficient"
}
```

### Task 1 - Create a Host Pool

### Task 2 - Create a Workspace

### Task 3 - Create an Application Group

### Task 4 - Create Session Host Virtual Machines

### Task 5 - Assign users or groups to the application group for users to get access