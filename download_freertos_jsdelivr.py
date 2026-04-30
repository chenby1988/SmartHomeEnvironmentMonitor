import os
import urllib.request
import ssl

BASE = "https://cdn.jsdelivr.net/gh/FreeRTOS/FreeRTOS-Kernel@V10.4.6"
DEST = "/mnt/d/STM32开发/projects/03-FreeRTOS-EnvironmentMonitor/FreeRTOS"

files = {
    "": ["tasks.c", "list.c", "queue.c", "timers.c", "event_groups.c"],
    "portable/GCC/ARM_CM3": ["port.c", "portmacro.h"],
    "portable/MemMang": ["heap_4.c"],
    "include": [
        "FreeRTOS.h", "task.h", "list.h", "queue.h", "timers.h",
        "event_groups.h", "portable.h", "deprecated_definitions.h",
        "mpu_wrappers.h", "projdefs.h", "stack_macros.h"
    ]
}

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

os.makedirs(DEST, exist_ok=True)
for subdir, filenames in files.items():
    d = os.path.join(DEST, subdir)
    os.makedirs(d, exist_ok=True)
    for f in filenames:
        url = f"{BASE}/{subdir}/{f}" if subdir else f"{BASE}/{f}"
        out = os.path.join(d, f)
        if os.path.exists(out) and os.path.getsize(out) > 100:
            print(f"[SKIP] {f}")
            continue
        print(f"[DOWNLOAD] {f} ...", end=" ", flush=True)
        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
            with urllib.request.urlopen(req, timeout=30, context=ctx) as resp:
                data = resp.read()
                with open(out, 'wb') as fh:
                    fh.write(data)
            print(f"OK ({os.path.getsize(out)} bytes)")
        except Exception as e:
            print(f"FAILED: {e}")

print("\nDone. Checking files...")
total = 0
for root, dirs, files_list in os.walk(DEST):
    for f in files_list:
        total += 1
        fp = os.path.join(root, f)
        sz = os.path.getsize(fp)
        if sz < 100:
            print(f"  WARNING: {fp} is only {sz} bytes (may be incomplete)")
print(f"Total files: {total}")
