# Troy's Arch Linux Install Guide

The official install guige can be found at <https://wiki.archlinux.org/title/Installation_guide>

## Prepare and boot the install media

If needed, create an EFI USB install device. Download an install image from <https://archlinux.org/download>

```sh
dd bs=16M if=archlinux-YYYY.MM.DD-x86_64.iso of=/dev/sdX status=progress && sync
```

Boot from the newly created USB device. **F12** typically brings up the system boot menu.
If a larger console font is needed, edit (e) the boot option and append the following:

```sh
fbcon=font:TER16x32
```

If using WiFi, connect to an access point. Ethernet should connect automatically

```sh
iwctl device list
iwctl station <device> scan
iwctl station <device> get-networks
iwctl station <device> connect <SSID>
```

## Disk Setup

### Partition disks

Ensure that there is an **efi** boot partition formatted as FAT32 and flagged as type **ef00**. Allocate the remaining disk space as a partition of type **8e00 Linux LVM**

- /dev/nvme0n1p2 256M
- /dev/nvme0n1p2 max

### Disk Encryption

If full disk encryption will be used, first:

```sh
modprobe dm-crypt
```

If encryption is already set up on the partition and you wish to
preserve the existing file systems, skip the following command. **Be sure to remember the password.**

```sh
cryptsetup -v luksFormat --type luks2 /dev/nvme0n1p2
```

To open the crypt, issue the following command. The word 'crypt' on the
end represents the name of the crypt. Adjust if desired.

```sh
cryptsetup open /dev/nvme0n1p2 crypt --allow-discards --persistent
```

### BTRFS Setup Example

#### Mount the volumes (btrfs)

If btrfs is being used, compression and nodatacow options need to be specified on the mount command for the virt storage disk.

- mount -o compress=zstd **nodatacow** /dev/vg/virt

### LVM Setup Example

#### Create the volumes

If the LVM disks are not yet created, the following commands will
facilitate, assuming the crypt was named 'crypt'. Adjust as needed according to the name given when opening the crypt. If not using encryption, the device will be a physical device such as '/dev/nvme0n1p2'. The 'vg' is the name of the volume group. The '-n xxxx' specifies the name of the logical volume being created. The '-L xxG' specifies the size of the logical volume

```sh
pvcreate /dev/mapper/crypt
vgcreate vg /dev/mapper/crypt
lvcreate -L 32G vg -n root
lvcreate -L 64G vg -n data
lvcreate -L 128G vg -n virt
lvcreate -L 16G vg -n swap
```

#### Format the volumes

Examples given below assume xfs file system. Adjust as required. **Use extreme caution formatting the EFI partition when in a dual boot scenario.**

```sh
mkfs.fat -n boot -F32 /dev/nvme0n1p1
mkfs.xfs -L root /dev/vg/root
mkfs.xfs -L data /dev/vg/data
mkfs.xfs -L virt /dev/vg/virt
mkswap -L swap /dev/vg/swap
```

#### Mount the volumes (lvm)

```sh
mount --mkdir /dev/vg/root /mnt
mount --mkdir /dev/nvme0n1p1 /mnt/boot zsh
mount --mkdir /dev/vg/virt /mnt/virt
mount --mkdir /dev/vg/data /mnt/home/troy/data
swapon -L swap
```

## Install the basics

Enable the **testing** and **community-testing** repositories by
un-commenting them from **/etc/pacman/conf**

```sh
pacstrap /mnt base base-devel git intel-ucode linux linux-firmware linux-headers lvm2 man-db man-pages mlocate nano networkmanager openssh python reflector vim wget zsh
```

>Note: If system will use WiFi, add the following packages: `iw iwd`

### Create an **/etc/fstab** file

```sh
genfstab /mnt > /mnt/etc/fstab
```

### Change to the newly installed root environment

```sh
arch-chroot /mnt
```

### Adjust vconsole (if needed)

In order to ensure that the terminal font is a readable size, execute the following:

```sh
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

```sh
mkinitcpio -P
```

### Install a bootloader

#### BIOS

```sh
pacman -S grub
grub-install --recheck /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg
```

#### EFI

```sh
bootctl install
```

### Create the file: **/boot/loader/entries/arch.conf**

```sh
#/boot/loader/entries/arch.conf

title Arch Linux
linux /vmlinuz-linux
initrd /intel-ucode.img
initrd /initramfs-linux.img
options root=/dev/vg/root rw quiet
```

If using encryption, add the following to the options line:

```sh
rd.luks.name=<UUID>=crypt rd.luks.options=timeout=0 rootflags=x-systemd.device-timeout=0
```

>Note: Use **lsblk -up** to determine the appropriate UUID for the encrypted volume, **NOT** the root volume.

### Edit the file: **/boot/loader/loader.conf**

```sh
#/boot/loader/loader.conf

