///|
pub(all) struct ClipSpan {
  start_frame : Int32
  end_frame : Int32
}

///|
pub(all) struct MixMetrics {
  peak : Double
  rms : Double
  clipped_samples : Int32
  clip_spans : Array[ClipSpan]
  omitted_spans : Int32
}

///|
pub(all) struct PreviewPair {
  binaural : Stereo
  pan : Stereo
  binaural_input : MixMetrics
  pan_input : MixMetrics
  binaural_gain : Double
  pan_gain : Double
  matched_rms : Double?
}

///|
fn metrics(audio : Stereo) -> MixMetrics {
  let mut peak = 0.0
  let mut sum = 0.0
  let mut clipped_samples = 0
  let mut start = -1
  let mut omitted_spans = 0
  let clip_spans : Array[ClipSpan] = []
  for i in 0..<=audio.left.length() {
    let mut clipping = false
    if i < audio.left.length() {
      let left = audio.left[i].abs()
      let right = audio.right[i].abs()
      if left > peak {
        peak = left
      }
      if right > peak {
        peak = right
      }
      sum += left * left + right * right
      if left > 1.0 {
        clipped_samples += 1
        clipping = true
      }
      if right > 1.0 {
        clipped_samples += 1
        clipping = true
      }
    }
    if clipping && start == -1 {
      start = i
    }
    if !clipping && start != -1 {
      if clip_spans.length() < 128 {
        clip_spans.push({ start_frame: start, end_frame: i, })
      } else {
        omitted_spans += 1
      }
      start = -1
    }
  }
  {
    peak,
    rms: (sum / (2.0 * audio.left.length().to_double())).sqrt(),
    clipped_samples,
    clip_spans,
    omitted_spans,
  }
}

///|
fn pan_gains(direction : Direction) -> (Double, Double) raise AudioError {
  // Positive x is to the listener's right; the pan baseline ignores front/back.
  let x = normalized(direction).x
  (((1.0 - x) * 0.5).sqrt(), ((1.0 + x) * 0.5).sqrt())
}

///|
fn pan_preview(
  sources : Array[Source],
  frames : Int32,
  fade_samples : Int32,
) -> Stereo raise AudioError {
  let out : Stereo = {
    left: Array::make(frames, 0.0),
    right: Array::make(frames, 0.0),
  }
  for source in sources {
    let mut previous = pan_gains(source.keyframes[0].direction)
    for f in 0..<source.keyframes.length() {
      let frame = source.keyframes[f]
      let next = pan_gains(frame.direction)
      let (old_left, old_right) = previous
      let (new_left, new_right) = next
      let end = if f + 1 < source.keyframes.length() {
        source.keyframes[f + 1].at
      } else {
        source.samples.length()
      }
      for i in frame.at..<end {
        let elapsed = i - frame.at + 1
        let alpha = if f == 0 || elapsed >= fade_samples {
          1.0
        } else {
          elapsed.to_double() / fade_samples.to_double()
        }
        let x = source.samples[i] * source.gain
        let at = source.start + i
        out.left[at] += x * ((1.0 - alpha) * old_left + alpha * new_left)
        out.right[at] += x * ((1.0 - alpha) * old_right + alpha * new_right)
      }
      previous = next
    }
  }
  out
}

///|
fn scale(audio : Stereo, gain : Double) -> Unit {
  for ear in [audio.left, audio.right] {
    for i in 0..<ear.length() {
      ear[i] *= gain
    }
  }
}

///|
/// Render an HRTF mix and a matched-timeline equal-power pan reference.
/// When both are non-silent, attenuate to a common RMS with 0.98 peak headroom.
pub fn render_comparison(
  sources : Array[Source],
  measurements : Array[Measurement],
  sample_rate : Int32,
  hrir_rate : Int32,
  fade_samples : Int32,
) -> PreviewPair raise AudioError {
  let binaural = render_mix(
      sources, measurements, sample_rate, hrir_rate, fade_samples,
    ).audio
  let pan = pan_preview(sources, binaural.left.length(), fade_samples)
  let binaural_input = metrics(binaural)
  let pan_input = metrics(pan)
  let (binaural_gain, pan_gain, matched_rms) = if binaural_input.rms > 0.0 &&
    pan_input.rms > 0.0 {
    let target = @cmp.minimum(
      @cmp.minimum(binaural_input.rms, pan_input.rms),
      @cmp.minimum(
        0.98 * binaural_input.rms / binaural_input.peak,
        0.98 * pan_input.rms / pan_input.peak,
      ),
    )
    (target / binaural_input.rms, target / pan_input.rms, Some(target))
  } else {
    (
      if binaural_input.peak > 0.98 {
        0.98 / binaural_input.peak
      } else {
        1.0
      },
      if pan_input.peak > 0.98 {
        0.98 / pan_input.peak
      } else {
        1.0
      },
      None,
    )
  }
  scale(binaural, binaural_gain)
  scale(pan, pan_gain)
  {
    binaural,
    pan,
    binaural_input,
    pan_input,
    binaural_gain,
    pan_gain,
    matched_rms,
  }
}
