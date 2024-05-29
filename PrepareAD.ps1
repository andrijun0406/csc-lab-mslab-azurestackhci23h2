$AsHCIOUName="OU=clus01,DC=th,DC=dcoffee,DC=com"
$LCMUserName="clus01-LCMUser"
$LCMPassword="LS1setup!LS1setup!"
$SecuredPassword = ConvertTo-SecureString $password -AsPlainText -Force
$LCMCredentials= New-Object System.Management.Automation.PSCredential ($UserName,$SecuredPassword)

#install posh module for prestaging Active Directory
Install-PackageProvider -Name NuGet -Force
Install-Module AsHciADArtifactsPreCreationTool -Repository PSGallery -Force

#make sure active directory module and GPMC is installed
Install-WindowsFeature -Name RSAT-AD-PowerShell,GPMC

#populate objects
New-HciAdObjectsPreCreation -AzureStackLCMUserCredential  $LCMCredentials -AsHciOUName $AsHCIOUName

#install management features to explore cluster,settings...
Install-WindowsFeature -Name "RSAT-ADDS","RSAT-Clustering"