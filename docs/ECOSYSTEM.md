# 生态职责对照

| 项目 | 公开能力 | 本项目的对应范围 |
| --- | --- | --- |
| Steam Audio | 成熟空间音频 SDK，公开接口支持 HRTF 点声源、应用到音频缓冲区及读取尾音。 [官方 C API](https://valvesoftware.github.io/steam-audio/doc/capi/binaural-effect.html) | 提供原生 MoonBit 的单声道转双耳节点、可变块长 PCM 接口和方向更新规则。 |
| `dowdiness/moondsp` | MoonBit 的信号图、声部调度和浏览器 AudioWorklet 运行时。 [MoonCakes](https://mooncakes.io/docs/dowdiness/moondsp) | 提供单个空间处理节点，由宿主决定图结构、调度和播放。 |
| `2227057182/moonbit-dsp` | 提供通用 FFT、卷积、数字滤波与统计。 [MoonCakes](https://mooncakes.io/docs/2227057182/moonbit-dsp@0.1.0) | 以两个实测耳通道、三维方向和听者偏航建立测量选择与跨块滤波状态。 |
| `zmjknn/moon_sfx` | 提供音效生成、立体声等功率声像、多轨游戏混音和 WAV。 [MoonCakes](https://mooncakes.io/docs/zmjknn/moon_sfx) | 根据宿主给定的世界空间方向和听者水平朝向输出两耳信号。 |

HRIR 卷积、方向点积和滤波输出淡化使用已有方法。0.5.0 的实现范围是预分配输出缓冲区、具有明确快速更新语义的跨块渲染、可分段排出的尾音，以及通过同一公开接口运行的两个独立宿主。 [空间 API](../spatial.mbt) · [来源与许可](../THIRD_PARTY.md)
