# Proxmox VE (optional)

## VMs
- Create NMS VM and Log VM (or one lite VM) from an Oracle/Rocky 9 or Debian cloud image; VirtIO disk + net,
  QEMU guest agent on, "Start at boot" on. Log VM: second disk for `DATA_ROOT` (XFS/ext4, `noatime`).
- Bridge the VMs on the management LAN bridge (e.g. `vmbr0`). Static IPs.

## Backups (Datacenter → Backup, or CLI)
```bash
pvesh create /cluster/backup --id weekly-nas --schedule 'sun 01:00' --storage <nas-storage> \
  --vmid <nms-vmid>,<log-vmid> --mode snapshot --compress zstd --prune-backups keep-last=1
```
Add the NAS as storage first (Datacenter → Storage → NFS/SMB).

## Graylog incident archive (optional, from the LRES netmon repo)
`deploy/obsv01/graylog-archive.py` (weekly export of warning+ events) and
`deploy/pve/graylog-archive-pull.sh` (PVE pulls the archive to NAS, verifies sha256, keeps 53 weeks).
Copy and adapt host names/paths if you want long-term incident history beyond Graylog retention.
