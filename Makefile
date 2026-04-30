PREFIX = arm-none-eabi-
CC      = $(PREFIX)gcc
OBJCOPY = $(PREFIX)objcopy
SIZE    = $(PREFIX)size

TARGET  = env_monitor
TARGET_BARE = env_monitor_bare

FREERTOS = ./FreeRTOS

# Check if FreeRTOS source is available
HAS_FREERTOS := $(shell test -f $(FREERTOS)/tasks.c && echo 1 || echo 0)

ifeq ($(HAS_FREERTOS),1)
SRCS = \
    startup.c \
    main.c \
    $(FREERTOS)/tasks.c \
    $(FREERTOS)/list.c \
    $(FREERTOS)/queue.c \
    $(FREERTOS)/timers.c \
    $(FREERTOS)/event_groups.c \
    $(FREERTOS)/portable/MemMang/heap_4.c \
    $(FREERTOS)/portable/GCC/ARM_CM3/port.c

INCLUDES = \
    -I. \
    -I$(FREERTOS)/include \
    -I$(FREERTOS)/portable/GCC/ARM_CM3
else
SRCS = startup.c main_bare.c
INCLUDES =
endif

OBJS = $(SRCS:.c=.o)

CFLAGS  = -mcpu=cortex-m3 -mthumb -O0 -g -Wall
CFLAGS += -ffunction-sections -fdata-sections
CFLAGS += $(INCLUDES)
CFLAGS += -DSTM32F103xB

LDFLAGS = -mcpu=cortex-m3 -mthumb -T linker_script.ld
LDFLAGS += -nostartfiles -Wl,--gc-sections

.PHONY: all clean qemu qemu_bare info

all:
ifeq ($(HAS_FREERTOS),1)
	@echo "[INFO] FreeRTOS detected. Building RTOS version..."
	$(MAKE) $(TARGET).bin
else
	@echo "[INFO] FreeRTOS not found. Building bare-metal fallback version..."
	@echo "       Run 'bash download_freertos.sh' to get FreeRTOS source."
	$(MAKE) $(TARGET_BARE).bin
endif

info:
ifeq ($(HAS_FREERTOS),1)
	@echo "FreeRTOS source: AVAILABLE"
else
	@echo "FreeRTOS source: NOT FOUND (run 'bash download_freertos.sh')"
endif

$(TARGET).elf: startup.o main.o $(FREERTOS)/tasks.o $(FREERTOS)/list.o $(FREERTOS)/queue.o $(FREERTOS)/timers.o $(FREERTOS)/event_groups.o $(FREERTOS)/portable/MemMang/heap_4.o $(FREERTOS)/portable/GCC/ARM_CM3/port.o
	$(CC) $(LDFLAGS) -o $@ $^

$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@
	@echo "Build complete:"
	$(SIZE) $(TARGET).elf

$(TARGET_BARE).elf: startup.o main_bare.o
	$(CC) $(LDFLAGS) -o $@ $^

$(TARGET_BARE).bin: $(TARGET_BARE).elf
	$(OBJCOPY) -O binary $< $@
	@echo "Build complete (bare-metal):"
	$(SIZE) $(TARGET_BARE).elf

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

clean:
	rm -f $(OBJS) $(TARGET).elf $(TARGET).bin $(TARGET_BARE).elf $(TARGET_BARE).bin

qemu: all
ifeq ($(HAS_FREERTOS),1)
	qemu-system-arm -M mps2-an385 -cpu cortex-m3 \
	    -device loader,file=$(TARGET).bin,addr=0x00000000 \
	    -semihosting -nographic
else
	qemu-system-arm -M mps2-an385 -cpu cortex-m3 \
	    -device loader,file=$(TARGET_BARE).bin,addr=0x00000000 \
	    -semihosting -nographic
endif
