#!/bin/sh

# User set variables

BOOTPARTSIZE="100M"
SWAPPARTSIZE="4G"
ROOTPARTSIZE=" "

SRCLINK="https://mirrors.tuna.tsinghua.edu.cn/gentoo/releases/amd64/autobuilds/current-stage3-amd64/stage3-amd64-20210630T214504Z.tar.xz "

# exit when any command fails
set -e

# Helper functions

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color


exit_on_error() {
    exit_code=$?
    if [ $exit_code -ne 0 ]; then
        >&2 echo "command failed with exit code ${exit_code}."
        exit $exit_code
    fi
}

function cleanup {
    printf "${RED}[-] Errors occured. Exiting installer \n${NC}"
    sleep 5
    umount -R /mnt/gentoo
}

trap cleanup EXIT


# Disk Partitioning
printf "${GREEN}[+] Existing disk partitions: ${NC}\n"
lsblk

read -t 5 -p "Enter the disk to intall to [/dev/sda]:" TGTDEV
TGTDEV=${TGTDEV:-"/dev/sda"}

printf "${GREEN}[+] Partitioning disks.... ${NC}\n"
# to create the partitions programatically (rather than manually)
# we're going to simulate the manual input to fdisk
# The sed script strips off all the comments so that we can
# document what we're doing in-line with the actual commands
# Note that a blank line (commented as "defualt" will send a empty
# line terminated with a newline to take the fdisk default.
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk ${TGTDEV}

  o # clear the in memory partition table
  n # new partition
  p # primary partition
  1 # partition number 1
    # default - start at beginning of disk
  +$BOOTPARTSIZE # 100 MB boot parttion

  n # new partition
  p # primary partition
  2 # partion number 2
    # default, start immediately after preceding partition
  +$SWAPPARTSIZE   # 1Gb swap partition

  n # new partition
  p # primary partition
  3 # partion number 3
    # default, start immediately after preceding partition
  $ROOTPARTSIZE  # default, extend partition to end of disk

  t # change partition type
  2 # Select partition 2 (swap)
  82# Hex code for swap partition type

  t # change partition type
  1 # Select partition 1 (efi boot)
  1 # Hex code for efi partition type

  p # print the in-memory partition table
  w # write the partition table
  q # and we're done
EOF
exit_on_error
  #a # make a partition bootable
  #1 # bootable partition is partition 1 -- /dev/sda1

printf "${GREEN}[+] Creating filesystems ${NC}\n"
mkfs.ext4 $TGTDEV\1
mkfs.ext4 $TGTDEV\3
mkswap $TGTDEV\2
swapon

# Mount disks
#read -t 5 -p "Enter the root mount partition [/dev/sda3]:" ROOTPART
#ROOTPART=${ROOTPART:-"/dev/sda3"}

printf "${GREEN}[+] Mounting root partition at /mnt/gentoo ${NC}\n"
mount $TGTDEV\3 /mnt/gentoo

# Install stage tarball
printf "${GREEN}[+] Updating date and time ${NC}\n"
ntpd -qg
date

printf "${GREEN}[+] Downloading root filesystem ${NC}\n"
cd /mnt/gentoo
wget $SRCLINK 

# Unpack stage tarball
printf "${GREEN}[+] Unpacking root fs tarball ${NC}\n"
tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner

