"""Build two independent consumers and compare their output to measured HRIRs."""

import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
import math
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tempfile
from threading import Thread

ROOT = Path(__file__).resolve().parents[1]
EXAMPLES = ROOT / "examples/spatial-hosts"


def run(arguments, cwd, env):
    result = subprocess.run(
        [str(arg) for arg in arguments], cwd=cwd, env=env,
        capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=120,
    )
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    return result.stdout


def floats(values):
    return "[" + ", ".join(repr(float(value)) for value in values) + "]"


def bank_source(dataset):
    lines = ["fn measured_bank() -> @audio.HrirBank raise @audio.AudioError {", "  @audio.HrirBank::new(["]
    for measurement in dataset["measurements"]:
        x, y, z = (float(measurement["direction"][key]) for key in "xyz")
        lines.extend([
            "    {",
            f"      direction: {{ x: {x}, y: {y}, z: {z} }},",
            f'      hrir: @audio.Hrir::new({floats(measurement["left"])}, {floats(measurement["right"])}),',
            "    },",
        ])
    return "\n".join([*lines, f'  ], {dataset["hrir_rate"]})', "}", ""])


def build_consumer(work, host, args, dataset, env):
    folder = work / host
    folder.mkdir()
    name = f"demo/spatial_{host}"
    (folder / "moon.mod").write_text(
        f'name = "{name}"\nversion = "0.1.0"\n'
        f'import {{ "btlqql/moon_binaural@{args.version}" }}\n', encoding="utf-8",
    )
    comparisons = ', "moonbitlang/core/cmp"' if host == "offline" else ""
    (folder / "moon.pkg").write_text(
        f'import {{ "btlqql/moon_binaural" @audio{comparisons} }}\n'
        'pkgtype(kind: "executable")\n', encoding="utf-8",
    )
    if args.local:
        (folder / "moon.work").write_text(
            f'members = [".", {json.dumps(str(ROOT))}]\n', encoding="utf-8",
        )
    shutil.copyfile(EXAMPLES / host / "main.mbt", folder / "main.mbt")
    (folder / "bank.mbt").write_text(bank_source(dataset), encoding="utf-8")
    run([args.moon, "build", "--target", "js", "--deny-warn"], folder, env)
    output = folder / "_build/js/debug/build"
    if args.local:
        output /= name
    artifacts = list(output.glob("*.js"))
    assert len(artifacts) == 1, artifacts
    return artifacts[0]


def verify_channels(report, expected, tolerance):
    errors = {}
    for ear in ("left", "right"):
        received, reference = report[ear], expected[ear]
        assert len(received) == len(reference), (ear, len(received), len(reference))
        assert all(math.isfinite(sample) for sample in received), ear
        errors[ear] = max(abs(a - b) for a, b in zip(received, reference, strict=True))
        assert errors[ear] <= tolerance, (ear, errors[ear], tolerance)
    return errors


def verify_offline(work, executable, dataset, env):
    samples = [math.sin(i / 23) * 0.22 + math.cos(i / 97) * 0.06 for i in range(731)]
    path = work / "mono-pcm.json"
    path.write_text(json.dumps(samples), encoding="utf-8")
    report = json.loads(run(["node", executable, path], work, env))
    measurement = dataset["measurements"][0]
    taps = len(measurement["left"])
    assert report["tail_frames"] == taps - 1
    expected = {
        ear: [
            sum(
                measurement[ear][lag] * samples[index - lag]
                for lag in range(taps) if 0 <= index - lag < len(samples)
            )
            for index in range(len(samples) + taps - 1)
        ]
        for ear in ("left", "right")
    }
    return {
        "input_frames": len(samples), "tail_frames": report["tail_frames"],
        "output_frames": len(report["left"]),
        "max_abs_error": verify_channels(report, expected, 1e-12),
    }


class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, *_args):
        pass


def verify_browser(work, output, executable, browser, profile_root, dataset, env):
    app = output / "browser-app"
    app.mkdir(exist_ok=True)
    for name in ("index.html", "host.mjs"):
        shutil.copyfile(EXAMPLES / "browser" / name, app / name)
    shutil.copyfile(executable, app / "worklet.js")
    with ThreadingHTTPServer(("127.0.0.1", 0), partial(QuietHandler, directory=app)) as server:
        thread = Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            url = f"http://127.0.0.1:{server.server_port}/index.html"
            with tempfile.TemporaryDirectory(prefix="mb-", dir=profile_root) as scratch:
                command = ["node", EXAMPLES / "browser/check.mjs", browser, Path(scratch) / "profile", url]
                report = json.loads(run(command, work, env))
        finally:
            server.shutdown()
            thread.join()
    assert report["sample_rate"] == 48000
    expected = {ear: [0.0] * 1024 for ear in ("left", "right")}
    for offset, index in [(0, 0), (512, 1)]:
        for ear in expected:
            for lag, coefficient in enumerate(dataset["measurements"][index][ear]):
                expected[ear][offset + lag] = coefficient * 0.5
    return {
        "browser": report["browser"], "sample_rate": report["sample_rate"],
        "output_frames": len(report["left"]), "yaw_changed_at_frame": 384,
        "max_abs_error": verify_channels(report, expected, 1e-7),
    }


def benchmark(work, executable, env):
    result = []
    for line in run(["node", executable, "--benchmark"], work, env).splitlines():
        row = json.loads(line)
        timings = sorted(row.pop("ms"))
        assert len(timings) == 500 and all(math.isfinite(x) and x >= 0 for x in timings)
        result.append({
            **row, "p50_ms": timings[249], "p95_ms": timings[474], "p99_ms": timings[494],
            "block_duration_ms": row["frames"] * 1000 / 48000,
        })
    assert len(result) == 4
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--moon", default=os.environ.get("MOON_BIN", "moon"))
    parser.add_argument("--browser", required=True, help="path to a Chromium, Chrome, or Edge executable")
    parser.add_argument("--version", default="0.5.0")
    parser.add_argument("--local", action="store_true", help="test the checkout before publishing")
    parser.add_argument("--profile-root", type=Path, help="optional short directory for the browser temporary profile")
    parser.add_argument("--output", type=Path, default=ROOT / "_build/spatial-hosts")
    args = parser.parse_args()
    if not shutil.which("node"):
        parser.error("Node.js 22 or newer is required")
    dataset = json.loads((ROOT / "examples/drama/hrir.json").read_text(encoding="utf-8"))
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="consumers-", dir=output) as directory:
        work = Path(directory)
        env = {**os.environ, "TMPDIR": directory, "TEMP": directory, "TMP": directory}
        offline = build_consumer(work, "offline", args, dataset, env)
        browser = build_consumer(work, "browser", args, dataset, env)
        report = {
            "version": args.version, "dependency": "checkout" if args.local else "MoonCakes",
            "environment": {
                "os": platform.platform(),
                "cpu": platform.processor() or platform.machine(),
                "node": run(["node", "--version"], work, env).strip(),
                "moon": run([args.moon, "version"], work, env).splitlines()[0],
            },
            "sample_rate": dataset["hrir_rate"],
            "directions": len(dataset["measurements"]),
            "taps_per_ear": len(dataset["measurements"][0]["left"]),
            "offline": verify_offline(work, offline, dataset, env),
            "worklet": verify_browser(
                work, output, browser, args.browser, args.profile_root or output, dataset, env,
            ),
            "dsp_benchmark": benchmark(work, offline, env),
        }
    text = json.dumps(report, indent=2)
    (output / "spatial-hosts.json").write_text(text + "\n", encoding="utf-8")
    print(text)


if __name__ == "__main__":
    main()
