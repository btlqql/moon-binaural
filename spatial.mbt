///|
/// Owned set of normalized measurement directions and equal-length HRIRs.
pub struct HrirBank {
  priv measurements : Array[Measurement]
  priv sample_rate : Int32
}

///|
/// Build a bank for one sample rate in Hz. First entry wins exact direction ties.
pub fn HrirBank::new(
  measurements : Array[Measurement],
  sample_rate : Int32,
) -> HrirBank raise AudioError {
  if measurements.is_empty() ||
    measurements.length() > 4096 ||
    sample_rate < 1 ||
    sample_rate > 192000 {
    raise InvalidAudio
  }
  let taps = measurements[0].hrir.left.length()
  let owned : Array[Measurement] = []
  for m in measurements {
    if m.hrir.left.length() != taps {
      raise InvalidAudio
    }
    owned.push({
      direction: normalized(m.direction),
      hrir: Hrir::new(m.hrir.left, m.hrir.right),
    })
  }
  { measurements: owned, sample_rate, }
}

///|
fn HrirBank::nearest_pose(
  self : HrirBank,
  source : Direction,
  listener_yaw : Double,
) -> Int32 raise AudioError {
  if !finite(listener_yaw) || listener_yaw.abs() > 1.0e6 {
    raise InvalidDirection
  }
  let d = normalized(source)
  let sin = @math.sin(listener_yaw)
  let cos = @math.cos(listener_yaw)
  let x = d.x * cos - d.y * sin
  let y = d.x * sin + d.y * cos
  let mut best = 0
  let mut score = -2.0
  for i in 0..<self.measurements.length() {
    let m = self.measurements[i].direction
    let dot = x * m.x + y * m.y + d.z * m.z
    if dot > score {
      best = i
      score = dot
    }
  }
  best
}

///|
/// Stateful mono-to-stereo HRIR processing for host-owned PCM buffers.
pub struct SpatialRenderer {
  priv bank : HrirBank
  priv renderer : Renderer
  priv fade_frames : Int32
  priv mut selected : Int32
  priv mut requested : Int32
  priv mut has_input : Bool
  priv mut tail_remaining : Int32
}

///|
/// Source is a world-space direction relative to the listener position. Axes
/// are x right, y forward, z up. Listener yaw is in radians, positive from +y
/// toward +x. The host PCM sample rate must match the bank.
pub fn SpatialRenderer::new(
  bank : HrirBank,
  sample_rate : Int32,
  source : Direction,
  listener_yaw : Double,
  fade_frames : Int32,
) -> SpatialRenderer raise AudioError {
  if sample_rate != bank.sample_rate || fade_frames < 1 || fade_frames > 480000 {
    raise InvalidAudio
  }
  let selected = bank.nearest_pose(source, listener_yaw)
  {
    bank,
    renderer: Renderer::new(bank.measurements[selected].hrir),
    fade_frames,
    selected,
    requested: selected,
    has_input: false,
    tail_remaining: -1,
  }
}

///|
/// Latch the nearest measured direction for subsequent frames. Updates before
/// the next frame coalesce. An active fade completes using the same history
/// on both sides, then the latest pending direction starts on the next frame.
pub fn SpatialRenderer::set_pose(
  self : SpatialRenderer,
  source : Direction,
  listener_yaw : Double,
) -> Unit raise AudioError {
  if self.tail_remaining >= 0 {
    raise InvalidAudio
  }
  self.requested = self.bank.nearest_pose(source, listener_yaw)
}

///|
fn SpatialRenderer::step_into(
  self : SpatialRenderer,
  sample : Double,
  left : Array[Double],
  right : Array[Double],
  frame : Int32,
) -> Unit {
  if self.renderer.target is None && self.requested != self.selected {
    self.selected = self.requested
    let target = self.bank.measurements[self.selected].hrir
    self.renderer.begin_transition(target, self.fade_frames)
  }
  self.renderer.step_into(sample, left, right, frame)
}

///|
/// Process one whole PCM block in order into caller-owned buffers of equal
/// length. The three arrays must be distinct. Validation precedes any writes
/// or change to stream state. An empty block does not advance time.
pub fn SpatialRenderer::process_into(
  self : SpatialRenderer,
  input : Array[Double],
  left : Array[Double],
  right : Array[Double],
) -> Unit raise AudioError {
  if self.tail_remaining >= 0 ||
    input.length() != left.length() ||
    input.length() != right.length() ||
    physical_equal(input, left) ||
    physical_equal(input, right) ||
    physical_equal(left, right) {
    raise InvalidAudio
  }
  validate_audio_block(input, self.renderer.history.length())
  for i in 0..<input.length() {
    self.step_into(input[i], left, right, i)
  }
  if !input.is_empty() {
    self.has_input = true
  }
}

///|
/// Mark end of input and write up to the output capacity from the FIR tail.
/// Each call returns the number of newly written frames. Entries beyond that
/// count are untouched. A nonempty stream has exactly taps minus one tail
/// frames. A zero capacity call marks EOF without consuming any tail frame.
pub fn SpatialRenderer::finish_into(
  self : SpatialRenderer,
  left : Array[Double],
  right : Array[Double],
) -> Int32 raise AudioError {
  if left.length() != right.length() || physical_equal(left, right) {
    raise InvalidAudio
  }
  if self.tail_remaining < 0 {
    self.tail_remaining = if self.has_input {
      self.renderer.history.length() - 1
    } else {
      0
    }
  }
  let count = @cmp.minimum(left.length(), self.tail_remaining)
  for i in 0..<count {
    self.step_into(0.0, left, right, i)
  }
  self.tail_remaining -= count
  count
}

///|
/// Clear all stream history, the active fade and any pending update. Select
/// the given starting pose before the next input, without fading from the
/// previous stream. The bank and the renderer's own buffers are reused.
pub fn SpatialRenderer::reset(
  self : SpatialRenderer,
  source : Direction,
  listener_yaw : Double,
) -> Unit raise AudioError {
  let selected = self.bank.nearest_pose(source, listener_yaw)
  let renderer = self.renderer
  for i in 0..<renderer.history.length() {
    renderer.history[i] = 0.0
  }
  renderer.cursor = 0
  renderer.current = self.bank.measurements[selected].hrir
  renderer.target = None
  renderer.progress = 0
  renderer.fade_length = 0
  self.selected = selected
  self.requested = selected
  self.has_input = false
  self.tail_remaining = -1
}
