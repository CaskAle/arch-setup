# Troy's Opinionated Arch Linux Install Guide

This guide will provide a minimal install of Archlinux.  It provides relevant links to the appropriate official installation and wiki information.  The official install guide can be found at <https://wiki.archlinux.org/title/Installation_guide>.

## Initial Setup

### Prepare and boot the install media

If needed, create an EFI USB install device. The official images can be downloaded from <https://archlinux.org/download>.  Once downloaded, there are many tools to create a bootable USB disk from the downloaded image.  This guide prefers the **dd** utility.  The following example will demonstrate:

```zsh
# Download the image.
wget https://dfw.mirror.rackspace.com/archlinux/iso/YYYY.MM.DD/archlinux-YYYY.MM.DD-x86_64.iso

# List devices for image copy.
lsblk -fp

#Create the install media.
sudo dd bs=16M if=archlinux-YYYY.MM.DD-x86_64.iso of=/dev/sda status=progress && sync
```

- Replace the 'YYYY.MM.DD' with the appropriate date for the image you download.
- Replace 'of=/dev/sda' with the appropriate device name determined from the execution of the "lsblk" command.
- The **dd** command is very powerful and will overwrite whatever destination (of) that is given.  Be very careful and double check your typing.
- For VM install, skip the creation of USB disk and install direct from ISO.

Now that you have an installation media, simply boot your computer from the this media.  Pressing the **F12** key during the initial boot splash screen typically brings up the system boot menu and you can select the installation media from there.

### Make the terminal usable

```zsh
# If you need a larger font due to High DPI.
fbcon=font:TER132b
```

### Make sure that the system is in UEFI mode  

```Zsh
# If this command returns 64 or 32 then you are in UEFI.
cat /sys/firmware/efi/fw_platform_size 
```

### Get a network connection

If using wired ethernet you should should connect automatically.  If you need a WiFI connection, use the following:

```zsh
# List WiFi devices
iwctl device list

# Scan for networks on the appropriate device (no output)
iwctl station <device> scan

# List the networks (SSIDs) on the device
iwctl station <device> get-networks

# Connect to a network
iwctl station <device> connect <SSID>

# Verify a connection
ping archlinux.org
```

## Prepare the Disks

### Partitioning

- Ensure that the partition table uses GPT format.
- Ensure that there is a 1Gb **efi** partition formatted as FAT32 and flagged as type **efi**.
- Allocate the remaining disk space as a partition of type **Linux Filesystem**

| Number | Type             | Size                             |
| ------ | ---------------- | -------------------------------- |
| 1      | EFI              | 1 Gb                             |
| 2      | Linux Filesystem | max (all of the remaining space) |  

```zsh
# Determine the appropriate device to work with.
lsblk -fp

# Replace xxx with the device you wish to partition.
# In my case, /dev/nvme0n1
fdisk /dev/nvme0n1

# Set the partition table to GPT.
g

# Create the new efi partition.
n
default
default
+1G
t
1

# Create the new Linux Filesystem partition.
n
default
default
default

# Verify your work.
p

# If all is good, write the changes.
w

# If not, you can quit without saving and redo from the beginning.
q
```

### Encryption

Skip this section if you are not enabling full disk encryption.

```zsh
# Initialize the dm-crypt module.
modprobe dm-crypt

# If encryption is already set up on the partition and you wish to preserve the existing file systems, skip the following command which initializes the crypt. The device should be your root filesystem created above. # In my case, /dev/nvme0n1p2

cryptsetup -v luksFormat --type luks2 /dev/nvme0n1p2

# To open the crypt.  The word 'crypt' represents the name of the encrypted vault. I use 'crypt', adjust if desired.

cryptsetup open /dev/nvme0n1p2 crypt --allow-discards --persistent
```

### Format the volumes

Examples given below assume btrfs file system. Adjust as required. Optional instructions are included for creating btrfs subvolumes.

**Use extreme caution formatting the EFI partition when in a dual boot scenario.**

```zsh
# Format the EFI partition as fat32 (label = boot).
mkfs.fat -n boot -F32 /dev/nvme0n1p1

# Format the root partition as btrfs (label = root).
mkfs.btrfs -L root /dev/nvme0n1p2

# Or, if using disk encryption
mkfs.btrfs -L root /dev/mapper/crypt

```

### Mount the volumes

