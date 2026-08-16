---
title: "proxmox-usb-pass-guide"
date: 2026-08-16T22:49:27Z
lastmod: 2026-08-16T22:49:27Z
draft: false
tags: []
categories: []
series: []
summary: ""
ShowToc: true
TocOpen: true
weight: 10
---

# Proxmox: Pass a USB SSD Through to a Debian 13 VM

A complete guide covering: checking the port, confirming power, passing the drive through by device ID, then formatting and persistently mounting it inside a Debian 13 guest (with SSD TRIM).

## 0. Background: USB Port Speeds and Power

Check the USB tree and negotiated speeds on the Proxmox host:

```bash
lsusb -t
```

| Shown | USB standard | Speed | Power budget |
| --- | --- | --- | --- |
| `480M` | USB 2.0 high | 480 Mbps | 2.5 W (500 mA) |
| `5000M` | USB 3.0 / 3.1 Gen1 | 5 Gbps | 4.5 W (900 mA) |
| `10000M` | USB 3.1 Gen2 | 10 Gbps | 4.5 W+ |

**Power check for a 2.5" SSD enclosure:** an SSD draws about 1-2 W, well under the 2.5 W a USB 2.0 (`480M`) port supplies. It runs reliably even on a 480M port, with no spin-up surge like a spinning HDD.

**Throughput note:** on a `480M` port you are capped at about 30-40 MB/s real-world. Move to a `5000M` port for full SSD speed. The config below does not change.

## 1. Identify the Device on the Proxmox Host

```bash
lsusb          # note the ID as vendor:product, e.g. 152d:0578
lsusb -t       # confirm bus/port and negotiated speed
```

## 2. Pass the Drive Through to the VM (by Vendor/Device ID)

Using the Vendor/Device ID binds the drive to the VM regardless of which port it is plugged into. This is best for a single unique device.

```bash
qm set <VMID> -usb0 host=152d:0578
```

Or via the web UI: **VM > Hardware > Add > USB Device > Use USB Vendor/Device ID**.

| Method | Binds to | Use when |
| --- | --- | --- |
| Vendor/Device ID (recommended) | the specific device, any port | single unique drive |
| USB Port | whatever is in that physical port | multiple identical devices / dock |

## 3. Restart the VM and Locate the Disk (inside Debian 13)

Passthrough attaches at VM start, so reboot the VM, then run in the guest:

```bash
lsblk              # find the new disk, e.g. /dev/sdb
sudo dmesg | tail  # confirm it enumerated
```

## 4. Partition and Format (inside the VM)

**Warning:** this erases the drive. Double-check the device name with `lsblk` first. The steps below assume the drive is `/dev/sdb`.

```bash
# Fresh GPT table + one full-size partition
sudo parted /dev/sdb --script mklabel gpt
sudo parted /dev/sdb --script mkpart primary ext4 0% 100%

# Format ext4 with a label
sudo mkfs.ext4 -L mydata /dev/sdb1
```

Filesystem choice: use **ext4** for Linux-only; use **exfat** (`sudo mkfs.exfat`) if you need to share the drive with Windows or macOS.

## 5. Mount Persistently via /etc/fstab (inside the VM)

### 5a. Get the UUID

```bash
sudo blkid
# /dev/sdb1: LABEL="mydata" UUID="a1b2c3d4-...-1234567890ab" TYPE="ext4"
```

### 5b. Create the mount point

```bash
sudo mkdir -p /mnt/mydata
```

### 5c. Add the fstab entry

```bash
sudo nano /etc/fstab
```

Append the following line, replacing the UUID with your own:

```
UUID=a1b2c3d4-5678-90ab-cdef-1234567890ab  /mnt/mydata  ext4  defaults,nofail,x-systemd.device-timeout=10  0  2
```

Key options for a removable USB drive:

- `nofail` - the VM boots normally even if the drive is unplugged (essential).
- `x-systemd.device-timeout=10` - do not wait 90s for a missing device.
- `defaults` - standard read-write mount options.

Save and exit nano with **Ctrl+O**, **Enter**, **Ctrl+X**.

### 5d. Test BEFORE rebooting

```bash
sudo systemctl daemon-reload
sudo mount -a          # no output = success
df -h /mnt/mydata      # verify it mounted
```

Fix any fstab error now. A bad line can block boot.

### 5e. (Optional) Grant write access to your user

```bash
sudo chown $USER:$USER /mnt/mydata
```

## 6. Enable SSD TRIM (inside the VM)

`fstrim` and its timer ship with `util-linux`, a core Debian package that is already installed. There is nothing to `apt install`.

```bash
sudo systemctl enable --now fstrim.timer      # weekly automatic TRIM
systemctl list-timers fstrim.timer            # confirm next run
sudo fstrim -v /mnt/mydata                    # test a manual trim
```

Check whether your enclosure supports TRIM passthrough:

```bash
lsblk -D
```

Look at the `DISC-GRAN` and `DISC-MAX` columns for the drive:

- Non-zero values mean TRIM works through the enclosure.
- Both `0` means the bridge does not pass TRIM. This is harmless; the SSD's own garbage collection still runs.

## Caveats

- **Live migration:** a VM with a passed-through USB device cannot be live-migrated while the device is attached.
- **Backups:** Proxmox VM backups cover virtual disks, not the passed-through USB drive. Back it up separately.
- **Don't double-mount:** never mount the drive on the host and guest at the same time (corruption risk).
