#include <stdint.h>

/* Semihosting syscall numbers */
#define SYS_WRITEC  0x03
#define SYS_WRITE0  0x04

static void sh_write0(const char *str) {
    __asm__ volatile (
        "mov r0, %0\n"
        "mov r1, %1\n"
        "bkpt 0xAB\n"
        :
        : "r"(SYS_WRITE0), "r"(str)
        : "r0", "r1", "memory"
    );
}

static void sh_writec(char c) {
    __asm__ volatile (
        "mov r0, %0\n"
        "mov r1, %1\n"
        "bkpt 0xAB\n"
        :
        : "r"(SYS_WRITEC), "r"(&c)
        : "r0", "r1", "memory"
    );
}

/*-----------------------------------------------------------*/
typedef struct {
    int16_t temperature;
    uint16_t humidity;
} SensorData_t;

/*-----------------------------------------------------------*/
static void print_fixed(int16_t value, uint8_t decimals)
{
    if (value < 0) {
        sh_writec('-');
        value = -value;
    }
    int16_t divisor = 1;
    for (uint8_t i = 0; i < decimals; i++) divisor *= 10;
    int16_t integer = value / divisor;
    int16_t fraction = value % divisor;
    char buf[8];
    int i = 0;
    if (integer == 0) buf[i++] = '0';
    else while (integer > 0) { buf[i++] = '0' + (integer % 10); integer /= 10; }
    while (i > 0) sh_writec(buf[--i]);
    if (decimals > 0) {
        sh_writec('.');
        for (int d = divisor / 10; d > 0; d /= 10) {
            sh_writec('0' + (fraction / d));
            fraction %= d;
        }
    }
}

/*-----------------------------------------------------------*/
static int16_t simulate_temperature(uint32_t tick)
{
    uint32_t phase = tick % 100;
    if (phase < 50) return (int16_t)(200 + phase * 3);
    else return (int16_t)(350 - (phase - 50) * 3);
}

static uint16_t simulate_humidity(uint32_t tick)
{
    static uint32_t state = 12345;
    state = state * 1103515245 + 12345;
    (void)tick;
    return (uint16_t)(400 + ((state >> 16) % 401));
}

/*-----------------------------------------------------------*/
typedef struct {
    int16_t  temp_buf[5];
    uint16_t humi_buf[5];
    uint8_t  index;
    uint8_t  count;
} Filter_t;

static void filter_init(Filter_t *f)
{
    f->index = 0;
    f->count = 0;
}

static SensorData_t filter_process(Filter_t *f, SensorData_t raw)
{
    f->temp_buf[f->index] = raw.temperature;
    f->humi_buf[f->index] = raw.humidity;
    f->index = (f->index + 1) % 5;
    if (f->count < 5) f->count++;
    int32_t sum_temp = 0;
    uint32_t sum_humi = 0;
    for (uint8_t i = 0; i < f->count; i++) {
        sum_temp += f->temp_buf[i];
        sum_humi += f->humi_buf[i];
    }
    SensorData_t out;
    out.temperature = (int16_t)(sum_temp / f->count);
    out.humidity    = (uint16_t)(sum_humi / f->count);
    return out;
}

/*-----------------------------------------------------------*/
static void delay_ms(uint32_t ms)
{
    for (uint32_t i = 0; i < ms * 8000; i++) {
        __asm__ volatile("nop");
    }
}

/*-----------------------------------------------------------*/
int main(void)
{
    SensorData_t raw, filtered;
    Filter_t filter;
    filter_init(&filter);
    uint32_t tick = 0;
    uint32_t sampleCount = 0;
    uint32_t alarmCount = 0;

    sh_write0("\r\n========================================\r\n");
    sh_write0("  Smart Home Environment Monitor\r\n");
    sh_write0("  Bare-metal Version (QEMU)\r\n");
    sh_write0("========================================\r\n\r\n");

    while (1) {
        /* Sensor */
        raw.temperature = simulate_temperature(tick);
        raw.humidity    = simulate_humidity(tick);
        tick++;

        /* Filter */
        filtered = filter_process(&filter, raw);

        /* Alarm */
        if (filtered.temperature > 300) {
            alarmCount++;
            sh_write0("  >>> [ALARM #");
            print_fixed((int16_t)alarmCount, 0);
            sh_write0("] Temperature exceeded 30.0 C! <<<\r\n");
        }

        /* Display every ~1s (3 cycles) */
        if (tick % 3 == 0) {
            sampleCount++;
            sh_write0("[");
            print_fixed((int16_t)sampleCount, 0);
            sh_write0("] Temp: ");
            print_fixed(filtered.temperature, 1);
            sh_write0(" C | Humidity: ");
            print_fixed((int16_t)filtered.humidity, 1);
            sh_write0(" %\r\n");
        }

        delay_ms(300);
    }
}
