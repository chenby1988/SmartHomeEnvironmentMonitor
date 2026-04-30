#!/bin/bash
set -e

cd "$(dirname "$0")"

# Smart detection: check if FreeRTOS is actually usable (non-empty tasks.c)
if [ -s "FreeRTOS/tasks.c" ]; then
    echo "[INFO] FreeRTOS source found. Building RTOS version..."
    make clean
    make all
    echo "[INFO] Starting QEMU emulation..."
    echo "(Press Ctrl+A then X to exit)"
    qemu-system-arm -M mps2-an385 -cpu cortex-m3 \
        -device loader,file=env_monitor.bin,addr=0x00000000 \
        -semihosting -nographic
else
    echo "[INFO] FreeRTOS source not found or incomplete."
    echo "[INFO] Running bare-metal version (no download needed)..."
    make env_monitor_bare.bin
    echo "[INFO] Starting QEMU emulation..."
    echo "(Press Ctrl+A then X to exit)"
    qemu-system-arm -M mps2-an385 -cpu cortex-m3 \
        -device loader,file=env_monitor_bare.bin,addr=0x00000000 \
        -semihosting -nographic
fi
