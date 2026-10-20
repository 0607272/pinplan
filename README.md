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
| 可接线结果 | `wiring.mbt`、`export.mbt` | 独立检查最终方案，投影到 Pico 实体排针，保留总线归属和 PWM slice/channel |
| 使用入口 | `json_api.mbt`、CLI、网页、测试和 CI | 同一 MoonBit 核心支撑四种模式、机器可读报告与可运行案例 |

首版继续聚焦原版 Pico 和四类外设。工程范围按工作流和可复现结果说明，不靠增加映射表、重复实现通用求解器功能或堆行数说明价值。七个案例的背景、命令、预期与验证方式见 [`docs/CASE_STUDIES.md`](docs/CASE_STUDIES.md)。

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

输入顶层字段为 `board`（目前只能是 `pico`）、`mode`、`devices`、`max_nodes`，可选 `reserved_pins`，以及仅在 `repair` 中必填的 `baseline` 数组。设备字段为 `id`、`kind`、可选 `pins`、`instance`、`bus`、`frequency_hz`、`i2c_address`。未知字段会被拒绝；输入限 65536 个 UTF-16 单元、32 层嵌套、16 个目标设备和 16 个基线设备。

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

## 预留 GPIO、地址与文件导出（0.2.0）

`reserved_pins` 默认 `[]`，必须是唯一的可用 GPIO 整数，最多 26 个。它预留的是 GPIO 接点，不推断外部电路占用的 PWM/串口资源。四种模式共用这一条件：规划中的硬锁与预留脚相撞为 `unsatisfiable`，检查这样的旧线为 `invalid`，修复允许从旧 `baseline` 的预留脚移走。诊断缩减设备时仍保留同样的预留条件，结果 JSON 回显列表。调用 checker 复核结果时也须传回 `reserved_pins`。

`i2c_address` 是可选的十进制整数，仅 I²C 接受正常 7 位地址 8..119（0x08..0x77），不接受 8 位读写地址或保留地址。同名共享 I²C 总线上的两个相同已知地址产生 `I2C_ADDRESS_CONFLICT`；不同独立控制器可重复地址。未填写或 `null` 表示未知，结果和网页明确保留此状态，不能宣称地址已完整检查。工具不会通过换 GPIO 自动改变器件地址；应根据器件手册更改硬件地址声明，或使用独立总线。

```powershell
node bin/pinplan.mjs fixtures/reserved-repair.json
node bin/pinplan.mjs fixtures/i2c-address-conflict.json
node bin/pinplan.mjs --format csv fixtures/shared-wiring.json > wiring.csv
node bin/pinplan.mjs --format pico-header fixtures/shared-wiring.json > pinplan_config.h
```

CLI 的 `--format` 默认为 `json`。`csv` / `pico-header` 只在通过独立复核的 `solved` 状态输出文件，其他状态 stdout 为空、stderr 输出 JSON，退出码与原模式一致。CLI 参数用法错误写 stderr。结果 JSON 的 `exports.csv` 和 `exports.pico_header` 也是同一 MoonBit 函数生成的文本；无效结果无 `exports`。CSV 使用 CRLF、双引号转义，非空设备名/总线名单元格统一加字面单引号前缀以避免表格公式执行，该前缀是导出内容的一部分；列 `device_index` 对应结果数组顺序，未知地址列为空。C 常量使用 `PINPLAN_DEVICE_0_*` 等序号，与 JSON assignments 一一对应，不把用户名称写进 C 代码。头文件含 GPIO、实体排针、实例、频率元数据、PWM slice/channel、已知 I²C 地址和预留脚；`I2C_ADDRESS_KNOWN=0` 表示未知。

这些文件只描述已验证的信号映射，不初始化 Pico SDK、生成驱动或验证电气连接。可行但未证明最优的修复也可导出，应同时保留 JSON 检查 `repair.optimal`；CSV 的 `repair_optimal` 列保留 true/false，非修复模式为空；头文件用 `PINPLAN_REPAIR_OPTIMAL_KNOWN` / `PINPLAN_REPAIR_OPTIMAL` 保留对应状态，未证最优时附 `REPAIR_LIMIT` 注释。空设备方案有效，可导出只有列名的 CSV 和计数为 0 的头文件。旧版 Windows PowerShell 的 `>` 可能写成 UTF-16；供 C 工具链使用时请使用 PowerShell 7，或网页直接下载 UTF-8 文件。

MoonBit API 的 `plan/check/repair/diagnose/candidates/check_assignments/wiring_rows/report_json` 新增默认空数组的 `reserved_pins~` 参数，另有 `export_wiring_csv` / `export_pico_header`，验证失败返回 `None`。`device(...)` 原调用保持兼容；直接构造公开 `Device` / `Assignment` 记录时须新增 `i2c_address: None`。JSON schema_version 保持 1，本次仅增加可选输入和输出字段；详细变更见 [CHANGELOG.md](CHANGELOG.md)。

## 网页演示

```powershell
npm run build
npm run demo
```

然后打开 <http://127.0.0.1:4173/>。网页调用和 CLI 相同的编译后 MoonBit JS 模块；可运行最少改线、无解诊断、共享总线及预算示例，显示信号差异和实体排针，并下载完整结果 JSON、CSV 接线表和 Pico 配置头文件。预置案例包括 GPIO 预留迁移和 I²C 地址碰撞。输入在本机计算，无需联网服务。

## 资源规则

- GPIO0–22、GPIO26–28 可用；GPIO23–25 为 Pico 板内使用，GPIO29 不作为自由引脚。
- UART、SPI、I²C 依据 RP2040 的备用功能映射选择实例；SPI 的 CS 仍独占。
- 明确声明相同 `bus` 的 I²C/SPI 设备只有在类型、实例、频率和共享信号引脚一致时才能共用。
- PWM 的两个通道共享 slice 频率；相同 slice/channel 是同一物理资源，即使 GPIO 不同也会冲突。

## 结构与验证

`types.mbt` 和 `board.mbt` 定义资源模型，`validate.mbt` 检查结构与资源冲突，`candidates.mbt` 生成合法候选，`solver.mbt` 进行可行性搜索。`repair.mbt` 以稳定成本排序、后缀成本下界和分支定界完成优化；`diagnose.mbt` 做共享预算的删除检验；`wiring.mbt` 验证并投影信号到实体排针；`export.mbt` 在完整复核后生成 CSV/C 常量；`json_api.mbt` 提供严格 JSON 边界。

Linux CI 还以 C11 编译实际生成的头文件并执行静态断言（`node scripts/check-header.mjs`，需 C 编译器）。MoonBit 测试包含小规模 PWM 独立穷举对照、优化早期非最优结果的案例、硬锁不可放松、超限可行结果、三设备整体无解、删除验证、共享总线计数与排针边界。Node 测试覆盖编译后的 JSON API、CLI 退出码和文件/标准输入。`npm run cases` 对案例结果再次执行独立可调用的检查入口，并逐一复核无解集合的删除见证。

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
