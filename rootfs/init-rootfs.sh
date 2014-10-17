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

#----------------------------------------------------------
# Copy over the current kernel configuration file.
mkdir -p etc/config
cp ../arm-soc/.config etc/config/config.txt

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
# Create the init.d/rcS
cat <<EOF > etc/init.d/rcS
#!/bin/sh
echo Running rcS

# Mount file systems
/bin/mount -t proc proc /proc
/bin/mount -t sysfs sysfs /sys
/bin/mount -t tmpfs -o size=64k,mode=0755 tmpfs /dev

# Fill in /dev directory with mdev
/bin/echo > /dev/mdev.seq
/sbin/mdev -s

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