# Configure compile options
printf "${GREEN}[+] Writing make options to make.conf file ${NC}\n"
wget https://github.com/fmash16/gentoo_configs/archive/refs/tags/gentoo_config_1.zip
unzip gentoo_config_1 
cp -rv gentoo_configs-gentoo_config_1/* /mnt/gentoo/etc/portage/
echo "sys-kernel/linux-firmware linux-fw-redistributable no-source-code" >> /mnt/gentoo/etc/portage/package.license
#wget https://raw.githubusercontent.com/fmash16/gentoo_configs/main/make.conf -O /mnt/gentoo/etc/portage/make.conf

# Copy gentoo ebuild repo
mkdir --parents /mnt/gentoo/etc/portage/repos.conf
cp /mnt/gentoo/usr/share/portage/config/repos.conf /mnt/gentoo/etc/portage/repos.conf/gentoo.conf

# Copy DNS info
printf "${GREEN}[+] Copying resolv.conf ${NC}\n"
cp --dereference /etc/resolv.conf /mnt/gentoo/etc/

# Mount necessary filesystems
printf "${GREEN}[+] Mounting necessary filesystems ${NC}\n"
mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev 

# Enter chroot environment
printf "${GREEN}[+] Entering chroot environment ${NC}\n"

chroot /mnt/gentoo /bin/bash << EOT
source /etc/profile
#export PS1="(chroot) ${PS1}"

# Mount /boot partition
printf "${GREEN}[+] Mounting boot partition at /boot ${NC}\n"
mount $TGTDEV\1 /boot

# Install gentoo ebuild repo snapshot
printf "${GREEN}[+] Installing gentoo ebuild repo snapshot ${NC}\n"
emerge-webrsync

# Set profile
printf "${GREEN}[+] Setting kernel profile ${NC}\n"
eselect profile list
eselect profile set 1

# Update the @world set
printf "${GREEN}[+] Updating @world ${NC}\n"
emerge --verbose --update --deep --newuse @world
if [ $retval -ne 0 ]; then
    dispatch-conf u
    emerge --verbose --update --deep --newuse @world
fi

set -e


# Set timezone
printf "${GREEN}[+] Setting timezone ${NC}\n"
ls /usr/share/zoneinfo
echo "Asia/Dhaka" > /etc/timezone
emerge --config sys-libs/timezone-data

# Configure Locale
#printf "${GREEN}[+] Configuring locale ${NC}\n"

#function uncomment() {
    ## Uncomments a line from a config file (comment char: #)
    #local regex="\${1:?}"
    #local file="\${2:?}"
    #local comment_mark="\${3:-#}"
    #sed -ri "s:^([ ]*)[\$comment_mark]+[ ]?([ ]*\$regex):\\1\\2:" "$file"
#}

#uncomment "en_US.UTF-8 UTF-8" /etc/locale.gen
#uncomment "en_US ISO-8859-1" /etc/locale.gen

#locale-gen
#eselect locale list
#eselect locale set

env-update && source /etc/profile

# Copy configs from github
#printf "${GREEN}[+] Copying portage configs from github ${NC}\n"
#emerge dev-vcs/git
#git clone https://github.com/fmash16/gentoo_configs
#wget https://github.com/fmash16/gentoo_configs/archive/refs/tags/gentoo_config_1.zip
#unzip gentoo_config_1 
#cp -rv gentoo_configs-gentoo_config_1/* /etc/portage/
#echo "sys-kernel/linux-firmware linux-fw-redistributable no-source-code" >> /etc/portage/package.license

# Installing the sources
printf "${GREEN}[+] Installing gentoo sources ${NC}\n"
emerge sys-kernel/gentoo-sources
eselect kernel list
eselect kernel set 1 

# Build kernel using genkernel
emerge sys-kernel/genkernel
genkernel all

# Install necessary firmware
emerge sys-kernel/linux-firmware

printf "${GREEN}[+] Setting root passwd ${NC}\n"
echo "password1234\npassword1234" | passwd root

# Add user
printf "${GREEN}[+] Adding new user ${NC}\n"
useradd -m -G users,wheel,audio -s /bin/bash user 
echo "password1234\npassword1234" | passwd user

# Network setup
printf "${GREEN}[+] Setting up dhcpcd ${NC}\n"
emerge dhcpcd
rc-update add dhcpcd default


# Install grub
printf "${GREEN}[+] Installing and updating grub ${NC}\n"
#echo 'GRUB_PLATFORMS="efi-64"' >> /etc/portage/make.conf
emerge --verbose sys-boot/grub:2

grub-install --target=x86_64-efi --efi-directory=/boot
grub-mkconfig -o /boot/grub/grub.cfg

EOT

# unmount all mounts and reboot
printf "${GREEN}[+] Unmounting all mounts ${NC}\n"
cd
umount -l /mnt/gentoo/dev{/shm,/pts,}
umount -R /mnt/gentoo
printf "${GREEN}[+] Rebooting system ${NC}\n"
reboot
