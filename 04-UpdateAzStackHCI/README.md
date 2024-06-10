## 4. Update Azure Stack HCI 23H2 via PowerShell

Now that you have deployed your 23H2 cluster you realize the cluster is a little bit outdated.
![Cluster status](Cluster-Status.png)

### Task 1 - Connect to one of your Azure Stack HCI Cluster Node

```powershell
$cred = Get-Credential
Enter-PSSession -ComputerName th-mc660-1 -Credential $cred
```

### Task 2 - Identify the stamp version on your cluster

```powershell
Get-StampInformation
```