#timeout 0
#console-mode keep
default arch
```

### Set root password and shell

```sh
passwd
chsh -s /bin/zsh
```

### Create user - troy

```sh
groupadd -f -g 1000 troy
useradd -m -s /bin/zsh -u 1000 -g troy -G wheel troy
passwd troy
chown -R troy:troy /home/troy
```

### Create user - ansible

```sh
groupadd -f -g 1001 ansible
useradd -m -s /bin/zsh -u 1001 -g ansible -G wheel ansible
passwd ansible
chown -R ansible:ansible /home/ansible
```

### Enable sudo for wheel group

```sh
echo '%wheel ALL=(ALL) ALL' > /etc/sudoers.d/00_wheel
echo 'troy ALL=(ALL) ALL' > /etc/sudoers.d/00_troy
echo 'ansible ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/00_ansible
```

### Finish up

Exit the chroot environment

```sh
exit
```

Unmount filesystems

```sh
umount /mnt/boot
umount /mnt/home/troy/data
umount /mnt/virt
umount /mnt
```

Reboot into the new system

```sh
reboot
```

## Customise the new system

### Set the clock

```sh
sudo hwclock --systohc --utc
sudo timedatectl set-timezone America/Chicago
sudo timedatectl set-ntp true
```

### Set the hostname

```sh
sudo hostnamectl hostname <hostname>
```

### Set the locale to British English

- Edit the **/etc/locale.gen** file
- Un-comment **en_GB.UTF-8** and **en_US.UTF-8**
- Then run:

   ```sh
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

   ```sh
   [kde-unstable]
   Include = /etc/pacman.d/mirrorlist
   ```

#### Automate periodic mirrorlist updates

```sh
sudo systemctl --now enable reflector.timer
```

### Customise makepkg

Edit /etc/makepkg.conf

- Un-comment **BUILDDIR=/tmp/makepkg**
- att **--threads=0** to **COMPRESSZST=(zstd -c -z -q -)**

### Install yay from AUR

```sh
mkdir ~/aur
cd ~/aur
git clone https://aur.archlinux.org/yay.git
cd ~/aur/yay
mkpkg -si
```

### Do a full system update

```sh
yay -Syyu
```

### Configure networking

#### Enable the iwd backend for NetworkManager

Create the **/etc/NetworkManager/conf.d/iwd_backend.conf** file.

```sh
#/etc/NetworkManager/conf.d/iwd_backend.conf

[device]
wifi.backend=iwd
```

#### Enable systemd-resolvd for dns

Create **/etc/systemd/resolved.conf.d/resolved.conf**

```sh
#/etc/systemd/resolved.conf.d/resolved.conf

[Resolve]
LLMNR=no
DNSSEC=no
```

#### Start network services

```sh
sudo systemctl --now enable systemd-resolved.service
sudo systemctl --now enable NetworkManager.service
```

#### Avahi and mdns (MOVING AWAY FROM THIS)

- Edit the file **/etc/nsswitch.conf**

- Add **mdns_minimal [NOTFOUND=return]** before **resolve** on hosts line

- Enable Avahi daemon

   ```sh
   sudo systemctl --now enable avahi-daemon
   ```

#### Connect using terminal based network config tool

```sh
sudo nmtui
```

### Bluetooth

In order to activate mouse on boot, edit **/etc/bluetooth/main.conf**

```sh
#/etc/bluetooth/main.conf

[Policy]
AutoEnable=true
```

Enable the bluetooth service

```sh
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

### Audio/Video

yay -S \--needed alsa-utils alsa-plugins pulseaudio pulseaudio-alsa
pulseaudio-bluetooth

Set audio levels (pressing "m" toggles mute on a channel):

sudo alsamixer

For gstreamer:

yay gstreamer-vaapi gst-libav phonon-qt5-gstreamer

For vlc:

yay vlc phono-qt5-vlc

Intel Video

yay -S \--needed libva-intel-driver (Hardware Video Accelleration)

yay -S \--needed xf86-video-intel (Video Driver)

Edit /etc/mkinitcpio.conf

Modules: Add intel_agp and i915

Create or copy /etc/modprobe.d/intel.conf

### KDE/Plasma

Install plasma

yay -S \--needed plasma plasma-wayland-session

Install kde apps

yay -S dolphin kate kdialog kfind khelpcenter konsole kdegraphics ark
kwalletmanager kcalc yakuake kaccounts-integration kaccounts-providers
kio-extras signon-kwallet-extension ksystemlog ffmpegthumbs ktorrent
phonon-qt5-gstreamer phonon-qt5-vlc

For the kde discover app, the backends are:

packagekit-qt5 (for arch packages)

Enable sddm service

sudo systemctl \--now enable sddm

KDE System Settings / Display and Monitor / Compositor

Rendering backend = OpenGL 3.1

Scale Method = Accurate

Setting volumes with kmix one time will fix the audio issues around
notification sounds. Not sure,but I think it fixes microphone as well.

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
