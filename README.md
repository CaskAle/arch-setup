# Troy’s Arch Linux Install Guide

## Prepare the install media

If needed, create an EFI USB install device.  
`dd bs=16M if=archlinux-YYYY.MM.DD-x86_64.iso of=/dev/sdX && sync`

## Boot the Arch Linux install media.

- If a larger console font is needed, issue the following command:  
`setfont latarcyrheb-sun32`

- If using WiFi, connect to an access point.  Ethernet should connect automatically.
`wifi-menu`

## Partition disk for EFI and LVM

Ensure that there is an efi boot partition formatted as FAT32 and flagged as type 'ef00'
`/dev/nvme0n1p2  256M`

Allocate the remaining disk space as a partition of '8e00 Linux LVM'
`/dev/nvme0n1p2	max`
