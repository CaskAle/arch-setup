#!/bin/sh

#country='country=CA&country=FR&country=DE&country=GB&country=US'
country='country=US'
url="http://www.archlinux.org/mirrorlist/?$country&protocol=https&ip_version=4&use_mirror_status=on"

# Get latest mirror list and save to /etc/pacman.d/mirrorlist
wget -qO- "$url" | sed 's/^#Server/Server/g' > /etc/pacman.d/mirrorlist.tta
nano /etc/pacman.d/mirrorlist.tta

# add ok to move logic
#mv /etc/pacman.d/mirrorlist.tta /etc/pacman.d/mirrorlist
echo 'If all is ok, run: sudo mv /etc/pacman.d/mirrorlist.tta /etc/pacman.d/mirrorlist'
