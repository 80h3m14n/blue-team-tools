#!/usr/bin/env python3
import subprocess, sys, base64, json, re, shlex

if len(sys.argv) < 2:
    print("usage: pcap_extract.py file.pcap")
    sys.exit(1)

pcap = sys.argv[1]

def tshark_fields(filter_expr, fields):
    # fields can be list or whitespace-separated string
    if isinstance(fields, str):
        fields = fields.split()
    cmd = ["tshark", "-r", pcap, "-Y", filter_expr, "-T", "fields"]
    for f in fields:
        cmd += ["-e", f]
    try:
        out = subprocess.check_output(cmd, stderr=subprocess.DEVNULL).decode(errors='ignore').splitlines()
    except subprocess.CalledProcessError:
        return []
    return out

results = {"http_auth": [], "cleartext_matches": [], "strings_hits": []}

# HTTP Authorization (fields robust)
http_lines = tshark_fields("http.authorization", ["http.authorization", "ip.src", "ip.dst"])
for line in http_lines:
    parts = line.split('\t')
    if not parts:
        continue
    auth = parts[0]
    src = parts[1] if len(parts) > 1 else ""
    dst = parts[2] if len(parts) > 2 else ""
    if auth.lower().startswith("basic "):
        token = auth.split(None, 1)[1]
        try:
            dec = base64.b64decode(token + "===" ).decode(errors='ignore')  # pad just in case
        except Exception:
            dec = ""
        results["http_auth"].append({"type": "basic", "raw": auth, "decoded": dec, "src": src, "dst": dst})
    else:
        results["http_auth"].append({"type": "other", "raw": auth, "src": src, "dst": dst})

# Try a verbose grep of cleartext protocols (best-effort)
try:
    verb = subprocess.check_output(["tshark", "-r", pcap, "-Y", "ftp || smtp || pop || imap || telnet || sip", "-V"], stderr=subprocess.DEVNULL).decode(errors='ignore')
    pat = re.compile(r'(password|passwd|username|user|login|authorization|bearer|token|api[_-]?key|secret)', re.I)
    for m in pat.finditer(verb):
        # capture a snippet around match
        i = max(0, m.start()-80)
        j = min(len(verb), m.end()+80)
        results["cleartext_matches"].append(verb[i:j])
except Exception:
    pass

# strings() scan (fast)
try:
    s = subprocess.check_output(["strings", pcap]).decode(errors='ignore')
    pat = re.compile(r'(password|passwd|username|user|login|authorization|bearer|token|api[_-]?key|secret)', re.I)
    for m in pat.finditer(s):
        # de-dupe similar hits
        hit = s[max(0, m.start()-40):m.end()+40].replace('\n',' ')
        if hit not in results["strings_hits"]:
            results["strings_hits"].append(hit)
except Exception:
    pass

print(json.dumps(results, indent=2))
