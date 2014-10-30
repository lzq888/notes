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
/bin/mount -t devpts devpts /dev/pts
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

# Mount the wifi romfs
if [ -f /boot/wifi_romfs.bin ]; then
  echo "Mounting wifi_romfs.bin"
  mkdir -p /usr/wifi
  mount -t romfs /boot/wifi_romfs.bin /usr/wifi
  if [ ! "\$?" == "0" ]; then
    echo "Failed to mount wifi_romfs.bin"
  fi
fi

# Mount the netplug romfs
if [ -f /boot/netplug_romfs.bin ]; then
  echo "Mounting netplug_romfs.bin"
  mkdir -p /usr/netplug
  mount -t romfs /boot/netplug_romfs.bin /usr/netplug
  if [ ! "\$?" == "0" ]; then
    echo "Failed to mount netplug_romfs.bin"
  fi
fi

# Mount the dropbear romfs
if [ -f /boot/dropbear_romfs.bin ]; then
  echo "Mounting dropbear_romfs.bin"
  mkdir -p /usr/dropbear
  mount -t romfs /boot/dropbear_romfs.bin /usr/dropbear
  if [ ! "\$?" == "0" ]; then
    echo "Failed to mount dropbear_romfs.bin"
  else
    ln -s /usr/dropbear/scp /bin/scp
  fi
fi

# Copy the default network configuration file
if [ ! -f /boot/network_config ]; then
  if [ -f /usr/wifi/network_config.default ]; then
    echo "Creating default network configuration"
    cp /usr/wifi/network_config.default /boot/network_config
  fi
fi

# Bring up the loopback interface
ifconfig lo up

# Bring up the web server
if [ -d /mnt/mmcblk0p5/www ]; then
  echo "Starting web server using /www"
  /bin/ln -s /mnt/mmcblk0p5/www /www
  /usr/sbin/httpd -p 80 -h /www
fi

# Bring up the ssh server
if [ -e /usr/dropbear/dropbear ]; then
  echo "Starting ssh server"
  /usr/dropbear/dropbear.sh
fi

# Bring up the wifi network
if [ -d /usr/wifi ]; then
  cd /usr/wifi
  ./network.sh
fi

# Start up netplug daemon
if [ -d /usr/netplug ]; then
  cd /usr/netplug
  ./netplugd.sh
fi

# Start up custom apps
if [ -d /boot/apps ]; then
  echo "Starting apps script"
  /boot/apps/start_apps.sh
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
# Create the resolv.conf file
cat <<EOF > etc/resolv.conf
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF
chmod 644 etc/resolv.conf

#----------------------------------------------------------
# Create the httpd.conf file
cat <<EOF > etc/httpd.conf
A:*
EOF
chmod 644 etc/passwd

#----------------------------------------------------------
# Install a basic udhcpc script
mkdir -p usr/share/udhcpc
cp ../runtime/busybox/examples/udhcp/simple.script usr/share/udhcpc/default.script

#----------------------------------------------------------
# Designate a hostname
cat <<EOF > etc/hostname
minilinux
EOF
chmod 644 etc/hostname

#----------------------------------------------------------
# Create the netplug.d/netplug file
cat <<EOF > etc/netplug.d/netplug
#!/bin/sh
#
# netplug - policy agent for netplugd
#
# Copyright 2003 Key Research, Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2, as
# published by the Free Software Foundation.  You are forbidden from
# redistributing or modifying it under the terms of any other license,
# including other versions of the GNU General Public License.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH

dev="\$1"
action="\$2"

case "\$action" in
"in")
    if [ -x /sbin/ifup ]; then
        exec /sbin/ifup \$dev
    else
        echo "Please teach me how to plug in an interface!" 1>&2
        exit 1
    fi
    ;;
"out")
    if [ -x /sbin/ifdown ]; then
        # At least on Fedora Core 1, the call to ip addr flush infloops
        #/sbin/ifdown \$dev && exec /bin/ip addr flush \$dev
        echo "line Out"
    else
        echo "Please teach me how to unplug an interface!" 1>&2
        exit 1
    fi
    ;;
"probe")
    exec /bin/ip link set \$dev up >/dev/null 2>&1
    ;;
*)
    echo "I have been called with a funny action of '%s'!" 1>&2
    exit 1
    ;;
esac
EOF
chmod 755 etc/netplug.d/netplug

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

