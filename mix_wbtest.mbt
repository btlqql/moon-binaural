///|
test "sources keep separate histories and mix with offsets and gains" {
  let d : Direction = { x: 1.0, y: 0.0, z: 0.0, }
  let ms : Array[Measurement] = [
    { direction: d, hrir: Hrir::new([1.0, 0.5], [0.5, 1.0]), },
  ]
  let sources : Array[Source] = [
    {
      samples: [1.0],
      keyframes: [{ at: 0, direction: d, }],
      start: 0,
      gain: 1.0,
    },
    {
      samples: [2.0],
      keyframes: [{ at: 0, direction: d, }],
      start: 1,
      gain: 0.5,
    },
  ]
  let r = render_mix(sources, ms, 48000, 48000, 1)
  assert_eq(r.audio.left[0], 1.0)
  assert_eq(r.audio.left[1], 1.5)
  assert_eq(r.audio.left[2], 0.5)
  assert_eq(r.peak, 1.5)
  assert_eq(r.clipped_samples, 2)
}
