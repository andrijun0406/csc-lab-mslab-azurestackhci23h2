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

$ModuleNames="Az.Accounts","Az.Resources","Az.Compute","Az.DesktopVirtualization"
foreach ($ModuleName in $ModuleNames) {
    if (!(Get-InstalledModule -Name $ModuleName -ErrorAction Ignore)){
	    Install-Module -Name $ModuleName -Force
    }
} 

if (-not (Get-AzContext)){
	Connect-AzAccount -ServicePrincipal -TenantId $tenantID -Credential $AdminSPNCred
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
You can also check them in Azure Portal:

![Check SPN Roles for AVD](images/Check-Roles.png)

### Task 1 - Create a Host Pool

There are two type of Host Pool: Pooled or Personal. Pooled destkops are stateless where Personal are stateful. I will create both to test.

#### Step 1A - Create Pooled Host Pool

```powershell
$parameters = @{
     Name = $HostPoolPooled
     ResourceGroupName = $ResourceGroupName
     HostPoolType = 'Pooled'
     LoadBalancerType = 'BreadthFirst'
     PreferredAppGroupType = 'Desktop'
     MaxSessionLimit = '5'
     Location = $Location
}

New-AzWvdHostPool @parameters

# Check HostPool created in Azure
Get-AzWvdHostPool -Name $parameters.Name -ResourceGroupName $parameters.ResourceGroupName | FL *

```
#### Expected Result

```
PS C:\Windows\system32> New-AzWvdHostPool @parameters

Etag IdentityPrincipalId IdentityTenantId IdentityType Kind Location ManagedBy Name              PlanName PlanProduct PlanPromotionCode PlanPublisher PlanVersion SkuCapacity SkuFamily SkuN
                                                                                                                                                                                        ame
---- ------------------- ---------------- ------------ ---- -------- --------- ----              -------- ----------- ----------------- ------------- ----------- ----------- --------- ----
                                                            eastus             MC760-Pooled-Pool


PS C:\Windows\system32> Get-AzWvdHostPool -Name $parameters.Name -ResourceGroupName $parameters.ResourceGroupName | FL *


AgentUpdateMaintenanceWindow               :
AgentUpdateMaintenanceWindowTimeZone       :
AgentUpdateType                            :
AgentUpdateUseSessionHostLocalTime         :
ApplicationGroupReference                  : {}
CloudPcResource                            : False
CustomRdpProperty                          : drivestoredirect:s:*;audiomode:i:0;videoplaybackmode:i:1;redirectclipboard:i:1;redirectprinters:i:1;devicestoredirect:s:*;redirectcomports:i:1;redirectsmartcards:i:1;usbdevicestoredirect:s:*;enablecredsspsupport:i:1;redirectwebauthn:i:1;use multimon:i:1;
Description                                :
Etag                                       :
FriendlyName                               :
HostPoolType                               : Pooled
Id                                         : /subscriptions/368ac09c-01c9-4b47-9142-a7581c6694a3/resourcegroups/rg-sg-mc760/providers/Microsoft.DesktopVirtualization/hostpools/MC760-Pooled-Pool
Identity                                   : Microsoft.Azure.PowerShell.Cmdlets.DesktopVirtualization.Models.Api10.Identity
IdentityPrincipalId                        :
IdentityTenantId                           :
IdentityType                               :
Kind                                       :
LoadBalancerType                           : BreadthFirst
Location                                   : eastus
ManagedBy                                  :
MaxSessionLimit                            : 5
Name                                       : MC760-Pooled-Pool
ObjectId                                   : 37c135d5-6626-4a6c-b8c0-e9aba1af9b2b
PersonalDesktopAssignmentType              :
Plan                                       : Microsoft.Azure.PowerShell.Cmdlets.DesktopVirtualization.Models.Api10.Plan
PlanName                                   :
PlanProduct                                :
PlanPromotionCode                          :
PlanPublisher                              :
PlanVersion                                :
PreferredAppGroupType                      : Desktop
PrivateEndpointConnection                  : {}
PublicNetworkAccess                        : Enabled
RegistrationInfoExpirationTime             :
RegistrationInfoRegistrationTokenOperation :
RegistrationInfoToken                      :
Ring                                       :
Sku                                        : Microsoft.Azure.PowerShell.Cmdlets.DesktopVirtualization.Models.Api10.Sku
SkuCapacity                                :
SkuFamily                                  :
SkuName                                    :
SkuSize                                    :
SkuTier                                    :
SsoClientId                                :
SsoClientSecretKeyVaultPath                :
SsoSecretType                              :
SsoadfsAuthority                           :
StartVMOnConnect                           : False
SystemDataCreatedAt                        : 2/9/2024 10:32:30 AM
SystemDataCreatedBy                        : d329535d-0cf4-473a-8646-8c612949142a
SystemDataCreatedByType                    : Application
SystemDataLastModifiedAt                   : 2/9/2024 10:32:30 AM
SystemDataLastModifiedBy                   : d329535d-0cf4-473a-8646-8c612949142a
SystemDataLastModifiedByType               : Application
Tag                                        : Microsoft.Azure.PowerShell.Cmdlets.DesktopVirtualization.Models.Api10.ResourceModelWithAllowedPropertySetTags
Type                                       : Microsoft.DesktopVirtualization/hostpools
VMTemplate                                 :
ValidationEnvironment                      : False
```

You can also check on Azure Portal:

![Pooled Host Pool](images/pooled-host-pool.png)

#### Step 1B - Create Personal Host Pool

```powershell
$parameters = @{
     Name = $HostPoolPersonal
     ResourceGroupName = $ResourceGroupName
     HostPoolType = 'Personal'
     LoadBalancerType = 'Persistent'
     PreferredAppGroupType = 'Desktop'
     PersonalDesktopAssignmentType = 'Automatic'
     Location = $Location
}

New-AzWvdHostPool @parameters

# Check HostPool created in Azure
Get-AzWvdHostPool -Name $parameters.Name -ResourceGroupName $parameters.ResourceGroupName | FL *

```
#### Expected Result

```
PS C:\Windows\system32> New-AzWvdHostPool @parameters

Etag IdentityPrincipalId IdentityTenantId IdentityType Kind Location ManagedBy Name                PlanName PlanProduct PlanPromotionCode PlanPublisher PlanVersion SkuCapacity SkuFamily SkuName SkuSize SkuTier
---- ------------------- ---------------- ------------ ---- -------- --------- ----                -------- ----------- ----------------- ------------- ----------- ----------- --------- ------- ------- -------
                                                            eastus             MC760-Personal-Pool


PS C:\Windows\system32> Get-AzWvdHostPool -Name $parameters.Name -ResourceGroupName $parameters.ResourceGroupName | FL *


AgentUpdateMaintenanceWindow               :
AgentUpdateMaintenanceWindowTimeZone       :
AgentUpdateType                            :
AgentUpdateUseSessionHostLocalTime         :
ApplicationGroupReference                  : {}
CloudPcResource                            : False
CustomRdpProperty                          : drivestoredirect:s:*;audiomode:i:0;videoplaybackmode:i:1;redirectclipboard:i:1;redirectprinters:i:1;devicestoredirect:s:*;redirectcomports:i:1;redirectsmartcards:i:1;usbdevicestoredirect:s:*;enablecredsspsupport:i:1;redirectwebauthn:i:1;use multimon:i:1;
Description                                :
Etag                                       :
FriendlyName                               :
HostPoolType                               : Personal
Id                                         : /subscriptions/368ac09c-01c9-4b47-9142-a7581c6694a3/resourcegroups/rg-sg-mc760/providers/Microsoft.DesktopVirtualization/hostpools/MC760-Personal-Pool
Identity                                   : Microsoft.Azure.PowerShell.Cmdlets.DesktopVirtualization.Models.Api10.Identity
IdentityPrincipalId                        :
IdentityTenantId                           :
IdentityType                               :
Kind                                       :
LoadBalancerType                           : Persistent
Location                                   : eastus
ManagedBy                                  :
MaxSessionLimit                            : 999999
Name                                       : MC760-Personal-Pool
ObjectId                                   : 54aa095a-d620-47c3-9fb1-5fdc47b9c733
PersonalDesktopAssignmentType              : Automatic
Plan                                       : Microsoft.Azure.PowerShell.Cmdlets.DesktopVirtualization.Models.Api10.Plan
PlanName                                   :
PlanProduct                                :
PlanPromotionCode                          :
PlanPublisher                              :
PlanVersion                                :
PreferredAppGroupType                      : Desktop
PrivateEndpointConnection                  : {}
PublicNetworkAccess                        : Enabled
RegistrationInfoExpirationTime             :
RegistrationInfoRegistrationTokenOperation :
RegistrationInfoToken                      :
Ring                                       :
Sku                                        : Microsoft.Azure.PowerShell.Cmdlets.DesktopVirtualization.Models.Api10.Sku
SkuCapacity                                :
SkuFamily                                  :
SkuName                                    :
SkuSize                                    :
SkuTier                                    :
SsoClientId                                :
SsoClientSecretKeyVaultPath                :
SsoSecretType                              :
SsoadfsAuthority                           :
StartVMOnConnect                           : False
SystemDataCreatedAt                        : 2/9/2024 2:34:48 PM
SystemDataCreatedBy                        : d329535d-0cf4-473a-8646-8c612949142a
SystemDataCreatedByType                    : Application
SystemDataLastModifiedAt                   : 2/9/2024 2:34:48 PM
SystemDataLastModifiedBy                   : d329535d-0cf4-473a-8646-8c612949142a
SystemDataLastModifiedByType               : Application
Tag                                        : Microsoft.Azure.PowerShell.Cmdlets.DesktopVirtualization.Models.Api10.ResourceModelWithAllowedPropertySetTags
Type                                       : Microsoft.DesktopVirtualization/hostpools
VMTemplate                                 :
ValidationEnvironment                      : False
```

You can also check on Azure Portal:

![Personal Host Pool](images/personal-host-pool.png)

### Task 2 - Create a Workspace

### Task 3 - Create an Application Group

### Task 4 - Create Session Host Virtual Machines

### Task 5 - Assign users or groups to the application group for users to get access