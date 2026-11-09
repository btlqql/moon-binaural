# MoonBinaural 项目申报书

**MoonBinaural 0.4.0 · 面向独立有声剧的耳机混音工具**

参赛账号 btlqql，主要实现语言 MoonBit，代码许可证 Apache-2.0。 [GitHub 仓库](https://github.com/btlqql/moon-binaural) · [MoonCakes](https://mooncakes.io/docs/btlqql/moon_binaural@0.4.0)

## 使用者与任务

独立有声剧制作人拿到对白、脚步和门声的单声道素材后，需要把各声音放到剧情时间线上，再试听位置变化、检查叠加时的超幅，并根据试听返修。MoonBinaural 将这些步骤放入可保存的场景工程。同一工程可重复生成普通声像与双耳两个版本，用于耳机审听和修改。

本轮对应初审的实际应用问题，新增了从录音文件导入到成品和质量报告的完整入口。交付的《走廊》样片使用公开旁白及环境拟音录音，允许评委拿同一套素材修改方向、重新导出并比较结果。

## 实现与输出

制作人以毫秒记录轨道入点及方向关键帧。MoonBit 解码单声道 PCM16 WAV，验证输入采样率与 HRIR 匹配。不同轨道保有各自卷积历史，方向改变时两套滤波器读取相同历史并交叉淡化，导出时排空 FIR 尾部。

一次渲染输出两个 48 kHz 立体声 WAV。普通声像版本使用等功率左右声像，双耳版本使用实测 HRIR。两版以同一套素材和时间轴制作，再衰减至可比的全片 RMS。报告列出轨道起止和关键帧、配平前后峰值与 RMS、超幅样本数和相应时间区间。输出目录排他创建，重复运行可另选目录保留已有结果。

## 样片与验收

```sh
moon run cmd/main --target js -- project examples/drama/scene.json _build/drama-preview
moon run cmd/main --target js -- project examples/drama/scene-revised.json _build/drama-revision
```

样片从三段公开录音编排为四个轨道实例，产生 744,255 帧，约 15.5 秒。原场景让一组脚步从左后转向左前，返修版改成左后转向右前。验证确认仅改动一个方向关键帧即可得到不同的双耳文件。另一个独立对照固定左侧的脚步方向，测得普通声像输入 RMS 不变，而双耳渲染的输入 RMS 随前后切换改变。该对照验证输出信号的变化，实际方向感留给试听者核对。

两个 PCM 文件的 RMS 约为 0.03085，峰值分别约为 0.689 与 0.557。脚本独立读取 WAV 校验采样率、声道、帧数、电平和排他写入，并验证截断 WAV 的拒绝路径。公开 CI 覆盖 JS、Wasm、Wasm-GC 与 native 核心测试。 [验证记录](VALIDATION.md) · [试听与工程附件](https://github.com/btlqql/moon-binaural/releases/tag/v0.4.0)

## 差异与适用范围

核心价值是把 MoonBit 双耳渲染接到录音文件、可编辑时间轴、可比试听、质量检查与返修流程。Steam Audio 提供成熟的游戏和 VR 空间音频能力。MoonBinaural 的交付对象是可复现的离线制作工程。 [生态对照](ECOSYSTEM.md)

当前支持固定听者方向和有限实测方向集，按最近点切换滤波器。输出上限 1,440,000 帧，输入为同采样率单声道 PCM16。复审材料提供实际录音、客观数值和试听文件。真人定位效果仍待听测。素材、滤波器、第三方许可和转换记录随工程交付。 [样片来源](../examples/drama/README.md)
