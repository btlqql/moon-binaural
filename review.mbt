///|
pub(all) enum PeakChannel {
  Left
  Right
}

///|
pub(all) struct TrackContribution {
  source_index : Int32
  sample : Double
}

///|
pub struct OverloadCue {
  start_frame : Int32
  mut end_frame : Int32
  mut clipped_samples : Int32
  mut peak_frame : Int32
  mut peak_channel : PeakChannel
  mut peak_sample : Double
  contributions : Array[TrackContribution]
}

///|
pub(all) struct ReviewedPreview {
  preview : PreviewPair
  overload_cues : Array[OverloadCue]
  omitted_cues : Int32
  merge_gap_frames : Int32
}

///|
let overload_cue_limit : Int32 = 32

///|
fn locate_overload_cues(
  audio : Stereo,
  gap_frames : Int32,
) -> (Array[OverloadCue], Int32) {
  let cues : Array[OverloadCue] = []
  let mut last_clipped = -1
  let mut cue_count = 0
  for frame in 0..<audio.left.length() {
    let left = audio.left[frame]
    let right = audio.right[frame]
    let clipped = (if left.abs() > 1.0 { 1 } else { 0 }) +
      (if right.abs() > 1.0 { 1 } else { 0 })
    if clipped == 0 {
      continue
    }
    let (channel, sample) = if right.abs() > left.abs() {
      (Right, right)
    } else {
      (Left, left)
    }
    if last_clipped < 0 || frame - last_clipped - 1 > gap_frames {
      cue_count += 1
      if cue_count <= overload_cue_limit {
        cues.push({
          start_frame: frame,
          end_frame: frame + 1,
          clipped_samples: 0,
          peak_frame: frame,
          peak_channel: channel,
          peak_sample: sample,
          contributions: [],
        })
      }
    }
    last_clipped = frame
    if cue_count <= overload_cue_limit {
      let cue = cues[cue_count - 1]
      cue.end_frame = frame + 1
      cue.clipped_samples += clipped
      if sample.abs() > cue.peak_sample.abs() {
        cue.peak_frame = frame
        cue.peak_channel = channel
        cue.peak_sample = sample
      }
    }
  }
  (cues, cue_count - cues.length())
}

///|
fn trace_overload_peaks(
  cues : Array[OverloadCue],
  sources : Array[Source],
  measurements : Array[Measurement],
  sample_rate : Int32,
  hrir_rate : Int32,
  fade_samples : Int32,
) -> Unit raise AudioError {
  // The normal mix already passed validation. Rerender only sources that
  // intersect a reported peak and retain one stereo stem at a time.
  let taps = measurements[0].hrir.left.length()
  for index in 0..<sources.length() {
    let source = sources[index]
    let end = source.start + source.samples.length() + taps - 1
    if source.gain == 0.0 ||
      !cues.any(fn(cue) {
        cue.peak_frame >= source.start && cue.peak_frame < end
      }) {
      continue
    }
    let stem = render_scene(
        source.samples,
        measurements,
        source.keyframes,
        sample_rate,
        hrir_rate,
        fade_samples,
      ).audio
    for cue in cues {
      let frame = cue.peak_frame - source.start
      if frame < 0 || frame >= stem.left.length() {
        continue
      }
      let sample = source.gain *
        (match cue.peak_channel {
          Left => stem.left[frame]
          Right => stem.right[frame]
        })
      if sample != 0.0 {
        cue.contributions.push({ source_index: index, sample, })
      }
    }
  }
  for cue in cues {
    let sign = if cue.peak_sample < 0.0 { -1.0 } else { 1.0 }
    cue.contributions.sort_by(fn(a, b) {
      let order = (sign * b.sample).compare(sign * a.sample)
      if order == 0 {
        a.source_index.compare(b.source_index)
      } else {
        order
      }
    })
  }
}

///|
/// Render a matched preview and report the first 32 pre-attenuation binaural
/// overload cues. Gaps of at most 20 ms are merged. Each contribution is the
/// signed rendered sample at the cue's strongest ear and frame, including the
/// source gain. A contribution describes that sample and its gain edit must be
/// checked by rerendering the mix.
pub fn render_reviewed_comparison(
  sources : Array[Source],
  measurements : Array[Measurement],
  sample_rate : Int32,
  hrir_rate : Int32,
  fade_samples : Int32,
) -> ReviewedPreview raise AudioError {
  let mix = render_mix(
    sources, measurements, sample_rate, hrir_rate, fade_samples,
  )
  let merge_gap_frames = sample_rate / 50
  let (overload_cues, omitted_cues) = if mix.clipped_samples > 0 {
    locate_overload_cues(mix.audio, merge_gap_frames)
  } else {
    ([], 0)
  }
  if !overload_cues.is_empty() {
    trace_overload_peaks(
      overload_cues, sources, measurements, sample_rate, hrir_rate, fade_samples,
    )
  }
  let preview = compare_with_pan(mix.audio, sources, fade_samples)
  { preview, overload_cues, omitted_cues, merge_gap_frames, }
}
