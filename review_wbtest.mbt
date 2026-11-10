///|
test "overload attribution includes FIR tail and opposing contribution" {
  let direction : Direction = { x: -1.0, y: 0.0, z: 0.0, }
  let keyframes = [{ at: 0, direction, }]
  let measurements = [{ direction, hrir: Hrir::new([1.0, 0.5], [0.5, 1.0]), }]
  let sources : Array[Source] = [
    { samples: [0.875], keyframes, start: 1, gain: 1.0, },
    { samples: [0.875], keyframes, start: 2, gain: 1.0, },
    { samples: [0.125], keyframes, start: 2, gain: -1.0, },
  ]
  let review = render_reviewed_comparison(sources, measurements, 1000, 1000, 1)
  let baseline = render_comparison(sources, measurements, 1000, 1000, 1)
  assert_eq(review.preview.binaural.left, baseline.binaural.left)
  assert_eq(review.preview.binaural.right, baseline.binaural.right)
  assert_eq(review.overload_cues.length(), 1)
  assert_eq(review.preview.binaural_input.clipped_samples, 2)
  let cue = review.overload_cues[0]
  assert_eq(cue.start_frame, 2)
  assert_eq(cue.end_frame, 3)
  assert_eq(cue.clipped_samples, 2)
  assert_eq(cue.peak_frame, 2)
  assert_true(cue.peak_channel is Right)
  assert_eq(cue.peak_sample, 1.25)
  assert_eq(cue.contributions.map(fn(c) { c.source_index }), [0, 1, 2])
  assert_eq(cue.contributions.map(fn(c) { c.sample }), [0.875, 0.4375, -0.0625])
}

///|
test "cue windows merge nearby clipped frames and count omitted windows" {
  let audio : Stereo = {
    left: Array::make(140, 0.0),
    right: Array::make(140, 0.0),
  }
  audio.left[0] = 1.25
  audio.right[3] = -1.5
  for i in 0..<34 {
    audio.left[7 + 4 * i] = 1.125
  }
  let (cues, omitted) = locate_overload_cues(audio, 2)
  assert_eq(cues.length(), 32)
  assert_eq(omitted, 3)
  assert_eq(cues[0].start_frame, 0)
  assert_eq(cues[0].end_frame, 4)
  assert_eq(cues[0].clipped_samples, 2)
  assert_eq(cues[0].peak_frame, 3)
  assert_true(cues[0].peak_channel is Right)
  assert_eq(cues[1].start_frame, 7)
  assert_eq(cues[31].start_frame, 127)
}
