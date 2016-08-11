# Scope : Quiesce,snapshot and unquiesce Meditech 6.1 servers (MAT and NPR)
# Note : Requires Elevated privileges for the MBF64 tool to run
# Quiesce and unquiesce operations for a group (NPR or MAT) need to run as a block.
# The following command was ran previsouly as an Administrator to allow writing to the local event log
#        New-EventLog -LogName Application -Source "MTBackupPS"
# Quiesce/Unquiesce event should also be logged by the ANPServer but added them as part of this process just in case.

# Requirements :
# Meditech Quiesce tool : MBF64.exe
# Nutanix CmdLets for Nutanix Automation
# PowerCLI/SCVMM CmdLets for Hypervisor Automation
# Local Nutanix user to connect to the Nutanix Block


# Import Third Party Cmdlets
# Nutanix Cmdlets
# Used to take/restore snapshots
Add-PsSnapin NutanixCmdletsPSSnapin
# PowerCLI
# Used to interact with vCenter
Add-PSSnapin VMware.VimAutomation.Core

# Connect to vCenter
connect-viserver -server vwidc700.east.wan.ramsayhealth.com.au -user 'EAST\ovdp' -password 'Open Data'

#Remove existing VM copies
get-vm NBU-MT* | remove-vm -DeletePermanently -Confirm:$false

# Prism/vCenter credentials
$username = 'mtbackup'
$password = 'QuickBackups1!'
$connectstatus = Connect-NTNXCluster -Server NTNX01 -UserName $username -Password (ConvertTo-SecureString $password -AsPlainText -force) -AcceptInvalidSSLCerts

## TODO : encrypt passwords in a local file

if ($connectstatus.isConnected) {
# Log success in Application Event Log
Write-EventLog -LogName Application -Source MTBackupPS -EventId 1000 -Message "Meditech Backup - Nutanix Cluster : Connected" -EntryType Information
}
else {
    # Something went wrong connecting to the Nutanix Cluster, log event and exit
    Write-EventLog -LogName Application -Source MTBackupPS -EventId 1001 -Message "Meditech Backup - Nutanix Cluster : NOT Connected. Please check Credentials" -EntryType Error
    break}


# Quiesce NPR
$quiesceNPR = C:\MTBackupScripts\MBF64.exe c=quiesce u=ISB p=ISB m=quiet t=90 i=mtbg61001
Write-EventLog -LogName Application -Source MTBackupPS -EventId 2000 -Message "Meditech Backup - NPR Quiesce Status : $quiesceNPR" -EntryType Information

# Snapshot NPR - Retention slightly over a day (86400 seconds) to avoid any scheduling conflict
Add-NTNXOutOfBandSchedule -Name Meditech61_NPR -SnapshotRetentionTimeSecs 88000

# Unquiesce NPR
$unquiesceNPR = C:\MTBackupScripts\MBF64.exe c=unquiesce u=ISB p=ISB m=quiet t=90 i=mtbg61001
Write-EventLog -LogName Application -Source MTBackupPS -EventId 2001 -Message "Meditech Backup - NPR Unquiesce Status : $unquiesceNPR" -EntryType Information

# Quiesce MAT
$quiesceMAT = C:\MTBackupScripts\MBF64.exe c=quiesce u=ISB p=ISB m=quiet t=90 i=mtts61001
Write-EventLog -LogName Application -Source MTBackupPS -EventId 2002 -Message "Meditech Backup - MAT Quiesce Status : $quiesceMAT" -EntryType Information

# Snapshot MAT - Retention slightly over a day (86400 seconds) to avoid any scheduling conflict
Add-NTNXOutOfBandSchedule -Name Meditech61_MAT -SnapshotRetentionTimeSecs 88000

# Unquiesce MAT
$unquiesceMAT = C:\MTBackupScripts\MBF64.exe c=unquiesce u=ISB p=ISB m=quiet t=90 i=mtts61001
Write-EventLog -LogName Application -Source MTBackupPS -EventId 2003 -Message "Meditech Backup - MAT Unquiesce Status : $unquiesceMAT" -EntryType Information


# Restore the VMs as copies (They will automatically be registered in vCenter/SCVMM)
# Get PD snapshots
$pdSnapshotsNPR = Get-NTNXProtectionDomainSnapshot -Name Meditech61_NPR -SortCriteria ascending
$pdSnapshotsMAT = Get-NTNXProtectionDomainSnapshot -Name Meditech61_MAT -SortCriteria ascending

# Sleep to allow for Snapshot creation and registration
sleep 60

# Restore most recent snapshot for FS NPR and FS/TS MAT
Restore-NTNXEntity -Name Meditech61_NPR -PathPrefix "/NBU" -VmNamePrefix "NBU-" -SnapshotId $pdSnapshotsNPR[0].snapshotId
Restore-NTNXEntity -Name Meditech61_MAT -PathPrefix "/NBU" -VmNamePrefix "NBU-" -SnapshotId $pdSnapshotsMAT[0].snapshotId

# Sleep to allow for Snapshot restoration and VM Registration
sleep 60

# Disconnect NICs to avoid issues if VMs are powered on
get-vm nbu* | Get-NetworkAdapter | Set-NetworkAdapter -StartConnected:$false -Confirm:$false | Out-Null

# Move Recovered VMs to Meditech Folder
get-vm nbu* | move-vm -location MeditechVM | Out-Null

# Call to Netbackup to start backup of clones
