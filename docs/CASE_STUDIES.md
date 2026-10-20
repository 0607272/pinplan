# Reproducible PinPlan workflows

这些案例用于说明工具的实际输入与结果，均为项目自建的逻辑配置，未声称经过实物测试。运行环境：MoonBit 0.10.14+、Node.js 20+，无需硬件。

```powershell
npm run build
npm run cases
```

`cases` 会断言以下七个案例的结果，调用 `check` 重新验证修复后的完整方案，并对无解集合逐一删除设备再求解。失败会返回非零退出码；CI 也运行此命令。下述节点数是当前确定性搜索顺序下的候选尝试数，不是耗时承诺。

## 1. 固定电机，修复 PWM 别名冲突

使用者已有电机 GPIO0 和指示灯 GPIO16，频率均为 1000Hz。两者占用同一 PWM0/A，GPIO 不同仍会冲突。电机线不允许移动，指示灯可以移动。

```powershell
node bin/pinplan.mjs fixtures/rewire-pwm.json
```

`devices` 锁住电机 GPIO0；`baseline` 记录完整旧接线。输出 `solved`，只移动 `indicator.OUT: GPIO16 → GPIO1`，`changed_pins=1`、`optimal=true`，尝试 4 个候选。电机仍为 GPIO0，指示灯改用 PWM0/B，实体排针为 2。

独立理由：原配置有 PWM_CHANNEL 冲突，因此 0 次变化不可行；输出经 checker 验证可行且仅变 1 个信号，所以确为最少。若把指示灯 GPIO16 也写成目标硬锁，工具返回 `unsatisfiable`，不会擅自放松用户锁。

## 2. 调整前面的设备，避免两根不必要的改线

创客接入一个 1000Hz 指示灯和两个 50Hz 舵机。旧接线为指示灯 GPIO0、舵机 A GPIO1、舵机 B GPIO0。除引脚重叠外，同 slice 的 A/B 通道频率也不兼容。

```powershell
node bin/pinplan.mjs fixtures/rewire-frequency.json
```

保留先遇到的指示灯 GPIO0，会迫使两个舵机都改线；首个可行修复需要改动 2 个端点。优化器继续分支定界，最终仅移动指示灯 `GPIO0 → GPIO2`，两个舵机保留 GPIO1/0。结果 `changed_pins=1`、`optimal=true`，尝试 63 个候选。

最终两个舵机使用 PWM0/B、PWM0/A，均为 50Hz；指示灯使用独立的 PWM1/A，1000Hz。此案例检查的是全局改线数量优化，不能用“每个设备选一个最接近旧引脚的候选”代替。

## 3. 三个 UART 的整体容量冲突

课程项目维护者希望同时接控制台、GPS 和调制解调器三个独立硬件 UART，另有一个 GPIO26/27 I²C 传感器。

```powershell
node bin/pinplan.mjs fixtures/diagnose-uart.json
```

输出 `unsatisfiable`，CLI 退出码 3。`diagnosis.core_devices=["console","gps","modem"]`，`irreducible=true`，共用预算内尝试 10041 个候选。I²C 传感器被移出无解集合。

独立理由：RP2040 只有两个硬件 UART，三个独立设备无法同时占用；任意删去一个 UART，另外两个都可分配。案例运行器会确认核心本身无解，并复核全部三个删除后的可行见证。该结论不建议自动合并独立 UART，也不声称这是任意问题的最小设备数冲突集。

## 4. 共享 I²C 的实体排针清单

教师提交温湿度模块的同名共享总线 GPIO4/5 和控制台 UART GPIO16/17，想把逻辑编号转换成实际接线清单。

```powershell
node bin/pinplan.mjs fixtures/shared-wiring.json
```

结果为 `solved`，共 6 个设备信号端点。两个 I²C 设备共用实体排针 6/7，UART 对应实体排针 21/22。每行保留设备、信号、GPIO、实体排针、资源与总线名，重复总线端点不是独占冲突。网页使用相同 MoonBit 输出展示清单和排针位置。

这里只验证映射与资源，不能据此推断 I²C 地址不同、电压兼容、已接地、上拉合适或硬件输出频率已正确配置。

## 5. 预算不足时保持结论诚实

将诊断案例的 `max_nodes` 改为 0，结果为 `limit`、空无解集合、`irreducible=false`。不能将“还没找到解”写为“无解”。

两设备 GPIO0/16 别名冲突在预算 2 下可证明原集合无解，但剩余预算不足以完成删除检验，因此保留 `unsatisfiable` 且 `irreducible=false`。三设备改线优化在预算 8 下已有可行修复，返回 `solved`、`optimal=false` 和 `REPAIR_LIMIT`，退出码 0 只证明可行。

这三个分支都有自动化测试。`nodes` 始终计量候选尝试；预生成候选、解析和验证不计入该数值。


## 6. 给其他电路预留 GPIO，移动旧接线

`node bin/pinplan.mjs fixtures/reserved-repair.json` 为 GPIO0、1 声明预留，旧指示灯在 GPIO0，目标无硬锁。输出只移动 `indicator.OUT: GPIO0 → GPIO16`，最优成本 1；预留的是 GPIO 接点，所以 GPIO16 的 PWM 别名本身仍允许使用。运行器使用相同预留列表再次检查结果，CSV 与 C 头文件保留预留元数据。

## 7. 同总线同地址不能通过换线解决

`node bin/pinplan.mjs fixtures/i2c-address-conflict.json` 的两个共享 I²C 传感器均声明 64（0x40）。输出无解，核心为这两个设备，移除任何一个即有解。把其中一个的硬件地址声明改为 65 后，共用 GPIO4/5 的配置可行。此操作仅验证更正后的声明，不声称软件可以改变硬件地址。若器件地址固定，应另选独立控制器或另行设计复用硬件。
