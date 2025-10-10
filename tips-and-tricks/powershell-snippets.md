
## Powershell (.ps1) and Command line (.cmd or .bat)


## Analyze network connections

Analyze network connections and identify the process associated with each: lists local and remote IP addresses and ports, connection state, process name, and the full command line of the process, sorted by remote address.

```bash
Get-NetTCPConnection | select LocalAddress,localport,remoteaddress,remoteport,state,@{name="process";Expression={(get-process -id $_.OwningProcess).ProcessName}}, @{Name="cmdline";Expression={(Get-WmiObject Win32_Process -filter "ProcessId = $($_.OwningProcess)").commandline}} | sort Remoteaddress -Descending | ft -wrap -autosize
```

## Analyse suspicious services

For identifying suspicious services, check registry entries for services not located in `C:\System32` using:

```bash
Get−ItemProperty−Path"HKLM:
System
CurrentControlSet
services
∗"∣whereImagePath−notlike"∗System32∗"∣ftPSChildName,ImagePath−autosize∣out−string−width800
```


### Disk information

For system hardware and disk space information: to retrieve disk capacity and free space in gigabytes

```bash
gcim -ClassName Win32_LogicalDisk | Select -Property DeviceID, DriveType, @{L='FreeSpaceGB';E={"{0:N2}" -f ($_.FreeSpace /1GB)}}, @{L="Capacity";E={"{0:N2}" -f ($_.Size/1GB)}} | fl
```


## 👥© Credits

Thank you for your work, which I have incorporated into this project. Your contribution has been valuable, and I appreciate the effort you've put into it.

\- [Blue teamnotes by PurpleW0lf](https://github.com/Purp1eW0lf/Blue-Team-Notes)



🕵️‍♂️ “Stay alert, stay patched.”
