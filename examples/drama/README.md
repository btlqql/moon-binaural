# 《走廊》录音混音工程

`scene-overload.json` 把 `approaching-steps` 增益调为 10.0，用于复现混音超幅。对照的 `scene.json` 将同一轨设为 1.6。报告的 `overload_review` 显示配平前峰值处的分轨贡献，返修后的输出仍可正常试听。 [返修命令](../../README.md#定位并修复走廊样片的脚步超幅)

`scene.json` 中，旁白从 0 秒开始。脚步在 4.4 秒进入，从左后切换到左前，在 8.6 秒有另一段从左到右的脚步。门声在 14.5 秒从右后出现。每个标记都可直接编辑。`scene-revised.json` 将第一组脚步的目标改为右前。方向坐标为 x 向右、y 向前、z 向上，样例四个实测方向位于仰角约 35 度的平面。

从仓库根目录运行以下命令，打开输出文件夹内两份 WAV，并根据 `report.json` 中的关键帧和超幅区间复核。

```sh
moon run cmd/main --target js -- project examples/drama/scene.json _build/drama-preview
```

| 素材 | 来源与处理 |
|---|---|
| narrator.wav | Linda Johnson 的 LJ Speech 样本 LJ037-0171。公开领域录音，线性重采样至 48 kHz，首尾 10 ms 淡化。 [LJ Speech](https://keithito.com/LJ-Speech-Dataset/) |
| steps.wav | FOSSarts 的木地板脚步录音，CC0。使用公开 HQ 试听版，解码后声道均值转单声道，首尾 10 ms 淡化。 [原录音](https://freesound.org/people/FOSSarts/sounds/740292/) |
| door.wav | kobemano 的开关门录音，CC0。使用公开 HQ 试听版，截取峰值前约 0.2 秒开始的 1 秒片段，转换至 48 kHz，首尾 10 ms 淡化。 [原录音](https://freesound.org/people/kobemano/sounds/745550/) |
| hrir.json | Google spatial-media 固定提交中的四份 SADIE 衍生 KU100 测量，PCM 样本转浮点。上游许可、NOTICE 和数据说明位于 `testdata/`。 [四方向来源](https://github.com/google/spatial-media/tree/2308497c39bb604a7c3ba56ac17e302f2b1b6a96/spatial-audio/raw-symmetric-cube-hrirs) |

转换前后哈希、原始文件地址与切片偏移见 [provenance.json](provenance.json)。播放对照时使用同一副耳机和相同音量。样片使用公开录音编排，用于验证制作步骤和试听。
