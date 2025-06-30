#
# This PowerShell script connects to a vCenter server, identifies all VMware Tanzu Supervisor Control Plane virtual machines, and examines their disk utilization. It generates output formatted for Nagios monitoring, 
# raising critical alerts if usage exceeds a configurable threshold (default 80%). Additionally, on Unix systems, it logs any critical events to syslog, enabling integration with broader infrastructure monitoring and alerting tools.
