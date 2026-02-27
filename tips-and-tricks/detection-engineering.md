# Detection engineering

Detection engineering is a structured, systematic approach to developing, implementing, and refining threat detection mechanisms tailored to an organization's specific environment.

The process is cyclic and includes stages such as:

1. Threat modeling
2. Rule development
3. Validation
4. Deployment
5. Continuous tuning



## Honeypots (deception)

Honeypots are security mechanisms designed to lure attackers and study their behavior.  

They're like digital traps—intentionally vulnerable systems or networks set up to attract hackers, allowing cyber security experts to analyze threats in a controlled environment.  

  
**Reasons to use Honeypots** 

✔ Detect cyber threats early   

✔ Study attackers' tactics   

✔ Divert attackers from real assets   

✔ Improve defensive strategies  

  

**Types of Honeypots**  

1. Low-Interaction Honeypots   

   - Simulate common vulnerabilities but limit attacker actions.  
   - Example: A fake login portal designed to log unauthorized attempts.  

  

2. High-Interaction Honeypots  

   - Provide real systems with deep interaction to monitor sophisticated attacks.  
   - Example: A full-functioning but isolated server used to analyze real-world malware behavior.  

  

3. Research vs. Production Honeypots  

 - Research Honeypots : Used by cybersecurity experts to study attack techniques.  
 - Production Honeypots : Used within organizations to detect live threats.  


 **Forms of honeypots(Make It Believable)**

- Database honeypot
- Website honeypot
- SSH honeypot
- Active directory honeypot
- Server honeypot

  
**Isolate the honeypot**

⚠️Put it on a separate VLAN or in a cloud instance with no path back to production.

Use a firewall to limit outbound traffic (don’t let your honeypot become someone else’s botnet host).


**Add Logging & Monitoring**

Forward logs to your SIEM (Splunk, ELK, Wazuh).

Enable pcap or Zeek to capture full network traffic.

Record keystrokes, commands, uploads.



**Honeypot Tools**

- [Cowrie SSH/Telnet Honeypot](https://github.com/cowrie/cowrie)
- [Dionaea malware collection honeypot](https://github.com/DinoTools/dionaea)
- [Conpot ICS/SCADA honeypot](https://github.com/mushorg/conpot)
- [T-Pot multiple honeypots in one VM](https://github.com/telekom-security/tpotce)
- [Nepenthes honeypots](http://nepenthes.carnivore.it)
- KFSensor  
- Pentbox  
- WinPcap  


---


## Malware scanners

Example: Install calmAV & rkhunter

```bash
sudo dnf install clamav clamav-update rkhunter -y
sudo freshclam   # Update virus definitions
sudo rkhunter --update
sudo rkhunter --propupd
```

Schedule scans

```bash
sudo crontab -e
# Add:
0 3 * * 0 clamscan -r / --bell -i >/var/log/clamscan.log 2>&1
0 4 * * 0 rkhunter --check --skip-keypress >/var/log/rkhunter.log 2>&1
```


--- 

## IPS & IDS

Exmple: Install AIDE

```bash
sudo dnf install aide -y
sudo aide --init
sudo mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
```

Shedule daily checks

```bash
sudo crontab -e
# Add this line:
0 4 * * * /usr/sbin/aide --check | mail -s "AIDE check on $(hostname)" root
```


---


### Resources

- [MITRE ATT&CK](https://attack.mitre.org/)


🕵️‍♂️ “Stay alert, stay patched.”
