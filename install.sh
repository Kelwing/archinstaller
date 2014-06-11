#!/bin/sh

#   Copyright 2014 Jacob Wiltse
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

echo "Arch Linux Installer by Jacob Wiltse"
echo "This will install a base system with some default options."
echo "Ensure that you have an ethernet cable plugged into the ethernet port"

echo "Lets choose some options"
echo -n "Enter your hostname: "
read hostname
echo -n "Choose your root password: "
read password

echo "THIS WILL ERASE YOUR MAIN HARD DISK!!!!!!!!!"
read -p "Continue? (y/n) " -n 1 -r
echo
# Get ethernet adapter name
$eth="ls /sys/class/net | head -1 | awk '{print $1}'"

if [[ $REPLY =~ ^[Yy]$ ]]
then
    # Try to start networking
    echo "Interface=$eth" > /etc/netctl/eth
    echo "Connection=ethernet" >> /etc/netctl/eth
    echo "IP=dhcp" >> /etc/netctl/eth
    netctl start eth

    # Wipe Partition Table
    dd bs=512 count=1 if=/dev/zero of=/dev/sda
    
    # Create new partitions
    parted /dev/sda --script "mklabel msdos"
    parted /dev/sda --script "mkpart primary ext2 0% -2G"
    parted /dev/sda --script "mkpart primary linux-swap -2G 100%"
    
    # Format partitions
    mkfs.ext4 /dev/sda1
    mkswap /dev/sda2
    
    # Mount new system
    mount /dev/sda1 /mnt
    
    # Enable swap
    swapon /dev/sda2
    
    # Install base system
    pacstrap /mnt base base-devel vim sudo wireless_tools syslinux

    # Generate fstab
    genfstab -p /mnt >> /mnt/etc/fstab

    # Prepare chroot
    mount -t proc proc /mnt/proc/
    mount --rbind /sys /mnt/sys/
    mount --rbind /dev /mnt/dev/
    cp /etc/resolv.conf /mnt/etc/resolv.conf
    
    # Set the hostname
    chroot /mnt /bin/sh -c "echo $hostname > /etc/hostname"

    # Set timezone info
    chroot /mnt /bin/sh -c "ln -s /usr/share/zoneinfo/America/Detroit /etc/localtime"

    # Set locale
    chroot /mnt /bin/sh -c 'echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen'
    chroot /mnt /bin/sh -c "locale-gen"

    # Set root passwd
    chroot /mnt /bin/sh -c "echo $password | passwd --stdin"

    # Make initial ram disk
    chroot /mnt /bin/sh -c "mkinitcpio -p linux"

    # Configure Syslinux
    chroot /mnt /bin/sh -c "syslinux-install_update -i -a -m"
    sed -i 's/sda3/sda1/g' /mnt/boot/syslinux/syslinux.cfg

    # Set up networking in new system
    cp /etc/netcfg/eth /mnt/etc/netcfg/
    chroot /mnt /bin/sh -c "netctl enable eth"
    
    # Unmount our new system
    umount -R /mnt

    # Reboot the computer into our new system
    reboot
fi
