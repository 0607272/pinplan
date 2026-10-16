# PinPlan

PinPlan 是用 MoonBit 编写的 Raspberry Pi Pico 接线检查、最少改线与无解诊断工具。输入外设需求和既有接线，可以保留指定硬锁、寻找改动设备信号端点最少的可行方案、定位无法共存的设备集合，并导出含实体排针号的接线清单。

它解决的是“外设都能买到，但引脚和共享资源不够用”的问题。PinPlan 是离线规划器，不是驱动库，也不替代电气设计：它不验证电压、电流、信号完整性、面包板接线或任意频率的实物输出。首版只建模原版 Raspberry Pi Pico 的 GPIO0–22、GPIO26–28。

## 快速运行

需要 MoonBit 0.10.14+、Node.js 20+。

```powershell
moon check --deny-warn
moon test --deny-warn
moon run examples
```

示例输出是 JSON，状态为 `solved`、`invalid`、`unsatisfiable` 或 `limit`。`limit` 表示达到候选尝试上限，工具没有宣称无解。

## 工程范围与同类关系

本仓库没有引入 MoonPlan 包或其源码。`moon.mod` 无第三方模块依赖，根包只导入 MoonBit core 的 debug/json；资源建模、候选生成、检查、搜索和优化都在本仓库实现。依赖检查不等同于全网原创性证明。来源与对照记录见 [`docs/SOURCES.md`](docs/SOURCES.md)。

