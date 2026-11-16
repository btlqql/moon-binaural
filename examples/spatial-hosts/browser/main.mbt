///|
extern "js" fn register(
  create : (Int, Int) -> (FixedArray[Double], FixedArray[Double], FixedArray[Double], Double) -> Unit,
) -> Unit =
  #| create => {
  #|   class SpatialProcessor extends AudioWorkletProcessor {
  #|     static get parameterDescriptors() {
  #|       return [{name: "yaw", defaultValue: 0, automationRate: "k-rate"}];
  #|     }
  #|     process(inputs, outputs, parameters) {
  #|       const [left, right] = outputs[0];
  #|       if (!this.buffers || this.buffers[0].length !== left.length) {
  #|         this.buffers = Array.from({length: 3}, () => Array(left.length).fill(0));
  #|         this.render ??= create(sampleRate, 64);
  #|       }
  #|       const [input, moonLeft, moonRight] = this.buffers;
  #|       const mono = inputs[0][0];
  #|       for (let i = 0; i < input.length; i++) input[i] = mono?.[i] ?? 0;
  #|       this.render(input, moonLeft, moonRight, parameters.yaw[0]);
  #|       left.set(moonLeft);
  #|       right.set(moonRight);
  #|       return true;
  #|     }
  #|   }
  #|   registerProcessor("moon-spatial", SpatialProcessor);
  #| }

///|
fn main {
  let bank = measured_bank() catch { _ => abort("invalid HRIR bank") }
  let source : @audio.Direction = { x: 0.0, y: 1.0, z: 0.0 }
  register(fn(rate, fade) {
    let renderer = @audio.SpatialRenderer::new(bank, rate, source, 0.0, fade) catch {
      _ => abort("unsupported worklet sample rate")
    }
    let mut pcm : Array[Double] = []
    let mut left : Array[Double] = []
    let mut right : Array[Double] = []
    fn(input, output_left, output_right, yaw) {
      if pcm.length() != input.length() {
        pcm = Array::make(input.length(), 0.0)
        left = Array::make(input.length(), 0.0)
        right = Array::make(input.length(), 0.0)
      }
      for i in 0..<input.length() {
        pcm[i] = input[i]
      }
      renderer.set_pose(source, yaw) catch { _ => abort("invalid pose") }
      renderer.process_into(pcm, left, right) catch { _ => abort("invalid audio block") }
      for i in 0..<input.length() {
        output_left[i] = left[i]
        output_right[i] = right[i]
      }
    }
  })
}
