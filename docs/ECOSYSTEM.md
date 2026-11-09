# 与相邻项目的职责对照

| 项目 | 主要职责 | MoonBinaural 本轮交付 |
|---|---|---|
| Steam Audio | 游戏及 VR 的空间音频 SDK，含 HRTF 双耳渲染 | 用可保存的场景文件批量导入录音，产出双耳/声像对照、可定位的超幅区间和修改后的成品 |
| roomacoustics | 基于房间脉冲响应的声学指标分析 | 根据源方向及其变化渲染两耳时间信号 |
| MoonWavKit 等 WAV 工具 | 容器与音频文件处理 | PCM16 读取接到多轨时间轴、HRIR 渲染和制作流程，格式读取作为支撑能力 |

比较基于公开资料中的用途与接口。HRTF 卷积与声像采用已有方法，本轮新增价值是 MoonBit 内核与离线创作工作流的结合。 [Steam Audio](https://valvesoftware.github.io/steam-audio/doc/capi/binaural-effect.html) · [roomacoustics](https://github.com/AYHEY001/roomacoustics)
