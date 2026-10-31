///|
test "moving scene preserves tail and checks rate and transition spacing" {
  let measurements : Array[Measurement] = [
    {
      direction: { x: 1.0, y: 0.0, z: 0.0, },
      hrir: Hrir::new([1.0, 0.0], [0.0, 1.0]),
    },
    {
      direction: { x: 0.0, y: 1.0, z: 0.0, },
      hrir: Hrir::new([0.0, 1.0], [1.0, 0.0]),
    },
  ]
  let frames : Array[Keyframe] = [
    { at: 0, direction: { x: 1.0, y: 0.0, z: 0.0, }, },
    { at: 1, direction: { x: 0.0, y: 1.0, z: 0.0, }, },
  ]
  let s = render_scene([2.0, 4.0, 8.0], measurements, frames, 48000, 48000, 2)
  assert_eq(s.audio.left[1], 3.0)
  assert_eq(s.audio.left[2], 4.0)
  assert_eq(s.audio.left[3], 8.0)
  assert_eq(s.audio.right.length(), 4)
  assert_eq(s.peak, 8.0)
  assert_true(
    try {
      ignore(render_scene([1.0], measurements, [frames[0]], 44100, 48000, 2))
      false
    } catch {
      _ => true
    },
  )
}

///|
test "largest supported filter can be drained within per-block budget" {
  let taps = Array::make(4096, 0.0)
  taps[4095] = 1.0
  let r = Renderer::new(Hrir::new(taps, taps))
  ignore(r.process([1.0]))
  let tail = r.drain()
  assert_eq(tail.left.length(), 4095)
  assert_eq(tail.left[4094], 1.0)
}
