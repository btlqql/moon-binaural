# MoonBinaural 一页项目说明

**用 MoonBit 定位并返修有声剧混音超幅 · 0.4.1**

独立有声剧制作人导入对白、脚步和门声的单声道 WAV，用场景文件记录入点、方向和增益。报告定位配平前的超幅时间、耳道和峰值处分轨贡献，制作人可以调整指定轨道并重渲染复核。工具同时导出双耳混音和普通声像对照。

《走廊》使用三段公开录音，生成约 15.5 秒的成品。故障样例在左耳约 7.802 秒出现最强峰值，报告指向脚步轨。只将该轨增益从 10.0 调至 1.6，配平前超幅耳样本由 8 个降至 0，峰值从 1.1572 降至 0.7279。前后报告和试听文件可下载复查。

WAV 解码、实测 HRIR 卷积、方向切换、声像与超幅检查由 MoonBit 实现。当前面向同采样率 PCM16 素材和固定头向的离线制作，数值验证与耳机试听分别提供，真人定位效果仍待听测。

```sh
moon run cmd/main --target js -- project examples/drama/scene-overload.json _build/drama-overload
moon run cmd/main --target js -- project examples/drama/scene.json _build/drama-repair
```

[GitHub](https://github.com/btlqql/moon-binaural) · [MoonCakes 0.4.1](https://mooncakes.io/docs/btlqql/moon_binaural@0.4.1) · [报告与试听附件](https://github.com/btlqql/moon-binaural/releases/tag/v0.4.1) · [完整申报书](proposal.md)
