# MoonBinaural

实测HRIR驱动的离线方向轨迹与多声源双耳渲染，主要业务机制由MoonBit实现，Apache-2.0。

从单声道采样、实测耳部响应与方向关键帧，渲染左右耳音频；多个声源使用独立历史、不同起始时刻和增益，再混合导出。

## 可运行任务

```sh
moon run cmd/main --target js -- examples/two-sources.json
moon run cmd/main --target js -- examples/moving-sadie.json
```

双源例左耳输出[1,1.5,0.5]，峰值1.5，左右合计2个超幅采样；合成短音配两份固定实测HRIR的方向轨迹输出12255帧、48kHz立体声。

measurements给定方向和左右滤波器；sources为samples、keyframes、start、gain的数组。只有指定output时才写WAV，已有目标拒绝覆盖；示例默认只输出JSON，不需要修改已有音频。

CLI读取JSON文件，ok表示计算执行成功；领域可行性、超时或削波需读取各自字段。Node只读写文件、设置退出码和封装PCM；核心算法不转发给Python/C或外部服务。

## 可复用接口与安装

```sh
moon add btlqql/moon_binaural@0.3.0
```

在moon.pkg导入`"btlqql/moon_binaural" @core`；完整签名见[pkg.generated.mbti](pkg.generated.mbti)。

双耳流式FIR、球面最近测量点、共享历史交叉淡化、关键帧场景、分块尾部排空、多源独立卷积和带增益/起点混合、峰值与超幅统计、排他WAV导出。

## 验证

```sh
moon check --target all --deny-warn
moon test --target js --deny-warn
moon test --target wasm --deny-warn
moon test --target wasm-gc --deny-warn
python scripts/verify.py
```

当前8项MoonBit测试。独立开发对照：两份固定SADIE衍生KU100 HRIR，动态逐采样双卷积/淡化对照误差约1.11e-15；独立多源线性叠加、WAV元数据与排他输出验证。

脚本只需要Python标准库、Node与MoonBit；可用MOON_BIN指定moon路径。产物保存在本仓库_build/oracle，脚本不下载外部库，不访问相邻工作区。CI覆盖JS/Wasm/Wasm-GC/native，实际运行状态见[Actions](https://github.com/btlqql/moon-binaural/actions)。本地验证和公共CI结论分别记录，不用静态检查冒称native运行。

## 实现边界与来源

离线直接FIR，复杂度O(N*M)，切换期间双卷积。没有分区FFT、任意音频文件/ SOFA导入、重采样或实时线程保证。测量方向取最近点，输出淡化不是ITD保持的HRTF插值。当前源信号合成，HRIR来自外部实测，没有真人听测。

对照详见[ECOSYSTEM](docs/ECOSYSTEM.md)，归属见[THIRD_PARTY](THIRD_PARTY.md)。实例是软件模型或合成输入，不是生产部署证明。

## 申报与开发记录

[完整版Markdown申报书](docs/proposal.md) | [一页Markdown摘要](docs/proposal-summary.md) | [实际提交历史](https://github.com/btlqql/moon-binaural/commits/main/)

版本0.3.0。GitHub提交保留真实时间与每次文件变化；不以数量替代独立价值和实际质量。十一月规则尚未从公开页面完整确认，开源发布不等于比赛报名或验收通过。