#----------------------------------------------------------
# Create services file
cat <<EOF > etc/services
# /etc/services:
# \$Id: services,v 1.1.1.1 1999/12/27 21:11:58 chmouel Exp \$
#
# Network services, Internet style
#
# Note that it is presently the policy of IANA to assign a single well-known
# port number for both TCP and UDP; hence, most entries here have two entries
# even if the protocol doesn't support UDP operations.
# Updated from RFC 1700, "Assigned Numbers" (October 1994).  Not all ports
# are included, only the more common ones.
tcpmux          1/tcp                           # TCP port service multiplexer
echo            7/tcp
echo            7/udp
discard         9/tcp           sink null
discard         9/udp           sink null
systat          11/tcp          users
daytime         13/tcp
daytime         13/udp
netstat         15/tcp
qotd            17/tcp          quote
msp             18/tcp                          # message send protocol
msp             18/udp                          # message send protocol
chargen         19/tcp          ttytst source
chargen         19/udp          ttytst source
ftp-data        20/tcp
ftp             21/tcp
fsp             21/udp          fspd
ssh             22/tcp                          # SSH Remote Login Protocol
ssh             22/udp                          # SSH Remote Login Protocol
telnet          23/tcp
# 24 - private
smtp            25/tcp          mail
# 26 - unassigned
time            37/tcp          timserver
time            37/udp          timserver
rlp             39/udp          resource        # resource location
nameserver      42/tcp          name            # IEN 116
whois           43/tcp          nicname
re-mail-ck      50/tcp                          # Remote Mail Checking Protocol
re-mail-ck      50/udp                          # Remote Mail Checking Protocol
domain          53/tcp          nameserver      # name-domain server
domain          53/udp          nameserver
mtp             57/tcp                          # deprecated
bootps          67/tcp                          # BOOTP server
bootps          67/udp
bootpc          68/tcp                          # BOOTP client
bootpc          68/udp
tftp            69/udp
gopher          70/tcp                          # Internet Gopher
gopher          70/udp
rje             77/tcp          netrjs
finger          79/tcp
www             80/tcp          http            # WorldWideWeb HTTP
www             80/udp                          # HyperText Transfer Protocol
link            87/tcp          ttylink
kerberos        88/tcp          kerberos5 krb5  # Kerberos v5
kerberos        88/udp          kerberos5 krb5  # Kerberos v5
supdup          95/tcp
# 100 - reserved
hostnames       101/tcp         hostname        # usually from sri-nic
iso-tsap        102/tcp         tsap            # part of ISODE.
csnet-ns        105/tcp         cso-ns          # also used by CSO name server
csnet-ns        105/udp         cso-ns
# unfortunately the poppassd (Eudora) uses a port which has already
# been assigned to a different service. We list the poppassd as an
# alias here. This should work for programs asking for this service.
# (due to a bug in inetd the 3com-tsmux line is disabled)
#3com-tsmux     106/tcp         poppassd
#3com-tsmux     106/udp         poppassd
rtelnet         107/tcp                         # Remote Telnet
rtelnet         107/udp
pop2            109/tcp         pop-2   postoffice      # POP version 2
pop2            109/udp         pop-2
pop3            110/tcp         pop-3           # POP version 3
pop3            110/udp         pop-3
sunrpc          111/tcp         portmapper      # RPC 4.0 portmapper TCP
sunrpc          111/udp         portmapper      # RPC 4.0 portmapper UDP
auth            113/tcp         authentication tap ident
sftp            115/tcp
uucp-path       117/tcp
nntp            119/tcp         readnews untp   # USENET News Transfer Protocol
ntp             123/tcp
ntp             123/udp                         # Network Time Protocol
netbios-ns      137/tcp                         # NETBIOS Name Service
netbios-ns      137/udp
netbios-dgm     138/tcp                         # NETBIOS Datagram Service
netbios-dgm     138/udp
netbios-ssn     139/tcp                         # NETBIOS session service
netbios-ssn     139/udp
imap2           143/tcp         imap            # Interim Mail Access Proto v2
imap2           143/udp         imap
snmp            161/udp                         # Simple Net Mgmt Proto
snmp-trap       162/udp         snmptrap        # Traps for SNMP
cmip-man        163/tcp                         # ISO mgmt over IP (CMOT)
cmip-man        163/udp
cmip-agent      164/tcp
cmip-agent      164/udp
xdmcp           177/tcp                         # X Display Mgr. Control Proto
xdmcp           177/udp
nextstep        178/tcp         NeXTStep NextStep       # NeXTStep window
nextstep        178/udp         NeXTStep NextStep       # server
bgp             179/tcp                         # Border Gateway Proto.
bgp             179/udp
prospero        191/tcp                         # Cliff Neuman's Prospero
prospero        191/udp
irc             194/tcp                         # Internet Relay Chat
irc             194/udp
smux            199/tcp                         # SNMP Unix Multiplexer
smux            199/udp
at-rtmp         201/tcp                         # AppleTalk routing
at-rtmp         201/udp
at-nbp          202/tcp                         # AppleTalk name binding
at-nbp          202/udp
at-echo         204/tcp                         # AppleTalk echo
at-echo         204/udp
at-zis          206/tcp                         # AppleTalk zone information
at-zis          206/udp
qmtp            209/tcp                         # The Quick Mail Transfer Protocol
qmtp            209/udp                         # The Quick Mail Transfer Protocol
z3950           210/tcp         wais            # NISO Z39.50 database
z3950           210/udp         wais
ipx             213/tcp                         # IPX
ipx             213/udp
imap3           220/tcp                         # Interactive Mail Access
imap3           220/udp                         # Protocol v3
rpc2portmap     369/tcp
rpc2portmap     369/udp                         # Coda portmapper
codaauth2       370/tcp
codaauth2       370/udp                         # Coda authentication server
ulistserv       372/tcp                         # UNIX Listserv
ulistserv       372/udp
https           443/tcp                         # MCom
https           443/udp                         # MCom
snpp            444/tcp                         # Simple Network Paging Protocol
snpp            444/udp                         # Simple Network Paging Protocol
saft            487/tcp                         # Simple Asynchronous File Transfer
saft            487/udp                         # Simple Asynchronous File Transfer
npmp-local      610/tcp         dqs313_qmaster  # npmp-local / DQS
npmp-local      610/udp         dqs313_qmaster  # npmp-local / DQS
npmp-gui        611/tcp         dqs313_execd    # npmp-gui / DQS
npmp-gui        611/udp         dqs313_execd    # npmp-gui / DQS
hmmp-ind        612/tcp         dqs313_intercell# HMMP Indication / DQS
hmmp-ind        612/udp         dqs313_intercell# HMMP Indication / DQS
#
# UNIX specific services
#
exec            512/tcp
biff            512/udp         comsat
login           513/tcp
who             513/udp         whod
shell           514/tcp         cmd             # no passwords used
syslog          514/udp
printer         515/tcp         spooler         # line printer spooler
talk            517/tcp
ntalk           518/udp
route           520/udp         router routed   # RIP
timed           525/udp         timeserver
tempo           526/tcp         newdate
courier         530/tcp         rpc
conference      531/tcp         chat
netnews         532/tcp         readnews
netwall         533/udp                         # -for emergency broadcasts
uucp            540/tcp         uucpd           # uucp daemon
afpovertcp      548/tcp                         # AFP over TCP
afpovertcp      548/udp                         # AFP over TCP
remotefs        556/tcp         rfs_server rfs  # Brunhoff remote filesystem
klogin          543/tcp                         # Kerberized 'rlogin' (v5)
kshell          544/tcp         krcmd           # Kerberized 'rsh' (v5)
kerberos-adm    749/tcp                         # Kerberos 'kadmin' (v5)
#
webster         765/tcp                         # Network dictionary
webster         765/udp
#
# From "Assigned Numbers":
#
#> The Registered Ports are not controlled by the IANA and on most systems
#> can be used by ordinary user processes or programs executed by ordinary
#> users.
#
#> Ports are used in the TCP [45,106] to name the ends of logical
#> connections which carry long term conversations.  For the purpose of
#> providing services to unknown callers, a service contact port is
#> defined.  This list specifies the port used by the server process as its
#> contact port.  While the IANA can not control uses of these ports it
#> does register or list uses of these ports as a convienence to the
#> community.
#
ingreslock      1524/tcp
ingreslock      1524/udp
prospero-np     1525/tcp                        # Prospero non-privileged
prospero-np     1525/udp
datametrics     1645/tcp        old-radius      # datametrics / old radius entry
datametrics     1645/udp        old-radius      # datametrics / old radius entry
sa-msg-port     1646/tcp        old-radacct     # sa-msg-port / old radacct entry
sa-msg-port     1646/udp        old-radacct     # sa-msg-port / old radacct entry
radius          1812/tcp                        # Radius
radius          1812/udp                        # Radius
radacct         1813/tcp                        # Radius Accounting
radacct         1813/udp                        # Radius Accounting
cvspserver      2401/tcp                        # CVS client/server operations
cvspserver      2401/udp                        # CVS client/server operations
venus           2430/tcp                        # codacon port
venus           2430/udp                        # Venus callback/wbc interface
venus-se        2431/tcp                        # tcp side effects
venus-se        2431/udp                        # udp sftp side effect
codasrv         2432/tcp                        # not used
codasrv         2432/udp                        # server port
codasrv-se      2433/tcp                        # tcp side effects
codasrv-se      2433/udp                        # udp sftp side effect
mysql           3306/tcp                        # MySQL
mysql           3306/udp                        # MySQL
rfe             5002/tcp                        # Radio Free Ethernet
rfe             5002/udp                        # Actually uses UDP only
cfengine        5308/tcp                        # CFengine
cfengine        5308/udp                        # CFengine
bbs             7000/tcp                        # BBS service
#
#
# Kerberos (Project Athena/MIT) services
# Note that these are for Kerberos v4, and are unofficial.  Sites running
# v4 should uncomment these and comment out the v5 entries above.
#
kerberos4       750/udp         kerberos-iv kdc # Kerberos (server) udp
kerberos4       750/tcp         kerberos-iv kdc # Kerberos (server) tcp
kerberos_master 751/udp                         # Kerberos authentication
kerberos_master 751/tcp                         # Kerberos authentication
passwd_server   752/udp                         # Kerberos passwd server
krb_prop        754/tcp                         # Kerberos slave propagation
krbupdate       760/tcp         kreg            # Kerberos registration
kpasswd         761/tcp         kpwd            # Kerberos "passwd"
kpop            1109/tcp                        # Pop with Kerberos
knetd           2053/tcp                        # Kerberos de-multiplexor
zephyr-srv      2102/udp                        # Zephyr server
zephyr-clt      2103/udp                        # Zephyr serv-hm connection
zephyr-hm       2104/udp                        # Zephyr hostmanager
eklogin         2105/tcp                        # Kerberos encrypted rlogin
#
# Unofficial but necessary (for NetBSD) services
#
supfilesrv      871/tcp                         # SUP server
supfiledbg      1127/tcp                        # SUP debugging
#
# Datagram Delivery Protocol services
#
rtmp            1/ddp                           # Routing Table Maintenance Protocol
nbp             2/ddp                           # Name Binding Protocol
echo            4/ddp                           # AppleTalk Echo Protocol
zip             6/ddp                           # Zone Information Protocol
#
# Services added for the Debian GNU/Linux distribution
poppassd        106/tcp                         # Eudora
poppassd        106/udp                         # Eudora
mailq           174/tcp                         # Mailer transport queue for Zmailer
mailq           174/tcp                         # Mailer transport queue for Zmailer
ssmtp           465/tcp                         # SMTP over SSL
gdomap          538/tcp                         # GNUstep distributed objects
gdomap          538/udp                         # GNUstep distributed objects
snews           563/tcp                         # NNTP over SSL
ssl-ldap        636/tcp                         # LDAP over SSL
omirr           808/tcp         omirrd          # online mirror
omirr           808/udp         omirrd          # online mirror
rsync           873/tcp                         # rsync
rsync           873/udp                         # rsync
simap           993/tcp                         # IMAP over SSL
spop3           995/tcp                         # POP-3 over SSL
socks           1080/tcp                        # socks proxy server
socks           1080/udp                        # socks proxy server
rmtcfg          1236/tcp                        # Gracilis Packeten remote config server
xtel            1313/tcp                        # french minitel
support         1529/tcp                        # GNATS
cfinger         2003/tcp                        # GNU Finger
ninstall        2150/tcp                        # ninstall service
ninstall        2150/udp                        # ninstall service
afbackup        2988/tcp                        # Afbackup system
afbackup        2988/udp                        # Afbackup system
icp             3130/tcp                        # Internet Cache Protocol (Squid)
icp             3130/udp                        # Internet Cache Protocol (Squid)
postgres        5432/tcp                        # POSTGRES
postgres        5432/udp                        # POSTGRES
fax             4557/tcp                        # FAX transmission service        (old)
hylafax         4559/tcp                        # HylaFAX client-server protocol  (new)
noclog          5354/tcp                        # noclogd with TCP (nocol)
noclog          5354/udp                        # noclogd with UDP (nocol)
hostmon         5355/tcp                        # hostmon uses TCP (nocol)
hostmon         5355/udp                        # hostmon uses TCP (nocol)
ircd            6667/tcp                        # Internet Relay Chat
ircd            6667/udp                        # Internet Relay Chat
webcache        8080/tcp                        # WWW caching service
webcache        8080/udp                        # WWW caching service
tproxy          8081/tcp                        # Transparent Proxy
tproxy          8081/udp                        # Transparent Proxy
mandelspawn     9359/udp        mandelbrot      # network mandelbrot
amanda          10080/udp                       # amanda backup services
kamanda         10081/tcp                       # amanda backup services (Kerberos)
kamanda         10081/udp                       # amanda backup services (Kerberos)
amandaidx       10082/tcp                       # amanda backup services
amidxtape       10083/tcp                       # amanda backup services
isdnlog         20011/tcp                       # isdn logging system
isdnlog         20011/udp                       # isdn logging system
vboxd           20012/tcp                       # voice box system
vboxd           20012/udp                       # voice box system
binkp           24554/tcp                       # Binkley
binkp           24554/udp                       # Binkley
asp             27374/tcp                       # Address Search Protocol
asp             27374/udp                       # Address Search Protocol
tfido           60177/tcp                       # Ifmail
tfido           60177/udp                       # Ifmail
fido            60179/tcp                       # Ifmail
fido            60179/udp                       # Ifmail
# Local services
EOF
chmod 644 etc/services

