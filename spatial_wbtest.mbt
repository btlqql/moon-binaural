///|
let spatial_front : Direction = { x: 0.0, y: 1.0, z: 0.0, }

///|
let spatial_left : Direction = { x: -1.0, y: 0.0, z: 0.0, }

///|
let spatial_right : Direction = { x: 1.0, y: 0.0, z: 0.0, }

///|
fn spatial_measurements() -> Array[Measurement] raise AudioError {
  [
    {
      direction: spatial_front,
      hrir: Hrir::new([1.0, 0.5, 0.25], [0.0, 1.0, 0.0]),
    },
    {
      direction: spatial_left,
      hrir: Hrir::new([0.0, 1.0, 0.0], [1.0, 0.0, 0.0]),
    },
    {
      direction: spatial_right,
      hrir: Hrir::new([-1.0, 0.0, 0.5], [0.0, 0.0, 1.0]),
    },
  ]
}

///|
test "listener yaw changes the measured direction and the bank owns its data" {
  let measurements = spatial_measurements()
  let bank = HrirBank::new(measurements, 48000)
  measurements[1].hrir.right[0] = 13.0
  measurements.clear()
  let left = [0.0]
  let right = [0.0]
  let quarter_turn = 1.5707963267948966
  let renderer = SpatialRenderer::new(
    bank, 48000, spatial_front, quarter_turn, 1,
  )
  renderer.process_into([2.0], left, right)
  assert_eq(left, [0.0])
  assert_eq(right, [2.0])
  renderer.reset(spatial_right, quarter_turn)
  renderer.process_into([2.0], left, right)
  assert_eq(left, [2.0])
  assert_eq(right, [0.0])
}

///|
test "direction updates coalesce and fade on exact frames across blocks" {
  let bank = HrirBank::new(spatial_measurements(), 48000)
  let renderer = SpatialRenderer::new(bank, 48000, spatial_front, 0.0, 2)
  let one_l = [0.0]
  let one_r = [0.0]
  renderer.process_into([1.0], one_l, one_r)
  assert_eq(one_l, [1.0])
  assert_eq(one_r, [0.0])
  renderer.set_pose(spatial_right, 0.0)
  renderer.set_pose(spatial_left, 0.0)
  renderer.process_into([], [], [])
  renderer.process_into([2.0], one_l, one_r)
  assert_eq(one_l, [1.75])
  assert_eq(one_r, [1.5])
  renderer.set_pose(spatial_right, 0.0)
  renderer.set_pose(spatial_front, 0.0)
  let many_l = Array::make(4, 0.0)
  let many_r = Array::make(4, 0.0)
  renderer.process_into([4.0, 8.0, 16.0, 32.0], many_l, many_r)
  // Direct convolution for B, half B+A, A, A over the same signal history.
  assert_eq(many_l, [2.0, 7.25, 21.0, 42.0])
  assert_eq(many_r, [4.0, 6.0, 8.0, 16.0])
  assert_eq(renderer.finish_into(one_l, one_r), 1)
  assert_eq(one_l, [20.0])
  assert_eq(one_r, [32.0])
  assert_eq(renderer.finish_into(many_l, many_r), 1)
  assert_eq(many_l, [8.0, 7.25, 21.0, 42.0])
  assert_eq(many_r, [0.0, 6.0, 8.0, 16.0])
  assert_eq(renderer.finish_into(many_l, many_r), 0)
}

///|
test "invalid blocks leave both output and pending transition unchanged" {
  let bank = HrirBank::new(spatial_measurements(), 48000)
  let renderer = SpatialRenderer::new(bank, 48000, spatial_front, 0.0, 2)
  let one_l = [0.0]
  let one_r = [0.0]
  renderer.process_into([1.0], one_l, one_r)
  renderer.set_pose(spatial_left, 0.0)
  let left = [11.0, 12.0]
  let right = [13.0, 14.0]
  assert_true(
    try {
      renderer.process_into([2.0, 1000001.0], left, right)
      false
    } catch {
      InvalidAudio => true
      _ => false
    },
  )
  assert_true(
    try {
      renderer.process_into([2.0, 4.0], left, left)
      false
    } catch {
      InvalidAudio => true
      _ => false
    },
  )
  assert_true(
    try {
      renderer.finish_into(left, one_r) |> ignore
      false
    } catch {
      InvalidAudio => true
      _ => false
    },
  )
  assert_eq(left, [11.0, 12.0])
  assert_eq(right, [13.0, 14.0])
  renderer.process_into([2.0, 4.0], left, right)
  assert_eq(left, [1.75, 2.0])
  assert_eq(right, [1.5, 4.0])
}

///|
test "EOF is sticky, pending fades drain, and reset clears history" {
  let bank = HrirBank::new(spatial_measurements(), 48000)
  let renderer = SpatialRenderer::new(bank, 48000, spatial_front, 0.0, 2)
  let left = [17.0]
  let right = [19.0]
  assert_eq(renderer.finish_into(left, right), 0)
  assert_eq(left, [17.0])
  assert_eq(right, [19.0])
  assert_true(
    try {
      renderer.process_into([1.0], left, right)
      false
    } catch {
      InvalidAudio => true
      _ => false
    },
  )
  renderer.reset(spatial_front, 0.0)
  renderer.process_into([2.0], left, right)
  renderer.set_pose(spatial_left, 0.0)
  assert_eq(renderer.finish_into([], []), 0)
  assert_true(
    try {
      renderer.set_pose(spatial_right, 0.0)
      false
    } catch {
      InvalidAudio => true
      _ => false
    },
  )
  assert_eq(renderer.finish_into(left, right), 1)
  assert_eq(left, [1.5])
  assert_eq(right, [1.0])
  renderer.reset(spatial_right, 0.0)
  renderer.process_into([1.0], left, right)
  assert_eq(left, [-1.0])
  assert_eq(right, [0.0])
}

///|
test "invalid measurement rate, tap count and non-direction inputs reject" {
  let bank = HrirBank::new(spatial_measurements(), 48000)
  assert_true(
    try {
      ignore(SpatialRenderer::new(bank, 44100, spatial_front, 0.0, 2))
      false
    } catch {
      InvalidAudio => true
      _ => false
    },
  )
  let inconsistent = spatial_measurements()
  inconsistent.push({ direction: spatial_front, hrir: Hrir::new([1.0], [1.0]), })
  assert_true(
    try {
      ignore(HrirBank::new(inconsistent, 48000))
      false
    } catch {
      InvalidAudio => true
      _ => false
    },
  )
  let renderer = SpatialRenderer::new(bank, 48000, spatial_front, 0.0, 1)
  assert_true(
    try {
      renderer.set_pose({ x: 0.0, y: 0.0, z: 0.0, }, 0.0)
      false
    } catch {
      InvalidDirection => true
      _ => false
    },
  )
  assert_true(
    try {
      renderer.set_pose(spatial_left, 1000001.0)
      false
    } catch {
      InvalidDirection => true
      _ => false
    },
  )
}
