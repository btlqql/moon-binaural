# MoonBinaural项目申报书

**实测HRIR驱动的离线方向轨迹与多声源双耳渲染**

账号：btlqql；版本：0.3.0；主要语言：MoonBit；许可：Apache-2.0。

## 解决的问题与使用场景

从单声道采样、实测耳部响应与方向关键帧，渲染左右耳音频；多个声源使用独立历史、不同起始时刻和增益，再混合导出。

## 已实现功能与技术路线

双耳流式FIR、球面最近测量点、共享历史交叉淡化、关键帧场景、分块尾部排空、多源独立卷积和带增益/起点混合、峰值与超幅统计、排他WAV导出。

## 完整案例

双源例左耳输出[1,1.5,0.5]，峰值1.5，左右合计2个超幅采样；合成短音配两份固定实测HRIR的方向轨迹输出12255帧、48kHz立体声。 运行`moon run cmd/main --target js -- examples/two-sources.json`可复现。

## 独立贡献与验证

由房间IR计算混响/噪声底/模态；本项目将源音频渲染为两耳信号。MoonSpectrum的FFT、MoonWavKit的文件解析不作为本项目新增贡献。 当前8项MoonBit测试；两份固定SADIE衍生KU100 HRIR，动态逐采样双卷积/淡化对照误差约1.11e-15；独立多源线性叠加、WAV元数据与排他输出验证。 相邻项目对照见docs/ECOSYSTEM.md，来源与许可见THIRD_PARTY.md。

## 当前边界

离线直接FIR，复杂度O(N*M)，切换期间双卷积。没有分区FFT、任意音频文件/ SOFA导入、重采样或实时线程保证。测量方向取最近点，输出淡化不是ITD保持的HRTF插值。当前源信号合成，HRIR来自外部实测，没有真人听测。

GitHub：https://github.com/btlqql/moon-binaural。模块：btlqql/moon_binaural@0.3.0。AI辅助开发；公开提交、CI和独立安装以实际核验记录为准，开源发布不代表比赛报名或验收通过。
