####################### 
#	Script Name:		vSphere-Functions-v1.1.ps1
#	Description:		Functions for intern service script for CANCOM. 
#	Data:				26/Jul/2019
#	Version:			1.1
#	Author:				Fernando Martínez
#	Email:				fernando.martinez@cancom.de
#   Sources:			https://github.com/arielsanchezmora/vDocumentation
#						https://vmguru.com/2016/01/powershell-friday-enabling-ssh-with-powercli/
#						https://kb.vmware.com/s/article/2042141
#						http://austintovey.blogspot.com/2017/04/resetting-lost-esxi-password.html
#						https://www.top-password.com/knowledge/reset-esxi-root-password.html
#						https://kb.vmware.com/s/article/1003728
#	Version Control:	20190726 - 1.0	First file with functions
#						20190726 - 1.1	Function "Ping from Host to IP"
#
#######################

function Show-Menu-task
{
     param (
           [string]$Title = 'Task selection'
     )
     cls
     Write-Host "================ $Title ======== fernando.martinez@cancom.de ========"
     
     Write-Host "Run vDocumentation:       Press '1' for this option."
     Write-Host "Run SSH Management:       Press '2' for this option."
     Write-Host "ESXi Backup:              Press '3' for this option."
     Write-Host "Reset ESXi root Password: Press '4' for this option."
     Write-Host "Check Time:               Press '5' for this option."
     Write-Host "Show Access Data:         Press '6' for this option."
     Write-Host "Open VM Console:          Press '7' for this option."
     Write-Host "Ping from Host to IP:     Press '8' for this option."
}

function Show-Menu-sshmgmt
{
     param (
           [string]$Title = 'SSH Enable-Disable-Check'
     )
     cls
     Write-Host "================ $Title ======== fernando.martinez@cancom.de ========"
     
     Write-Host "Enable  SSH: Press '1' for this option."
     Write-Host "Disable SSH: Press '2' for this option."
     Write-Host "Check   SSH: Press '3' for this option."
}

function connvis($a, $b, $c)
{
	Connect-VIServer $a -user $b -password $c
}

function disconnvis()
{
	Disconnect-VIServer -Server * -Force -Confirm:$false
}

function vDocum($d)
{
     Get-ESXInventory -ExportExcel -folderPath $d
     Get-ESXIODevice -ExportExcel -folderPath $d
     Get-ESXNetworking -ExportExcel -folderPath $d
     Get-ESXStorage -ExportExcel -folderPath $d
     #Get-ESXPatching -ExportExcel -folderPath $d
}

function sshmgmt()
{
	 Show-Menu-sshmgmt
     $input = Read-Host "Please make a selection"
     switch ($input)
     {
           '1' {
				Get-VMHost | Foreach {Start-VMHostService -HostService ($_ | Get-VMHostService | Where { $_.Key -eq "TSM-SSH"} )}
			} '2' {
				Get-VMHost | Foreach {Stop-VMHostService -HostService ($_ | Get-VMHostService | Where { $_.Key -eq "TSM-SSH"} ) -Confirm:$false }
			} '3' {
				Get-VMHost | Get-VMHostService | Where { $_.Key -eq "TSM-SSH" } |select VMHost, Label, Running
			} 'q' {
                return
		}
	}
}

function esxiback($a)
{
	Get-VMHost | Foreach { Get-VMHostFirmware -VMHost $_ -BackupConfiguration -DestinationPath $a }
	#$vmhosts = Get-VMHost
	#foreach ($vmhost in $vmhosts) {
	#	Get-VMHostFirmware -VMHost $vmhost -BackupConfiguration -DestinationPath $a
	#}
	$timestamp = Get-Date -Format o | foreach {$_ -replace ":", "."}
	$DestDir = $a + "\" + $timestamp
	mkdir $DestDir
	$DestDir
	Move-Item -Path $a\*.tgz -Destination $DestDir
}

