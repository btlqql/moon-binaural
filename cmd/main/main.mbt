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
