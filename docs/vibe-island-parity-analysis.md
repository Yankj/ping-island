# Vibe Island / Ping Island 交互与声音对照

记录日期：2026-08-24

对照版本：

- Vibe Island 1.0.46（本机已安装发行版）
- Ping Island 0.28.0（本机已安装发行版与 `v0.28.0` 源码）

## 范围与方法

本次只分析应用包结构、公开符号、设置模型与可观察到的运行行为。实现不复制 Vibe Island 的代码、音频、图像或其他专有资源，也不涉及授权校验或付费限制。

运行时观察在同一台 Mac、同一组活跃 Codex 会话下完成。静态观察来自应用的 `Info.plist`、链接框架、Mach-O 类型/字段元数据与 Ping Island 开源源码。

## 关键差距

| 维度 | Vibe Island 1.0.46 | Ping Island 0.28.0（改动前） | 影响 |
| --- | --- | --- | --- |
| 技术栈 | 原生 AppKit / SwiftUI；直接链接 AVFAudio 与 CoreAudio | 原生 AppKit / SwiftUI；声音主要走 `NSSound` | 两者 UI 基础相近，声音体感差异主要来自架构而非跨平台框架 |
| Hover 进入 | 本机偏好值为 150 ms | 普通 240 ms、全屏 180 ms | Ping 会明显晚半拍 |
| Hover 离开 | 有独立 mouse-leave timer 与 hover cooldown | 鼠标离开后立即折叠 | Ping 更容易在边缘移动时抖动或误收起 |
| Hover 宽度 | 约 370 pt 的当前任务摘要 | 600 pt 的多会话 dashboard；点击面板反而最多 520 pt | Ping 的轻触预览比深入点击更重，渐进披露顺序倒置 |
| Hover 内容 | 当前任务标题、阶段摘要、真实任务进度 | 最多三个会话卡片和多组元数据 badge | Vibe 扫读路径短；Ping 信息完整但认知负担更大 |
| 展示状态 | `NotchDisplayState`、pin、keyboard focus、menu-bar zone、expanded-panel zone、cooldown 等显式状态 | `NotchStatus` + open reason + 若干布尔状态 | Vibe 对 hover 生命周期和自动 reveal 的建模更细 |
| 声音入口 | `SoundManager` + `SoundFilter` + source store | 事件边缘在 `NotchView` 内识别后直接播放 | Vibe 的过滤、来源选择与播放职责更集中 |
| 文件播放 | 独立 `SoundPackPlayer`，字段显示 prepare/stop task、playback generation、last played | 单一 `NSSound` 槽，新声音会停止旧声音 | Ping 容易出现首播解码延迟或连续事件截断感 |
| 合成音 | `SoundSynthesizer` 持有 AVAudioEngine、mixer、player node、PCM buffer | 无实时合成音 | Vibe 可用短、统一响度且与事件语义绑定的提示音 |
| 输出设备变化 | 监听 CoreAudio 输出设备与 AVAudioEngine configuration change | 无独立恢复链路 | 切换耳机、显示器或声卡后，Vibe 更容易保持可用 |
| 声音过滤 | session start、stop、idle、replay、spam 等独立 cooldown / debounce | 已有焦点抑制和状态边缘去重，但没有最终播放门 | Ping 在状态重建或密集事件下更可能重复提示 |
| 声音设置 | quiet hours、事件分类、来源选择、自定义声音、CESP 音效包 | 系统音、8-bit、CESP 音效包、临时静音与焦点抑制 | Ping 已有不错基础，但缺少 quiet hours 与逐事件来源组合 |

## 本轮实现

### Hover 交互

- 普通 hover 延迟从 240 ms 调整为 150 ms；全屏 reveal 为 120 ms。
- 鼠标离开增加 120 ms grace period，重新进入会取消折叠任务。
- docked hover 最大宽度从 600 pt 收敛到 440 pt；点击仍保留最大 520 pt 的完整列表。
- 普通 hover 最多展示两个最高优先级的真实会话；审批和问题仍会抢占为可操作通知卡。
- 展开/收起与 hover 反馈的弹簧时长收紧；开启 macOS“减少动态效果”时改用淡入淡出或静态反馈。

