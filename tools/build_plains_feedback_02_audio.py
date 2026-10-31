#!/usr/bin/env python3
"""Build scoped plains material cues from preserved CC0 field recordings.

No oscillator or generated-noise layer is used. Every layer comes from the
existing reviewed library; source SHA and the exact filters remain in provenance.
"""
import array
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys
import wave

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/audio/plains_feedback_02"
RATE = 48000
VERSION = "plains-material-feedback-02-v1"
SOURCES = {
    "break1": ("v3", "hit/bfh1_breaking_01.ogg"),
    "break2": ("v3", "hit/bfh1_breaking_02.ogg"),
    "break3": ("v3", "hit/bfh1_breaking_03.ogg"),
    "hit3": ("v2", "hit/bfh1_hit_03.ogg"),
    "metal1": ("v2", "material/metal_hit_01.ogg"),
    "metal2": ("v2", "material/metal_hit_02.ogg"),
    "wood1": ("v2", "material/wood_hit_01.ogg"),
    "wood3": ("v2", "material/wood_hit_03.ogg"),
    "wood4": ("v2", "material/wood_hit_04.ogg"),
}
# source, rate multiplier, high/low-pass Hz, duration, offset, relative gain
RECIPES = {
    "shell_hurt": {"duration": .115, "peak": .42, "layers": [["hit3", 1.35, 180, 3900, .105, 0, 1.0]]},
    "shell_death": {"duration": .39, "peak": .70, "layers": [["break1", 1.32, 120, 8200, .19, 0, 1.0], ["break3", 1.52, 650, 6500, .26, .075, .45], ["metal2", 1.5, 550, 5200, .18, .12, .10]]},
    "shell_land": {"duration": .18, "peak": .37, "layers": [["wood1", .84, 65, 1900, .16, 0, 1.0], ["metal2", 1.4, 450, 3900, .12, .025, .18]]},
    "wing_hurt": {"duration": .12, "peak": .42, "layers": [["metal2", 1.64, 420, 4800, .11, 0, 1.0]]},
    "wing_death": {"duration": .41, "peak": .70, "layers": [["break2", 1.47, 320, 7900, .14, 0, .75], ["metal1", 1.19, 200, 5900, .34, .035, 1.0], ["wood1", 1.22, 80, 1600, .075, .01, .13]]},
    "wing_land": {"duration": .22, "peak": .37, "layers": [["metal2", .91, 130, 3600, .20, 0, 1.0], ["wood1", 1.1, 70, 1600, .10, 0, .23]]},
    "plant_hurt": {"duration": .12, "peak": .42, "layers": [["wood3", 1.45, 130, 3900, .11, 0, 1.0]]},
    "plant_death": {"duration": .42, "peak": .70, "layers": [["break2", .94, 190, 6100, .20, 0, .82], ["wood4", 1.16, 120, 4200, .29, .025, 1.0], ["wood1", .85, 110, 2800, .15, .18, .23]]},
    "plant_land": {"duration": .18, "peak": .37, "layers": [["wood1", .92, 75, 2300, .16, 0, 1.0], ["wood3", 1.7, 350, 4800, .08, .035, .19]]},
}


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def decode(path, speed, high, low, duration):
    filters = f"asetrate={RATE}*{speed},aresample={RATE},highpass=f={high},lowpass=f={low}"
    command = ["ffmpeg", "-v", "error", "-i", str(path), "-af", filters,
               "-ar", str(RATE), "-ac", "1", "-f", "f32le", "pipe:1"]
    samples = array.array("f")
    samples.frombytes(subprocess.check_output(command, timeout=30))
    if sys.byteorder != "little":
        samples.byteswap()
    peak = max((abs(v) for v in samples), default=0)
    if peak < 1e-5:
        raise ValueError("Silent source: " + str(path))
    onset = next(i for i, value in enumerate(samples) if abs(value) > peak * .015)
    # Retain .5ms ahead of the recorded transient, rather than introducing a
    # click or replacing it with an artificial impulse.
    onset = max(0, onset - 24)
    body = list(samples[onset:onset + round(duration * RATE)])
    peak = max(abs(v) for v in body)
    fade = min(round(.012 * RATE), len(body))
    for i in range(len(body)):
        tail = min(1.0, (len(body) - i - 1) / max(1, fade))
        body[i] = body[i] / peak * tail
    return body, filters, onset


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sources = {}
    for key, (version, name) in SOURCES.items():
        ledger = json.loads((ROOT / f"config/audio_director/{version}/sources.json").read_text())
        row = ledger["sources"][name]
        path = ROOT / row["path"]
        if digest(path) != row["sha256"] or row["license"] != "CC0-1.0":
            raise ValueError("Source/license mismatch: " + key)
        row = dict(row)
        page = path.parent / "source-page.html"
        if digest(page) != row["source_page_sha256"]:
            raise ValueError("Source-page proof mismatch: " + key)
        row["source_page_path"] = str(page.relative_to(ROOT))
        row["license_path"] = "assets/audio/director_v2/_sources/CC0-1.0.txt"
        row["license_sha256"] = digest(ROOT / row["license_path"])
        sources[key] = row
    outputs = []
    for name, recipe in RECIPES.items():
        samples = [0.0] * round(recipe["duration"] * RATE)
        layers = []
        for key, speed, high, low, duration, offset, gain in recipe["layers"]:
            body, filters, onset = decode(ROOT / sources[key]["path"], speed, high, low, duration)
            start = round(offset * RATE)
            for i, value in enumerate(body[:len(samples) - start]):
                samples[start + i] += value * gain
            layers.append({"source": key, "filters": filters, "source_onset_frame": onset,
                           "duration": duration, "offset": offset, "relative_gain": gain})
        peak = max(abs(v) for v in samples)
        gain = recipe["peak"] / peak
        pcm = array.array("h", [round(max(-.999, min(.999, v * gain)) * 32767) for v in samples])
        if sys.byteorder != "little":
            pcm.byteswap()
        path = OUT / (name + ".wav")
        with wave.open(str(path), "wb") as wav:
            wav.setnchannels(1)
            wav.setsampwidth(2)
            wav.setframerate(RATE)
            wav.writeframes(pcm.tobytes())
        rms = math.sqrt(sum((v * gain) ** 2 for v in samples) / len(samples))
        outputs.append({"path": str(path.relative_to(ROOT)), "sha256": digest(path),
                        "duration": len(samples) / RATE, "rate": RATE, "channels": 1,
                        "frame_count": len(samples), "sample_width_bits": 16,
                        "bytes": path.stat().st_size,
                        "peak": recipe["peak"], "rms": rms, "post_mix_gain": gain,
                        "layers": layers})
    provenance = {"schema_version": 1, "version": VERSION, "generator": "tools/build_plains_feedback_02_audio.py",
                  "generator_sha256": digest(__file__), "sources": sources, "outputs": outputs,
                  "ffmpeg_version": subprocess.check_output(["ffmpeg", "-version"], text=True).splitlines()[0],
                  "source_recordings_only": True, "oscillator_or_noise_layers": False,
                  "license": "CC0-1.0", "attribution": "Original recordings: rubberduck (OpenGameArt), CC0-1.0.",
                  "scope": "Plains7 material hurt/death/landing candidates; no coin/heal/BGM edits; listening and user acceptance unverified."}
    (OUT / "provenance.json").write_text(json.dumps(provenance, ensure_ascii=False, indent=2) + "\n")
    (OUT / "recipes.json").write_text(json.dumps({"version": VERSION, "rate": RATE, "recipes": RECIPES}, indent=2) + "\n")
    (OUT / "manifest.json").write_text(json.dumps({"schema_version": 1, "version": VERSION,
        "kind": "recorded_material_sfx", "assets": outputs,
        "provenance": "assets/audio/plains_feedback_02/provenance.json",
        "license": "CC0-1.0", "listening_status": "unverified"}, indent=2) + "\n")
    print(f"Built {len(outputs)} recorded-source material cues; all source SHA/license checks passed.")


if __name__ == "__main__":
    main()
