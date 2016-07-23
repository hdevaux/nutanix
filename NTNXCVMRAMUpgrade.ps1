 
#Find all of the Nutanix CVMs that have less than 24GB RAM
$vms = Get-VM -name NTNX* | Where MemoryGB -lt 24
 
#Sort the CVMs by IP address (just to watch the CVMs be done in order)
$vms = $vms | Sort-Object guest.IPAddress[0]
 
Write-Host "CVMs to be upgraded: $vms"
Read-Host "Proceed or Ctl-C to break "
#Loop though the CVMs and upgrade them one at a time
foreach ($vm in $vms) {
 
      $CVM = $vm.guest.IPAddress[0]
      write-host "Shutting down $CVM"
      Shutdown-VMGuest $vm -Confirm:$false
 
      #Wait a period of time to make sure the CVM is shutdown before changing settings
      sleep 120
 
      #Set CVM memory
      write-host "Setting $CVM Memory"
      Set-VM $vm -MemoryGB 24 -Confirm:$false
 
      #Power-on CVM
      write-host "Starting $CVM"
      Start-VM $vm -Confirm:$false
    
      #Wait for CVM to start before checking that it is UP
      sleep 120
      write-host "Check $CVM state before proceeding (genesis status on the CVM)"
      Read-Host "Are we OK to proceed with the next CVM?"
      Read-Host "Not that I don't trust you, but you checked right? I don't need to build some SSH checks in that script, do I?"
      Write-Host "OK. Good."
 

}
