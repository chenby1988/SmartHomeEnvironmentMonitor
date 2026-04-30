#!/bin/bash
set -e

BASE="https://raw.githubusercontent.com/FreeRTOS/FreeRTOS-Kernel/V10.4.6"
DEST="./FreeRTOS"

echo "[INFO] Downloading FreeRTOS V10.4.6 core files..."
mkdir -p "$DEST/include"
mkdir -p "$DEST/portable/GCC/ARM_CM3"
mkdir -p "$DEST/portable/MemMang"

download_file() {
    local url="$1"
    local out="$2"
    if [ -f "$out" ]; then
        echo "[SKIP] $out already exists"
        return
    fi
    echo "[DOWNLOAD] $out"
    if command -v wget >/dev/null 2>&1; then
        wget -q "$url" -O "$out"
    else
        curl -sL "$url" -o "$out"
    fi
}

for f in tasks.c list.c queue.c timers.c event_groups.c; do
    download_file "$BASE/$f" "$DEST/$f"
done

for f in port.c portmacro.h; do
    download_file "$BASE/portable/GCC/ARM_CM3/$f" "$DEST/portable/GCC/ARM_CM3/$f"
done

download_file "$BASE/portable/MemMang/heap_4.c" "$DEST/portable/MemMang/heap_4.c"

for f in FreeRTOS.h task.h list.h queue.h timers.h event_groups.h portable.h deprecated_definitions.h mpu_wrappers.h projdefs.h stack_macros.h; do
    download_file "$BASE/include/$f" "$DEST/include/$f"
done

echo "[SUCCESS] FreeRTOS ready in $DEST"