这里保留两个会话而不是强行只显示一个，是因为 Ping 目前无法可靠区分 Codex Desktop 同一进程中的前台线程。显示两个可以在紧凑性与“不要选错当前任务”之间取得更稳妥的平衡。

### 声音播放

- 内置 WAV 与 CESP 文件改由缓存的 `AVAudioPlayer` 播放，并在启动时预热内置音频。
- 新增“柔和合成音”模式，作为新安装的默认声音模式；现有用户已保存的选择保持不变。
- 十类事件使用独立生成的 48 kHz 双声道 PCM cue：会话开始、任务确认、需要介入、完成、任务失败、上下文限制、闲置提醒、额度预警、额度恢复、连续提交。
- 所有合成 cue 统一归一化到 0.68 峰值，保留余量并降低事件切换时的响度跳变。
- 合成 cue 预渲染为内存 WAV，由预热后的 `AVAudioPlayer` 播放，避免首播被输出设备配置通知打断。
- 真实通知增加逐事件 cooldown；设置页手动试听不受 cooldown 限制。
- 8-bit 启动旋律只在选择 8-bit 模式时播放，避免其他声音模式仍被启动音打扰。

### 首次启动与品牌

- Vibe Island 的首启体验采用“桌面揭幕 → 全屏能力演示 → 环境配置”的渐进流程，并用约 6 秒的仪式音强化品牌记忆。
- AgentIsland 将其重构为六页：品牌揭幕、统一视野、语义声效、精准返回、安静交互、位置与隐私选择；提供跳过与返回，不强迫观看完整介绍。
- 首启音是独立设计的 6 秒三阶段立体声合成主题，并为五次翻页配套短提示，不使用 Vibe Island 的音频文件或采样。
- 首启动画改为版本化欢迎体验；覆盖旧预览版安装也会展示一次，不再仅依赖上游的“从未安装”标记。
- 后续 Hooks 安装改为显式确认；不会因为用户完成视觉引导就自动写入客户端配置。
- 产品名、应用包名、本地 Bundle ID 和首启徽章统一标记为 AgentIsland，同时说明它基于 Ping Island，避免与原版混淆。
- 首启从三页扩展为六页：品牌、统一视野、语义声效、精准返回、安静交互、位置与隐私；阶段数与信息密度更接近完整产品导览。
- 使用原创 `A + 状态岛` 玻璃图标替换上游图标，并在设置侧栏与右键快捷菜单中提供浅层退出入口。

## 未在本轮伪装实现的能力

- **当前前台线程定位**：Vibe 模型中有 `focusedSessionId`；Ping 需要先建立 Codex Desktop 当前 thread 与 `SessionState` 的可信映射。
- **任务 checklist**：只有在 hook / app-server 提供真实计划步骤时才应展示，不能从聊天文本猜测并冒充任务状态。
- **Quiet Hours**：适合下一轮补入设置持久化和跨午夜时间段测试。
- **逐事件声音来源**：每个事件可独立启用并选择系统音或 8-bit 映射；声音来源主题仍按整套切换。
- **健康检查过滤规则**：连续提交检测和逐事件 cooldown 已加入；健康探测会话的完整静音规则仍需继续下沉到 ingestion 层。

## 验证基线

- 新增合成音渲染测试：格式、帧数、有限样本、峰值和时长范围。
- 新增声音门测试：同类事件防抖，不同事件互不抑制。
- 新增 hover 延迟、离开缓冲、紧凑宽度与双会话上限测试。
- 本机没有完整 Xcode，应用 target 的 `xcodebuild` / UI 测试需在安装 Xcode 的机器或 CI 上补跑。
