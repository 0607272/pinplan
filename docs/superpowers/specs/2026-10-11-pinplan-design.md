# PinPlan 首版设计

用户已选择 PinPlan 并要求继续比赛提交。本期实现 Pico 的离线资源规划，截止 2026-10-31。

## 输入输出

JSON 输入包含 board（仅 pico）、mode（plan/check）、devices 和 max_nodes。Device 使用 id、kind（uart/spi/i2c/pwm）、pins（按信号名锁定 GPIO）、bus（显式共享总线名称）、frequency_hz（PWM 频率，通信总线频率元数据）。plan 允许部分锁定；check 要求信号全部给定。
输出包含 status（solved/invalid/unsatisfiable/limit）、assignments、findings、nodes、board、mode。节点预算达到时报告 limit，不声称无解。只验证引脚和实例资源，不验证电气安全。

## 约束

Pico 可用 GPIO 为 0..22 和 26..28；禁止板内 GPIO23..25 与未引出 GPIO29。
UART0 的 TX/RX 基础映射为 (0,1)、(12,13)、(16,17)、(28,29)，UART1 为 (4,5)、(8,9)、(20,21)、(24,25)，分别筛掉未引出引脚；TX/RX 可使用同一实例的不同备选映射。
SPI0 RX 为 0/4/16/20，CS 为 1/5/17/21，SCK 为 2/6/18/22，TX 为 3/7/19/23；SPI1 为每一值加 8 后按 RP2040 GPIO0..29 映射筛选，具体表在 board.mbt 写明。
I2C0 SDA 为 GPIO mod 4 == 0，SCL 为 mod 4 == 1；I2C1 SDA 为 mod 4 == 2，SCL 为 mod 4 == 3；均筛选 Pico 可用 GPIO。PWM slice = (gpio / 2) mod 8，channel = gpio mod 2。
GPIO 默认独占。相同非空 bus、相同 kind（I2C/SPI）、相同实例和频率可共享总线信号，SPI CS 独占。共享总线名称不能跨外设类型或实例；UART 不支持共享。
PWM 同一 slice/channel 独占；同一 slice 的两个 channel 需要相同 frequency_hz。frequency_hz 只作为资源配置元数据，不保证芯片能精确产生任意频率。

## 实现与验证

MoonBit 核心库包含类型、Pico 映射、配置校验、冲突检查、确定性回溯、JSON API。Node CLI 仅处理文件、进程退出码与加载 MoonBit JS；网页通过同一导出函数调用核心。另有 moon run 示例。
测试覆盖手工核对映射、非法输入、锁定保留、共享总线、PWM 别名资源、无解/超限、小规模穷举交叉验证与 CLI 退出码。浏览器手动验证示例、修改输入和 SVG 板图。
源码采用 MIT。官方资料作为映射来源记录，不打包官方 PDF。报名材料保持本地且被 gitignore 排除。公开仓库、CI、Mooncakes 和报名仅报告取得的实际证据。
