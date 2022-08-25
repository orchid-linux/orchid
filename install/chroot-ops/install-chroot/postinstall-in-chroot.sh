#!/usr/bin/env bash
#===================================================================================
#
# FILE : postinstall-in-chroot.sh
#
# USAGE : Automatique
#
# DESCRIPTION : Script d'installation dans le chroot pour Orchid Linux.
#
# BUGS : ---
# NOTES : Ce script n'est pas à lancer par l'utilisateur, il est lancé automatiquement
#         lors de l'exécution du script d'installation , install.sh.
# CONTRUBUTORS : Babilinx, Chevek, Crystal, Wamuu
# CREATED : mars 2022
# REVISION : 17 avril 2022
#
# LICENCE :
# Copyright (C) 2022 Babilinx, Yannick Defais aka Chevek, Wamuu-sudo, Crystal
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

#=== PRECONFIGURATION ==============================================================

# Initialisation des couleurs
#-----------------------------------------------------------------------------------
COLOR_YELLOW=$'\033[0;33m'
COLOR_GREEN=$'\033[0;32m'
COLOR_RED=$'\033[0;31m'
COLOR_LIGHTBLUE=$'\033[1;34m'
COLOR_WHITE=$'\033[1;37m'
COLOR_RESET=$'\033[0m'
#-----------------------------------------------------------------------------------

# Importation des variables du script principal
#-----------------------------------------------------------------------------------
CHOOSEN_DISK=$1
ROM=$2
ROOT_PASS=$3
USERNAME=$4
USER_PASS=$5
HOSTNAME=$6
ORCHID_LOGIN=$7
ESYNC_SUPPORT=$8
UPDATE_ORCHID=$9
ORCHID_NAME=${10}
FILESYSTEM=${11}
COUNTED_BY_TREE=${12}
LANGUAGE=${13}
ROOT_PARTITION=${14}
SWAP_PARTITION=${15}
BOOT_PARTITION_UEFI=${16}
BAR='=================================================='                                # This is full bar, i.e. 50 chars

#-----------------------------------------------------------------------------------

# Functions
#-----------------------------------------------------------------------------------

