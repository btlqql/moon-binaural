///|
pub(all) suberror AudioError {
  InvalidAudio
  InvalidDirection
  TransitionBusy
}

///|
pub struct Hrir {
  left : Array[Double]
  right : Array[Double]
}

///|
pub(all) struct Stereo {
  left : Array[Double]
  right : Array[Double]
}

///|
pub struct Renderer {
  mut current : Hrir
  mut target : Hrir?
  history : Array[Double]
  mut cursor : Int32
  mut progress : Int32
  mut fade_length : Int32
}

///|
fn finite(x : Double) -> Bool {
  x == x && x - x == 0.0
}

///|
pub fn Hrir::new(
  left : Array[Double],
  right : Array[Double],
) -> Hrir raise AudioError {
  if left.is_empty() || left.length() != right.length() || left.length() > 4096 {
    raise InvalidAudio
  }
  for x in left {
    if !finite(x) || x.abs() > 1.0e6 {
      raise InvalidAudio
    }
  }
  for x in right {
    if !finite(x) || x.abs() > 1.0e6 {
      raise InvalidAudio
    }
  }
  { left: left.copy(), right: right.copy(), }
}

///|
pub fn Renderer::new(hrir : Hrir) -> Renderer {
  {
    current: hrir,
    target: None,
    history: Array::make(hrir.left.length(), 0.0),
    cursor: 0,
    progress: 0,
    fade_length: 0,
  }
}

// The old and new filters both read the complete existing input history.
// A transition cannot lose a block's tail or restart a newly selected filter.

///|
pub fn Renderer::transition(
  self : Renderer,
  target : Hrir,
  samples : Int32,
) -> Unit raise AudioError {
  if self.target is Some(_) {
    raise TransitionBusy
  }
  if target.left.length() != self.history.length() ||
    samples < 1 ||
    samples > 480000 {
    raise InvalidAudio
  }
  self.begin_transition(target, samples)
}

///|
fn Renderer::begin_transition(
  self : Renderer,
  target : Hrir,
  samples : Int32,
) -> Unit {
  self.target = Some(target)
  self.progress = 0
  self.fade_length = samples
}

///|
fn Renderer::step_into(
  self : Renderer,
  input : Double,
  left : Array[Double],
  right : Array[Double],
  frame : Int32,
) -> Unit {
  self.history[self.cursor] = input
  let size = self.history.length()
  let old = self.current
  let mut old_left = 0.0
  let mut old_right = 0.0
  match self.target {
    None => {
      for tap in 0..<size {
        let x = self.history[(self.cursor - tap + size) % size]
        old_left += old.left[tap] * x
        old_right += old.right[tap] * x
      }
      left[frame] = old_left
      right[frame] = old_right
    }
    Some(next) => {
      let mut new_left = 0.0
      let mut new_right = 0.0
      for tap in 0..<size {
        let x = self.history[(self.cursor - tap + size) % size]
        old_left += old.left[tap] * x
        old_right += old.right[tap] * x
        new_left += next.left[tap] * x
        new_right += next.right[tap] * x
      }
      self.progress += 1
      let alpha = self.progress.to_double() / self.fade_length.to_double()
      left[frame] = (1.0 - alpha) * old_left + alpha * new_left
      right[frame] = (1.0 - alpha) * old_right + alpha * new_right
      if self.progress == self.fade_length {
        self.current = next
        self.target = None
      }
    }
  }
  self.cursor = (self.cursor + 1) % size
}

///|
fn validate_audio_block(
  input : Array[Double],
  taps : Int32,
) -> Unit raise AudioError {
  if input.length() > 1000000 ||
    input.length().to_int64() * taps.to_int64() > 16000000L {
    raise InvalidAudio
  }
  // Validate the whole block before mutating stream state.
  for x in input {
    if !finite(x) || x.abs() > 1.0e6 {
      raise InvalidAudio
    }
  }
}

///|
pub fn Renderer::process(
  self : Renderer,
  input : Array[Double],
) -> Stereo raise AudioError {
  validate_audio_block(input, self.history.length())
  let left = Array::make(input.length(), 0.0)
  let right = Array::make(input.length(), 0.0)
  for i in 0..<input.length() {
    self.step_into(input[i], left, right, i)
  }
  { left, right, }
}

// Drains M-1 zeros; caller controls end-of-stream. Repeated drains advance time.

///|
pub fn Renderer::drain(self : Renderer) -> Stereo raise AudioError {
  let out : Stereo = { left: [], right: [], }
  let mut remaining = self.history.length() - 1
  while remaining > 0 {
    let count = if remaining > 1024 { 1024 } else { remaining }
    let block = self.process(Array::make(count, 0.0))
    for x in block.left {
      out.left.push(x)
    }
    for x in block.right {
      out.right.push(x)
    }
    remaining -= count
  }
  out
}

///|
pub(all) struct Direction {
  x : Double
  y : Double
  z : Double
}

///|
pub(all) struct Measurement {
  direction : Direction
  hrir : Hrir
}

///|
fn normalized(d : Direction) -> Direction raise AudioError {
  if !finite(d.x) ||
    !finite(d.y) ||
    !finite(d.z) ||
    d.x.abs() > 1.0e6 ||
    d.y.abs() > 1.0e6 ||
    d.z.abs() > 1.0e6 {
    raise InvalidDirection
  }
  let length = (d.x * d.x + d.y * d.y + d.z * d.z).sqrt()
  if length < 1.0e-12 {
    raise InvalidDirection
  }
  { x: d.x / length, y: d.y / length, z: d.z / length, }
}

// Nearest measured direction on the sphere; deterministic first-entry ties.
// No undocumented interpolation or individual-listener accuracy claim.

///|
pub fn select(
  measurements : Array[Measurement],
  direction : Direction,
) -> Hrir raise AudioError {
  if measurements.is_empty() || measurements.length() > 4096 {
    raise InvalidDirection
  }
  let d = normalized(direction)
  let mut best = 0
  let mut score = -2.0
  for i in 0..<measurements.length() {
    let m = normalized(measurements[i].direction)
    let dot = d.x * m.x + d.y * m.y + d.z * m.z
    if dot > score {
      best = i
      score = dot
    }
  }
  measurements[best].hrir
}
