## 4. Update Azure Stack HCI 23H2 via PowerShell

Now that you have deployed your 23H2 cluster you realize the cluster is a little bit outdated.
![Cluster status](images/Cluster-Status.png)

### Task 1 - Connect to one of your Azure Stack HCI Cluster Node

```powershell
$cred = Get-Credential
Enter-PSSession -ComputerName th-mc660-2 -Credential $cred
```

### Task 2 - Identify the stamp version on your cluster

```powershell
Get-StampInformation
```

![Current Version](images/Current-Version.png)
Compare to the [release notes](https://learn.microsoft.com/en-us/azure-stack/hci/known-issues-2402) and see known issues.


### Task 3 - Validate System Health

Run the following command to validate system health via the Environment Checker.
```powershell
$result = Test-EnvironmentReadiness
$result | ft Name,Status,Severity
```
![Validate System health](images/Validate-Health.png)
> In this release, the informational failures for **Test-CauSetup** are expected and will not impact the updates.

### Task 4 - Discover the updates online

Verify the update service discovers the update package
```powershell
Get-SolutionUpdate | ft DisplayName, State
$Update = Get-SolutionUpdate 
$Update.ComponentVersions
```
![Discover Updates](images/Discover-Updates.png)