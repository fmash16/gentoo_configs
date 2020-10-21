# gentoo_configs
Config files for my gentoo installation.

# Gentoo Installation

## Booting

Download the iso from gentoo site, and burn it to a disc. Booting from the live
installation media, boot into the gentoo kernel

```
boot: gentoo
```


## Network

Check if the network is setup automatically with ```ifconfig```. Test the
network with ping.

```
ping -c 3 www.google.com
```

## Partition Scheme (UEFI)

When installing Gentoo on a system that uses UEFI to boot the operating system
(instead of BIOS), then it is important that an EFI System Partition (ESP) is
created. The instructions for parted below contain the necessary pointers to
correctly handle this operation. 

```
mkfs.fat -F 32 /dev/sda2
```

We are going to follow the following partitioning scheme for our gentoo
installation.

Partition |  Filesystem | Size | Description
--- | --- | ---
/dev/sda1 |  (bootloader) | 2M | BIOS boot partition
/dev/sda2 |  ext2 (or fat32 if UEFI is being used) |  128M | Boot/EFI system partition
/dev/sda3 |  (swap) | 512M or higher | Swap partition
/dev/sda4 |  ext4 | Rest of the disk | Root partition 

We use cfdisk for partitioning the disk

```
cfdisk /dev/sda
```

### Creating Filesystems

We use ext4 filesystem for our partitions.

```
mkfs.ext4 /dev/sda2
mkfs.ext4 /dev/sda4
```

> mkfs.ext4 command comes from the package ```sys-fs/e2fsprogs```  
> mkfs.ntfs command comes from the package ```sys-fs/ntfs-3g```

### Acticating SWAP partition

```
mkswap /dev/sda3
swapon /dev/sda3
```


## Mounting the ROOT partition

```
mount /dev/sda4 /mnt/gentoo
```


# Installing the Gentoo installation files

## Installing a stage tarball

We first set the date and time

```
ntpd -qg
date
```

We are going to use the multilib(both 32 and 64 bit support) tarball for our
installation. We download the tarball using a terminal based web browser "links".

```bash
cd /mnt/gentoo
links https://www.gentoo.org/downloads/mirrors/
```

### Unpacking the stage tarball

```bash
tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner
```


## Configuring compile options


ptimize Gentoo, it is possible to set a couple of variables which impacts the
behavior of Portage, Gentoo's officially supported package manager. All those
variables can be set as environment variables (using export) but that isn't
permanent. To keep the settings, Portage reads in the /etc/portage/make.conf
file, a configuration file for Portage. 

You can read up more on this on the [gentoo handbook.]
(https://wiki.gentoo.org/wiki/Handbook:AMD64/Installation/Stage)

I have make.conf file setup specifically for my system. And it is available in
this repository. We are going to copy it to ```/etc/portage``` and use it. The
same make.conf file would not work for all systems, as I have it setup
specifically for my current running system.


# Installing the Gentoo base system

## Chrooting

Select a mirror for downloading your installation files

```bash
mirrorselect -i -o >> /mnt/gentoo/etc/portage/make.conf
```

### Gentoo ebuild repository

```bash
mkdir --parents /mnt/gentoo/etc/portage/repos.conf
cp /mnt/gentoo/usr/share/portage/config/repos.conf /mnt/gentoo/etc/portage/repos.conf/gentoo.conf
```

We already have a repos.conf in this repository setup as my personal
preferences, so we can use that.

### Copy DNS info

```bash
cp --dereference /etc/resolv.conf /mnt/gentoo/etc/
```


## Mounting the necessary filesystems

```bash
mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev 
```

## Entering the new environment

```bash
chroot /mnt/gentoo /bin/bash
source /etc/profile
export PS1="(chroot) ${PS1}"
```

## Mounting the boot partition

```
mount /dev/sda2 /boot
```


# Configuring Portage

## Installing a Gentoo ebuild repository snapshot from the web

```bash
emerge-webrsync
```

We are also going to update the ebuild repository

```bash
emerge --sync
```

## Choosing the right profile

A profile is a building block for any Gentoo system. Not only does it specify
default values for USE, CFLAGS, and other important variables, it also locks
the system to a certain range of package versions. These settings are all
maintained by Gentoo's Portage developers. 

We check the profiles using the following command

```bash
eselect profile list
```

Viewing the list, we select a profile as per our needs

```bash
eselect profile set 2
```


## Updating the @world set

At this point, it is wise to update the system's @world set so that a base can
be established.

This following step is necessary so the system can apply any updates or USE
flag changes which have appeared since the stage3 was built and from any
profile selection: 

```bash
emerge --ask --verbose --update --deep --newuse @world

OR, emerge -DuvaN @world
```

## Configuring the USE variable

You can view your USE variables using the folowing

```bash
emerge --info
```

You can also readup on USE flags more here

```bash
less /var/db/repos/gentoo/profiles/use.desc
```

We already have our USE flags configured in our make.conf file. But Setting the
flags is very important as it gives a lot of control over support for what is
installed on your system and what is not, and makes your system lightweight.


## Timezone

```bash
ls /usr/share/zoneinfo
echo "Europe/Brussels" > /etc/timezone
emerge --config sys-libs/timezone-data
```

## Configure locales

```bash
nano -w /etc/locale.gen
```

Uncomment the following for English

```
en_US ISO-8859-1
en_US.UTF-8 UTF-8
```

And then, generate the locales

```bash
locale-gen
```

### Locale selection

```bash
eselect locale list
```

From the list, select the prefered locale

```
eselect locale set <locale number>
```

Now, reload the environment.

```bash
env-update && source /etc/profile && export PS1="(chroot) ${PS1}"
```
