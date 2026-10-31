///|
test "block boundaries preserve full FIR tail" {
  let h = Hrir::new([1.0, 2.0, 3.0], [3.0, 2.0, 1.0])
  let a = Renderer::new(h)
  let all = a.process([1.0, 2.0, 3.0, 4.0])
  let b = Renderer::new(h)
  let first = b.process([1.0])
  let second = b.process([2.0, 3.0, 4.0])
  assert_eq(first.left[0], all.left[0])
  for i in 0..<3 {
    assert_eq(second.left[i], all.left[i + 1])
  }
  let tail = b.drain()
  assert_eq(tail.left[0], 17.0)
  assert_eq(tail.left[1], 12.0)
}

///|
test "transition uses old history and finishes exactly" {
  let a = Hrir::new([1.0, 0.0], [0.0, 1.0])
  let b = Hrir::new([0.0, 1.0], [1.0, 0.0])
  let r = Renderer::new(a)
  ignore(r.process([2.0]))
  r.transition(b, 2)
  let s = r.process([4.0, 8.0])
  assert_eq(s.left[0], 3.0)
  assert_eq(s.right[0], 3.0)
  assert_eq(s.left[1], 4.0)
  assert_eq(s.right[1], 8.0)
  assert_eq(r.process([16.0]).left[0], 8.0)
}

///|
test "spherical nearest selection, ownership and bad inputs" {
  let raw = [1.0]
  let a = Hrir::new(raw, [2.0])
  raw[0] = 9.0
  assert_eq(Renderer::new(a).process([1.0]).left[0], 1.0)
  let b = Hrir::new([3.0], [4.0])
  let h = select(
    [
      { direction: { x: 1.0, y: 0.0, z: 0.0, }, hrir: a, },
      { direction: { x: 0.0, y: 1.0, z: 0.0, }, hrir: b, },
    ],
    { x: 0.0, y: 7.0, z: 0.0, },
  )
  assert_eq(Renderer::new(h).process([1.0]).left[0], 3.0)
  assert_true(
    try {
      ignore(Hrir::new([], [1.0]))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(select([], { x: 0.0, y: 0.0, z: 0.0, }))
      false
    } catch {
      _ => true
    },
  )
}