function reset-esxi-root-password ()
{
    $vmhosts = Get-VMHost

    $NewCredential = Get-Credential -UserName "root" -Message "Enter an existing ESXi username (not vCenter), and what you want their password to be reset to."

    foreach ($vmhost in $vmhosts) {
		#Gain access to ESXCLI on the host
		$esxcli = get-esxcli -vmhost $vmhost -v2
	
		#Get Parameter list (Arguments)
		$esxcliargs = $esxcli.system.account.set.CreateArgs() 
	
		#Specify the user to reset
		$esxcliargs.id = $NewCredential.UserName
	
		#Specify the user to reset
		$esxcliargs.password = $NewCredential.GetNetworkCredential().Password
	
		#Specify the new password
		$esxcliargs.passwordconfirmation = $NewCredential.GetNetworkCredential().Password
	
		#Debug line so admin can see what's happening.
		Write-Host ("Resetting password for: " + $vmhost)
	
		#Run command, if returns "true" it was successful.
		$esxcli.system.account.set.Invoke($esxcliargs)
	}

}

function checktime ()
{
	foreach ( $esx in (get-vmhost) )
	{
		$esx.Name + " -> " + (get-view $esx.ExtensionData.ConfigManager.DateTimeSystem).QueryDateTime().ToLocalTime()
	}
}

function ShowAccesData ($a, $b, $c)
{
    Write-host "vCenter FQDN: " $a
	Write-host "Username: " $b
	Write-host "Password: " $c
	Write-Host "Connect-VIServer" $a  "-Username" $b "-Password" $c
}

function OpenVMConsole ()
{
	$VMs = Get-Vm
	for($i=0;$i-le $VMs.length-1;$i++){"`{0} = {1}" -f $i,$VMs[$i]}
	$VMID = Read-host "Which VM do you want to open the Console from?" 
	Open-VMConsoleWindow $VMs[$VMID]
	pause
}

function VMHostPing ()
{
	$VMHosts = Get-VMHost
	if ( $VMHosts.length -gt 1 ){
		for($i=0;$i-le $VMHosts.length-1;$i++){"`{0} = {1}" -f $i,$VMHosts[$i]}
		$VMHostID = Read-host "Which Host do you want to ping from?"
		$VMHost = $VMHosts[$VMHostID]
		#$ESXiCLI = Get-EsxCli -v2 -VMHost $VMHost
	} else {
		$VMHost = $VMHosts
		#$ESXiCLI = Get-EsxCli -v2 -VMHost $VMHost
	}
	
	$ESXiCLI = Get-EsxCli -v2 -VMHost $VMHost
	# $ESXiCLI.network.ip.interface.ipv4.address.list.Invoke()
	$params = $ESXiCLI.network.diag.ping.CreateArgs()
	$params.host = Read-host "Which FQDN/IP do you want to ping to?"
	$params.count = Read-host "How many pings?"
	
	#if ( $VMHosts.length -gt 1 ){
	#	for($i=0;$i-le $VMHosts.length-1;$i++){"`{0} = {1}" -f $i,$VMHosts[$i]}
	#	$VMHostID = Read-host "Which Host do you want to ping from?" 
	#	$ESXiCLI = Get-EsxCli -v2 -VMHost $VMHosts[$VMHostID]
	#} else {
	#	$ESXiCLI = Get-EsxCli -v2 -VMHost $VMHosts
	#}
	
	$params.interface = 'vmk0'
	$results = $ESXiCLI.network.diag.ping.Invoke($params)
	$results.summary
	# pause
}

# $ESXiCLI = Get-EsxCli -v2 -VMHost labesxi65-0.lab.local
# $ESXiCLI.network.ip.interface.ipv4.address.list.Invoke()
# $params = $ESXiCLI.network.diag.ping.CreateArgs()
# $params.host = '192.168.51.10'
# $params.count = 5
# $params.interface = 'vmk0'
# $resultado = $ESXiCLI.network.diag.ping.Invoke($params)
# $resultado = $ESXiCLI.network.diag.ping.Invoke($params)
# $resultado.summary


function Menu-task ($a, $b, $c, $d, $e, $f)
{
	switch ($a)
	{
		'1' {
			vDocum -d $b
		} '2' {
			sshmgmt						
		} '3' {
			esxiback -a $c					
		} '4' {
			reset-esxi-root-password
		} '5' {
			checktime
		} '6' {
			ShowAccesData -a $d -b $e -c $f
		} '7' {
			OpenVMConsole
		} '8' {
			VMHostPing
		} 'q' {
                return
		}
	}
}

function ServiceInCustomer ($a, $b, $c ,$d, $e)
{
    connvis -a $a -b $b -c $c
	Show-Menu-task
	$input2 = Read-Host "Please make a selection"
	Menu-task -a $input2 -b $d -c $e -d $a -e $b -f $c
	disconnvis
}