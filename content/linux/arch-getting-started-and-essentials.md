---
title: "arch-getting-started-and-essentials"
date: 2026-08-09T22:47:36Z
lastmod: 2026-08-09T22:47:36Z
draft: false
tags: []
categories: []
series: []
summary: ""
ShowToc: true
TocOpen: true
weight: 10
---

## Essentials

### Messaging
#### Signal
Encrypted messages, one of the best as of **2025**
```bash
sudo pacman -S signal-desktop
```

#### Telegram
Unencrypted message app, use for public stuff only
```bash
sudo pacman -S telegram-desktop
```

### System Utils
#### Ark
Unzipping utility, used across file browsers such as, thunar
```bash
sudo pacman -S ark
```

### Remote & Gaming Clients

#### Moonlight

### Good To Have Or Change
#### Setting Default Browser
1. Install `xdg-utils` 
2. Run the following to get the current default browser `xdg-settings get default-browser`
**TLDR Commands**
```bash
    #Print the default web browser:
    xdg-settings get default-web-browser

    #Set the default web browser to Firefox:
    xdg-settings set default-web-browser firefox.desktop

    #Set the default mail URL scheme handler to Evolution:
    xdg-settings set default-url-scheme-handler mailto evolution.desktop

    #Set the default PDF document viewer:
    xdg-settings set pdf-viewer.desktop

    #Display help:
    xdg-settings --help
```


### Encryption
#### Cryptomator
is a simple tool for digital self-defense. It allows you to protect your cloud data by yourself and independently
```bash
yay cryptomator 
# Pick the non `bin` version
```
#### Veracrypt
VeraCrypt is a free open source disk encryption software for Windows, Mac OSX and Linux. Brought to you by AM Crypto (https://amcrypto.jp) and based on TrueCrypt 7.1a.
```bash
sudo pacman -S veracrypt
```

### Remote Tools
-  [Remmina]() - VNC remote connection utility
	- `sudo pacman -S remmina freerdp` freerdp is needed to be able to connect to windows server
-  [Moonlight](https://github.com/moonlight-stream/moonlight-qt/releases) - Open source game/desktop streaming client
	- Install its **appimage** using **gear-lever**
- 

## Drive Encryption (Adding Extra Drive)
If an extra drive needs to be added to your machine **post installation** follow the following steps

### Partition Creation
1. Run `lsblk` to get the drive
2. Create a new partition using `fdisk`, if the drive is higher than **2TB** change the **GUID** to **GPT**
	1. `sudo fdisk /dev/<drive>`
	2. press `o`
	3. press `w` and hit enter
3. Create a new partition using `fdisk`
	1. `sudo fdisk /dev/<drive>`
	2. press `n` 3 times
### Drive Encryption and Formatting
1. Encrypt the new partition you just created, the partition will look something like this `sda1` if you using a **SSD** `nvme01np1` if you are using a **NVME/M.2 SSD**
2. `sudo cryptsetup luksFormat --use-random -S 1 -s 512 -h sha512 -i 5000 /dev/<drive>`
	1. Enter a strong password `123456789strong`
3. Open the encrypted drive `sudo crypsetup open /dev/<drive> luks`
	1. `luks` is just the label, this can be whatever you want
	2. Enter the previously used password
	3. A drive should be under `/dev/<drive>/luks`
4. Format drive `sudo mkfs.ext4 /dev/mapper/luks`

### Fstab Entries
1. `sudo nvim /etc/fstab`
2. add the following entry at the bottom of the `fstab`
	1. `/dev/mapper/extra /mnt/extra ext4 defaults 0 0`
	2. *Note: make sure to change all values to match your drive, "extra" mount point and "partition type" needs to be change*
![/images/Second-Drive-Fstab-Entry.png]
3. You can now, reboot and if the drive is detected, you should be asked to enter the **drive encryption password**

### Encryption Key and crypttab
1. Navigate to `sudo nvim /etc/crypttab`
2. There will be 2 entries that will need to be added to at the bottom of this file
	1. First, `extra /dev/<drive> /root/luks.key`
		1. **extra** = the name of the drive mount point folder
		2. **/dev/drive** = drive label location
		3. **/root/luks.key** = encryption key location
	2. Second, `extra /dev/<drive> /none`
		1.  **extra** = the name of the drive mount point folder
		2. **/dev/drive** = drive label location
		3. **none** = tell linux to ask for the drive encryption password on boot
3. After both options have been added, see *image below* proceed to creating a **encryption key**
![/images/crypttab-example-2nd-drive-encypt.png]
4. Generate LUKS key using **OpenSSL**
	1. `openssl rand -out /path/to/your/keyfile 4096`
5. Change permission to `read` only by `root`
	1. `sudo chmod 0400 /path/to/your/keyfile`
	2. `sudo chown root:root /path/to/your/keyfile`
6. Add the created key to your LUKS drive
	1. `cryptsetup luksAddKey /dev/DEVICE /path/to/your/keyfile`
	2. You will be prompted to enter the encrypted drive passphrase
7. Reboot, if all went well. Your drive should be open at boot
8. Lastly, make sure that your `user` is able to `rw` to the drive
	1. `sudo chown -R user: location_of_drive_mount_point`
	2. **NOTE: make sure you run the command on step 8 after rebooting your machine!!!**



