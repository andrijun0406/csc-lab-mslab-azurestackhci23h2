# Setup some variables
$ResourceGroupName="dcoffee-rg"
$Location="eastus" #make sure location is lowercase

# Make sure User or SPN is contributor and user access administrator in Azure Subscriptions
# We are using SPN here:
$tenantID = "2fc994a3-81d2-4ba3-ad3e-c1d68b3aaf6b"
$AdminSPNAppID="d329535d-0cf4-473a-8646-8c612949142a"
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