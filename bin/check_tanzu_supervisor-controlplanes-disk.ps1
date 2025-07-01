<#
.SYNOPSIS
Checks disk usage on VMware Tanzu Supervisor Control Plane VMs for Nagios monitoring and syslog alerts.

.DESCRIPTION
This script connects to vCenter, retrieves all Supervisor Control Plane VMs (by default but other VMs name can be used),
checks their disk usage, outputs Nagios-compatible results and logs critical usage
to syslog on Unix systems.

.PARAMETER vmName Specifies the VM that will be checked. Default is *SupervisorControlPlane*.
threshold Specifies the disk usage percentage threshold that triggers critical alerts. Default is 80.

.EXAMPLE
.\check_supervisorVMsDisks.ps1 -threshold 90

Runs the script with a threshold of 90%.

.NOTES
Author: Rafael.Urrutia.S@gmail.com


.LINK
https://github.com/rafaelurrutiasilva/All_in_PowerShell/edit/main/bin/check_tanzu_supervisor-controlplanes-disk.ps1
#>


param(
    [string]$vmName = "*SupervisorControlPlane*",
    [int]$threshold = 80
)
$scriptname = "check_supervisorVMsDisks.ps1"
$syslogCmd = "/bin/logger"

# Function to connect to vcenter server
Connect-to-vcenter
$supervisorVMs = (Get-VM -Name $vmName)

$alerts = @()
$reportLines = @()
$perfData = @()

# === Disk monitoring ===
$supervisorVMs | ForEach-Object {
    $vm = $_
    if ($vm.ExtensionData.Guest.ToolsStatus -eq "toolsOk") {
        $vm.ExtensionData.Guest.Disk | ForEach-Object {
            $disk = $_
            $capacityGB  = [math]::Round($disk.Capacity / 1GB, 2)
            $freeGB      = [math]::Round($disk.FreeSpace / 1GB, 2)
            $usedPercent = [math]::Round((($disk.Capacity - $disk.FreeSpace) / $disk.Capacity) * 100, 2)

            # === Root mount logik ===
            $parts = $disk.DiskPath -split "/"
            if ($parts.Count -ge 2 -and $parts[1]) {
                $mount = "/" + $parts[1]
                $diskLabel = "$mount"
            } else {
                $mount = "/"
                $diskLabel = "/"
            }

            # === Perfdata och rapport ===
            $vmName = $vm.Name -replace ' ', ''
            $vmName = $vmName -replace 'SupervisorControlPlaneVM', 'SCPvm'

            $label = "$($vmName)$diskLabel"
            $perfData += "$label=$usedPercent%;$threshold;100;0;100"

            $line = "$($vmName) ${mount}: $usedPercent% used ($freeGB GB free)"
            $reportLines += $line

            if ($usedPercent -ge $threshold) {
                $alerts += $line
            }
        }
    } else {
        Write-Warning "$($vmName): VMware Tools not running or not installed"
    }
}

# === NAGIOS-OUTPUT + SYSLOG VID LARM ===
$perfString = $perfData -join " "

if ($alerts.Count -eq 0) {
    $joined = $reportLines -join ", "
    Write-Output "OK: All SupervisorCP disks are below $threshold% usage. $joined| $perfString"
    exit 0
}
else {
    $joined = $alerts -join ", "
    Write-Output "CRITICAL: $joined| $perfString"

    # === SYSLOG ===
    if ($PSVersionTable.Platform -eq "Unix" -and (Test-Path $syslogCmd)) {
        $syslogMessage = "$scriptname $joined"
        & $syslogCmd -p local3.err -t "myLinuxServer[lxServer]" "$syslogMessage"
    }

    exit 2
}
Disconnect-VIServer * -Confirm:$false
