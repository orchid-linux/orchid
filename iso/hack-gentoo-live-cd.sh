#!/usr/bin/env bash
#===================================================================================
#
# FILE : hack-gentoo-live-cd.sh
#
# USAGE : Automatique
#
# DESCRIPTION : Script de modification du live CD gentoo pour accueillir Orchid Linux.
#
# BUGS : ---
# NOTES : Ce script édite un live CD, tel que produit par Gentoo.
# CONTRUBUTORS : Chevek
# CREATED : août 2022
# REVISION : 9 août 2022
#
# LICENCE :
# Copyright (C) 2022 Yannick Defais aka Chevek
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# You should have received a copy of the GNU General Public License along with
# this program. If not, see https://www.gnu.org/licenses/.
#===================================================================================

##== DEPENDENCIES ==================================================================

# wget, unsquashfs, mksquashfs, xorriso

#=== PRECONFIGURATION ==============================================================

# Initialisation des couleurs
#-----------------------------------------------------------------------------------
COLOR_YELLOW=$'\033[0;33m'
COLOR_GREEN=$'\033[0;32m'
COLOR_RED=$'\033[0;31m'
COLOR_LIGHTBLUE=$'\033[1;34m'
COLOR_WHITE=$'\033[1;37m'
COLOR_RESET=$'\033[0m'

if [ "$EUID" -ne 0 ]
  then echo "${COLOR_RED}* You need to be root to use this script!${COLOR_RESET}"
  exit
fi

#cd "/tmp"
#cd "/mnt/660b4c9c-926c-48f6-ac23-16ddd8d31ca5/Orchid/tmp"
echo "${COLOR_GREEN}* Fetching datas about the latest live CD release.${COLOR_RESET}"
wget "https://bouncer.gentoo.org/fetch/root/all/releases/amd64/autobuilds/latest-install-amd64-minimal.txt"
LAST_MINIMAL=$(sed -n '/^[0-9]/p' "latest-install-amd64-minimal.txt")
SIZE=${LAST_MINIMAL##*' '}
SIZE=$(( (${SIZE}+1048576/2)/1048576 ))
LASTPART_URL=${LAST_MINIMAL%%' '*}
FILE_NAME=${LASTPART_URL##*/}
echo "${COLOR_GREEN}* Downloading Gentoo live CD \"$FILE_NAME\", ${SIZE} MiB.${COLOR_RESET}"
wget "https://bouncer.gentoo.org/fetch/root/all/releases/amd64/autobuilds/${LASTPART_URL}"
mkdir -p iso
mount -t iso9660 -o loop $FILE_NAME iso/
unsquashfs iso/image.squashfs

#===== Here we can edit the gentoo file system in squashfs-root/ ==========
# replace with our own root's .bashrc
echo "${COLOR_GREEN}* Editing ISO...${COLOR_RESET}"
rm -f squashfs-root/root/.bashrc
cp -f .bashrc squashfs-root/root/

#===== Now we will build the new ISO ======================================
echo "${COLOR_GREEN}* New ISO is building...${COLOR_RESET}"
mksquashfs squashfs-root image.squashfs -b 1024k -comp xz -Xbcj x86 -e boot
#xorriso -indev '/mnt/660b4c9c-926c-48f6-ac23-16ddd8d31ca5/Orchid/tmp/install-amd64-minimal-20220807T170536Z.iso' -boot_image "any" "replay" -rm_r 'image.squashfs' -- -map '/mnt/660b4c9c-926c-48f6-ac23-16ddd8d31ca5/Orchid/tmp/image.squashfs' '/image.squashfs' -outdev '/mnt/660b4c9c-926c-48f6-ac23-16ddd8d31ca5/Orchid/tmp/orchid-linux-2022-08-09.iso' -close on -write_type auto -stream_recording data -commit
CURRENT_DATE=$(date -Iseconds)
CURRENT_DATE=${CURRENT_DATE//-}
CURRENT_DATE=${CURRENT_DATE//:}
CURRENT_DATE=${CURRENT_DATE:0:${#CURRENT_DATE}-5}
xorriso -indev "${FILE_NAME}" -boot_image "any" "replay" -rm_r "image.squashfs" -- -map "image.squashfs" "/image.squashfs" -outdev "orchid-linux-${CURRENT_DATE}.iso" -close on -write_type auto -stream_recording data -commit

#===== Let's clean up =====================================================
rm -f "latest-install-amd64-minimal.txt"
rm -f "${LASTPART_URL}"
umount iso/
rm -rf iso/
rm -rf squashfs-root/
rm -f image.squashfs

# ==========================================================================
echo "${COLOR_GREEN}* New ISO released: \"orchid-linux-${CURRENT_DATE}.iso\"${COLOR_RESET}"
