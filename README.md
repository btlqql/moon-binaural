# MoonBinaural 0.4.1

面向独立有声剧和叙事音频的离线耳机混音工具。导入单声道 WAV，用时间和方向标记安排对白、脚步、门声。报告给出配平前的超幅时间、声道和各轨道对峰值的贡献，制作人可据此调整指定轨道并复跑检查。每次渲染同时导出双耳和普通声像预览。

## 定位并修复《走廊》样片的脚步超幅

安装 MoonBit 和 Node.js 22 或以上，从仓库根目录运行。故障样例将第一条脚步轨增益设为 10.0。修正版保留同一素材、时间轴和方向，只把该轨增益设为 1.6。

```sh
moon run cmd/main --target js -- project examples/drama/scene-overload.json _build/drama-overload
moon run cmd/main --target js -- project examples/drama/scene.json _build/drama-repair
```

每次指定新的输出目录，父目录须存在。产物是 `binaural.wav`、`pan.wav`、`report.json`。报告的 `overload_review.cues` 给出配平前双耳混音的超幅时间、峰值耳道和该采样点的带符号分轨贡献。样例最强超幅位于左耳约 7.802 秒，报告指向 `approaching-steps`。重渲染后，配平前超幅耳样本从 8 个降到 0，峰值从 1.1572 降到 0.7279。导出的试听文件均使用原有 RMS 配平和 0.98 峰值上限。

样片长约 15.5 秒，包含三段公开录音及四个轨道实例。带符号贡献只解释该峰值采样点，混音修改的效果以重渲染复查为准。报告最多展示 32 个提示区间，并报告省略数量。 [样片与素材说明](examples/drama/README.md) · [0.4.1 试听和报告附件](https://github.com/btlqql/moon-binaural/releases/tag/v0.4.1)

## 自己制作一个场景

复制 `examples/drama/scene.json`。每条轨道有名称、WAV 路径、入点毫秒、线性增益和源内方向关键帧。路径相对于场景文件。第一个关键帧在 0 毫秒，后续时间递增。新项目方向坐标为 x 向右、y 向前、z 向上，原向量会归一化。

输入为单声道 16 位 PCM WAV，采样率需与 HRIR 文件一致。样例使用 48 kHz 和四个实测方向。每次混音最多 16 个源，输出上限 1,440,000 帧，含 FIR 尾部。卷积按样本数与抽头数限制工作量，滤波器切换时同一段历史供两套滤波器淡化。适用范围是固定听者方向的离线预览与混音，方向分辨率取决于测量集与听者。

## 库接口与验证

```sh
moon add btlqql/moon_binaural@0.4.1
moon test --target js --deny-warn
python scripts/verify.py
```

本轮新增 `render_reviewed_comparison`，在 `render_comparison` 的混音基础上提供超幅定位。旧接口及采样数组 JSON CLI 保持兼容。WAV 解析、卷积、声像和质量统计均由 MoonBit 实现，Node 负责文件读写和 PCM 封装。

[验证记录](docs/VALIDATION.md) · [生态对照](docs/ECOSYSTEM.md) · [来源与许可](THIRD_PARTY.md) · [完整申报书](docs/proposal.md) · [一页项目说明](docs/proposal-summary.md)
