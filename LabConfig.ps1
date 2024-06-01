$LabConfig=@{
    AllowedVLANs="1-10,711-723"; 
    DomainAdminName=''; 
    AdminPassword=''; 
    Prefix = 'dcoffee-' ; 
    DCEdition='4'; 
    Internet=$true ;
    UseHostDnsAsForwarder=$true; 
    AdditionalNetworksInDC=$true; 
    AdditionalNetworksConfig=@(); 
    VMs=@(); 
    DomainNetbiosName="th";
    DomainName="th.dcoffee.com";
    TelemetryLevel='Full' ; 
    TelemetryNickname='dcoffee'
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
        MGMTNICs=5 ; 
        NestedVirt=$true; 
        vTPM=$true;
        Unattend="NoDjoin"
    }
}

#add subnet 1-3

$LABConfig.AdditionalNetworksConfig += @{ 
        NetName = 'subnet1';                        # Network Name
        NetAddress='10.0.1.';                      # Network Addresses prefix. (starts with 1), therefore first VM with Additional network config will have IP 172.16.1.1
        NetVLAN='721';                                 # VLAN tagging
        Subnet='255.255.255.0'                       # Subnet Mask
    }
    $LABConfig.AdditionalNetworksConfig += @{ NetName = 'subnet2'; NetAddress='10.0.2.'; NetVLAN='722'; Subnet='255.255.255.0'}
    $LABConfig.AdditionalNetworksConfig += @{ NetName = 'subnet3'; NetAddress='10.0.3.'; NetVLAN='723'; Subnet='255.255.255.0'}

#Windows Admin Center gateway
$LabConfig.VMs += @{ VMName = 'WACGW' ; ParentVHD = 'Win2022Core_G2.vhdx' ; MGMTNICs=1 }

#Management machine
$LabConfig.VMs += @{ VMName = 'Management' ; ParentVHD = 'Win2022_G2.vhdx'; MGMTNICs=1 ; AddToolsVHD=$True }