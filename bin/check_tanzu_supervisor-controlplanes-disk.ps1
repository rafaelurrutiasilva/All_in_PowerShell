#
# This PowerShell script connects to a vCenter server, identifies all VMware Tanzu Supervisor Control Plane virtual machines, and examines their disk utilization. It generates output formatted for Nagios monitoring, 
# raising critical alerts if usage exceeds a configurable threshold (default 80%). Additionally, on Unix systems, it logs any critical events to syslog, enabling integration with broader infrastructure monitoring and alerting tools.

param(
    [int]$threshold = 80
)
$scriptname = "check_supervisorVMsDisks"
$syslogCmd = "/bin/logger"

# Function to connect to vcenter server
Connect-to-vcenter

$supervisorVMs = (Get-VM -Name *SupervisorControlPlane*)

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
