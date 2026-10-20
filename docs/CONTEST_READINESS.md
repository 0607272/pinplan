# 十月赛要求与项目对照

查阅日期：2026-10-20。本页记录工程准备情况，不是组委会的验收结论。

## 当期来源与日期差异

- [当前大赛官网](https://moonbitlang.github.io/Hackathon2026/)：十月赛报名与验收截止 **2026-10-31**，最多提交 3 次指报名表申报次数。
- [正式《MoonBit 黑客松大赛章程》](https://bxup9uklfcb.feishu.cn/wiki/Dx4Bwd6D1i3GfHkajQCcF7SznEd)：页面标注 10 月 10 日修改；验收章节仍含 9 月 30 日旧标题，时间表十月行写 **10 月 24 日**。

两处尚不一致，应按更早的 **10 月 24 日** 准备，并以组委会当期确认的时间为准，不能把官网的 31 日自行视为已确认延期。当前官网没有明确要求 20 个 Git 提交；开发历史应真实、连续、内容可解释，不能用凑数代替新增工作。

## 九项验收对照

| 章程要求 | 项目证据或检查方式 | 当前工程状态 |
| --- | --- | --- |
| MoonBit 为主要实现语言 | 根目录资源模型、求解、优化、诊断、JSON 与导出均为 `.mbt`；`moon version --all` | 已实现；适配器用 JS，工具链须在验收环境再核对 |
| GitHub 公开且提交清晰 | [公开仓库](https://github.com/0607272/pinplan)、默认分支 main、真实提交记录 | 已建立；最终以远端源码和提交为准 |
| 结构清晰且核心功能完成 | `moon.mod`、根包 API、`plan/check/repair/diagnose`、`docs/CASE_STUDIES.md` | 已实现原版 Pico 范围，能力边界见 README |
| README 目标、安装、使用及示例可复现 | README 的 CLI/网页/独立 MoonBit 消费说明；`scripts/check-consumer.mjs` | 有自动复现检查，独立消费使用本地路径依赖 |
| CI 覆盖 check/build/test | `.github/workflows/ci.yml`、[Actions](https://github.com/0607272/pinplan/actions) | 已配置 Linux 全目标与 Windows CLI；须核对目标提交的线上结果 |
| 至少一个可运行样例 | `moon run examples`；`npm run cases` | 含七个可复核案例 |
| 核心完整测试 | MoonBit 核心与穷举对照、Node CLI/JSON 回归、独立消费、C11 头文件断言 | 测试覆盖现有范围；不能推断未建模硬件的正确性 |
| 发布到 mooncakes.io | 包名 `0607272/pinplan`；注册表包页、版本与可安装性 | **尚未完成**；此前 dry-run 因未登录而停止，不能当作发布成功 |
| OSI 许可证、来源合规 | MIT `LICENSE`、`docs/SOURCES.md`，MoonBit core Apache-2.0 | 已提供声明；无第三方 MoonBit 模块依赖 |

## 参赛人与外部待办

参赛者自行完成报名、加入赛事群并按官方要求将群昵称改为 GitHub ID；报名状态及最终验收只能由官方确认。本仓库不存储报名表、申报书或联系方式。

Mooncakes 仍需包命名空间对应账号在本机登录，审查公开包清单，dry-run 成功后正式发布，再核对注册表版本、构建与安装结果。本地路径依赖成功、GitHub 上传或 CI 成功均不能替代此项。不要把登录 token 放入源码、日志或比赛材料。

AI 辅助生成的实现仍须由参赛者理解和把控；演示前应能解释硬锁与既有接线偏好的区别、PWM 资源别名、搜索预算、修复最优性和诊断不可再缩减的边界。README 和案例提供了可复现的对应输入与结果。
