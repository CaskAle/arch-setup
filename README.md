# Troy's Opinionated Arch Linux Install Guide

This guide will provide a minimal install of Archlinux.  It provides relevant links to the appropriate official installation and wiki information.  The official install guide can be found at <https://wiki.archlinux.org/title/Installation_guide>.

## Initial Setup

### Prepare and boot the install media

If needed, create an EFI USB install device. The official images can be downloaded from <https://archlinux.org/download>.  Once downloaded, there are many tools to create a bootable USB disk from the downloaded image.  This guide prefers the **dd** utility.  The following example will demonstrate:

```zsh
# Download the image
wget https://dfw.mirror.rackspace.com/archlinux/iso/YYYY.MM.DD/archlinux-YYYY.MM.DD-x86_64.iso

# List devices for image copy
lsblk -fp

#Create the install media
sudo dd bs=16M if=archlinux-YYYY.MM.DD-x86_64.iso of=/dev/sdX status=progress && sync
```

- Replace the 'YYYY.MM.DD' with the appropriate date for the image you download.
- Replace 'of=/dev/sdX' with the appropriate device name determined from the execution of the "lsblk" command.
- The **dd** command is very powerful and will overwrite whatever destination (of) that is given.  Be very careful and double check your typing.
- For VM install, skip the creation of USB disk and install direct from ISO.

Now that you have an installation media, simply boot your computer from the this media.  Pressing the **F12** key during the initial boot splash screen typically brings up the system boot menu and you can select the installation media from there.

### Make the terminal usable

```zsh
# If you need a larger font due to High DPI, 
fbcon=font:TER132b
```

### Make sure that the system is in UEFI mode  

```Zsh
# If this command returns 64 or 32 then you are in UEFI
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

- Ensure that the partition table uses GPT format
- Ensure that there is an **efi** partition formatted as FAT32 and flagged as type **efi**. Allocate the remaining disk space as a partition of type **Linux Filesystem**

| Number | Type | Size |
| --- | --- | --- |
| 1 | EFI | 1 Gb |
| 2 | Linux Filesystem | max (all of the remaining space) |  

```zsh
# Determine appropriate device to work with
lsblk -fp

#Replace XXX with device you wish to partition
fdisk /dev/XXX

# Set partition table to GPT
g

# Create new efi partition
n
default
default
+1G
t
1

# Create new Linux Filesystem partition
n
default
default
default


# Verify your work
p

# If all is good, write the changes
w

# If not you can quit without saving and redo from the beginning
q
```

### Encryption

If full disk encryption will be used:

```zsh
# Initialize the dm-crypt module
modprobe dm-crypt

# If encryption is already set up on the partition and you wish to preserve the existing file systems, skip the following command. 

# Setup the crypt.  The device should be your root filesystem created above.
cryptsetup -v luksFormat --type luks2 /dev/XXX

# To open the crypt.  The word 'crypt' represents the name of the crypt. Adjust if desired.
cryptsetup open /dev/XXX crypt --allow-discards --persistent
```

### Mount the volumes

If btrfs is being used, compression and nodatacow options need to be specified on the mount command for the virt storage disk.

- mount -o compress=zstd **nodatacow** /dev/vg/virt

### Format the volumes

Examples given below assume btrfs file system. Adjust as required. **Use extreme caution formatting the EFI partition when in a dual boot scenario.**

```zsh
mkfs.fat -n boot -F32 /dev/XXX
mkfs.btrfs -L root /dev/XXX
```

## Install the Minimal System

Enable the **testing** and **community-testing** repositories by
un-commenting them from **/etc/pacman/conf**

```zsh
pacstrap /mnt base base-devel git intel-ucode iw iwd linux linux-firmware linux-headers man-db man-pages micro nano networkmanager openssh plocate python reflector zsh
```

### Create an **/etc/fstab** file

```zsh
genfstab -U /mnt > /mnt/etc/fstab
```

### Change to the newly installed root environment

```zsh
arch-chroot /mnt
```

### Adjust vconsole (if needed)

In order to ensure that the terminal font is a readable size, execute the following:

```zsh
echo FONT=TER16x32 > /etc/vconsole.conf
```

### Edit **/etc/mkinitcpio.conf**

Modules:

- Add **intel_agp** and **i915**

Hooks:

- Replace **base** and **udev** with **systemd**
- Add **sd-vconsole** after **systemd**
- Insert **sd-lvm2** between **block** and **filesystems**

If using encryption:

- Insert **sd-encrypt** before **sd-lvm2**

If using plymouth:

- Insert **plymouth** between **systemd** and **sd-vconsole**

### Re-build initial RAM filesystem

```zsh
mkinitcpio -P
```

### Install systemd bootloader

```zsh
bootctl install
```

### Create the file: **/boot/loader/entries/arch.conf**

```zsh
#/boot/loader/entries/arch.conf

