# Step 1 - Populate Variables and trusted hosts
$ResourceGroupName="dcoffee-rg"
$Location="eastus" #make sure location is lowercase

# Make sure User or SPN is contributor and user access administrator in Azure Subscriptions
# We are using SPN here:
$tenantID = "2fc994a3-81d2-4ba3-ad3e-c1d68b3aaf6b"
$AdminSPNAppID="d329535d-0cf4-473a-8646-8c612949142a"
$AdminPlainSecret="-WO8Q~P_CQVmZROiLSLptFaIuTxVXCf51hq5scLL"
$AdminSecuredSecret = ConvertTo-SecureString $AdminPlainSecret -AsPlainText -Force
$AdminSPNCred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $AdminSPNAppID, $AdminSecuredSecret

# Login to azure if not already
if (-not (Get-AzContext)){
	Connect-AzAccount -ServicePrincipal -TenantId $tenantID -Credential $AdminSPNCred
}

$Servers="th-mc660-1","th-mc660-2"
$SubscriptionID=(Get-AzContext).Subscription.ID
$Cloud="AzureCloud"

#Since machines are not domain joined, let's do some preparation
$UserName="Administrator"
$Password="LS1setup!"
$SecuredPassword = ConvertTo-SecureString $password -AsPlainText -Force
$Credentials= New-Object System.Management.Automation.PSCredential ($UserName,$SecuredPassword)

#configure trusted hosts to be able to communicate with servers (not secure)
$TrustedHosts=@()
$TrustedHosts+=$Servers
Set-Item WSMan:\localhost\Client\TrustedHosts -Value $($TrustedHosts -join ',') -Force

# Step 2 - Wipe Existing data
# MSLab deploys clean disk so this step is unnecessary for now.

# Step 3 - Install features

Invoke-Command -ComputerName $servers -ScriptBlock {
    Enable-WindowsOptionalFeature -FeatureName Microsoft-Hyper-V -Online -NoRestart
    Install-WindowsFeature -Name Failover-Clustering
} -Credential $Credentials

# Step 4 - Install Cumulative Updates (optionals)

 Invoke-Command -ComputerName $servers -ScriptBlock {
    New-PSSessionConfigurationFile -RunAsVirtualAccount -Path $env:TEMP\VirtualAccount.pssc
    Register-PSSessionConfiguration -Name 'VirtualAccount' -Path $env:TEMP\VirtualAccount.pssc -Force
} -ErrorAction Ignore -Credential $Credentials
#sleep a bit
Start-Sleep 2
# Run Windows Update via ComObject.
Invoke-Command -ComputerName $servers -ConfigurationName 'VirtualAccount' -ScriptBlock {
    $Searcher = New-Object -ComObject Microsoft.Update.Searcher
    $SearchCriteriaAllUpdates = "IsInstalled=0 and DeploymentAction='Installation' or
        IsInstalled=0 and DeploymentAction='OptionalInstallation' or
        IsPresent=1 and DeploymentAction='Uninstallation' or
        IsInstalled=1 and DeploymentAction='Installation' and RebootRequired=1 or
        IsInstalled=0 and DeploymentAction='Uninstallation' and RebootRequired=1"
    $SearchResult = $Searcher.Search($SearchCriteriaAllUpdates).Updates
    if ($SearchResult.Count -gt 0){
        $Session = New-Object -ComObject Microsoft.Update.Session
        $Downloader = $Session.CreateUpdateDownloader()
        $Downloader.Updates = $SearchResult
        $Downloader.Download()
        $Installer = New-Object -ComObject Microsoft.Update.Installer
        $Installer.Updates = $SearchResult
        $Result = $Installer.Install()
        $Result
    }
} -Credential $Credentials
#remove temporary PSsession config
Invoke-Command -ComputerName $servers -ScriptBlock {
    Unregister-PSSessionConfiguration -Name 'VirtualAccount'
    Remove-Item -Path $env:TEMP\VirtualAccount.pssc
} -Credential $Credentials
  
# Step 5 - Install OEM Drivers
# Since we are using MSLAB this step is unnecessary.

# Step 6 - Restart servers to finish Features, Cumulative Updates and Drivers

Restart-Computer -ComputerName $Servers -Credential $Credentials -WsmanAuthentication Negotiate -Wait -For PowerShell -Force
Start-Sleep 20 #Failsafe as Hyper-V needs 2 reboots and sometimes it happens, that during the first reboot the restart-computer evaluates the machine is up
#make sure computers are restarted
Foreach ($Server in $Servers){
    do{$Test= Test-NetConnection -ComputerName $Server -CommonTCPPort WINRM}while ($test.TcpTestSucceeded -eq $False)
}
 

# Step 7 - Install PowerShell modules on nodes and deploy Arc Agent

#make sure nuget is installed on nodes
Invoke-Command -ComputerName $Servers -ScriptBlock {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    #Register-PSRepository -Default -InstallationPolicy Trusted
} -Credential $Credentials

#make sure azshci.arcinstaller is installed on nodes
Invoke-Command -ComputerName $Servers -ScriptBlock {
    Install-Module -Name azshci.arcinstaller -Force
} -Credential $Credentials

#make sure Az.Resources module is installed on nodes
Invoke-Command -ComputerName $Servers -ScriptBlock {
    Install-Module -Name Az.Resources -Force
} -Credential $Credentials

#make sure az.accounts module is installed on nodes
Invoke-Command -ComputerName $Servers -ScriptBlock {
    Install-Module -Name az.accounts -Force
} -Credential $Credentials

#make sure az.connectedmachine module is installed on nodes -- do we need this?
Invoke-Command -ComputerName $Servers -ScriptBlock {
    Install-Module -Name az.connectedmachine -Force
} -Credential $Credentials

# make sure resource providers are registered
Register-AzResourceProvider -ProviderNamespace "Microsoft.HybridCompute"
Register-AzResourceProvider -ProviderNamespace "Microsoft.GuestConfiguration"
Register-AzResourceProvider -ProviderNamespace "Microsoft.HybridConnectivity"
Register-AzResourceProvider -ProviderNamespace "Microsoft.AzureStackHCI"
 

#deploy ARC Agent with device authentication
$ARMtoken = (Get-AzAccessToken).Token
$id = (Get-AzContext).Account.Id
Invoke-Command -ComputerName $Servers -ScriptBlock {
    Invoke-AzStackHciArcInitialization -SubscriptionID $using:SubscriptionID -ResourceGroup $using:ResourceGroupName -TenantID $using:TenantID -Cloud $using:Cloud -Region $Using:Location -ArmAccessToken $using:ARMtoken -AccountID $using:id
} -Credential $Credentials
