#!/bin/bash

# start xterm with openocd in the background
xterm -e JLinkGDBServer -speed 4000 &

# save the PID of the background process
XTERM_PID=$!

# wait a bit to be sure the hardware is ready
sleep 2

# execute some initialisation commands via gdb
arm-none-linux-gnueabi-gdb --batch --command=init.gdb vmlinux

# start the gdb gui
nemiver --remote=localhost:2331 --gdb-binary="$(which arm-none-linux-gnueabi-gdb)" vmlinux

# close xterm when the user has exited nemiver
kill $XTERM_PID

