#include <stdint.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "semphr.h"

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
/* Sensor data structure (fixed point: value = real * 10)    */
typedef struct {
    int16_t temperature;   /* e.g. 255 = 25.5 C */
    uint16_t humidity;     /* e.g. 600 = 60.0 % */
} SensorData_t;

/*-----------------------------------------------------------*/
/* Queues and semaphore handles                              */
static QueueHandle_t xRawQueue;
static QueueHandle_t xFilteredQueue;
static SemaphoreHandle_t xAlarmSemaphore;

/*-----------------------------------------------------------*/
/* Simple number printer (handles negative + fixed point)    */
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
    if (integer == 0) {
        buf[i++] = '0';
    } else {
        while (integer > 0) {
            buf[i++] = '0' + (integer % 10);
            integer /= 10;
        }
    }
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
/* Simulate temperature: cyclic wave 20.0 C ~ 35.0 C         */
static int16_t simulate_temperature(uint32_t tick)
{
    uint32_t phase = tick % 100;
    if (phase < 50) {
        return (int16_t)(200 + phase * 3);   /* 20.0 -> 35.0 */
    } else {
        return (int16_t)(350 - (phase - 50) * 3); /* 35.0 -> 20.0 */
    }
}

/* Simulate humidity: LCG pseudo-random 40.0% ~ 80.0%        */
static uint16_t simulate_humidity(uint32_t tick)
{
    static uint32_t state = 12345;
    state = state * 1103515245 + 12345;
    (void)tick;
    return (uint16_t)(400 + ((state >> 16) % 401)); /* 40.0 ~ 80.0 */
}

/*-----------------------------------------------------------*/
/* Sliding average filter (window size = 5)                  */
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
/* Task 1: Sensor acquisition (300ms period)                 */
static void vTaskSensor(void *pvParameters)
{
    (void)pvParameters;
    SensorData_t data;
    uint32_t tick = 0;

    for (;;) {
        data.temperature = simulate_temperature(tick);
        data.humidity    = simulate_humidity(tick);
        xQueueSend(xRawQueue, &data, portMAX_DELAY);
        tick++;
        vTaskDelay(pdMS_TO_TICKS(300));
    }
}

/*-----------------------------------------------------------*/
/* Task 2: Digital filter + threshold check                  */
static void vTaskFilter(void *pvParameters)
{
    (void)pvParameters;
    Filter_t filter;
    filter_init(&filter);
    SensorData_t raw, filtered;

    for (;;) {
        if (xQueueReceive(xRawQueue, &raw, portMAX_DELAY) == pdPASS) {
            filtered = filter_process(&filter, raw);
            xQueueSend(xFilteredQueue, &filtered, portMAX_DELAY);

            /* Trigger alarm if temperature > 30.0 C */
            if (filtered.temperature > 300) {
                xSemaphoreGive(xAlarmSemaphore);
            }
        }
    }
}

/*-----------------------------------------------------------*/
/* Task 3: Display (1 second period)                         */
static void vTaskDisplay(void *pvParameters)
{
    (void)pvParameters;
    SensorData_t data;
    uint32_t sampleCount = 0;

    for (;;) {
        if (xQueueReceive(xFilteredQueue, &data, pdMS_TO_TICKS(1000)) == pdPASS) {
            sampleCount++;
            sh_write0("[");
            print_fixed((int16_t)sampleCount, 0);
            sh_write0("] Temp: ");
            print_fixed(data.temperature, 1);
            sh_write0(" C | Humidity: ");
            print_fixed((int16_t)data.humidity, 1);
            sh_write0(" %\r\n");
        }
    }
}

/*-----------------------------------------------------------*/
/* Task 4: Alarm monitor                                     */
static void vTaskAlarm(void *pvParameters)
{
    (void)pvParameters;
    uint32_t alarmCount = 0;

    for (;;) {
        if (xSemaphoreTake(xAlarmSemaphore, portMAX_DELAY) == pdTRUE) {
            alarmCount++;
            sh_write0("  >>> [ALARM #");
            print_fixed((int16_t)alarmCount, 0);
            sh_write0("] Temperature exceeded 30.0 C! <<<\r\n");
        }
    }
}

/*-----------------------------------------------------------*/
int main(void)
{
    sh_write0("\r\n========================================\r\n");
    sh_write0("  Smart Home Environment Monitor\r\n");
    sh_write0("  FreeRTOS + QEMU Simulation\r\n");
    sh_write0("========================================\r\n\r\n");

    /* Create queues */
    xRawQueue      = xQueueCreate(10, sizeof(SensorData_t));
    xFilteredQueue = xQueueCreate(10, sizeof(SensorData_t));
    configASSERT(xRawQueue);
    configASSERT(xFilteredQueue);

    /* Create alarm semaphore */
    xAlarmSemaphore = xSemaphoreCreateBinary();
    configASSERT(xAlarmSemaphore);

    /* Create tasks: Sensor(1), Filter(2), Display(1), Alarm(3) */
    xTaskCreate(vTaskSensor,  "Sensor",  256, NULL, 1, NULL);
    xTaskCreate(vTaskFilter,  "Filter",  256, NULL, 2, NULL);
    xTaskCreate(vTaskDisplay, "Display", 256, NULL, 1, NULL);
    xTaskCreate(vTaskAlarm,   "Alarm",   256, NULL, 3, NULL);

    vTaskStartScheduler();

    /* Should never reach here */
    for (;;);
}
