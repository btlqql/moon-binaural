///|
pub(all) struct Keyframe {
  at : Int32
  direction : Direction
}

///|
pub(all) struct SceneResult {
  audio : Stereo
  peak : Double
  clipped_samples : Int32
}

///|
fn append_audio(target : Stereo, source : Stereo) -> Unit {
  for x in source.left {
    target.left.push(x)
  }
  for x in source.right {
    target.right.push(x)
  }
}

// A bounded offline scene renderer. Directions are piecewise measured nearest
// neighbours; filter changes crossfade, not interpolation of unmeasured HRTFs.

///|
pub fn render_scene(
  input : Array[Double],
  measurements : Array[Measurement],
  keyframes : Array[Keyframe],
  sample_rate : Int32,
  hrir_rate : Int32,
  fade_samples : Int32,
) -> SceneResult raise AudioError {
  if sample_rate < 1 ||
    sample_rate > 192000 ||
    sample_rate != hrir_rate ||
    input.is_empty() ||
    input.length() > 240000 ||
    keyframes.is_empty() ||
    keyframes.length() > 512 ||
    keyframes[0].at != 0 ||
    fade_samples < 1 ||
    fade_samples > 480000 ||
    measurements.is_empty() ||
    measurements.length() > 4096 {
    raise InvalidAudio
  }
  let taps = measurements[0].hrir.left.length()
  if input.length().to_int64() * taps.to_int64() > 64000000L {
    raise InvalidAudio
  }
  for m in measurements {
    if m.hrir.left.length() != taps {
      raise InvalidAudio
    }
    ignore(normalized(m.direction))
  }
  for x in input {
    if !finite(x) || x.abs() > 1.0e6 {
      raise InvalidAudio
    }
  }
  for i in 0..<keyframes.length() {
    let f = keyframes[i]
    ignore(normalized(f.direction))
    if f.at < 0 || f.at >= input.length() {
      raise InvalidDirection
    }
    if i > 0 && f.at <= keyframes[i - 1].at {
      raise InvalidDirection
    }
    if i > 1 && f.at - keyframes[i - 1].at < fade_samples {
      raise TransitionBusy
    }
  }
  let renderer = Renderer::new(select(measurements, keyframes[0].direction))
  let output : Stereo = { left: [], right: [], }
  for f in 0..<keyframes.length() {
    if f > 0 {
      renderer.transition(
        select(measurements, keyframes[f].direction),
        fade_samples,
      )
    }
    let end = if f + 1 < keyframes.length() {
      keyframes[f + 1].at
    } else {
      input.length()
    }
    let mut start = keyframes[f].at
    while start < end {
      let stop = if start + 1024 < end { start + 1024 } else { end }
      let block : Array[Double] = []
      for i in start..<stop {
        block.push(input[i])
      }
      append_audio(output, renderer.process(block))
      start = stop
    }
  }
  append_audio(output, renderer.drain())
  let mut peak = 0.0
  let mut clipped = 0
  for ear in [output.left, output.right] {
    for x in ear {
      if x.abs() > peak {
        peak = x.abs()
      }
      if x.abs() > 1.0 {
        clipped += 1
      }
    }
  }
  { audio: output, peak, clipped_samples: clipped, }
}
