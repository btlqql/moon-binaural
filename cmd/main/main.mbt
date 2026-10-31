///|
extern "js" fn read_input(path : String) -> String =
  #| p => {const f=process.getBuiltinModule('fs'); const s=f.statSync(p); if(s.size>16000000)throw Error('input exceeds 16 MB');return f.readFileSync(p,'utf8');}

///|
extern "js" fn status(code : Int32) -> Unit =
  #| n => {process.exitCode=n;}

///|
fn field(j : Json, name : String) -> Json raise {
  guard j is Object(o) else { fail("expected object") }
  guard o.get(name) is Some(v) else { fail("missing field " + name) }
  v
}

///|
fn arr(j : Json) -> Array[Json] raise {
  guard j is Array(a) else { fail("expected array") }
  a
}

///|
fn num(j : Json) -> Double raise {
  guard j is Number(n, ..) else { fail("expected number") }
  if n != n || n - n != 0.0 {
    fail("nonfinite number")
  }
  n
}

///|
fn main {
  try {
    let args = @env.args()
    if args.length() < 3 {
      fail("usage: moon run cmd/main --target js -- request.json")
    }
    let request = @json.parse(read_input(args[args.length() - 1]))
    println(execute(request).stringify())
  } catch {
    error => {
      println(
        Json::object({ "ok": Json(false), "error": Json(error.to_string()) }).stringify(),
      )
      status(1)
    }
  }
}

///|
fn doubles(j : Json) -> Array[Double] raise {
  arr(j).map(fn(x) raise { num(x) })
}

///|
fn execute(j : Json) -> Json raise {
  if j is Object(fields) && fields.get("measurements") is Some(_) {
    return scene(j)
  }
  let renderer = @core.Renderer::new(
    @core.Hrir::new(doubles(field(j, "left")), doubles(field(j, "right"))),
  )
  let out : Array[Json] = []
  for block in arr(field(j, "blocks")) {
    let s = renderer.process(doubles(block))
    out.push(Json::object({ "left": Json(s.left), "right": Json(s.right) }))
  }
  let tail = renderer.drain()
  Json::object({
    "ok": Json(true),
    "blocks": Json(out),
    "tail": Json::object({ "left": Json(tail.left), "right": Json(tail.right) }),
  })
}

///|
fn integer(j : Json) -> Int32 raise {
  let n = num(j)
  if n < 0.0 || n > 1000000.0 || n.to_int().to_double() != n {
    fail("expected nonnegative integer")
  }
  n.to_int()
}

///|
fn direction(j : Json) -> @core.Direction raise {
  { x: num(field(j, "x")), y: num(field(j, "y")), z: num(field(j, "z")), }
}

///|
extern "js" fn write_wav(
  path : String,
  rate : Int32,
  left : FixedArray[Double],
  right : FixedArray[Double],
) -> Bool =
  #| (p,r,l,h) => {try {const f=process.getBuiltinModule('fs');const b=Buffer.alloc(44+l.length*4);b.write('RIFF');b.writeUInt32LE(b.length-8,4);b.write('WAVEfmt ',8);b.writeUInt32LE(16,16);b.writeUInt16LE(1,20);b.writeUInt16LE(2,22);b.writeUInt32LE(r,24);b.writeUInt32LE(r*4,28);b.writeUInt16LE(4,32);b.writeUInt16LE(16,34);b.write('data',36);b.writeUInt32LE(l.length*4,40);for(let i=0;i<l.length;i++){b.writeInt16LE(Math.max(-32768,Math.min(32767,Math.round(l[i]*32767))),44+i*4);b.writeInt16LE(Math.max(-32768,Math.min(32767,Math.round(h[i]*32767))),46+i*4);}f.writeFileSync(p,b,{flag:'wx'});return true;}catch{return false;}}

///|
fn scene(j : Json) -> Json raise {
  let measurements : Array[@core.Measurement] = []
  for m in arr(field(j, "measurements")) {
    measurements.push({
      direction: direction(field(m, "direction")),
      hrir: @core.Hrir::new(
        doubles(field(m, "left")),
        doubles(field(m, "right")),
      ),
    })
  }
  let frames : Array[@core.Keyframe] = []
  for f in arr(field(j, "keyframes")) {
    frames.push({
      at: integer(field(f, "at")),
      direction: direction(field(f, "direction")),
    })
  }
  let rate = integer(field(j, "sample_rate"))
  let result = @core.render_scene(
    doubles(field(j, "input")),
    measurements,
    frames,
    rate,
    integer(field(j, "hrir_rate")),
    integer(field(j, "fade_samples")),
  )
  let output = if j is Object(fields) &&
    fields.get("output") is Some(String(path)) {
    if !write_wav(
        path,
        rate,
        FixedArray::makei(result.audio.left.length(), fn(i) {
          result.audio.left[i]
        }),
        FixedArray::makei(result.audio.right.length(), fn(i) {
          result.audio.right[i]
        }),
      ) {
      fail("output exists or cannot be written")
    }
    Json(path)
  } else {
    Json::null()
  }
  Json::object({
    "ok": Json(true),
    "left": Json(result.audio.left),
    "right": Json(result.audio.right),
    "peak": Json(result.peak),
    "clipped_samples": Json(result.clipped_samples),
    "output": output,
  })
}
