# MoonBinaural 0.4.0

面向独立有声剧和叙事音频的离线耳机混音工具。导入单声道 WAV，用时间和方向标记安排对白、脚步、门声，导出双耳混音、普通声像对照和可定位到时间的超幅报告。场景文件可随素材一起保存和修改。

## 跑一遍《走廊》样片

安装 MoonBit 和 Node.js 22 或以上，从仓库根目录运行。第二条命令将一个脚步方向改到右前方，便于核对返修结果。

```sh
moon run cmd/main --target js -- project examples/drama/scene.json _build/drama-preview
moon run cmd/main --target js -- project examples/drama/scene-revised.json _build/drama-revision
```

每次指定新的输出目录，父目录须存在。产物是 `binaural.wav`、`pan.wav`、`report.json`。相同素材、轨道入点和增益用于两版。全片 RMS 配平通过衰减实现，并保留 0.98 峰值余量。报告保留衰减前的超幅区间，方便回到场景调整增益。

样片长约 15.5 秒，包含三段公开录音及四个轨道实例。第一组脚步从左后转向左前，普通声像只使用左右坐标，双耳版本会选择不同实测耳部滤波器。第二组脚步从左向右移动。可直接下载试听文件和工程。 [样片与素材说明](examples/drama/README.md) · [0.4.0 发布附件](https://github.com/btlqql/moon-binaural/releases/tag/v0.4.0)

## 自己制作一个场景

复制 `examples/drama/scene.json`。每条轨道有名称、WAV 路径、入点毫秒、线性增益和源内方向关键帧。路径相对于场景文件。第一个关键帧在 0 毫秒，后续时间递增。新项目方向坐标为 x 向右、y 向前、z 向上，原向量会归一化。

输入为单声道 16 位 PCM WAV，采样率需与 HRIR 文件一致。样例使用 48 kHz 和四个实测方向。每次混音最多 16 个源，输出上限 1,440,000 帧，含 FIR 尾部。卷积按样本数与抽头数限制工作量，滤波器切换时同一段历史供两套滤波器淡化。适用范围是固定听者方向的离线预览与混音，方向分辨率取决于测量集与听者。

## 库接口与验证

```sh
moon add btlqql/moon_binaural@0.4.0
moon test --target js --deny-warn
python scripts/verify.py
```

新增 `decode_mono_wav`、`render_comparison`。原有 `Renderer`、`render_scene`、`render_mix` 和采样数组 JSON CLI 仍可使用。WAV 解析、卷积、声像和质量统计均由 MoonBit 实现，Node 负责文件读写和 PCM 封装。

[验证记录](docs/VALIDATION.md) · [生态对照](docs/ECOSYSTEM.md) · [来源与许可](THIRD_PARTY.md) · [完整申报书](docs/proposal.md) · [一页项目说明](docs/proposal-summary.md)
