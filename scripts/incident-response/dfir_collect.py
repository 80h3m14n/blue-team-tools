#!/usr/bin/env python3
"""
DFIR Evidence Collection Script
Collects browser history and system logs for forensic analysis
"""

import os
import sys
import shutil
import sqlite3
import json
import platform
import subprocess
from datetime import datetime
from pathlib import Path

class DFIRCollector:
    def __init__(self):
        self.output_dir = Path(f"DFIR_Collection_{datetime.now().strftime('%Y%m%d_%H%M%S')}")
        self.output_dir.mkdir(exist_ok=True)
        self.report = []

    def log(self, message, status="INFO"):
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        entry = f"[{timestamp}] [{status}] {message}"
        self.report.append(entry)
        print(entry)

    def collect_chrome_history(self):
        """Collect Chrome browser history"""
        paths = {
            "Windows": os.path.expandvars(r"%LOCALAPPDATA%\Google\Chrome\User Data\Default\History"),
            "Darwin": os.path.expanduser("~/Library/Application Support/Google/Chrome/Default/History"),
            "Linux": os.path.expanduser("~/.config/google-chrome/Default/History")
        }

        history_path = paths.get(platform.system())
        if history_path and os.path.exists(history_path):
            dest = self.output_dir / "Chrome_History"
            try:
                shutil.copy2(history_path, dest)
                self.log("Chrome history collected", "SUCCESS")

                # Extract readable data
                self.parse_sqlite_history(history_path, "Chrome")
            except Exception as e:
                self.log(f"Chrome collection failed: {e}", "ERROR")
        else:
            self.log("Chrome history not found", "WARNING")

    def collect_firefox_history(self):
        """Collect Firefox browser history"""
        base_paths = {
            "Windows": os.path.expandvars(r"%APPDATA%\Mozilla\Firefox\Profiles"),
            "Darwin": os.path.expanduser("~/Library/Application Support/Firefox/Profiles"),
            "Linux": os.path.expanduser("~/.mozilla/firefox")
        }

        base_path = base_paths.get(platform.system())
        if not base_path or not os.path.exists(base_path):
            self.log("Firefox profiles not found", "WARNING")
            return

        for profile in os.listdir(base_path):
            profile_path = os.path.join(base_path, profile)
            if os.path.isdir(profile_path):
                places_db = os.path.join(profile_path, "places.sqlite")
                if os.path.exists(places_db):
                    dest = self.output_dir / f"Firefox_History_{profile}.sqlite"
                    try:
                        shutil.copy2(places_db, dest)
                        self.log(f"Firefox history collected from {profile}", "SUCCESS")
                        self.parse_sqlite_history(places_db, f"Firefox_{profile}")
                    except Exception as e:
                        self.log(f"Firefox collection failed: {e}", "ERROR")

    def parse_sqlite_history(self, db_path, browser_name):
        """Parse SQLite history to CSV/JSON for quick analysis"""
        try:
            # Create a copy to avoid locking issues
            temp_db = self.output_dir / f"{browser_name}_temp.db"
            shutil.copy2(db_path, temp_db)

            conn = sqlite3.connect(str(temp_db))
            cursor = conn.cursor()

            output = []
            try:
                # Chrome/Edge query
                cursor.execute("""
                    SELECT url, title, datetime(last_visit_time/1000000-11644473600, 'unixepoch') as visit_time, visit_count
                    FROM urls ORDER BY last_visit_time DESC LIMIT 1000
                """)
                rows = cursor.fetchall()

                for row in rows:
                    output.append({
                        "url": row[0],
                        "title": row[1],
                        "visit_time": row[2],
                        "visit_count": row[3]
                    })
            except:
                # Firefox query
                try:
                    cursor.execute("""
                        SELECT url, title, datetime(last_visit_date/1000000, 'unixepoch') as visit_time, visit_count
                        FROM moz_places ORDER BY last_visit_date DESC LIMIT 1000
                    """)
                    rows = cursor.fetchall()
                    for row in rows:
                        output.append({
                            "url": row[0],
                            "title": row[1],
                            "visit_time": row[2],
                            "visit_count": row[3]
                        })
                except Exception as e:
                    self.log(f"Could not parse {browser_name} history: {e}", "WARNING")

            # Save parsed data
            json_path = self.output_dir / f"{browser_name}_Parsed_History.json"
            with open(json_path, 'w') as f:
                json.dump(output, f, indent=2)

            conn.close()
            os.remove(temp_db)

        except Exception as e:
            self.log(f"History parsing failed: {e}", "ERROR")

    def collect_system_logs(self):
        """Collect system logs based on OS"""
        if platform.system() == "Windows":
            self.collect_windows_logs()
        elif platform.system() == "Darwin":
            self.collect_macos_logs()
        else:
            self.collect_linux_logs()

    def collect_windows_logs(self):
        """Collect Windows Event Logs"""
        log_dir = self.output_dir / "EventLogs"
        log_dir.mkdir(exist_ok=True)

        critical_logs = ["Security", "System", "Application", "Setup", "ForwardedEvents"]

        for log in critical_logs:
            try:
                output_file = log_dir / f"{log}.evtx"
                subprocess.run(["wevtutil", "epl", log, str(output_file)],
                           capture_output=True, check=True)
                self.log(f"Collected {log} event log", "SUCCESS")
            except Exception as e:
                self.log(f"Failed to collect {log}: {e}", "ERROR")

    def collect_macos_logs(self):
        """Collect macOS Unified Logs"""
        log_dir = self.output_dir / "Logs"
        log_dir.mkdir(exist_ok=True)

        try:
            # Export last 7 days of logs
            output_file = log_dir / "system_logs.logarchive"
            subprocess.run([
                "log", "collect",
                "--last", "7d",
                "--output", str(output_file)
            ], capture_output=True, check=True)
            self.log("macOS unified logs collected", "SUCCESS")
        except Exception as e:
            self.log(f"Log collection failed: {e}", "ERROR")

        # Copy traditional logs
        traditional_logs = ["/var/log/system.log", "/var/log/install.log"]
        for log in traditional_logs:
            if os.path.exists(log):
                try:
                    shutil.copy2(log, log_dir / os.path.basename(log))
                    self.log(f"Collected {log}", "SUCCESS")
                except Exception as e:
                    self.log(f"Failed to collect {log}: {e}", "ERROR")

    def collect_linux_logs(self):
        """Collect Linux system logs"""
        log_dir = self.output_dir / "Logs"
        log_dir.mkdir(exist_ok=True)

        log_files = [
            "/var/log/syslog",
            "/var/log/auth.log",
            "/var/log/secure",
            "/var/log/kern.log",
            "/var/log/dmesg",
            "/var/log/apache2/access.log",
            "/var/log/nginx/access.log",
            "/var/log/audit/audit.log"
        ]

        for log in log_files:
            if os.path.exists(log):
                try:
                    shutil.copy2(log, log_dir / os.path.basename(log))
                    self.log(f"Collected {log}", "SUCCESS")
                except Exception as e:
                    self.log(f"Failed to collect {log}: {e}", "ERROR")

        # Journal logs (systemd)
        try:
            journal_dir = log_dir / "journal"
            journal_dir.mkdir(exist_ok=True)
            subprocess.run([
                "journalctl", "--since", "7 days ago",
                "--output", "json"
            ], stdout=open(journal_dir / "journal.json", "w"), check=True)
            self.log("Systemd journal collected", "SUCCESS")
        except Exception as e:
            self.log(f"Journal collection failed: {e}", "ERROR")

    def collect_network_info(self):
        """Collect network configuration and connections"""
        net_dir = self.output_dir / "Network"
        net_dir.mkdir(exist_ok=True)

        info = {
            "hostname": platform.node(),
            "platform": platform.platform(),
            "timestamp": datetime.now().isoformat()
        }

        # Network connections
        try:
            if platform.system() == "Windows":
                result = subprocess.run(["netstat", "-ano"], capture_output=True, text=True)
            else:
                result = subprocess.run(["netstat", "-tuln"], capture_output=True, text=True)
            info["netstat"] = result.stdout
        except Exception as e:
            info["netstat_error"] = str(e)

        # ARP table
        try:
            if platform.system() == "Windows":
                result = subprocess.run(["arp", "-a"], capture_output=True, text=True)
            else:
                result = subprocess.run(["ip", "neigh"], capture_output=True, text=True)
            info["arp"] = result.stdout
        except Exception as e:
            info["arp_error"] = str(e)

        # DNS cache
        try:
            if platform.system() == "Windows":
                result = subprocess.run(["ipconfig", "/displaydns"], capture_output=True, text=True)
                info["dns"] = result.stdout
        except:
            pass

        with open(net_dir / "network_info.json", "w") as f:
            json.dump(info, f, indent=2)

        self.log("Network information collected", "SUCCESS")

    def generate_report(self):
        """Generate collection summary report"""
        report_path = self.output_dir / "COLLECTION_REPORT.txt"
        with open(report_path, "w") as f:
            f.write("=" * 60 + "\n")
            f.write("DFIR EVIDENCE COLLECTION REPORT\n")
            f.write("=" * 60 + "\n\n")
            f.write(f"Collection Time: {datetime.now()}\n")
            f.write(f"Platform: {platform.platform()}\n")
            f.write(f"Hostname: {platform.node()}\n")
            f.write(f"Output Directory: {self.output_dir.absolute()}\n\n")
            f.write("Collection Log:\n")
            f.write("-" * 60 + "\n")
            for entry in self.report:
                f.write(entry + "\n")

        print(f"\n{'='*60}")
        print(f"Collection complete. Evidence saved to: {self.output_dir.absolute()}")
        print(f"{'='*60}")

    def run(self):
        """Execute full collection"""
        print("=" * 60)
        print("DFIR EVIDENCE COLLECTION")
        print("=" * 60)

        self.collect_chrome_history()
        self.collect_firefox_history()
        self.collect_system_logs()
        self.collect_network_info()
        self.generate_report()

        # Create hashes of all collected files
        try:
            hash_file = self.output_dir / "file_hashes.txt"
            with open(hash_file, "w") as f:
                for file in self.output_dir.rglob("*"):
                    if file.is_file():
                        import hashlib
                        sha256 = hashlib.sha256(file.read_bytes()).hexdigest()
                        f.write(f"{sha256}  {file.relative_to(self.output_dir)}\n")
            self.log("File hashes generated", "SUCCESS")
        except Exception as e:
            self.log(f"Hash generation failed: {e}", "WARNING")

if __name__ == "__main__":
    collector = DFIRCollector()
    collector.run()
