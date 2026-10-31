# MoonBinaural

MoonBit双耳FIR流式渲染核心。首批实现，模块名november/moon_binaural为本地开发命名空间，未发布。

输入单声道采样与同采样率的左右HRIR；输出左右耳采样。核心实现Hrir、Renderer、球面最近测量点选择、跨块历史、双滤波器线性交叉淡化及尾部排空。完整API见pkg.generated.mbti。与分析房间衰减时间的roomacoustics职责不同，不把WAV或FFT解析作为新增贡献。

```powershell
moon run cmd/main --target js -- examples/impulse.json
moon run cmd/main --target js -- examples/measured-hrir.json
moon test --target wasm --deny-warn
```

CLI读取JSON的left/right滤波器和blocks采样块，返回每块左右输出及M-1尾部。空块不推进时间。transition是当前公共API，CLI首版只渲染固定方向；单元测试单独验证动态切换。drain是追加M-1个零，每次调用都会推进状态，不是幂等结束操作。新旧滤波器共用完整历史，过渡结束不丢尾部；过渡期间再次请求切换明确拒绝。

examples/measured-hrir.json由上级verify.py从固定上游实测HRIR解码生成；examples/measured-tone.wav是MoonBit渲染输出的440Hz合成短音，Python仅封装PCM。上游为Google spatial-media固定提交2308497c39bb604a7c3ba56ac17e302f2b1b6a96，SADIE衍生KU100，256 taps，48kHz。来源、SHA-256及数值误差在../../evidence/validation.json；上游原始README、LICENSE、NOTICE随testdata保留。

信号仍需由调用方保持正确采样率。当前最近方向选择不插值；没有SOFA导入、重采样、分区FFT、多声源、浏览器声卡或实时音频线程保证。HRIR适配个人听感未经真人听测，不能从数值一致性推出定位准确性。

直接FIR复杂度O(N*M)，过渡期间两次卷积。M<=4096，一块N<=1,000,000且N*M<=16,000,000；输入和滤波系数均须有限且绝对值<=1e6。输出不自动归一化/限幅，调用者需监测峰值。核心只返回Double采样；音频文件输出示例的PCM封装才有显式饱和量化。

核心与JS读取宿主分离。数值对照以独立Python卷积核对全部输出和尾部；真实外部数据仅指HRIR，不声称真实用户部署。运行上级verify.py重现三后端测试和对照。

实现代码Apache-2.0，AI辅助制作；实测HRIR遵循testdata/LICENSE及NOTICE。没有移植Web Audio/Steam Audio的渲染器代码，未发明HRTF算法。