title Arch Linux
linux /vmlinuz-linux
initrd /intel-ucode.img
initrd /initramfs-linux.img
options root=/dev/vg/root rw quiet
```

If using encryption, add the following to the options line:

```zsh
rd.luks.name=<UUID>=crypt rd.luks.options=timeout=0 rootflags=x-systemd.device-timeout=0
```

>Note: Use **lsblk -up** to determine the appropriate UUID for the encrypted volume, **NOT** the root volume.

### Edit the file: **/boot/loader/loader.conf**

```zsh
#/boot/loader/loader.conf

#timeout 0
#console-mode keep
default arch
```

### Set root password and shell

```zsh
passwd
chsh -s /bin/zsh
```

### Create user - troy

```zsh
groupadd -f -g 1000 troy
useradd -m -s /bin/zsh -u 1000 -g troy -G wheel troy
passwd troy
chown -R troy:troy /home/troy
```

### Create user - ansible ans set initial password to 'ansible'

```zsh
groupadd -f -g 999 ansible
useradd -m -s /bin/zsh -u 1001 -g ansible -G wheel ansible
passwd ansible
chown -R ansible:ansible /home/ansible
```

### Enable sudo for wheel group

```zsh
echo '%wheel ALL=(ALL) ALL' > /etc/sudoers.d/00_wheel
echo 'troy ALL=(ALL) ALL' > /etc/sudoers.d/00_troy
echo 'ansible ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/00_ansible
```

### Finish up

Exit the chroot environment

```zsh
exit
```

Unmount filesystems

```zsh
umount /mnt/boot
umount /mnt/home/troy/data
umount /mnt/virt
umount /mnt
```

Reboot into the new system

```zsh
reboot
```

## Customise the new system

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

### Set the locale to British English

- Edit the **/etc/locale.gen** file
- Un-comment **en_GB.UTF-8** and **en_US.UTF-8**
- Then run:

   ```zsh
   sudo locale-gen
   sudo localectl set-locale en_GB.UTF-8
   ```

### Enable fstrim

If using encryption, add the following to **kernel** parameters in boot loader to allow discards in the luks crypt:  
`rd.luks.options=discard`

Enable the fstrim systemd service to periodically trim the SSD:  
`sudo systemctl --now enable fstrim.timer`

### Customise pacman

#### Edit /etc/pacman.conf

- Enable **color** by un-commenting the appropriate line (#Color)
- Enable the **testing** and **community-testing** repositories by un-commenting them.
- Add the kde-unstable repository just above testing.

   ```zsh
   [kde-unstable]
   Include = /etc/pacman.d/mirrorlist
   ```

#### Automate periodic mirrorlist updates

```zsh
sudo systemctl --now enable reflector.timer
```

### Customise makepkg

Edit /etc/makepkg.conf

- Un-comment **BUILDDIR=/tmp/makepkg**

### Install yay from AUR

```zsh
mkdir ~/aur
cd ~/aur
git clone https://aur.archlinux.org/yay.git
cd yay
mkpkg -si
```

### Do a full system update

```zsh
yay -Syyu
```

### Configure networking

#### Enable the iwd backend for NetworkManager  (Note: wpa 3 not working under iwd)

Create the **/etc/NetworkManager/conf.d/iwd_backend.conf** file.

```zsh
#/etc/NetworkManager/conf.d/iwd_backend.conf

