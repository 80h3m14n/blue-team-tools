## Bash one-liners

A collection of useful bash one-liners for blue team operations includes commands for system information, process monitoring, and network analysis.


## System Information & Reconnaissance

```bash
# List all scheduled tasks (cron jobs) for all users
for user in $(cut -f1 -d: /etc/passwd); do echo "=== $user ==="; crontab -u $user -l; done 2>/dev/null

# Check for suspicious cron jobs (common persistence mechanism)
grep -r "curl|wget|bash|sh|python|perl" /etc/cron* 2>/dev/null
```

## Network Analysis & Monitoring

```bash
# Check for IP addresses with high connection counts (potential DDoS)
netstat -an | grep -i 'established' | awk '{print $5}' | cut -d':' -f1 | sort | uniq -c | sort -rn | head -10

# Scan for open ports on local system (nmap alternative)
for port in {1..1024}; do (echo >/dev/tcp/localhost/$port) 2>/dev/null && echo "Port $port is open"; done

# Monitor SSH login attempts in real-time
tail -f /var/log/auth.log | grep -i 'accepted|failed'

# Check for potential brute force attempts
grep -i 'failed' /var/log/auth.log | awk '{print $11}' | sort | uniq -c | sort -rn | head -10
```

## Log Analysis & Forensics

```bash
# Search for specific patterns in logs
grep -i "error|failed|suspicious" /var/log/syslog

# Monitor logs in real-time
tail -f /var/log/auth.log
tail -f /var/log/syslog

# Count failed login attempts
grep -i "failed" /var/log/auth.log | wc -l

# Find recently modified files (last 24 hours)
find / -type f -mtime -1 2>/dev/null

# Find recently modified executable files
find / -type f -executable -mtime -7 2>/dev/null

# Check for hidden files in system directories
find /etc /usr /bin /sbin -name ".*" -type f 2>/dev/null

# Search for suspicious strings in files
grep -r "password|passwd|secret|credential" /home 2>/dev/null

# Check file integrity (requires baseline)
md5sum /important/file > baseline.md5
md5sum -c baseline.md5

# Find files with suspicious permissions
find / -perm -4000 -type f 2>/dev/null  # SUID files
find / -perm -2000 -type f 2>/dev/null  # SGID files

# Check for world-writable files
find / -type f -perm -002 2>/dev/null

# Analyze authentication logs for patterns
awk '/Failed|Invalid|illegal/ {print $0}' /var/log/auth.log

# Extract IP addresses from logs
grep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' /var/log/auth.log | sort | uniq -c | sort -rn

# Find configuration files that were recently changed
find /etc -type f -mtime -1 2>/dev/null

# Check for unauthorized SSH keys
find /home -name "authorized_keys" -exec cat {} \; 2>/dev/null

# Monitor process creation in real-time
ps -eo pid,ppid,user,cmd | watch -n 1

# Check for processes running from /tmp or unusual locations
ps aux | grep -E '/tmp|/var/tmp'

# Find processes with deleted executables (potential malware)
ls -l /proc/*/exe 2>/dev/null | grep deleted

# Check for loaded kernel modules
lsmod

# Find processes using specific ports
lsof -i :[PORT_NUMBER]
```

## Incident Response & Remediation

```bash
# Kill all processes from a specific user
pkill -u [username]

# Kill process by name
pkill [process_name]

# Kill process by PID
kill -9 [PID]

# Block IP address with iptables
iptables -A INPUT -s [IP_ADDRESS] -j DROP

# Unblock IP address
iptables -D INPUT -s [IP_ADDRESS] -j DROP

# Disable user account
usermod -L [username]

# Enable user account
usermod -U [username]

# Remove user from system
userdel -r [username]

# Change file ownership
chroot [username]:[group] [file/directory]

# Change file permissions
chmod 755 [file/directory]

# Create backup of important files
tar -czf backup_$(date +%Y%m%d_%H%M%S).tar.gz /important/path

# Extract backup archive
tar -xzf backup_archive.tar.gz

# Securely delete files
shred -u [file]

# Check for root user login attempts
grep -i "root" /var/log/auth.log

# Disable remote root login (edit sshd_config)
echo "PermitRootLogin no" >> /etc/ssh/sshd_config && systemctl restart sshd

# Check for active SSH sessions
who | grep -i pts

# Terminate all SSH sessions except current
pkill -9 -f "sshd:.*pts"

# Generate random password
openssl rand -base64 32

# Hash a password
echo -n "password" | sha256sum

# Verify file authenticity
sha256sum [file]

# Check system for compromised credentials
grep -i "password" /var/log/auth.log

# Monitor system calls in real-time (requires auditd)
ausearch -m all -i

# Check for unauthorized cron jobs
crontab -l | grep -v "^#" | grep -v "^$"

# Remove unauthorized cron job
crontab -e  # Then manually remove suspicious entries

# Check for suspicious network interfaces
ip link show

# Disable suspicious network interface
ip link set [interface] down

# Check for wireless interfaces in monitor mode
iwconfig

# Find all SUID/SGID binaries (potential privilege escalation)
find / -type f -perm /6000 2>/dev/null

# Check for processes running as root that shouldn't be
ps -eo user,cmd | grep "^root" | grep -v "rootful|system|kernel"

# Emergency shutdown (if system is compromised)
shutdown -h now

# Reboot system
reboot

# Check for kernel-level rootkits (requires rkhunter)
rkhunter --check
```

## Timestamp

To display the current date, time, and timezone in a bash prompt, use the following configuration in the `.bashrc` file:

```bash
PS1='\\[\\033[00;35m\\][`date +"%d-%b-%y %T %Z"]` ${PWD#"${PWD%/*/*}/"}\\n\\[\\033[01;36m\\]-> \\[\\033[00;37m\\]'
```

Always remember to document your actions and maintain proper authorization before executing commands on production systems.

🕵️‍♂️ “Stay alert, stay patched.”
