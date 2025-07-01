# All_in_PowerShell
<img width="220" alt="All_in_Bash" src="https://raw.githubusercontent.com/PowerShell/PowerShell/eb7d6c191d788e3bf66ed4229916df2a3f225d3d/assets/ps_black_64.svg" align=left> <br>
<br>
It is not my intention to steal or take credit for others' work. My scripts are a product of both my own creation and a lot of borrowing and inspiration from like-minded individuals out there on forums, manuals, and the internet.
<br>
<br>
<br>
---
## Script Index
Script | Function
-------|---------
[check_tanzu_supervisor-controlplanes-disk.ps1](/bin/check_tanzu_supervisor-controlplanes-disk.ps1)|This PowerShell script retrieves all VMware Tanzu Supervisor Control Plane VMs and checks their disk usage. It outputs results for use as a Nagios check and also sends alerts to syslog if thresholds are exceeded.
