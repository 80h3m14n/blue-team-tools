# Blue-team-tools

Practical toolkit for blue teams to detect, analyze, and mitigate cyber threats effectively, includes: tips & tricks, scripts, configurations, and tools for incident response, malware analysis, network monitoring, and threat intelligence.

1. Preparation/hardening
2. Detection & monitoring
3. Analysis
4. Containment/isolation
5. Eradication
6. Recovery
7. Lessons Learned

## 🧭 Table of Contents
- [Project Structure](#-project-structure)
- [Contents](#-contents)
  - [Incident Response](#incident-response)
  - [Malware Analysis](#malware-analysis)
  - [Network Monitoring](#network-monitoring)
  - [Threat Intelligence](#threat-intelligence)
- [Tips & Tricks](#-tips--tricks)
- [Docs](#-docs)
- [Contributing](#-contributing)
- [License](#-license)
- [Author](#-author)

## 📁 Project Structure

<details>
<summary>📂 Click to expand</summary>

```bash
blue-team-tools/
│
├── README.md                     # Overview, usage, and setup
│
├── docs/
│   ├── index.md                  # Landing page for GitHub Pages
│   ├── ir-playbooks.md           # Incident response workflows
│   ├── malware-analysis.md       # Malware analysis notes/tips
│   ├── network-monitoring.md     # Setup guides for Zeek, Suricata, etc.
│   └── threat-intel.md           # Threat intel sources, enrichment methods
│
├── scripts/
│   ├── incident-response/
│   │   ├── memdump_collector.ps1
│   │   ├── log_parser.py
│   │   └── triage_script.sh
│   │
│   ├── malware-analysis/
│   │   ├── yara_rules/
│   │   │   └── suspicious_behavior.yar
│   │   ├── unpackers/
│   │   │   └── upx_unpacker.py
│   │   └── sandbox_helpers/
│   │       └── process_monitor.py
│   │
│   ├── network-monitoring/
│   │   ├── pcap_analyzer.py
│   │   ├── zeek/
│   │   │   ├── custom_scripts/
│   │   │   └── zeek_local_config.zeek
│   │   └── suricata/
│   │       └── rules/
│   │           └── custom.rules
│   │
│   └── threat-intel/
│       ├── intel_feeds_collector.py
│       ├── enrichments/
│       │   └── vt_lookup.py
│       └── indicators/
│           └── sample_iocs.csv
│
├── configs/
│   ├── sysmon/
│   │   └── sysmon-config.xml
│   ├── osquery/
│   │   └── queries.conf
│   ├── wazuh/
│   │   └── custom_rules.xml
│   └── elastic/
│       └── detection_rules/
│           └── suspicious_login.json
│
├── tools/
│   ├── ir-helpers/
│   │   └── forensic_collector/
│   ├── malware-analysis/
│   │   └── sample-detector/
│   └── network-tools/
│       └── passive_sniffer/
│
└── tips-and-tricks/
    ├── powershell-snippets.md
    ├── bash-oneliners.md
    ├── python-tricks.md
    └── detection-engineering.md
```
</details>



## 📋 Contents


## Incident Response
- Memory dump collectors  
- Log parsing & triage scripts  
- PowerShell and Bash automation  

## Malware Analysis
- YARA rules and unpackers  
- Sandbox helper scripts  
- IOC extractors  

## Network Monitoring
- PCAP parsers and analyzers  
- Zeek and Suricata configs  
- Detection rule templates  

## Threat Intelligence

Threat Intelligence are platforms that help analysts access different indicators of compromise (IoC) shared by people from around the world.

- Feed collectors & enrichment scripts  
- IOC management  
- Integration examples for MISP / VirusTotal / OTX  

**Threat emulation frameworks**

- [Caldera](https://github.com/mitre/caldera)

### Open-source platforms

- [Abuse.ch](https://abuse.ch/#statistics) 
- [Abuse.ch urlhaus](https://urlhaus.abuse.ch/browse/)
- [Abuse.ch Feodotracker](https://feodotracker.abuse.ch/)
- [Alienvault Open Threat Exchange (OTX)](https://otx.alienvault.com/browse/global/pulses)
- [Any.run](https://app.any.run)  
- [Abuse IP db](https://www.abuseipdb.com/)  
- [Blocklist Fail2ban reporting service](https://www.blocklist.de/en/index.html)
- [Bruteforce blocker](https://danger.rulez.sk/index.php/bruteforceblocker/download/)
- [CINS score Army list](https://cinsscore.com/#list)
- [Dan tools](https://www.dan.me.uk/)
- [FireHol IP List](https://iplists.firehol.org/)
- [Github](https://github.com)  
- [Malware Information Sharing Platform (MISP)](https://misp-project.org/index.html)  
- [MITRE CTI](https://github.com/mitre/cti)
- [Open CTI](https://github.com/OpenCTI-Platform/opencti)
- [Project honeypot](https://www.projecthoneypot.org/)
- Social media content i.e X, Facebook, Reddit, Bluesky, Telegram
- [Threat feeds](https://threatfeeds.io/)

### Close source intelligence platforms  

Information from non-public sources  

- Past court cases  
- Law enforcement  
- Police operations  
- Military & intelligence sources  
- Private organizations  
- Internet service providers (ISP)  

### Commercial sources platforms

- [Anomali Threat Stream](https://www.anomali.com/products/threatstream)
- [Recorded Future](https://www.recordedfuture.com/)
- [STIX - sharing threat intel](https://oasis-open.github.io/cti-documentation/)
- [Threat Connect](https://threatconnect.com/)

### 1. Technical controls

- Network segmentation
- Firewalls
- Intrusion Detection Systems (IDS)
- Intrusion Prevention Systems (IPS)
- Honeypots
- Proxy servers
- Virtual Private Networks (VPNs)
- Security Information and Event Management (SIEM) systems
- User and Entity Behavior Analytics (UBA)
- Anti-malware software.

## 💡 Tips & Tricks

Check out the [tips-and-tricks/](https://github.com/80h3m14n/blue-team-tools/tree/main/tips-and-tricks) folder for:

- [PowerShell snippets](https://github.com/80h3m14n/blue-team-tools/blob/main/tips-and-tricks/powershell-snippets.md)
- [Bash oneliners](https://github.com/80h3m14n/blue-team-tools/blob/main/tips-and-tricks/bash-oneliners.md)
- [Detection engineering tricks](https://github.com/80h3m14n/blue-team-tools/blob/main/tips-and-tricks/detection-engineering.md)
- [Python tricks](https://github.com/80h3m14n/blue-team-tools/blob/main/tips-and-tricks/python-tricks.md)
- Threat hunting queries

✅ Actively hunt threats and never rely solely on tools  
✅ Invest in your infrastructure  
✅ Learn to adapt to changes  
✅ Have the mindset of an attacker  

## 📘 Docs

Detailed guides & notes live in the [docs/](https://github.com/80h3m14n/blue-team-tools/tree/main/docs) folder.  
Use it like a blue team wiki — IR playbooks, network tuning, malware triage checklists, etc.

- [IR Playbooks](https://github.com/80h3m14n/blue-team-tools/blob/main/docs/ir-playbooks.md)
- [Malware Analysis](https://github.com/80h3m14n/blue-team-tools/blob/main/docs/malware-analysis.md)
- [Network Monitoring](https://github.com/80h3m14n/blue-team-tools/blob/main/docs/network-monitoring.md)
- [Threat Intel](https://github.com/80h3m14n/blue-team-tools/blob/main/docs/threat-intel.md)

## Additional resources

- [D3fend MITRE](https://d3fend.mitre.org/)
- [Microsoft Security Response Center](https://msrc.microsoft.com)
- [Opensecuritytraining](https://opensecuritytraining.info/Welcome.html)
- [Privacy International](https://privacyinternational.org/learn)
- [SANS cyber races](https://www.sans.org/cyberaces)
- [Threat Modelling Manifesto](https://threatmodelingmanifesto.org)

## 🤝 Contributing

Pull requests are welcome — just follow the folder structure and drop a short note in the README of your section.

## 📝 License

This repo is licensed under the MIT License — use it, modify it, share it.  
Just give credit where it’s due.

## 🧤 Author

[80h3m14n](https://github.com/80h3m14n/)  
Infosec & Cyber Defense Enthusiast

🕵️‍♂️ “Stay alert, stay patched.”
