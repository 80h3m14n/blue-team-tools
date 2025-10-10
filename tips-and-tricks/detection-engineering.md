# Detection engineering

Detection engineering is a structured, systematic approach to developing, implementing, and refining threat detection mechanisms tailored to an organization's specific environment.

The process is cyclical and includes stages such as:

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

1\. Low-Interaction Honeypots   

   - Simulate common vulnerabilities but limit attacker actions.  

   - Example: A fake login portal designed to log unauthorized attempts.  

  

2\. High-Interaction Honeypots  

   - Provide real systems with deep interaction to monitor sophisticated attacks.  

   - Example: A full-functioning but isolated server used to analyze real-world malware behavior.  

  

3\. Research vs. Production Honeypots  

 - Research Honeypots : Used by cybersecurity experts to study attack techniques.  

 - Production Honeypots : Used within organizations to detect live threats.  

 **Forms of honeypots(Make It Believable)**

\- Fake but legitimately looking files i.e `passwords.txt`, `database.sql`

\- Decoy user account with a Service Principle Name (SPN) that masquerades as a real one.

\- Alter HTTP response header

\- Fake DNS records

\- Run services on standard ports (22, 80, 445, etc.).

  
**Isolate the honeypot**

⚠️Put it on a separate VLAN or in a cloud instance with no path back to production.

Use a firewall to limit outbound traffic (don’t let your honeypot become someone else’s botnet host).


**Add Logging & Monitoring**

Forward logs to your SIEM (Splunk, ELK, Wazuh).

Enable pcap or Zeek to capture full network traffic.

Record keystrokes, commands, uploads.



**Honeypot Tools**

\- [Cowrie SSH/Telnet Honeypot](https://github.com/cowrie/cowrie)

\- [Dionaea malware collection honeypot](https://github.com/DinoTools/dionaea)

\- [Conpot ICS/SCADA honeypot](https://github.com/mushorg/conpot)

\- [T-Pot multiple honeypots in one VM](https://github.com/telekom-security/tpotce)

\- [Nepenthes honeypots](http://nepenthes.carnivore.it)

\- KFSensor  

\- Pentbox  

\- WinPcap  


### Resources

\- [MITRE ATT&CK](https://attack.mitre.org/)


🕵️‍♂️ “Stay alert, stay patched.”
