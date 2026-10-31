# 来源与归属

本项目为AI辅助的MoonBit实现，许可证为Apache-2.0。运行时核心只依赖MoonBit官方core；JS宿主负责文件I/O、PCM封装和退出状态，Python只用于开发验证。

成熟算法与领域参考见README和docs/ECOSYSTEM.md，未将第三方算法源码移植后冒称原创。其他参赛项目仅作为职责对照，相关链接和职责对照见docs/ECOSYSTEM.md，不属于本项目生产代码。

测量夹具来自google/spatial-media的固定提交2308497c39bb604a7c3ba56ac17e302f2b1b6a96中spatial-audio/raw-symmetric-cube-hrirs，保留上游LICENSE、NOTICE和README。E35_A45.wav及E35_A-45.wav为SADIE衍生KU100测量；转换后的示例JSON与生成音频保留同一来源说明。不是本项目自行测得的耳部响应。
