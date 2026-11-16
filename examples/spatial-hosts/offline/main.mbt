///|
extern "js" fn read_samples() -> FixedArray[Double] =
  #| () => JSON.parse(process.getBuiltinModule("fs").readFileSync(process.argv[2], "utf8"))

///|
extern "js" fn write_audio(left : FixedArray[Double], right : FixedArray[Double], tail : Int) -> Unit =
  #| (left, right, tail_frames) => console.log(JSON.stringify({left, right, tail_frames}))

///|
fn render_file() -> Unit raise @audio.AudioError {
  let samples = read_samples()
  let source : @audio.Direction = { x: 0.0, y: 1.0, z: 0.0 }
  let renderer = @audio.SpatialRenderer::new(measured_bank(), 48000, source, 0.0, 64)
  let output_left : Array[Double] = []
  let output_right : Array[Double] = []
  let block_sizes = [7, 71, 256, 97, 1]
  let mut offset = 0
  let mut block = 0
  while offset < samples.length() {
    let size = @cmp.minimum(block_sizes[block % block_sizes.length()], samples.length() - offset)
    let input = Array::makei(size, fn(i) { samples[offset + i] })
    let left = Array::make(size, 0.0)
    let right = Array::make(size, 0.0)
    renderer.process_into(input, left, right)
    for i in 0..<size {
      output_left.push(left[i])
      output_right.push(right[i])
    }
    offset += size
    block += 1
  }
  let left = Array::make(97, 0.0)
  let right = Array::make(97, 0.0)
  let mut tail = 0
  while true {
    let written = renderer.finish_into(left, right)
    if written == 0 { break }
    for i in 0..<written {
      output_left.push(left[i])
      output_right.push(right[i])
    }
    tail += written
  }
  write_audio(
    FixedArray::makei(output_left.length(), fn(i) { output_left[i] }),
    FixedArray::makei(output_right.length(), fn(i) { output_right[i] }),
    tail,
  )
}

///|
fn main {
  if benchmarking() {
    benchmark() catch { _ => abort("invalid benchmark request") }
  } else {
    render_file() catch { _ => abort("invalid offline render request") }
  }
}

///|
extern "js" fn benchmarking() -> Bool =
  #| () => process.argv[2] === "--benchmark"

///|
extern "js" fn now() -> Double =
  #| () => performance.now()

///|
extern "js" fn report_timings(size : Int, fading : Bool, ms : FixedArray[Double]) -> Unit =
  #| (frames, fading, ms) => console.log(JSON.stringify({frames, fading, ms}))

///|
fn benchmark() -> Unit raise @audio.AudioError {
  let bank = measured_bank()
  let source : @audio.Direction = { x: 0.0, y: 1.0, z: 0.0 }
  for size in [128, 256] {
    for fading in [false, true] {
      let renderer = @audio.SpatialRenderer::new(bank, 48000, source, 0.0, size)
      let input = Array::make(size, 0.125)
      let left = Array::make(size, 0.0)
      let right = Array::make(size, 0.0)
      let ms = FixedArray::make(500, 0.0)
      for trial in 0..<600 {
        let start = now()
        if fading {
          let yaw = if trial % 2 == 0 { -1.5 } else { 1.5 }
          renderer.set_pose(source, yaw)
        }
        renderer.process_into(input, left, right)
        let elapsed = now() - start
        if trial >= 100 {
          ms[trial - 100] = elapsed
        }
      }
      report_timings(size, fading, ms)
    }
  }
}
