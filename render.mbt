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
  self.target = Some(target)
  self.progress = 0
  self.fade_length = samples
}

///|
fn convolve(renderer : Renderer, h : Hrir) -> (Double, Double) {
  let mut l = 0.0
  let mut r = 0.0
  let size = renderer.history.length()
  for tap in 0..<size {
    let x = renderer.history[(renderer.cursor - tap + size) % size]
    l += h.left[tap] * x
    r += h.right[tap] * x
  }
  (l, r)
}

///|
pub fn Renderer::process(
  self : Renderer,
  input : Array[Double],
) -> Stereo raise AudioError {
  if input.length() > 1000000 ||
    input.length().to_int64() * self.history.length().to_int64() > 16000000L {
    raise InvalidAudio
  }
  // Validate the whole block before mutating stream state.
  for x in input {
    if !finite(x) || x.abs() > 1.0e6 {
      raise InvalidAudio
    }
  }
  let left : Array[Double] = []
  let right : Array[Double] = []
  for x in input {
    self.history[self.cursor] = x
    let (old_l, old_r) = convolve(self, self.current)
    let (l, r) = match self.target {
      None => (old_l, old_r)
      Some(next) => {
        let (new_l, new_r) = convolve(self, next)
        self.progress += 1
        let alpha = self.progress.to_double() / self.fade_length.to_double()
        if self.progress == self.fade_length {
          self.current = next
          self.target = None
        }
        (
          (1.0 - alpha) * old_l + alpha * new_l,
          (1.0 - alpha) * old_r + alpha * new_r,
        )
      }
    }
    left.push(l)
    right.push(r)
    self.cursor = (self.cursor + 1) % self.history.length()
  }
  { left, right, }
}

// Drains M-1 zeros; caller controls end-of-stream. Repeated drains advance time.

///|
pub fn Renderer::drain(self : Renderer) -> Stereo raise AudioError {
  self.process(Array::make(self.history.length() - 1, 0.0))
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