[device]
wifi.backend=iwd
```

#### Enable systemd-resolvd for dns

Create **/etc/systemd/resolved.conf.d/resolved.conf**

```zsh
#/etc/systemd/resolved.conf.d/resolved.conf

[Resolve]
LLMNR=no
DNSSEC=no
```

#### Start network services

```zsh
sudo systemctl --now enable systemd-resolved.service
sudo systemctl --now enable NetworkManager.service
```

#### Avahi and mdns (MOVING AWAY FROM THIS)

- Edit the file **/etc/nsswitch.conf**

- Add **mdns_minimal [NOTFOUND=return]** before **resolve** on hosts line

- Enable Avahi daemon

   ```zsh
   sudo systemctl --now enable avahi-daemon
   ```

#### Connect using terminal based network config tool

```zsh
sudo nmtui
```

### Bluetooth

In order to activate mouse on boot, edit **/etc/bluetooth/main.conf**

```zsh
#/etc/bluetooth/main.conf

[Policy]
AutoEnable=true
```

Enable the bluetooth service

```zsh
sudo systemctl --now enable bluetooth
```

### VPN support

### SSH

For kde wallet storing of key passwords:

yay -S \--needed ksshaskpass (plasma)

Edit \~/.zshrc & \~/.bashrc:

export SSH_ASKPASS=\"/usr/bin/ksshaskpass\"

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

### Audio/Video (maybe only install pipewire pipewire-jack and wireplumber???)

yay -S \--needed pipewire wireplumber

For vlc:
yay vlc phonon-qt6-vlc

Intel Video

yay -S --needed mesa vulkan-intel
yay -S \--needed libva-intel-driver (Hardware Video Acceleration)

Edit /etc/mkinitcpio.conf

Modules: Add intel_agp and i915

Create or copy /etc/modprobe.d/intel.conf

### KDE/Plasma

Install plasma

yay -S \--needed plasma plasma-wayland-session

Install kde apps

yay -S dolphin kate kdialog kfind khelpcenter konsole kdegraphics-thumbnailers
kwalletmanager kwallet kaccounts-integration kaccounts-providers
kio-extras signon-kwallet-extension ksystemlog ffmpegthumbs phonon-qt6-vlc

For the kde discover app, the backends are:

packagekit-qt6 (for arch packages)

Enable sddm service

sudo systemctl \--now enable sddm

KDE System Settings / Display and Monitor / Compositor

Rendering backend = OpenGL 3.1

Scale Method = Accurate

### Plymouth

Install:  
`yay -S --needed plymouth plymouth-kcm breeze-plymouth`

Add kernel options:  
`quiet splash`

Update the HOOKS in: **/etc/mkinitcpio.conf**:  
`HOOKS=(base systemd plymouth ...)`

Rebuild initram:  
`sudo mkinitcpio -P`

Set/query the default theme:  
`plymouth-set-default-theme -R \<theme\>`  
or use kde settings app.

Rebuild initial RAM disk after any changes to the theme:  
`mkinitcpio -P <https://wiki.archlinux.org/index.php/Plymouth>`

### Fonts

Install terminess font for larger console font

yay -S \--needed terminess-powerline-font-git

Install Microsoft Windows 10 ttf Fonts (if desired)

yay -U arch/builds/ttf-ms-win10/ttf-ms-win10-10.0.10586-1-any.pkg.tar.xz

Enable RGB sub-pixel rendering

ln -s /etc/fonts/conf.avail/10-sub-pixel-rgb.conf /etc/fonts/conf.d/

Enable default LCD filter

ln -s /etc/fonts/conf.avail/11-lcdfilter-default.conf /etc/fonts/conf.d/

Disable bitmap fonts

ln -s /etc/fonts/conf.avail/70-no-bitmaps.conf /etc/fonts/conf.d/

Disable the use of embedded bitmap fonts

cp \~/data/arch-setup/font/custom/99-no-embedded.conf /etc/fonts/conf.d

### Firmware updates

Install:  
`yay -S fwupd`

Get Updates:  
`fwupdmgr get-updates`

## Java JDK

yay -S \--needed jdk13-openjdk openjdk13-doc

### Synology Drive

yay -U arch/builds/synology-cloud-station-drive/synology\*.xz

### Firefox

yay -S \--needed firefox

