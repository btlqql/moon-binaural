# 与已有项目的职责对照

核查日期2026-10-31。检索公开仓库、模块和最接近项目的一手README；未命中不构成生态唯一保证。

- [AYHEY001/roomacoustics](https://github.com/AYHEY001/roomacoustics)：由房间IR计算混响/噪声底/模态；本项目将源音频渲染为两耳信号。MoonSpectrum的FFT、MoonWavKit的文件解析不作为本项目新增贡献。

离线直接FIR，复杂度O(N*M)，切换期间双卷积。没有分区FFT、任意音频文件/ SOFA导入、重采样或实时线程保证。测量方向取最近点，输出淡化不是ITD保持的HRTF插值。当前源信号合成，HRIR来自外部实测，没有真人听测。

本项目是AI辅助的独立MoonBit实现，算法来自成熟公开方法，不将CLI、基础I/O或第三方数据计为独立算法贡献。
