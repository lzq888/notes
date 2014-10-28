#!/bin/sh

cd ~mike/Linux/rootfs/

#----------------------------------------------------------
# Set sticky bit on busybox
chmod u+s bin/busybox

#----------------------------------------------------------
# Create various mountpoints and directories
mkdir -p etc
mkdir -p lib
mkdir -p proc
mkdir -p sys
mkdir -p dev
mkdir -p mnt
mkdir -p tmp
mkdir -p root
mkdir -p var/shm
mkdir -p var/run
mkdir -p etc/init.d
mkdir -p etc/network
mkdir -p etc/netplug
mkdir -p etc/netplug.d

#----------------------------------------------------------
# Copy over the current kernel configuration file.
mkdir -p etc/config
cp ../arm-soc/.config etc/config/config.txt

#----------------------------------------------------------
# Create the network interface directories
mkdir -p etc/network/if-down.d
mkdir -p etc/network/if-post-up.d
mkdir -p etc/network/if-pre-up.d
mkdir -p etc/network/if-post-down.d
mkdir -p etc/network/if-pre-down.d
mkdir -p etc/network/if-up.d

#----------------------------------------------------------
# Create Core Device files
if [ ! -e dev/console ]; then
  mknod dev/console c 5 1
fi
if [ ! -e dev/null ]; then
  mknod dev/null c 1 3
fi

#----------------------------------------------------------
# Create the profile
cat <<EOF > etc/profile
# Add paths here
EOF
chmod 644 etc/profile

#----------------------------------------------------------
# Create a basic inittab for init
cat <<EOF > etc/inittab
# Boot-time system configuration/initialization script.

# Stuff to do when run first except when booting in single-user mode
::sysinit:/etc/init.d/rcS
::sysinit:/bin/hostname -F /etc/hostname

# Note below that we prefix the shell commands with a "-" to indicate to the
# shell that it is supposed to be a login shell.  Normally this is handled by
# login, but since we are bypassing login in this case, BusyBox lets you do
# this yourself...
# Start an "askfirst" shell on the console
#::once:-/bin/sh
::askfirst:-/bin/sh
#::respawn:/sbin/getty -L ttyS1 115200 vt100

# Stuff to do when restarting the init process
::restart:/sbin/init

# Stuff to do before rebooting
::shutdown:/sbin/swapoff -a
::shutdown:/bin/umount -a -r
EOF
chmod 644 etc/inittab

#----------------------------------------------------------
# Create the fstab file
cat <<EOF > etc/fstab
proc  /proc      proc    defaults     0      0
none  /var/shm   shm     defaults     0      0
sysfs /sys       sysfs   defaults     0      0
none  /tmp       ramfs   defaults     0      0
none  /mnt       ramfs   defaults     0      0
none  /var       ramfs   defaults     0      0
EOF
chmod 644 etc/fstab

#----------------------------------------------------------
# Create the mdev file
cat <<EOF > etc/mdev.conf
mmcblk([0-9]+)p([0-9]+) 0:0 660 */sbin/automount.sh \$MDEV
sd([a-z]+)([0-9]+)      0:0 660 */sbin/automount.sh \$MDEV
mtdblock([0-9]+)        0:0 660 */sbin/automount.sh \$MDEV
EOF
chmod 644 etc/mdev.conf

#----------------------------------------------------------
# Create the init.d/rcS
cat <<EOF > etc/init.d/rcS
#!/bin/sh
echo Running rcS

# Mount file systems
/bin/mount -t proc proc /proc
/bin/mount -t sysfs sysfs /sys
/bin/mount -t tmpfs -o size=64k,mode=0755 tmpfs /dev

# Fill in /dev 
/bin/mkdir -p /dev/pts
#/bin/mount -t devpts devpts /dev/pts
/bin/echo > /dev/mdev.seq
/bin/echo /sbin/mdev > /proc/sys/kernel/hotplug
/sbin/mdev -s

# Linking the boot directory
if [ -d /mnt/mmcblk0p1 ]; then
  echo "Linking the /boot directory"
  /bin/ln -s /mnt/mmcblk0p1 /boot
else
  echo "Failed to link the /boot directory"
fi

# Mount the lib romfs
if [ -f /boot/lib_romfs.bin ]; then
  echo "Mounting lib_romfs.bin"
  mkdir -p /lib
  mount -t romfs /boot/lib_romfs.bin /lib
  if [ ! "\$?" == "0" ]; then
    echo "Failed to mount lib_romfs.bin"
  fi
fi

EOF
chmod 755 etc/init.d/rcS

#----------------------------------------------------------
# Create the password and group files
cat <<EOF > etc/passwd
root:x:0:0:root:/root:/bin/sh
EOF
chmod 644 etc/passwd

cat <<EOF > etc/shadow
root::10933:0:99999:7:::
EOF
chmod 644 etc/shadow

cat <<EOF > etc/group
root:x:0:root
EOF
chmod 644 etc/group

cat <<EOF > etc/gshadow
root:::root
EOF
chmod 644 etc/gshadow

#----------------------------------------------------------
# Designate a hostname
cat <<EOF > etc/hostname
minilinux
EOF
chmod 644 etc/hostname

#----------------------------------------------------------
# Create automount shell script
cat <<EOF > sbin/automount.sh
#!/bin/sh

if [ "\$1" == "" ]; then
  echo "parameter is none" > /tmp/error.txt
  exit 1
fi

MNT=\$1
if echo "\$1" | grep mmcblk; then
  if echo "\$1" | grep p[25]; then
    MNT=sdcard2
  else
    MNT=sdcard
  fi
else
  if echo "\$1" | grep sd; then
    if echo "\$1" | grep [25]; then
      MNT=nandcard2
    else
      MNT=nandcard
    fi
  fi
fi

mounted=\`mount | grep \$1 | wc -l\`
#echo "par=\$1,mounted=\$mounted,MNT=\$MNT" > /dev/console

# not mounted, lets mount under /mnt
if [ \$mounted -lt 1 ]; then
  if ! mkdir -p "/mnt/\$1"; then
    exit 1
  fi

#try jffs2 first
  if ! mount -t jffs2 "/dev/\$1" "/mnt/\$1" > /dev/null 2>&1; then
#try vfat
    if ! mount -t vfat -o noatime,shortname=mixed,utf8 "/dev/\$1" "/mnt/\$1" > /dev/null 2>&1; then
# failed to mount, clean up mountpoint
      if ! rmdir "/mnt/\$1"; then
        exit 1
      fi
      exit 1
    else
      ln -s /mnt/\$1 /mnt/\$MNT
      echo "[Mount VFAT]: /dev/\$1 --> /mnt/\$MNT" > /dev/console
      echo "A/mnt/\$1" >> /tmp/usbmnt.log
      echo "A/mnt/\$1" > /tmp/fifo.1
    fi
  else
    echo "[Mount JFFS2]: /dev/\$1 --> /mnt/\$MNT" > /dev/console
    echo "A/mnt/\$1" >> /tmp/usbmnt.log
    echo "A/mnt/\$1" > /tmp/fifo.1
  fi
fi
EOF
chmod 755 sbin/automount.sh


