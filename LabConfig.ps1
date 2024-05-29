$LabConfig=@{
    AllowedVLANs="1-10,711-719"; 
    ManagementSubnetIDs=0..4; 
    DomainAdminName='LabAdmin'; 
    AdminPassword='LS1setup!'; 
    Prefix = 'dcoffee-' ; 
    DCEdition='4'; 
    Internet=$true ; 
    AdditionalNetworksConfig=@(); 
    VMs=@(); 
    DomainNetbiosName="th";
    DomainName="th.dcoffee.com";
    TelemetryLevel='Full' ; 
    TelemetryNickname='csc'
}

#pre-domain joined
1..2 | ForEach-Object {
    $VMNames="th-mc660-" ; 
    $LABConfig.VMs += @{ 
        VMName = "$VMNames$_" ;
        Configuration = 'S2D' ; 
        ParentVHD = 'azshci23h2_g2.vhdx' ; 
        HDDNumber = 4; 
        HDDSize= 2TB ; 
        MemoryStartupBytes= 96GB; 
        VMProcessorCount="24"; 
        MGMTNICs=5; 
        NestedVirt=$true; 
        vTPM=$true;
        Unattend="NoDjoin"
    }
} 

#Windows Admin Center gateway
$LabConfig.VMs += @{ VMName = 'WACGW' ; ParentVHD = 'Win2022Core_G2.vhdx' ; MGMTNICs=1 }

#Management machine
$LabConfig.VMs += @{ VMName = 'Management' ; ParentVHD = 'Win2022_G2.vhdx'; MGMTNICs=1 ; AddToolsVHD=$True }