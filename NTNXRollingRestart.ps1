# Inputs
#$clusterName = "Production-NTNX"
$clusterName = "NTNX-Cluster1"
$cvmPrefix = "NTNX-"
$vmWaitTime = 60 #seconds
$hostWaitTime = 90 #seconds
$vmHosts =  Get-VMHost -Location $clusterName| Sort name -descending

# For each host in hosts
foreach($currentHost in $vmHosts){

# Start Maintenance Mode on host in Async mode 
$currentHost | Set-VMHost -State "Maintenance" -RunAsync

# Give time for VMs to move before shutting down CVM
$vmcount = ($currentHost | get-vm).count
while ($vmcount -gt 3)
	{
	sleep 30
	Write-Host "$vmcount VMs to migrate ..."
	$vmcount = ($currentHost | get-vm).count
	sleep 30
	}

# Power down CVM
$cvm = $currentHost | Get-VM | where {$_.Name -match $cvmPrefix}
Write-Host "Shutting down CVM"
$cvm | Shutdown-VMGuest -Confirm:$false

# Set wait time
$waitTime = $vmWaitTime

do {
# Wait
sleep 5.0
$waitTime = $waitTime + 5

Write-Host "Waiting for VMs to be migrated and CVM to be shutdown ($waitTime seconds)"
$ServerState = (get-vmhost $currenthost).ConnectionState
write-host $ServerState
}while ($ServerState -ne "Maintenance")

# VMs migrated and CVM shutdown
Write-Host "Rebooting host"
Restart-VMHost $currentHost -Force -Confirm:$false

# Wait for Server to show as down
do {
sleep 15
$ServerState = (get-vmhost $currenthost).ConnectionState
} while ($ServerState -ne "NotResponding")

Write-Host "$currentHost is Down"

# Sleep for n seconds
Write-Host "Sleeping for $hostWaitTime seconds for host reboot"
sleep $hostWaitTime

# Wait for server to reboot
do {
sleep $hostWaitTime
$ServerState = (get-vmhost $currenthost).ConnectionState
Write-Host "Waiting for Reboot ..."
}while ($ServerState -ne "Maintenance")

Write-Host "$currentHost is back up"

$currentHost | Set-VMHost -State "Connected"

# Make sure CVM is booting
$cvm | Start-VM -Confirm:$false

# Wait for CVM boot
sleep $vmWaitTime

Write-Host "Host reboot successful, moving on to next host"

}