```zsh
# Mount root filesystem onto /mnt
mount -o compress=zstd /dev/nvme0n1p2 /mnt

# or
mount -o compress=zstd /dev/mapper/crypt /mnt
```

#### Create btrfs subvolumes

Skip this section if you do not want to create btrfs subvolumes.

```zsh
# Create the subvolumes.
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home

# Unmount the old root filesystem.
umount /mnt

# Mount the new root subvolume.
mount -o compress=zstd,subvol=@ /dev/nvme0n1p2 /mnt

# or
mount -o compress=zstd,subvol=@ /dev/mapper/crypt /mnt

# Create the home directory.
mkdir -p /mnt/home

# Mount the home subvolume.
mount -o compress=zstd,subvol=@home /dev/nvme0n1p2 /mnt/home

# or
mount -o compress=zstd,subvol=@home /dev/mapper/crypt /mnt/home

```

#### Mount the efi filesystem onto boot

```zsh
# Create the boot directory.
mkdir -p /mnt/boot

# Mount the efi filesystem.
mount /dev/nvme0n1p1 /mnt/boot
```

## Install the Minimal System

```zsh
pacstrap -K /mnt base base-devel btrfs-progs git intel-ucode iw iwd linux linux-firmware linux-headers man-pages micro networkmanager openssh plocate python reflector
```

### Create an **/etc/fstab** file

```zsh
genfstab -U /mnt > /mnt/etc/fstab
```

### Change to the newly installed root environment

```zsh
arch-chroot /mnt
```

#### Adjust vconsole (if needed)

In order to ensure that the console font is a readable size upon booting into the new system, execute the following.  You should only need to do this if you needed to do it upon initial boot.

```zsh
# Set a console font
echo FONT=TER132B > /etc/vconsole.conf

# Otherwise, touch /etc/vconsole.conf
touch /etc/vconsole.conf
```

#### Edit **/etc/mkinitcpio.conf**

```zsh
# Modules. i915 is for intel.  AMD may use alternative.
MODULES=(i915)

#Hooks.  sd-encrypt is only needed if doing disk encryption
HOOKS=(systemd autodetect microcode modconf kms keyboard  systemd-vconsole block  sd-encrypt filesystems fsck)
```

#### Re-build initial RAM filesystem

```zsh
mkinitcpio -P
```

#### Install systemd-boot bootloader

```zsh
bootctl install
```

##### Create/Edit the file: /boot/loader/entries/arch.conf

```zsh
#/boot/loader/entries/arch.conf

title Arch Linux
linux /vmlinuz-linux
initrd /initramfs-linux.img

# no encryption.  Only use the subvol rootflag if you created btrfs subvolumes.
options root=/dev/nvme0n1p2 rootflags=subvol=@ rw quiet

# with full disk encryption.  Only use the subvol rootflag if you created btrfs subvolumes.
options rd.luks.name=<luks-UUID>=crypt root=/dev/mapper/crypt rd.luks.options=timeout=0,discard rootflags=x-systemd.device-timeout=0,subvol=@ rw quiet
```

- Use **lsblk -fp** to determine the appropriate 'luks-UUID' for the luks encrypted device, **NOT** the root volume.

##### Create/Edit the file: /boot/loader/loader.conf

```zsh
#/boot/loader/loader.conf

#timeout 0
#console-mode keep
default arch
```

#### Enable sudo for wheel group

```zsh
echo '%wheel ALL=(ALL) ALL' > /etc/sudoers.d/00_wheel
```

#### Create a user with admin rights (troy)

If you do not set a root passwd, it is imerative that a sudo enabled user be created for administrative (wheel group) access.

```zsh
groupadd -f -g 1000 troy
useradd -m -u 1000 -g troy -G wheel troy
passwd troy
```

#### Finish up the chroot configuration

```zsh
# Exit the chroot environment.
exit
```

### Reboot to the new system

```zsh
# Unmount the filesystems
umount /mnt/boot
umount /mnt/home
umount /mnt
```

## Reboot into the new system

```zsh
reboot
```

Besure to remove the install media when the shutdown process has completed.

## Customise the new system

If everything went according to plan, your new, minimal system will come up upon reboot.  As might be expected, this is where the real configuration begins.

### Set the clock

```zsh
sudo hwclock --systohc --utc
sudo timedatectl set-timezone America/Chicago
sudo timedatectl set-ntp true
```

### Set the hostname

