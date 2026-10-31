///|
pub(all) struct Source {
  samples : Array[Double]
  keyframes : Array[Keyframe]
  start : Int32
  gain : Double
}

// Bounded offline mixing. Each source has an independent convolution history.
// Summation is unclipped; clipping is measured before optional PCM quantization.

///|
pub fn render_mix(
  sources : Array[Source],
  measurements : Array[Measurement],
  sample_rate : Int32,
  hrir_rate : Int32,
  fade_samples : Int32,
) -> SceneResult raise AudioError {
  if sources.is_empty() || sources.length() > 16 || measurements.is_empty() {
    raise InvalidAudio
  }
  let taps = measurements[0].hrir.left.length()
  let mut work = 0L
  let mut length = 0
  for s in sources {
    if s.start < 0 || s.start > 240000 || !finite(s.gain) || s.gain.abs() > 16.0 {
      raise InvalidAudio
    }
    work += s.samples.length().to_int64() * taps.to_int64()
    if work > 64000000L || s.samples.length() > 240000 {
      raise InvalidAudio
    }
    let end = s.start + s.samples.length() + taps - 1
    if end > length {
      length = end
    }
  }
  if length > 480000 {
    raise InvalidAudio
  }
  let result : Stereo = {
    left: Array::make(length, 0.0),
    right: Array::make(length, 0.0),
  }
  for s in sources {
    let audio = render_scene(
        s.samples,
        measurements,
        s.keyframes,
        sample_rate,
        hrir_rate,
        fade_samples,
      ).audio
    for i in 0..<audio.left.length() {
      result.left[s.start + i] += s.gain * audio.left[i]
      result.right[s.start + i] += s.gain * audio.right[i]
    }
  }
  let mut peak = 0.0
  let mut clipped = 0
  for ear in [result.left, result.right] {
    for x in ear {
      if x.abs() > peak {
        peak = x.abs()
      }
      if x.abs() > 1.0 {
        clipped += 1
      }
    }
  }
  { audio: result, peak, clipped_samples: clipped, }
}
