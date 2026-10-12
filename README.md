# PinPlan

PinPlan 是一个用 MoonBit 编写的 Raspberry Pi Pico 外设引脚规划与冲突解释工具。它在接线前检查 UART、SPI、I²C 和 PWM 资源，保留用户锁定的引脚，并用确定性回溯搜索给出一份可行接线表。

它解决的是“外设都能买到，但引脚和共享资源不够用”的问题。PinPlan 是离线规划器，不是驱动库，也不替代电气设计：它不验证电压、电流、信号完整性、面包板接线或任意频率的实物输出。首版只建模原版 Raspberry Pi Pico 的 GPIO0–22、GPIO26–28。

## 快速运行

需要 MoonBit 0.10.14+、Node.js 20+。

```powershell
moon check --deny-warn
moon test --deny-warn
moon run examples
```

示例输出是 JSON，状态为 `solved`、`invalid`、`unsatisfiable` 或 `limit`。`limit` 表示达到候选尝试上限，工具没有宣称无解。

## CLI 与 JSON

```powershell
npm run build
node bin/pinplan.mjs fixtures/mixed.json
Get-Content fixtures/repair.json | node bin/pinplan.mjs -
npm test
```

输入顶层字段为 `board`（目前只能是 `pico`）、`mode`（`plan` 或 `check`）、`devices` 和 `max_nodes`。设备字段为 `id`、`kind`、可选 `pins`、`instance`、`bus`、`frequency_hz`。`plan` 支持部分锁定；`check` 要求每个信号都有引脚。完整的 JSON 形状和错误码见 `fixtures/` 及 `json_api.mbt`。

退出码：0 表示 solved，2 表示输入或配置 invalid，3 表示已穷举证明 unsatisfiable，4 表示搜索预算 limit。

## 网页演示

```powershell
npm run build
npm run demo
```

然后打开 <http://127.0.0.1:4173/>。网页调用和 CLI 相同的编译后 MoonBit JS 模块；下拉框包含混合外设、共享 I²C、PWM 冲突和搜索预算示例。

## 资源规则

- GPIO0–22、GPIO26–28 可用；GPIO23–25 为 Pico 板内使用，GPIO29 不作为自由引脚。
- UART、SPI、I²C 依据 RP2040 的备用功能映射选择实例；SPI 的 CS 仍独占。
- 明确声明相同 `bus` 的 I²C/SPI 设备只有在类型、实例、频率和共享信号引脚一致时才能共用。
- PWM 的两个通道共享 slice 频率；相同 slice/channel 是同一物理资源，即使 GPIO 不同也会冲突。

## 结构与验证

`types.mbt` 和 `board.mbt` 定义资源模型，`validate.mbt` 负责结构与冲突诊断，`candidates.mbt` 生成合法候选，`solver.mbt` 进行有预算的确定性搜索，`json_api.mbt` 提供严格 JSON 边界。MoonBit 测试覆盖映射、边界、共享总线、PWM 别名、无解和预算；Node 测试覆盖编译后的桥接 API、CLI 退出码和文件/标准输入。

```powershell
moon fmt
moon info
moon check --deny-warn
moon build --target js --release --deny-warn
moon test --deny-warn
npm run build
npm test
```

## 来源与许可证

实现为独立 MoonBit 代码，映射来源、算法边界和第三方说明见 [`docs/SOURCES.md`](docs/SOURCES.md)。项目使用 MIT；MoonBit core 依赖使用 Apache-2.0。申报书为赛事材料，留在本地且不会进入公开仓库（已在 `.gitignore` 中排除）。
