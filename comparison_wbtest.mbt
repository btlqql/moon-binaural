///|
test "PCM16 mono accepts padded unknown chunks and preserves signed samples" {
  let bytes = b"RIFF\x32\x00\x00\x00WAVEJUNK\x01\x00\x00\x00\xff\x00fmt \x10\x00\x00\x00\x01\x00\x01\x00\x80\xbb\x00\x00\x00\x77\x01\x00\x02\x00\x10\x00data\x04\x00\x00\x00\x00\x80\x00\x40"
  let audio = decode_mono_wav(bytes)
  assert_eq(audio.sample_rate, 48000)
  assert_eq(audio.samples, [-1.0, 0.5])
}

///|
test "headroom preserves cue and clipping span before matching comparison level" {
  let direction : Direction = { x: -1.0, y: 0.0, z: 0.0, }
  let source : Source = {
    samples: [0.0, 1.0, 1.0, 0.0],
    keyframes: [{ at: 0, direction, }],
    start: 3,
    gain: 2.0,
  }
  let pair = render_comparison(
    [source],
    [{ direction, hrir: Hrir::new([1.0], [0.5]), }],
    48000,
    48000,
    1,
  )
  assert_eq(pair.binaural.left.length(), 7)
  assert_eq(pair.binaural_input.clipped_samples, 2)
  assert_eq(pair.binaural_input.clip_spans.length(), 1)
  assert_eq(pair.binaural_input.clip_spans[0].start_frame, 4)
  assert_eq(pair.binaural_input.clip_spans[0].end_frame, 6)
  assert_true(pair.binaural.left[4] <= 0.98)
  assert_eq(pair.pan.right[4], 0.0)
  assert_true(
    (metrics(pair.binaural).rms - metrics(pair.pan).rms).abs() < 1.0e-12,
  )
}
