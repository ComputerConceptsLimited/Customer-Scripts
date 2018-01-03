#!/bin/bash

# Shell script to extend root volume group on a CentOS Linux image
#
# **** VERY dangerous to use in any other situation ****
#
# Jon Waite, 2018-01-04
#

# This is the disk containing /dev/mapper/centos-root in our template:
DEVICE=/dev/sda
PARTITION=2

# Show current partition info:
/usr/sbin/parted ${DEVICE} --script print
/usr/bin/df -vh /

# Get first sector:
FIRSTSECT=`/usr/sbin/fdisk -us -l | grep ${DEVICE}${PARTITION} | awk '{print $2}'`

echo "First sector = ${FIRSTSECT}"

# Get last sector:
LASTSECT=`/usr/sbin/parted ${DEVICE} --script unit s print | grep "Disk ${DEVICE}" | cut -d' ' -f3 | tr -d s`

echo "Last sector = ${LASTSECT}"

# Remove and recreate partition (!)
/usr/sbin/parted -s ${DEVICE} rm ${PARTITION} mkpart primary ext2 ${FIRSTSECT}s "100%"
/usr/sbin/parted -s ${DEVICE} set ${PARTITION} lvm on

# Re-read the partition table
/usr/sbin/partx -u ${DEVICE}

# Resize the LVM physical volume:
/usr/sbin/pvresize ${DEVICE}${PARTITION}

# Resize the LVM volume group:
/usr/sbin/lvresize -l +100%FREE /dev/mapper/centos-root

# Grow the xfs filesystem into the new space:
/usr/sbin/xfs_growfs /

# Should all be done...
/usr/sbin/parted ${DEVICE} --script print
/usr/bin/df -vh /
