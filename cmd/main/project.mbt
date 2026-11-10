///|
extern "js" fn resolve_from(document : String, name : String) -> String =
  #| (document, name) => {
  #|   const path = process.getBuiltinModule('path');
  #|   return path.resolve(path.dirname(document), name);
  #| }

///|
extern "js" fn read_pcm(path : String) -> Bytes =
  #| path => {
  #|   try {
  #|     const fs = process.getBuiltinModule('fs');
  #|     const size = fs.statSync(path);
  #|     if (!size.isFile() || size.size > 8000000) return new Uint8Array();
  #|     return new Uint8Array(fs.readFileSync(path));
  #|   } catch { return new Uint8Array(); }
  #| }

///|
extern "js" fn create_output(directory : String) -> Bool =
  #| path => {
  #|   try { process.getBuiltinModule('fs').mkdirSync(path); return true; }
  #|   catch { return false; }
  #| }

///|
extern "js" fn discard_output(directory : String) -> Unit =
  #| directory => {
  #|   const fs = process.getBuiltinModule('fs');
  #|   const path = process.getBuiltinModule('path');
  #|   for (const name of ['binaural.wav', 'pan.wav', 'report.json']) {
  #|     try { fs.unlinkSync(path.join(directory, name)); } catch {}
  #|   }
  #|   try { fs.rmdirSync(directory); } catch {}
  #| }

///|
extern "js" fn write_report(path : String, report : String) -> Bool =
  #| (path, report) => {
  #|   try {
  #|     process.getBuiltinModule('fs').writeFileSync(path, report + '\n', {flag:'wx'});
  #|     return true;
  #|   } catch { return false; }
  #| }

///|
fn output_wav(path : String, rate : Int32, audio : @core.Stereo) -> Unit raise {
  if !write_wav(
      path,
      rate,
      FixedArray::makei(audio.left.length(), fn(i) { audio.left[i] }),
      FixedArray::makei(audio.right.length(), fn(i) { audio.right[i] }),
    ) {
    fail("cannot write " + path)
  }
}

///|
fn frames_from_ms(j : Json, rate : Int32) -> Int32 raise {
  let ms = integer(j)
  if ms > 30000 {
    fail("timeline positions are limited to 30000 ms")
  }
  ((ms.to_int64() * rate.to_int64() + 500L) / 1000L).to_int()
}

///|
fn mix_report(metrics : @core.MixMetrics, gain : Double, rate : Int32) -> Json {
  Json::object({
    "input_peak": Json(metrics.peak),
    "input_rms": Json(metrics.rms),
    "gain_applied": Json(gain),
    "output_peak": Json(metrics.peak * gain),
    "output_rms": Json(metrics.rms * gain),
    "input_clipped_samples": Json(metrics.clipped_samples),
    "omitted_clip_spans": Json(metrics.omitted_spans),
    "input_clip_spans": Json(
      metrics.clip_spans.map(fn(span) {
        Json::object({
          "start_frame": Json(span.start_frame),
          "end_frame_exclusive": Json(span.end_frame),
          "start_ms": Json(
            span.start_frame.to_double() * 1000.0 / rate.to_double(),
          ),
          "end_ms_exclusive": Json(
            span.end_frame.to_double() * 1000.0 / rate.to_double(),
          ),
        })
      }),
    ),
  })
}

///|
fn overload_report(
  review : @core.ReviewedPreview,
  names : Array[String],
  rate : Int32,
) -> Json {
  let ms_per_frame = 1000.0 / rate.to_double()
  Json::object({
    "stage": Json("binaural_before_attenuation"),
    "merge_gap_frames": Json(review.merge_gap_frames),
    "omitted_cues": Json(review.omitted_cues),
    "cues": Json(
      review.overload_cues.map(fn(cue) {
        Json::object({
          "start_frame": Json(cue.start_frame),
          "end_frame_exclusive": Json(cue.end_frame),
          "start_ms": Json(cue.start_frame.to_double() * ms_per_frame),
          "end_ms_exclusive": Json(cue.end_frame.to_double() * ms_per_frame),
          "clipped_samples": Json(cue.clipped_samples),
          "peak_frame": Json(cue.peak_frame),
          "peak_ms": Json(cue.peak_frame.to_double() * ms_per_frame),
          "peak_channel": Json(
            match cue.peak_channel {
              Left => "left"
              Right => "right"
            },
          ),
          "peak_sample": Json(cue.peak_sample),
          "contributions": Json(
            cue.contributions.map(fn(track) {
              Json::object({
                "track": Json(names[track.source_index]),
                "signed_sample": Json(track.sample),
                "adds_to_peak": Json(track.sample * cue.peak_sample > 0.0),
              })
            }),
          ),
        })
      }),
    ),
  })
}