progress_bar()
{
	while read line; do
		pct_dash=$(( $processed * 50 / ${COUNTED_BY_TREE} ))
		pct_num=$(( $processed * 100 / ${COUNTED_BY_TREE} ))
		# Fail safe
		if [ $pct_num -ge 100 ]; then
		  	pct_num=99
		fi

		pct_num_pad="   $pct_num%"
		pct_num_lengh=${#pct_num_pad}
		position_to_trim=$(($pct_num_lengh - 4))
		echo -ne "\r${pct_num_pad:$position_to_trim}[${BAR:0:$pct_dash}>"
		processed=$((processed+1))
		# Fail safe
		if [ $processed -ge ${COUNTED_BY_TREE} ]; then
		  	processed=$((${COUNTED_BY_TREE} -1))
		fi
	done
}

#-----------------------------------------------------------------------------------

#============================================================== PRECONFIGURATION ===

#=== MAIN ==========================================================================

# MAJ des variables d'environnement
#-----------------------------------------------------------------------------------
echo "${COLOR_GREEN}*${COLOR_RESET} Mise à jour des variables d'environnement."
env-update && source /etc/profile
#-----------------------------------------------------------------------------------

# Configuration de fstab
#-----------------------------------------------------------------------------------
# Is this an NVME disk?
if [[ "${CHOOSEN_DISK}" == *"nvme"* ]]; then
	DISK_PARTITIONS="${CHOOSEN_DISK}p"
else
	DISK_PARTITIONS="${CHOOSEN_DISK}"
fi

echo "${COLOR_GREEN}*${COLOR_RESET} Configuration du fichier fstab"
UUID="$(blkid $ROOT_PARTITION -o value -s UUID)"
if [ "$FILESYSTEM" = "Btrfs" ]; then
	echo " ${COLOR_GREEN}*${COLOR_RESET} Configuration pour Btrfs"
	btrfs subvolume create /
	echo "UUID=${UUID}    /    btrfs    subvol=root,compress=zstd:1,defaults           0 0" >> /etc/fstab
	echo "UUID=${UUID}    /.snapshots    btrfs    subvol=.snapshots,compress=zstd:1           0 0" >> /etc/fstab
elif [ "$FILESYSTEM" = "ext4" ]; then	
	echo " ${COLOR_GREEN}*${COLOR_RESET} Configuration pour ext4"
	echo "UUID=${UUID}    /    ext4    defaults,noatime           0 1" >> /etc/fstab
fi
UUID="$(blkid $SWAP_PARTITION -o value -s UUID)"
echo "UUID=${UUID}    none    swap    sw    0 0" >> /etc/fstab
if [ "$ROM" = "UEFI" ]; then
	UUID="$(blkid $BOOT_PARTITION_UEFI -o value -s UUID)"
  echo "UUID=${UUID}    /boot/EFI    vfat    defaults    0 0" >> /etc/fstab
fi

#-----------------------------------------------------------------------------------

# Configuration du nom de la machine (hostname)
#-----------------------------------------------------------------------------------
echo "${COLOR_GREEN}*${COLOR_RESET} Configuration du nom du système sur le réseau."
sed -i "s/orchid/${HOSTNAME}/" /etc/conf.d/hostname
#-----------------------------------------------------------------------------------

# Utilisateurs et mots de passe
#-----------------------------------------------------------------------------------
echo "${COLOR_GREEN}*${COLOR_RESET} Utilisateurs :"
echo ""
echo -e "${ROOT_PASS}\n${ROOT_PASS}" | passwd -q                                        # Création du mot de passe root
useradd -m -G users,wheel,audio,cdrom,video,portage,lp,lpadmin,plugdev,usb -s /bin/bash $USERNAME # Création d'un utilisateur non privilégié
echo -e "${USER_PASS}\n${USER_PASS}" | passwd -q $USERNAME                               # Création du mot de passe utilisateur
#-----------------------------------------------------------------------------------

# Configuration de GRUB
#-----------------------------------------------------------------------------------
if [ "$FILESYSTEM" = "Btrfs" ]; then
	echo "${COLOR_GREEN}*${COLOR_RESET} Configuration de gentoo-kernel-bin pour Btrfs"
	emerge --quiet --config gentoo-kernel-bin
fi

echo "${COLOR_GREEN}*${COLOR_RESET} Configuration de GRUB :"
if [ "$ROM" = "UEFI" ]; then
  # Installation de GRUB pour UEFI
  grub-install --target=x86_64-efi --efi-directory=/boot/EFI --recheck
elif [ "$ROM" = "BIOS" ]; then
  # Installation de GRUB pour BIOS
  grub-install "${CHOOSEN_DISK}"
fi
grub-mkconfig -o /boot/grub/grub.cfg

#-----------------------------------------------------------------------------------

# Activation des services et autres optimisations
#-----------------------------------------------------------------------------------
echo "${COLOR_GREEN}*${COLOR_RESET} Activation de services :"
# Activation des services rc
if [ "$ORCHID_LOGIN" = "BASE" ]; then
	rc-update add dbus default && rc-update add NetworkManager default
elif [ "$ORCHID_LOGIN" = "STANDARD" ]; then
	rc-update add display-manager default && rc-update add dbus default && rc-update add NetworkManager default && rc-update add elogind boot
elif [ "$ORCHID_LOGIN" = "SYSTEMD-BUDGIE" ]; then
	systemctl enable lightdm && systemctl enable NetworkManager
elif [ "$ORCHID_LOGIN" = "SYSTEMD-BASE" ]; then
	systemctl enable NetworkManager
elif [ "$ORCHID_LOGIN" = "SYSTEMD-GNOME" ]; then
	systemctl enable NetworkManager && systemctl enable gdm
fi

if [ "${ORCHID_NAME}" = "KDE" -o "${ORCHID_NAME}" = "XFCE-GE" -o "${ORCHID_NAME}" = "MATE" -o "${ORCHID_NAME}" = "MATE-GAMING" ]; then
	# Lock session password
	echo "${COLOR_GREEN}*${COLOR_RESET} Activation de pam :"
	emerge -q pam
fi

# Change limits for esync support
# This change the configuration file of pam (see above)
if [[ "$ESYNC_SUPPORT" = "o" || "$ESYNC_SUPPORT" = "y" || "$ESYNC_SUPPORT" = "yes" || "$ESYNC_SUPPORT" = "no" ]]; then
	echo "${COLOR_GREEN}*${COLOR_RESET} Activation du support esync pour les jeux pour ${USERNAME}."
	echo "${USERNAME} hard nofile 524288" >> /etc/security/limits.conf
fi

if [ "$FILESYSTEM" = "Btrfs" ]; then
	echo "${COLOR_GREEN}*${COLOR_RESET} Passage des outils orchid-* en version Btrfs."
	cd /usr/share/orchid/orchid-bins
	git fetch
	git checkout btrfs
	cd /
fi

# Add CPU_FLAGS_X86 to make.conf
if ! test -x "$(command -v cpuid2cpuflags 2>/dev/null)"; then
	echo "${COLOR_GREEN}*${COLOR_RESET} Installation de cpuid2cpuflags."
	emerge -q --autounmask-write --autounmask=y app-portage/cpuid2cpuflags
fi

echo "${COLOR_GREEN}*${COLOR_RESET} Ajout des CPU_FLAGS_X86 personnalisés au make.conf."
echo "$(cpuid2cpuflags | sed 's/: /="/')\"" >> /etc/portage/make.conf
# Remove LINGUAS if any to make.conf
sed -i /LINGUAS=/d /etc/portage/make.conf
# set langage if not french, which is default in our Gentoo's stage 4
if [ "$LANGUAGE" = "English" ]; then
	sed -i /L10N=/d /etc/portage/make.conf
	cp /etc/X11/xorg.conf.d/10-keyboard.conf /etc/X11/xorg.conf.d/10-keyboard.conf.tmp
	sed "s/fr/us/g" /etc/X11/xorg.conf.d/10-keyboard.conf.tmp >> /etc/X11/xorg.conf.d/10-keyboard.conf
	echo "L10N=\"en\"" >> /etc/portage/make.conf
	echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
	locale-gen
	eselect locale set "en_US.UTF-8"
	emerge -vDN @world
	sed -i /keymap=/d /etc/conf.d/keymaps
	echo "keymap=\"us\"" >> /etc/conf.d/keymaps
elif [ "$LANGUAGE" = "Romana" ]; then
	sed -i /L10N=/d /etc/portage/make.conf
	echo "L10N=\"ro\"" >> /etc/portage/make.conf
	cp /etc/X11/xorg.conf.d/10-keyboard.conf /etc/X11/xorg.conf.d/10-keyboard.conf.tmp
	sed "s/fr/us/g" /etc/X11/xorg.conf.d/10-keyboard.conf.tmp >> /etc/X11/xorg.conf.d/10-keyboard.conf
	echo "ro_RO.UTF-8 UTF-8" >> /etc/locale.gen
	locale-gen
	eselect locale set "ro_RO.UTF-8"
	emerge -vDN @world
	sed -i /keymap=/d /etc/conf.d/keymaps
	echo "keymap=\"ro\"" >> /etc/conf.d/keymaps
elif [ "$LANGUAGE" = "German" ]; then
	sed -i /L10N=/d /etc/portage/make.conf
	echo "L10N=\"de\"" >> /etc/portage/make.conf
	cp /etc/X11/xorg.conf.d/10-keyboard.conf /etc/X11/xorg.conf.d/10-keyboard.conf.tmp
	sed "s/fr/de/g" /etc/X11/xorg.conf.d/10-keyboard.conf.tmp >> /etc/X11/xorg.conf.d/10-keyboard.conf
	echo "de_DE.UTF-8 UTF-8" >> /etc/locale.gen
	locale-gen
	eselect locale set "de_DE.UTF-8"
	emerge -vDN @world
	sed -i /keymap=/d /etc/conf.d/keymaps
	echo "keymap=\"de\"" >> /etc/conf.d/keymaps
fi
# Remove nvidia driver if not requested by user:
if  [[ ! $(grep "nvidia" /etc/portage/make.conf) ]]; then
	echo "${COLOR_GREEN}*${COLOR_RESET} Suppression du pilote Nvidia inutile."
	#emerge --update --newuse --deep --with-bdeps=y @world
	emerge --rage-clean -q x11-drivers/nvidia-drivers
	#emerge -q --depclean
fi

#-----------------------------------------------------------------------------------

# Mise à jour du système
#-----------------------------------------------------------------------------------
# We do an orchid-sync, in quiet mode:
echo "${COLOR_GREEN}*${COLOR_RESET} Mise à jour des commandes orchid-*."
git -C /usr/share/orchid/desktop/dwm/dwm-st-slstatus pull -q
git -C /usr/share/orchid/wallpapers pull -q
git -C /usr/share/orchid/orchid-bins pull -q 
cp /usr/share/orchid/orchid-bins/bins/* /usr/bin/
if [[ "$UPDATE_ORCHID" = "o" || "$UPDATE_ORCHID" = "y" || "$UPDATE_ORCHID" = "yes" || "$UPDATE_ORCHID" = "no" ]]; then
	echo "${COLOR_GREEN}*${COLOR_RESET} Mise à jour de votre Orchid Linux. Veuillez être patient."
  eix-sync -q
  emerge -qvuDNU @world
  flatpak update --assumeyes --noninteractive 
  grub-mkconfig -o /boot/grub/grub.cfg
  emerge --depclean -q
fi

if [ "$FILESYSTEM" = "Btrfs" ]; then
	echo "${COLOR_GREEN}*${COLOR_RESET} Défragmentation et compression du système de fichiers Btrfs"
	processed=0
	echo -ne "\r    [                                                  ]"	                # This is an empty bar, i.e. 50 empty chars
	btrfs filesystem defragment -r -v -czstd / 2>&1 | progress_bar
	# Fail safe
	echo -ne "\r100%[${BAR:0:50}]"
	# New line
	echo -ne "\r\v"
	echo " ${COLOR_GREEN}*${COLOR_RESET} Opération sur Btrfs terminée."
	echo "${COLOR_GREEN}*${COLOR_RESET} Configuration initiale de Snapper"
	if [ "$ORCHID_LOGIN" = "BASE"  -o "$ORCHID_LOGIN" = "STANDARD" ]; then
		mkdir -p /lib64/rc/init.d
		ln -s /lib64/rc/init.d /run/openrc
		touch /run/openrc/softlevel
		# save default OpenRC setup, and configure for chroot
		mv /etc/rc.conf /etc/rc.conf.SAVE
		echo 'rc_sys="prefix"' >> /etc/rc.conf
		echo 'rc_controller_cgroups="NO"' >> /etc/rc.conf
		echo 'rc_depend_strict="NO"' >> /etc/rc.conf
		echo 'rc_need="!net !dev !udev-mount !sysfs !checkfs !fsck !netmount !logger !clock !modules"' >> /etc/rc.conf
		rc-update --update
		/etc/init.d/dbus start		
	elif [ "$ORCHID_LOGIN" = "SYSTEMD-GNOME"  -o "$ORCHID_LOGIN" = "SYSTEMD-BASE" -o "$ORCHID_LOGIN" = "SYSTEMD-BUDGIE" ]; then
		systemctl start dbus.service
	fi
	snapper -c root create-config /
	if [ "$ORCHID_LOGIN" = "BASE"  -o "$ORCHID_LOGIN" = "STANDARD" ]; then
		/etc/init.d/dbus stop
		rm -f /etc/rc.conf
		mv /etc/rc.conf.SAVE /etc/rc.conf
	elif [ "$ORCHID_LOGIN" = "SYSTEMD-GNOME"  -o "$ORCHID_LOGIN" = "SYSTEMD-BASE" -o "$ORCHID_LOGIN" = "SYSTEMD-BUDGIE" ]; then
		systemctl stop dbus.service
	fi
fi

#-----------------------------------------------------------------------------------

#========================================================================== MAIN ===