```zsh
sudo hostnamectl hostname <hostname>
```

### Set the locale

I use British English but keep United States as well.

- Edit the /etc/locale.gen file
- Uncomment `en_GB.UTF-8`
- Uncomment `en_US.UTF-8`
- Then run:

   ```zsh
   sudo locale-gen
   sudo localectl set-locale en_GB.UTF-8
   ```

### Enable fstrim to allow periodic ssd trim

If using disk encryption, verify that the following kernel option exists in /boot/loader/entries/arch.conf to allow discards in the luks crypt:
`rd.luks.options=discard`

Enable the fstrim systemd timer to periodically trim the SSD:

```zsh
sudo systemctl --now enable fstrim.timer
```

### Configure Networking

#### Enable the iwd backend for NetworkManager  (Note: wpa 3 not working under iwd)

Create the `/etc/NetworkManager/conf.d/iwd_backend.conf` file.

```zsh
#/etc/NetworkManager/conf.d/iwd_backend.conf

[device]
wifi.backend=iwd
```

Configure the systemd-resolved DNS

```zsh
sudo systemctl stop NetworkManager
sudo rm /etc/resolv.conf
sudo ln -sf ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
```

Start the services

```zsh
sudo systemctl enable --now systemd-resolved.service
sudo systemctl enable --now NetworkManager.service
```

#### Connect to a WiFi network using terminal based network config tool

```zsh
sudo nmtui
```

### Reflector will build a customized mirrorlist

#### Edit the /etc/xdg/reflector/reflector.conf file

```zsh
--country United States
```

#### Enable the reflector.timer

```zsh
sudo systemctl enable --now reflector.timer
```

### Customize Pacman and perform system update

#### Edit the `/etc/pacman.conf` file

- Uncomment the `#Color` line.
- Uncomment the `#ParallelDownloads = 5` line.
- Uncomment the `#[core-testing]` repo section.
- Uncomment the `#[extra-testing]` repo section.
- Add a new repo for `[kde-unstable]` above the `[core-testing]` repo.

   ```zsh  
   [kde-unstable]
   Include = /etc/pacman.d/mirrorlist
   ```

#### Perform a full system update using the new settings

```zsh
sudo pacman -Syyu
```

### Customise Makepkg

Edit `/etc/makepkg.conf` file

- Uncomment `#BUILDDIR=/tmp/makepkg`

### Configure Git

Install git

```zsh
# Install git zsh completions
sudo pacman -S --needed --asdeps git-zsh-completion

# Configure user settings
git config --global user.email "you@example.com"
git config --global user.name "Your Name"
git config --global init.default.Branch main
```

### Install yay pacman helper from AUR

```zsh
mkdir ~/aur
cd ~/aur
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
```

### Configure Zsh Shell

```zsh
# Install
sudo pacman -S --needed zsh zsh-autosuggestions zsh-completions zsh-autocomplete zsh-syntax-highlighting

# Ensure that root and troy use zsh shell.
sudo chsh -s /bin/zsh
chsh -s /bis/zsh
```

#### Configure .zshrc

- Stuff needs to go here

### Enable Bluetooth

```zsh
yay -S --needed bluez
sudo systemctl --now enable bluetooth
```

### SSH

For kde wallet storing of key passwords:

yay -S --needed ksshaskpass (plasma)

Edit ~/.zshrc & ~/.bashrc:

export SSH_ASKPASS="/usr/bin/ksshaskpass\"

Edit /etc/ssh/sshd_config:

Un-comment: HostKey /etc/ssh/ssh_host_ed25519_key

Un-comment and edit: PasswordAuthentication no

Un-comment: PubkeyAuthentication yes

Ensure that the public key for id_ed25519 is in \~/.ssh/authorized_users

Enable ssh daemon

sudo systemctl \--now enable sshd

Edit "\~/.pam_environment" to include:

SSH_AUTH_SOCK DEFAULT=\"\${XDG_RUNTIME_DIR}/ssh-agent.socket\"

Enable storing of ssh key passwords:

sudo cp /data/arch-setup/ssh/ssh-agent.service /etc/systemd/user

systemctl \--user enable ssh-agent **(as a user, not root)**

Add the ssh preload script "\~/data/arch-setup/ssh/ssh-add.sh" to the
kde autostarts.

### Intel Video