///|
fn run_project(manifest_path : String, output : String) -> Json raise {
  let j = @json.parse(read_input(manifest_path))
  guard field(j, "format") is String("moon-binaural-scene-v1") else {
    fail("unsupported project format")
  }
  guard field(j, "hrir_file") is String(hrir_file) else {
    fail("hrir_file must be a path")
  }
  let hrir = @json.parse(read_input(resolve_from(manifest_path, hrir_file)))
  let rate = integer(field(hrir, "hrir_rate"))
  if rate < 1 || rate > 192000 {
    fail("invalid HRIR sample rate")
  }
  let measurements = parse_measurements(field(hrir, "measurements"))
  let fade = frames_from_ms(field(j, "fade_ms"), rate)
  let rows = arr(field(j, "tracks"))
  if rows.is_empty() || rows.length() > 16 {
    fail("expected 1 to 16 tracks")
  }
  let sources : Array[@core.Source] = []
  let tracks : Array[Json] = []
  let track_names : Array[String] = []
  let names : Map[String, Bool] = Map([])
  let mut total_frames = 0L
  for row in rows {
    guard field(row, "name") is String(name) else {
      fail("track name must be a string")
    }
    if name.is_empty() || names.get(name) is Some(_) {
      fail("empty or duplicate track name")
    }
    names[name] = true
    track_names.push(name)
    guard field(row, "wav") is String(path) else { fail("wav must be a path") }
    let decoded = @core.decode_mono_wav(
      read_pcm(resolve_from(manifest_path, path)),
    ) catch {
      _ => fail("cannot read mono PCM16 WAV for track " + name + ": " + path)
    }
    if decoded.sample_rate != rate {
      fail("sample rate differs from HRIR for track " + name)
    }
    total_frames += decoded.samples.length().to_int64()
    if total_frames > 5760000L {
      fail("total source frame limit")
    }
    let start = frames_from_ms(field(row, "start_ms"), rate)
    let gain = num(field(row, "gain"))
    let keys : Array[@core.Keyframe] = []
    for key in arr(field(row, "keyframes")) {
      keys.push({
        at: frames_from_ms(field(key, "at_ms"), rate),
        direction: direction(key),
      })
    }
    sources.push({ samples: decoded.samples, start, gain, keyframes: keys, })
    tracks.push(
      Json::object({
        "name": Json(name),
        "wav": Json(path),
        "start_frame": Json(start),
        "end_frame_exclusive": Json(start + decoded.samples.length()),
        "source_frames": Json(decoded.samples.length()),
        "gain": Json(gain),
        "keyframes": Json(
          keys.map(fn(k) {
            Json::object({
              "at_frame": Json(k.at),
              "x": Json(k.direction.x),
              "y": Json(k.direction.y),
              "z": Json(k.direction.z),
            })
          }),
        ),
      }),
    )
  }
  let review = @core.render_reviewed_comparison(
    sources, measurements, rate, rate, fade,
  )
  let pair = review.preview
  let report = Json::object({
    "ok": Json(true),
    "sample_rate": Json(rate),
    "frames": Json(pair.binaural.left.length()),
    "tracks": Json(tracks),
    "fade_samples": Json(fade),
    "rms_target": match pair.matched_rms {
      Some(value) => Json(value)
      None => Json::null()
    },
    "binaural": mix_report(pair.binaural_input, pair.binaural_gain, rate),
    "pan": mix_report(pair.pan_input, pair.pan_gain, rate),
    "overload_review": overload_report(review, track_names, rate),
  })
  if !create_output(output) {
    fail("output directory already exists or cannot be created")
  }
  let base = output + "/report.json"
  errdefer discard_output(output)
  output_wav(resolve_from(base, "binaural.wav"), rate, pair.binaural)
  output_wav(resolve_from(base, "pan.wav"), rate, pair.pan)
  if !write_report(base, report.stringify()) {
    fail("cannot write report.json")
  }
  report
}
