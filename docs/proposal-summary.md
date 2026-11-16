# MoonBinaural 0.5.0 项目说明

**MoonBit 可嵌入的分块空间音频渲染库** · `btlqql` · Apache-2.0

游戏音频、浏览器交互和离线音频处理可以调用同一个接口完成单声道到左右耳转换。宿主提供 PCM、声源相对方向和听者水平朝向，库选取实测 HRIR，将结果写入宿主已分配的数组。跨块保留卷积历史，方向变更保持滤波输出淡化。快速变向保留最新请求，可分段排出 FIR 尾音，并将节点重置为新的初始化姿态。

浏览器示例在 AudioWorklet 内调用该 API。离线示例以不规则块长处理外部 PCM，并把输出和尾音与独立直接卷积核对。两个宿主共用实测四方向 HRIR，样例数据采样率 48 kHz，每耳 256 抽头。旧《走廊》工程及配平前超幅诊断继续提供离线兼容样例。

初审反馈针对旧有声剧流程的狭窄使用范围。0.5.0 的新增交付是可嵌入空间节点、明确的流处理状态和独立宿主验证。公开材料包含代码、固定版依赖、运行说明、测试及素材出处。 [GitHub](https://github.com/btlqql/moon-binaural) · [v0.5.0 版本入口](https://github.com/btlqql/moon-binaural/releases/tag/v0.5.0) · [MoonCakes 0.5.0](https://mooncakes.io/docs/btlqql/moon_binaural@0.5.0) · [验证说明](VALIDATION.md)
