<#
.SYNOPSIS
Deploy a VM from an OVA file using VMware Workstation or Player.

.DESCRIPTION
This script automates the deployment of a virtual machine from an OVA file.
It ensures the network is set to NAT, optionally expands the disk size,
and starts the VM, reporting its IP address when ready.

.PARAMETER VMName
Name of the VM to create.

.PARAMETER VMsDir
Directory where the VM will be created.

.PARAMETER OVAFile
Path to the OVA file to import.

.PARAMETER NewDiskSize
(Optional) New disk size in GB. Default is 16. If larger than 16, disk is expanded.

.PARAMETER Force
(Optional) If specified, existing VM with the same name is forcefully stopped and deleted.

.EXAMPLE
.\deploy_vm_from_ova_file.ps1 -VMName vmTest -OVAFile C:\ISOs\vm.ova -VMsDir C:\VMs -Force

.NOTES
Author: Rafael.Urrutia.S@gmail.com
Repo: https://github.com/rafaelurrutiasilva/All_in_PowerShell
Version: 2.0
Requirements: VMware Workstation or Player with OVFTool and PowerShell
#>
param(
    [Parameter(Mandatory=$true)][string]$VMName,
    [Parameter(Mandatory=$true)][string]$VMsDir,
    [Parameter(Mandatory=$true)][string]$OVAFile,
    [int]$NewDiskSize=16,
    [switch]$Force
)

# Ensure required tools exist
function Check-RequiredCommands {
    $commands = @("ovftool", "vmrun", "vmware-vdiskmanager")
    foreach ($cmd in $commands) {
        if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
            Write-Error "Required command '$cmd' not found. Please check PATH."
            exit 1
        }
    }
}

# Handle existing VM
function Handle-ExistingVM {
    param($VMXFile)
    if (Test-Path $VMXFile) {
        if ($Force) {
            Write-Host "Force flag set. Stopping and deleting existing VM..."
            vmrun stop $VMXFile -soft | Out-Null
            vmrun deleteVM $VMXFile | Out-Null
        } else {
            Write-Error "VM '$VMName' already exists. Use -Force to redeploy."
            exit 1
        }
    }
}

# Import OVA
function Import-OVA {
    Write-Host "Importing OVA file..."
    ovftool --overwrite --targetType=VMX --name=$VMName `
        --acceptAllEulas --noSSLVerify $OVAFile $VMsDir
}

# Set network to NAT and add config
function Update-Network {
    param($VMXFile)
    (Get-Content $VMXFile) -replace 'ethernet\d.connectionType = "bridged"', 'ethernet0.connectionType = "nat"' |
        Set-Content $VMXFile
    Add-Content $VMXFile 'guestinfo.ssh = "True"'
}

# Expand disk if needed
function Expand-Disk {
    param($VMXFile)
    if ($NewDiskSize -gt 16) {
        Write-Host "Expanding disk to $NewDiskSize GB..."
        $diskFile = (Select-String -Path $VMXFile -Pattern "\.vmdk").Matches[0].Value -replace '.* = "', '' -replace '"', ''
        $diskPath = Join-Path (Split-Path $VMXFile) $diskFile
        vmware-vdiskmanager -x ${NewDiskSize}GB $diskPath
    }
}

# Start VM and wait for IP
function Start-VM-AndWait {
    param($VMXFile)
    vmrun start $VMXFile | Out-Null
    Write-Host "Waiting for VMware Tools to start..."
    while ((vmrun checkToolsState $VMXFile) -notmatch "running") {
        Write-Host "." -NoNewline; Start-Sleep -Seconds 1
    }
    Write-Host "`nWaiting for IP address..."
    $ip = ""
    while (-not ($ip = vmrun getGuestIPAddress $VMXFile -wait 60)) {
        Write-Host "." -NoNewline; Start-Sleep -Seconds 1
    }
    Write-Host "`nVM is running at IP: $ip"
}

# MAIN workflow
$VMXFile = Join-Path -Path (Join-Path $VMsDir $VMName) "$VMName.vmx"

Check-RequiredCommands
Handle-ExistingVM -VMXFile $VMXFile
Import-OVA
Update-Network -VMXFile $VMXFile
Expand-Disk -VMXFile $VMXFile
Start-VM-AndWait -VMXFile $VMXFile
