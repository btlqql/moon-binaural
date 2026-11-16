# MoonBinaural 项目申报书

**参赛账号** `btlqql` · **申报版本** `0.5.0` · **主要语言** MoonBit · **源码许可证** Apache-2.0

## 问题与交付

同一个双耳空间效果可以用在游戏中的移动声源、浏览器耳机交互、离线音频资产批量渲染。它们共有的输入是单声道 PCM、声源相对方向和听者朝向，宿主自己的播放、文件和时间轴各不相同。初审指出旧版围绕短篇有声剧流程，复用性和技术范围不足。0.5.0 增加供宿主直接调用的分块空间渲染库，由宿主控制输入块、方向和输出缓冲区。

`HrirBank` 校验和持有同采样率、同抽头长度的实测响应。声源方向按听者水平朝向转换到局部坐标，选择相近测量方向。`SpatialRenderer` 将 PCM 写到调用方提供的左右耳数组，不同块间保留 FIR 历史。滤波器变更时，旧、新滤波器使用同一输入历史交叉淡化。快速方向更新只保留最后一个请求，当前淡化结束后继续处理。输入结束后可分段取回 FIR 尾音，重置则清除历史、在途淡化和待处理请求。 [公开 API](../pkg.generated.mbti) · [空间实现](../spatial.mbt)

## 两条复用路径

| 宿主 | 输入与输出 | 复核方式 |
| --- | --- | --- |
| 浏览器交互 | Chromium 的 AudioWorklet 输入单声道，输出左右耳。滑块可改变听者方向。 | 脚本用离线音频上下文在指定帧改变偏航，以两个脉冲探测方向对应的两耳响应。 |
| 离线工具 | Node.js 读取外部单声道 PCM，按不规则块长调用同一渲染器，最后分段取回尾音。 | Python 直接卷积独立计算每个输出采样点，并核对长度和两耳误差。 |

两份宿主代码用独立 MoonBit 工程导入同一包，不依赖场景 CLI 或有声剧工程。样例 HRIR 为 48 kHz、每耳 256 抽头的四组测量。旧有声剧和超幅分析用作兼容验证。性能记录明确区分 Node.js 的 DSP 运行耗时与浏览器音频测试；设备延迟和主观听感需要独立测量。 [复现命令](../README.md) · [验证记录](VALIDATION.md)

## 技术范围与公开材料

通用 DSP 图和混音由宿主提供，项目负责姿态变换、测量选择、带状态的双耳渲染、尾音和重置。项目代码采用 Apache-2.0；实测夹具来自注明固定提交的 Google spatial-media，保留上游归属与许可。 [生态职责对照](ECOSYSTEM.md) · [第三方来源](../THIRD_PARTY.md)

| 评审材料 | 入口 |
| --- | --- |
| GitHub 源码、提交历史和测试 | [仓库](https://github.com/btlqql/moon-binaural) · [历史](https://github.com/btlqql/moon-binaural/commits/main/) · [CI](https://github.com/btlqql/moon-binaural/actions) |
| 固定发布版本 | [v0.5.0 版本入口](https://github.com/btlqql/moon-binaural/releases/tag/v0.5.0) · [MoonCakes 0.5.0](https://mooncakes.io/docs/btlqql/moon_binaural@0.5.0) |
| 可运行的宿主与核验脚本 | [宿主源码](../examples/spatial-hosts/) · [验证脚本](../scripts/verify_spatial_hosts.py) |