[MoonPlan](https://github.com/cn-xjr/MoonPlan) 已提供通用有限域求解、冲突集及排班修复等能力。PinPlan 的工程贡献体现在以下可独立运行的硬件工作流，不能把通用回溯或“也能解释冲突”本身当作创新点：

| 工程能力 | 本仓库实现 | 可检查的结果 |
| --- | --- | --- |
| RP2040 资源语义 | `board.mbt`、`validate.mbt`、`candidates.mbt` | 功能映射、SPI CS 独占、显式共享总线、PWM 引脚别名与 slice 频率 |
| 既有接线优化 | `repair.mbt` | 旧接线软偏好与新需求硬锁分离；分支定界求最少信号改线，输出逐项差异与最优性标志 |
| 可复现无解诊断 | `diagnose.mbt` | 共用预算的设备删除检验；得到可单独复现的无解子集，完整检验后才标记不可再缩减 |
| 可接线结果 | `wiring.mbt` | 独立检查最终方案，投影到 Pico 实体排针，保留总线归属和 PWM slice/channel |
| 使用入口 | `json_api.mbt`、CLI、网页、测试和 CI | 同一 MoonBit 核心支撑四种模式、机器可读报告与可运行案例 |

首版继续聚焦原版 Pico 和四类外设。工程范围按工作流和可复现结果说明，不靠增加映射表、重复实现通用求解器功能或堆行数说明价值。五个案例的背景、命令、预期与验证方式见 [`docs/CASE_STUDIES.md`](docs/CASE_STUDIES.md)。

## CLI 与 JSON

```powershell
npm run build
node bin/pinplan.mjs fixtures/mixed.json
Get-Content fixtures/repair.json | node bin/pinplan.mjs -
node bin/pinplan.mjs fixtures/rewire-pwm.json
node bin/pinplan.mjs fixtures/rewire-frequency.json
node bin/pinplan.mjs fixtures/diagnose-uart.json
npm run cases
npm test
```

输入顶层字段为 `board`（目前只能是 `pico`）、`mode`、`devices`、`max_nodes`，以及仅在 `repair` 中必填的 `baseline` 数组。设备字段为 `id`、`kind`、可选 `pins`、`instance`、`bus`、`frequency_hz`。未知字段会被拒绝；输入限 65536 个 UTF-16 单元、32 层嵌套、16 个目标设备和 16 个基线设备。

| 模式 | 输入语义 | 结果 |
| --- | --- | --- |
| `plan`（默认） | `devices.pins` 为部分或全部硬锁 | 确定性可行方案，不优化 |
| `check` | 每个信号必须指定引脚 | 检查映射与完整资源兼容性 |
| `repair` | `devices.pins` 仍是硬锁；`baseline` 为既有接线软偏好 | `repair.changed_pins`、逐信号 `changes` 与 `optimal` |
| `diagnose` | 对 `devices` 的硬约束求解并缩减 | `diagnosis.core_devices` 与 `irreducible` |

`baseline` 中每个设备必须有完整、单独合法的映射，ID/类型匹配目标；设备之间可以冲突，否则无法修复冲突接线。目标未出现在基线中视为新增设备，改线成本为 0。要允许移动旧线，把旧引脚写进 `baseline`，不要重复写成目标硬锁。

示例：锁住电机 GPIO0，移动与其 PWM 资源别名冲突的 GPIO16 指示灯：

```json
{
  "mode": "repair",
  "devices": [
    {"id": "motor", "kind": "pwm", "pins": {"OUT": 0}},
    {"id": "indicator", "kind": "pwm"}
  ],
  "baseline": [
    {"id": "motor", "kind": "pwm", "pins": {"OUT": 0}},
    {"id": "indicator", "kind": "pwm", "pins": {"OUT": 16}}
  ]
}
```

结果只移动 `indicator.OUT: GPIO16 → GPIO1`，`changed_pins=1`、`optimal=true`，接线清单对应实体排针 2。完整 JSON 形状和错误码见 `fixtures/`、`json_api.mbt`。

退出码：0 表示 solved，2 表示输入或配置 invalid，3 表示已穷举证明 unsatisfiable，4 表示搜索预算 limit。

`max_nodes` 默认为 50000，范围为 0..200000，计量单位是候选尝试次数。它不是运行时间或候选生成内存上限。诊断的初次求解和全部删除检验共用这一个预算。

- 修复优化：有可行方案时即为 `solved`；若预算耗尽，`repair.optimal=false` 且有 `REPAIR_LIMIT`。退出码 0 只证明可行，不证明最优。未找到可行方案且超限为 `limit`。
- 改线数量按“设备 ID + 信号”的 GPIO 变化计数，不是线材数、成本金额或被移动设备数；共享总线两个设备各改 SDA/SCL 会计作 4 个端点。实例、频率变化不计费，也不会自动调整频率。
- 诊断：`irreducible=true` 表示移除集合中任意一个设备都可解，不保证全局设备数量最少，也不是引脚锁级别的最小冲突集。缩减超限时仍可保留已证明无解的集合，但 `irreducible=false`。
- 成功结果的 `wiring` 是信号端点清单；`header_pin` 是实体排针号，`gpio` 是 GPIO 编号，两者不可混用。无效/无解/未确定的结果不生成接线清单。

## 网页演示

```powershell
npm run build
npm run demo
```

然后打开 <http://127.0.0.1:4173/>。网页调用和 CLI 相同的编译后 MoonBit JS 模块；可运行最少改线、无解诊断、共享总线及预算示例，显示信号差异和实体排针，并下载完整结果 JSON。输入在本机计算，无需联网服务。

## 资源规则

- GPIO0–22、GPIO26–28 可用；GPIO23–25 为 Pico 板内使用，GPIO29 不作为自由引脚。
- UART、SPI、I²C 依据 RP2040 的备用功能映射选择实例；SPI 的 CS 仍独占。
- 明确声明相同 `bus` 的 I²C/SPI 设备只有在类型、实例、频率和共享信号引脚一致时才能共用。
- PWM 的两个通道共享 slice 频率；相同 slice/channel 是同一物理资源，即使 GPIO 不同也会冲突。

## 结构与验证

`types.mbt` 和 `board.mbt` 定义资源模型，`validate.mbt` 检查结构与资源冲突，`candidates.mbt` 生成合法候选，`solver.mbt` 进行可行性搜索。`repair.mbt` 以稳定成本排序、后缀成本下界和分支定界完成优化；`diagnose.mbt` 做共享预算的删除检验；`wiring.mbt` 验证并投影信号到实体排针；`json_api.mbt` 提供严格 JSON 边界。

MoonBit 测试包含小规模 PWM 独立穷举对照、优化早期非最优结果的案例、硬锁不可放松、超限可行结果、三设备整体无解、删除验证、共享总线计数与排针边界。Node 测试覆盖编译后的 JSON API、CLI 退出码和文件/标准输入。`npm run cases` 对案例结果再次执行独立可调用的检查入口，并逐一复核无解集合的删除见证。

```powershell
moon fmt
moon info
moon check --deny-warn
moon build --target js --release --deny-warn
moon test --deny-warn
npm run build
npm test
npm run cases
```

## 来源与许可证

实现为独立 MoonBit 代码，映射来源、算法边界和第三方说明见 [`docs/SOURCES.md`](docs/SOURCES.md)。项目使用 MIT；MoonBit core 依赖使用 Apache-2.0。申报书为赛事材料，留在本地且不会进入公开仓库（已在 `.gitignore` 中排除）。

## Mooncakes 发布

如赛事验收要求发布到 Mooncakes，先在本机完成登录，再执行 dry-run 和正式发布：

```powershell
moon login
moon publish --dry-run
moon publish
```

本项目模块名为 `0607272/pinplan`。登录凭据保存在本机 MoonBit 配置目录，不应写入仓库；申报书和联系方式也不属于发布包。
