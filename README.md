# Blue-team-tools

Practical toolkit for blue teams to detect, analyze, and mitigate cyber threats effectively, includes: tips & tricks, scripts, configurations, and tools for incident response, malware analysis, network monitoring, and threat intelligence.

### Blue team life cycle

1. Preparation/hardening
2. Detection & monitoring
3. Analysis
4. Containment/isolation
5. Eradication
6. Recovery
7. Lessons Learned



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
│   │
│   ├── malware-analysis/
│   │   ├── yara_rules/
│   │   ├── unpackers/
│   │   └── sandbox_helpers/
│   │
│   ├── network-monitoring/
│   │   ├── zeek/
│   │   └── suricata/
│   │
│   └── threat-intel/
│       └── indicators/  # Indicator of compromise (IOCs)
│
├── configs/
│   ├── sysmon/
│   ├── wazuh/
│
└── tips-and-tricks/
    ├── powershell-snippets.md
    ├── bash-oneliners.md
    ├── python-tricks.md
    └── detection-engineering.md
```
</details>



### Technical controls

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
- [Threat hunting tips](https://github.com/80h3m14n/blue-team-tools/blob/main/tips-and-tricks/threat-hunting.md)


✅ Actively hunt threats and never solely rely on tools 
✅ Invest in your infrastructure
✅ Learn to adapt to changes
✅ Have the mindset of an attacker 
✅ If you happen to opt to outsource, make sure to choose the right vendor  



## 📘 Docs

Detailed guides & notes live in the [docs/](https://github.com/80h3m14n/blue-team-tools/tree/main/docs) folder.  
Use it like a blue team wiki — IR playbooks, network tuning, malware triage checklists, etc.

- [IR Playbooks](https://github.com/80h3m14n/blue-team-tools/blob/main/docs/ir-playbooks.md)
- [Malware Analysis](https://github.com/80h3m14n/blue-team-tools/blob/main/docs/malware-analysis.md)
- [Network Monitoring](https://github.com/80h3m14n/blue-team-tools/blob/main/docs/network-monitoring.md)
- [Preparation](https://github.com/80h3m14n/blue-team-tools/blob/main/docs/preparation.md)
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
