# 03-FreeRTOS-EnvironmentMonitor: 智能家居环境监控器

这是验证你 STM32 仿真环境的**综合实战项目**，涵盖 FreeRTOS 多任务、队列通信、信号量、数字滤波等核心技术。

## 功能演示

4 个 FreeRTOS 任务协同工作：

| 任务 | 优先级 | 周期 | 功能 |
|------|--------|------|------|
| **vTaskSensor** | 1 | 300ms | 模拟采集温湿度数据，送入原始数据队列 |
| **vTaskFilter** | 2 | 事件驱动 | 从队列取数据，进行 5 点滑动平均滤波，再送入显示队列 |
| **vTaskDisplay** | 1 | 1s | 从显示队列取数据，通过 Semihosting 打印到控制台 |
| **vTaskAlarm** | 3 | 事件驱动 | 监测温度是否超过 30.0°C，超限时打印报警 |

**预期输出：**
```
========================================
  Smart Home Environment Monitor
  FreeRTOS + QEMU Simulation
========================================

[1] Temp: 20.3 C | Humidity: 58.2 %
[2] Temp: 21.5 C | Humidity: 61.4 %
  >>> [ALARM #1] Temperature exceeded 30.0 C! <<<
[3] Temp: 25.2 C | Humidity: 55.7 %
[4] Temp: 29.8 C | Humidity: 62.1 %
  >>> [ALARM #2] Temperature exceeded 30.0 C! <<<
```

## 快速开始

```bash
cd /mnt/d/STM32开发/projects/03-FreeRTOS-EnvironmentMonitor

# 下载 FreeRTOS 源码（只需一次）
bash download_freertos.sh

# 编译
make

# 运行仿真
bash run_qemu.sh
```

> 按 `Ctrl+A` 然后按 `X` 退出 QEMU。

## 项目结构

| 文件 | 说明 |
|------|------|
| `main.c` | 4 个任务实现 + 模拟传感器 + 滑动平均滤波器 |
| `startup.c` | 启动代码（含 FreeRTOS 所需的 SVC/PendSV/SysTick 弱定义） |
| `FreeRTOSConfig.h` | RTOS 配置：8MHz 时钟、1kHz Tick、8KB 堆 |
| `linker_script.ld` | QEMU Cortex-M3 参考板链接脚本 |
| `Makefile` | 自动编译 FreeRTOS 内核 + 应用代码 |
| `download_freertos.sh` | 一键下载 FreeRTOS V10.4.6 |
| `run_qemu.sh` | 一键编译 + 运行 QEMU 仿真 |

## 技术亮点

### 1. 固定小数点运算
温度/湿度全部用整数表示（`value = 真实值 * 10`），避免浮点运算开销，适合资源受限的嵌入式设备。

### 2. 滑动平均滤波
```c
SensorData_t filter_process(Filter_t *f, SensorData_t raw)
```
窗口大小 5，有效抑制传感器噪声。后续接真实传感器时，只需把 `simulate_xxx()` 替换为实际驱动读取函数。

### 3. 优先级设计
- Filter(2) > Sensor(1)：确保数据及时处理，不堆积
- Alarm(3) 最高：紧急事件优先响应
- Display(1) 最低：人机界面不阻塞核心业务

### 4. 队列解耦
Sensor → RawQueue → Filter → FilteredQueue → Display，任务间零共享状态，安全且易于扩展。

## 扩展思路

1. **接入真实传感器**：替换 `simulate_temperature()` 为 DHT11/DS18B20 驱动
2. **增加 OLED 显示**：将 `sh_write0()` 替换为 SSD1306 驱动
3. **加入 WiFi 模块**：新增任务通过 ESP8266 上传数据到云平台
4. **低功耗模式**：空闲任务中进入 Sleep Mode，用中断唤醒采样

## 验证清单

- [ ] `make` 编译成功，无警告
- [ ] `bash run_qemu.sh` 正常运行，看到温湿度输出
- [ ] 温度超过 30°C 时，出现 `[ALARM]` 提示
- [ ] 观察 1 分钟，无死机或异常输出

全部通过 = 你的仿真环境**完全可用**！🎉
