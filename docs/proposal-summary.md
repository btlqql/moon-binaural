# MoonBinaural 一页项目说明

**用 MoonBit 制作和返修有声剧耳机混音 · 0.4.0**

独立有声剧制作人导入对白、脚步、门声的单声道 WAV，用场景文件记录入点、移动方向和增益。工具一次导出双耳混音、等电平普通声像对照和超幅时间报告，创作者可以针对某段效果修改方向再渲染。

《走廊》示例由三段可公开分发的录音组成，含四个轨道实例。生成 744,255 帧、48 kHz 的两个立体声文件，约 15.5 秒。将脚步的第二个方向关键帧从左前改成右前即可得到返修版本。独立检查核对 WAV 元数据、输出电平、修改前后文件差异，以及截断输入和输出覆盖的拒绝路径。

WAV 解码、实测 HRIR 卷积、方向切换、声像与超幅检查由 MoonBit 实现。当前面向同采样率 PCM16 素材和固定头向的离线制作，数值验证与耳机试听分别提供，真人定位效果仍待听测。

```sh
moon run cmd/main --target js -- project examples/drama/scene.json _build/drama-preview
```

[GitHub](https://github.com/btlqql/moon-binaural) · [MoonCakes 0.4.0](https://mooncakes.io/docs/btlqql/moon_binaural@0.4.0) · [工程与试听附件](https://github.com/btlqql/moon-binaural/releases/tag/v0.4.0) · [完整申报书](proposal.md)