yay -S --needed  vulkan-intel
yay -S --needed libva-intel-driver (Hardware Video Acceleration)
yay -S vulcan-intel intel-media-driver (Explicit)

Edit /etc/mkinitcpio.conf

Modules: Add i915 xe

Create or copy /etc/modprobe.d/intel.conf

#### This really needs consultation of the wiki, machine dependent

### KDE/Plasma

#### Install plasma group

Some issues existed around this group from kde_unstable.  Lots did not get installed

`yay -S --needed plasma`

#### Now install the kde applications

```zsh
yay -S --needed dolphin dolphin-plugins gwenview kate kdialog kfind khelpcenter konsole kwalletmanager kaccounts-providers kcolorchooser kcron kgpg kjournald kio-gdrive kompare ksystemlog kweather markdownpart okular

yay -S --needed --asdeps ffmpegthumbs kdegraphics-thumbnailers keditbookmarks kio-admin poppler-data purpose
```

Enable sddm service

`sudo systemctl --now enable sddm.service`

## Other Stuff

### Firmware updates

```zsh
yay -S fwupd
yay -S --asdeps udisks2
sudo systemctl enable --now udisks2.service

fwupdmgr get-updates
```

### Plymouth

- Install:  
`yay -S --needed plymouth`

- Add `splash` to options in `/boot/loader/entries/arch.conf`

- Update the HOOKS in: `/etc/mkinitcpio.conf`  
`HOOKS=(systemd plymouth ...)`

- Rebuild initramfs:  
`sudo mkinitcpio -P`

- Set/query the default theme:  
`plymouth-set-default-theme -R \<theme\>`  
or use the kde settings app.

- Rebuild initial RAM disk after any changes to the theme:  
`mkinitcpio -P`

### Java JDK

`yay -S --needed jdk13-openjdk openjdk13-doc`

### Synology Drive

Install from Flatpak

### Firefox

yay -S --needed firefox

### Yubikey

yay -S --needed libu2f-host to enable reading the device

yay -S --needed yubico-pam to enable sign on with device

Add this as the top line to /etc/pam.d/system-auth:

auth sufficient pam_yubico.so id=1 authfile=/etc/yubikeys

Create /etc/yubikeys

troy:cccccckbdftk:ccccccjekvfu\
root:cccccckbdftk:ccccccjekvfu

<https://fedoraproject.org/wiki/Using_Yubikeys_with_Fedora>

### Printing and Scanning

yay -S --needed cups hplip python-pyqt5 python-reportlab python-pillow
rpcbind sane

sudo systemctl --now enable org.cups.cupsd

sudo hp-setup

Uncomment hpaio from the bottom of /etc/sane.d/dll.conf for scanner
support

### Power and CPU Management

yay -S --asdeps tuned-ppd tuned
enable these
or
yay -S --asdeps power-profiles-daemon
and enable it

### LibreOffice

yay -S --needed libreoffice-fresh libreoffice-fresh-en-gb

yay -S --needed libmythes mythes-en for thesarus

yay -S --needed hunspell hunspell-en_GB hunspell-en_US for spell check

yay -S --needed hyphen hyphen-en for hyphenation

Enable Writing Aids under Language Settings/Writing Aids

Enable Java under LibreOffice/Advanced

Edit `/etc/profile.d/libreoffice-fresh.sh` to enable QT look and feel

### KVM/Qemu/Libvirt

yay -S --needed libvirt qemu virt-manager

yay -S --needed ovmf to enable EFI in guests

yay -S --needed ebtables dnsmasq for the default NAT/DHCP networking.

yay -S --needed bridge-utils for bridged networking.

Enable nested virtualisation via /etc/modprobe.d/kvm.conf.  Create or copy.

`options kvm_intel nested=1*`

Video card needs extra ram configured in guest to get full resolution.
Under Video QXL ensure xml looks like:

ram="65536" vram="65536" vgamem=\"65536\"

<https://wiki.archlinux.org/index.php/Libvirt>
<https://wiki.archlinux.org/index.php/Libvirt#UEFI_Support>

For file sharing with virtio-fs:
<https://libvirt.org/kbase/virtiofs.html>

### DVD Ripping

`yay -S handbrake libdvdcss dvd+rw-tools libx264`

### Podman

`yay -S --needed podman`

### Things to look up

- Java fonts look funny.
- Password not working with yubikey enabled on kde lock screen.
- Bridging with libvirt.
- Intel GPU on libvirt
