# Cloud backup comparisons

## Open-source backup/sync programs

These are independent, open-source backup/sync programs (mostly command-line focused, some with GUIs) that you run on your own computer. They talk to cloud storage services (including Google Drive, OneDrive, pCloud, S3, Backblaze, etc.) using their APIs — but they are not the official apps from those companies.


| Tool      | Dedup + Compression | Native Cloud Support (GDrive/OneDrive/S3) | GUI Available     | Best For           |
|-----------|---------------------|-------------------------------------------|-------------------|--------------------|
| rclone    | ✅                  | Many (Google Drive, Onedrive)             | rcloneUI          | CLI-focused  |
| Restic    | ✅ + excellent      | Many (S3 etc.), rclone for others"        | ✅ (Pika, others) | Secure, efficient snapshots" |
| Borg      | ✅                  | Mostly SSH, rclone for cloud              | ✅ (Vorta)        | Long-time users, fuse mounts" |
| Kopia     | ✅                  | Good native + rclone                      | ✅ built-in GUI   | Modern UI + speed |
| Duplicati | ✅                  | Excellent (GDrive, OneDrive, S3, etc.)    | ✅ Web UI         | Easy setup, web-based |
| Déjà Dup  | Yes (via restic)    | Google Drive, OneDrive, etc. | Native GNOME integration | Simple desktop backups |


**Tool Selection Guidance**

Choose based on your threat model and operational needs:
- **For air-gapped or encrypted backups**: Restic or Borg (strong dedup + encryption).
- **For cloud-native workflows**: rclone (flexible, CLI-driven) or Duplicati (web UI).
- **For desktop users**: Kopia or Déjà Dup (GUI-first, GNOME integration).
- **For enterprise-scale**: Borg or Restic (efficient storage, scriptable).

Always test with a small dataset first — performance and compatibility vary by cloud provider and file type.



## Proprietary cloud storage & sync services

These are platforms that provide cloud storage which are closed-source clients (except sometimes parts are open), tied to the company's ecosystem, and the company controls encryption keys (unless you use client-side encryption add-ons like Cryptomator).

- Dropbox
- Google drive storage
- Google drive
- iCloud
- Mega
- Microsoft Azure Blob
- Microsoft Onedrive
- Pcloud

These are convenient, polished, user-friendly for everyday use, especially if you're already in their ecosystem (Gmail, Office, etc.).