### Chrome/Chromium

### ZSH

### Nano

- Customise **/etc/nanorc**
  - set autoindent
  - set mouse
  - set linenumbers
  - include \"/usr/share/nano/\*.nanorc\"
  - extendsyntax python tabgives \" \"

- Set nano as default editor over vi
  - export VISUAL=nano
  - export EDITOR=nano

### Samba

yay -S \--needed samba

edit /etc/samba/smb.conf

Under \[global\]

usershare path = /var/lib/samba/usershare

usershare max shares = 100

usershare allow guests = no

usershare owner only = no

workgroup = BEER

server string = Troy\'s Arch Linux

For shared folders:

mkdir -p /var/lib/samba/usershare

groupadd sambashare

chown root:sambashare /var/lib/samba/usershare

chmod 1770 /var/lib/samba/usershare

usermod -a -G sambashare troy

pdbedit -a -u troy

sudo systemctl --now enable nmb

sudo systemctl --now enable smb

Still need to look into proper password synchronisation between linux
and samba

### Yubikey

yay -S \--needed libu2f-host to enable reading the device

yay -S \--needed yubico-pam to enable sign on with device

Add this as the top line to /etc/pam.d/system-auth:

auth sufficient pam_yubico.so id=1 authfile=/etc/yubikeys

Create /etc/yubikeys

troy:cccccckbdftk:ccccccjekvfu\
root:cccccckbdftk:ccccccjekvfu

<https://fedoraproject.org/wiki/Using_Yubikeys_with_Fedora>

### Printing and Scanning

yay -S \--needed cups hplip python-pyqt5 python-reportlab python-pillow
rpcbind sane

sudo systemctl \--now enable org.cups.cupsd

sudo hp-setup

Uncomment hpaio from the bottom of /etc/sane.d/dll.conf for scanner
support

### Power and CPU Management

yay -S --needed tlp smartmontools thermald powertop cpupower

sudo systemctl --now enable tlp

sudo systemctl --now enable tlp-sleep \*\*\*

sudo systemctl --now enable thermald \*\*\*

Sudo systemctl --now enable cpupower

### LibreOffice

yay -S --needed libreoffice-fresh libreoffice-fresh-en-gb

yay -S --needed libmythes mythes-en for thesarus

yay -S --needed hunspell hunspell-en_GB hunspell-en_US for spell check

yay -S \--needed hyphen hyphen-en for hyphenation

Enable Writing Aids under Language Settings/Writing Aids

Enable Java under LibreOffice/Advanced

Edit /etc/profile.d/libreoffice-fresh.sh to enable QT look and feel

### KVM/Qemu/Libvirt

yay -S --needed libvirt qemu virt-manager

yay -S --needed ovmf to enable EFI in guests

yay -S --needed ebtables dnsmasq for the default NAT/DHCP networking.

yay -S --needed bridge-utils for bridged networking.

**Enable iommu passthrough** **in **kernel options**:**

**iommu_intel*=1*

Enable nested virtualisation via /etc/modprobe.d/kvm.conf.  Create or copy.

`options kvm_intel nested=1*`

Video card needs extra ram configured in guest to get full resolution.
Under Video QXL ensure xml looks like:

ram=\"65536\" vram=\"65536\" vgamem=\"65536\"

<https://wiki.archlinux.org/index.php/Libvirt>
<https://wiki.archlinux.org/index.php/Libvirt#UEFI_Support>

For file sharing with virtio-fs:
<https://libvirt.org/kbase/virtiofs.html>

### BeerSmith

yay -U \~/vmdata/aur/beersmith/BeerSmith\*.xz

### DVD Ripping

yay -S handbrake libdvdcss dvd+rw-tools libx264

### Flatpak Installs

yay -S flatpak

- discord
- telegram
- slack
- mumble

### Other Interesting Packages

smplayer, k3b, cdrdao, audex, docker, podman, reflector

### Things to look up

- Java fonts look funny.
- Password not working with yubikey enabled on kde lock screen.
- Bridging with libvirt.
- Intel GPU on libvirt
- Password synchronisation between linux and samba
- Do I need to include fsck and fstab parms for xsf & vfat filesystems???
