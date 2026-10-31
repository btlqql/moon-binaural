///|
test "negative gain cancels at mix output and invalid source offsets reject" {
  let d : Direction = { x: 1.0, y: 0.0, z: 0.0, }
  let m : Array[Measurement] = [
    { direction: d, hrir: Hrir::new([1.0], [0.5]), },
  ]
  let a : Source = {
    samples: [2.0, 1.0],
    keyframes: [{ at: 0, direction: d, }],
    start: 0,
    gain: 1.0,
  }
  let b : Source = { ..a, gain: -1.0, }
  let r = render_mix([a, b], m, 48000, 48000, 1)
  assert_eq(r.peak, 0.0)
  assert_eq(r.clipped_samples, 0)
  assert_eq(a.samples[0], 2.0)
  assert_true(
    try {
      ignore(render_mix([{ ..a, start: -1, }], m, 48000, 48000, 1))
      false
    } catch {
      _ => true
    },
  )
}

///|
test "a rejected block preserves pending convolution state" {
  let h = Hrir::new([1.0, 0.5], [1.0, 0.5])
  let r = Renderer::new(h)
  ignore(r.process([1.0]))
  assert_true(
    try {
      ignore(r.process([1000001.0]))
      false
    } catch {
      _ => true
    },
  )
  assert_eq(r.process([0.0]).left[0], 0.5)
}
