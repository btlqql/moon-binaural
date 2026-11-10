# MoonBinaural 项目申报书

**MoonBinaural 0.4.1 · 面向独立有声剧的耳机混音与返修工具**

参赛账号 btlqql，主要实现语言 MoonBit，代码许可证 Apache-2.0。 [GitHub 仓库](https://github.com/btlqql/moon-binaural) · [MoonCakes](https://mooncakes.io/docs/btlqql/moon_binaural@0.4.1)

## 使用者与任务

独立有声剧制作人拿到对白、脚步和门声的单声道素材后，需要把各声音放到剧情时间线上，再试听位置变化、检查叠加时的超幅，并根据试听返修。MoonBinaural 将这些步骤放入可保存的场景工程。同一工程可重复生成普通声像与双耳两个版本，用于耳机审听和修改。

初审反馈要求明确实际场景和用途。本轮交付的《走廊》样片使用公开旁白和拟音录音，复现制作人调高脚步轨后出现的配平前超幅。报告定位到时间和轨道，制作人只需修改该轨增益，再渲染确认超幅消失。

## 实现与输出

制作人以毫秒记录轨道入点及方向关键帧。MoonBit 解码单声道 PCM16 WAV，验证输入采样率与 HRIR 匹配。不同轨道保有各自卷积历史，方向改变时两套滤波器读取相同历史并交叉淡化，导出时排空 FIR 尾部。

一次渲染输出两个 48 kHz 立体声 WAV。普通声像版本使用等功率左右声像，双耳版本使用实测 HRIR。两版以同一套素材和时间轴制作，再衰减至可比的全片 RMS。报告在衰减之前读取混音，按时间聚合超幅并找出每段最强峰值，保留耳道、精确采样点和各轨道的带符号贡献。贡献包括卷积尾音，允许评审者查看哪些分量同向叠加、哪些分量发生相消。输出目录排他创建，便于保留前后两个版本。

## 样片与验收

```sh
moon run cmd/main --target js -- project examples/drama/scene-overload.json _build/drama-overload
moon run cmd/main --target js -- project examples/drama/scene.json _build/drama-repair
```

样片从三段公开录音编排为四个轨道实例，产生 744,255 帧，约 15.5 秒。故障场景最强峰值在左耳约 7.802 秒，配平前峰值 1.1572，贡献来自 `approaching-steps`。把这条轨的增益从 10.0 调至 1.6 后，配平前峰值为 0.7279，超幅耳样本由 8 个降为 0，试听文件仍为原长度、48 kHz 立体声。

脚本独立读取 WAV 校验采样率、声道、帧数、电平和排他写入，同时验证分轨贡献、针对性返修和截断 WAV 的拒绝路径。公开 CI 覆盖四后端库测试和 JS 文件工作流。导出的试听文件均经过配平，返修判定依据配平前的混音指标。 [验证记录](VALIDATION.md) · [试听与报告附件](https://github.com/btlqql/moon-binaural/releases/tag/v0.4.1)

## 差异与适用范围

核心价值是把 MoonBit 双耳渲染接到录音文件、可编辑时间轴、可比试听、质量检查与返修流程。Steam Audio 提供成熟的游戏和 VR 空间音频能力。MoonBinaural 的交付对象是可复现的离线制作工程。 [生态对照](ECOSYSTEM.md)

当前支持固定听者方向和有限实测方向集，按最近点切换滤波器。输出上限 1,440,000 帧，输入为同采样率单声道 PCM16。复审材料提供公开录音、峰值定位、返修前后数值和试听文件。真人定位效果仍待听测。素材、滤波器、第三方许可和转换记录随工程交付。 [官方十一月验收标准](https://github.com/moonbitlang/Hackathon2026/blob/2ca8a6440a5d6d1881104538852bf5f05c90c68e/src/App.tsx#L204-L214) · [样片来源](../examples/drama/README.md)
