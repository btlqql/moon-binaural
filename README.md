# MoonBinaural 0.5.0

MoonBit 的分块空间音频渲染库。宿主将单声道 PCM、声源相对位置和听者朝向送入同一接口，写出左右耳 PCM，适用于交互音频和离线资产处理。核心库使用实测头相关脉冲响应（HRIR），自身不执行文件读写或设备播放。

## 安装与调用

在自己的 MoonBit 模块执行 `moon add btlqql/moon_binaural@0.5.0`。下面是 `moon.pkg` 的导入写法。

~~~moonbit
import {
  "btlqql/moon_binaural" @audio,
}
~~~

构建测量库时提供同一采样率、同一抽头长度的左右耳响应。以下一抽头示例只展示调用方式，实测数据见仓库样例。

~~~moonbit
fn render_one_block() -> Unit raise @audio.AudioError {
  let front : @audio.Direction = { x: 0.0, y: 1.0, z: 0.0 }
  let bank = @audio.HrirBank::new(
    [{ direction: front, hrir: @audio.Hrir::new([0.5], [0.25]) }],
    48000,
  )
  let renderer = @audio.SpatialRenderer::new(bank, 48000, front, 0.0, 64)
  let input = [1.0, 0.0]
  let left = Array::make(2, 0.0)
  let right = Array::make(2, 0.0)
  renderer.process_into(input, left, right)
}
~~~

- x 向右、y 向前、z 向上。声源方向以听者位置为原点，由宿主从世界坐标计算。听者水平朝向以弧度表示，从 +y 转向 +x 为正。
- `set_pose` 更新下一个采样点起的目标。同一次淡化期间保留最新请求，完成后从下一帧启动后续淡化。
- `process_into` 接收三个长度相同、彼此独立的数组。不同调用可以使用不同块长，按顺序保留滤波历史。空输入块不推进时间。
- `finish_into` 结束输入，分次填充输出数组的前缀，并返回本次写入帧数。有非空输入时总尾音长度为抽头数减一。尾音排完返回 0。`reset` 清空尾音、过渡和历史，立即选择新的初始方向。
- 测量库作用于一个采样率，调用端负责必要的重采样。当前使用最邻近方向匹配和输出淡化，听者朝向支持水平偏航。参数和状态边界见 API 源码。

## 复现两个独立宿主

安装 MoonBit、Node.js 22 或以上、Python 3 和 Chromium 系浏览器。在仓库根目录执行，按本机情况替换浏览器路径。

~~~sh
python scripts/verify_spatial_hosts.py --browser /path/to/chromium
~~~

默认从 MoonCakes 获取 0.5.0，分别构建两个外部 MoonBit 工程。追加 `--local` 可改用当前源码；追加 `--output` 可指定报告与浏览器演示目录。脚本同时生成 `spatial-hosts.json` 和 `browser-app/`。通过浏览器的 [AudioWorklet](https://www.w3.org/TR/webaudio/#AudioWorklet) 接入实测 HRIR，可复现水平转向后的双耳输出；另一个示例从 Node.js 宿主读取 PCM，按多种块长处理并写出尾音。

本地脚本生成浏览器页面后，可从仓库根目录另开终端运行 `python -m http.server 8000 --bind 127.0.0.1 --directory _build/spatial-hosts/browser-app`，在浏览器打开 `http://127.0.0.1:8000`。点击 Start beacon，拖动朝向滑块并用耳机试听。脚本对离线渲染结果做数值核对，手工页面用于交互操作。

## 兼容性与交付入口

0.4.x 的 `Renderer`、场景 JSON CLI、录音样片及配平前超幅诊断接口继续保留。可运行 `python scripts/verify.py` 执行原有独立验证。 [旧场景示例](examples/drama/README.md) · [验证记录](docs/VALIDATION.md) · [生态对照](docs/ECOSYSTEM.md) · [来源与许可](THIRD_PARTY.md)

[简版申报书](docs/proposal.md) · [一页说明](docs/proposal-summary.md) · [GitHub v0.5.0](https://github.com/btlqql/moon-binaural/releases/tag/v0.5.0) · [MoonCakes 0.5.0](https://mooncakes.io/docs/btlqql/moon_binaural@0.5.0)
