# Specify remote target
target remote :2331

# Load kernel into memory.
restore ../image/conprog.bin binary 0

# Set PC to the start of RAM.
set $pc = 0

# Set initial breakpoint.
hbreak start_kernel

# Run to the breakpoint.
continue

# Disconnect without halting.
disconnect
