# 0.4.0 验证记录

## 录音工作流

本地 JS 执行《走廊》示例得到 744,255 帧、48 kHz、16 位立体声 WAV。用 Python 标准库从 PCM 文件独立测得以下结果。

| 输出 | 峰值 | 全片 RMS |
|---|---:|---:|
| 双耳 | 0.688589 | 0.03084816 |
| 普通声像 | 0.556536 | 0.03084816 |

`scripts/verify.py` 检查修改一个关键帧后的文件差异、同侧前后变化对两种渲染的影响、截断 WAV 拒绝和排他写入。测试将结果保存在 `_build/oracle/result.json`，包含导出哈希和当次运行耗时。局部测得脚本中的主场景渲染约 0.9 秒，性能依赖主机和素材。

旧流程的逐采样双卷积/淡化独立对照最大误差约 1.11e-15，多源线性叠加对照通过。10 项 MoonBit 测试覆盖原功能、带奇数长度填充块的 PCM16 WAV、两耳样本与超幅区间和电平配平。Windows 本地执行 JS、Wasm、Wasm-GC 测试，GitHub Actions 提供四后端执行记录。 [公共 CI](https://github.com/btlqql/moon-binaural/actions)

试听可使用发布附件的两版 WAV，报告和素材可从仓库复现。电平为全片 RMS，定位效果仍待听测。 [试听附件](https://github.com/btlqql/moon-binaural/releases/tag/v0.4.0)
