///|
pub(all) struct MonoPcm {
  sample_rate : Int32
  samples : Array[Double]
}

///|
fn read_le(data : Bytes, at : Int32, width : Int32) -> Int64 {
  let mut value = 0L
  for i in 0..<width {
    value = value | (data[at + i].to_int().to_int64() << (8 * i))
  }
  value
}

///|
fn fourcc(data : Bytes, at : Int32, tag : Bytes) -> Bool {
  for i in 0..<4 {
    if data[at + i] != tag[i] {
      return false
    }
  }
  true
}

///|
/// Decode bounded RIFF/WAVE PCM16 mono data. Unknown chunks are skipped with padding.
pub fn decode_mono_wav(data : Bytes) -> MonoPcm raise AudioError {
  if data.length() < 12 ||
    data.length() > 8000000 ||
    !fourcc(data, 0, b"RIFF") ||
    !fourcc(data, 8, b"WAVE") ||
    read_le(data, 4, 4) != (data.length() - 8).to_int64() {
    raise InvalidAudio
  }
  let mut rate = 0
  let mut sample_start = -1
  let mut sample_bytes = 0
  let mut position = 12
  while position < data.length() {
    if data.length() - position < 8 {
      raise InvalidAudio
    }
    let size = read_le(data, position + 4, 4)
    let body = position + 8
    let end = body.to_int64() + size + (size & 1L)
    if end > data.length().to_int64() {
      raise InvalidAudio
    }
    if fourcc(data, position, b"fmt ") {
      if rate != 0 ||
        size < 16L ||
        read_le(data, body, 2) != 1L ||
        read_le(data, body + 2, 2) != 1L ||
        read_le(data, body + 12, 2) != 2L ||
        read_le(data, body + 14, 2) != 16L {
        raise InvalidAudio
      }
      let hz = read_le(data, body + 4, 4)
      if hz < 1L || hz > 192000L || read_le(data, body + 8, 4) != hz * 2L {
        raise InvalidAudio
      }
      rate = hz.to_int()
    } else if fourcc(data, position, b"data") {
      if sample_start != -1 ||
        size == 0L ||
        (size & 1L) != 0L ||
        size / 2L > offline_frame_limit.to_int64() {
        raise InvalidAudio
      }
      sample_start = body
      sample_bytes = size.to_int()
    }
    position = end.to_int()
  }
  if rate == 0 || sample_start < 0 {
    raise InvalidAudio
  }
  let samples = Array::makei(sample_bytes / 2, fn(i) {
    let value = read_le(data, sample_start + 2 * i, 2).to_int()
    (if value >= 32768 { value - 65536 } else { value }).to_double() / 32768.0
  })
  { sample_rate: rate, samples, }
}
