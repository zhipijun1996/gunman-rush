#!/usr/bin/env python3
"""Original offline procedural SFX for FOREST-BIBLE-V2-01. No music/samples.

A fixed integer PRNG feeds noise; modal/filtered synthesis creates three short,
non-looping one-shots. Source and output SHA256 are kept in provenance.json.
"""
from __future__ import annotations
import argparse
import array
import hashlib
import io
import json
import math
from pathlib import Path
import sys
import wave

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "assets/forest_bible_v2/audio"
RATE = 22050
BIBLE = "docs/creative_direction/bibles/2-thorn_forest_region_bible_v2.md"
SEEDS = {"forest_wind": 151103, "forest_fruit": 151107, "forest_web": 151109}


def render(name: str) -> bytes:
    duration = {"forest_wind": 1.6, "forest_fruit": 0.32, "forest_web": 0.48}[name]
    state = SEEDS[name]
    slow = 0.0
    medium = 0.0
    signal: list[float] = []
    count = round(RATE * duration)
    for index in range(count):
        state = (1664525 * state + 1013904223) & 0xFFFFFFFF
        noise = state / 2147483648.0 - 1.0
        t = index / RATE
        slow += (noise - slow) * 0.015
        medium += (noise - medium) * 0.18
        # Both ends are exactly silent; these are one-shots without loop points.
        fade = min(1.0, index / (RATE * 0.009), (count - 1 - index) / (RATE * 0.035))
        if name == "forest_wind":
            swell = math.sin(math.pi * index / (count - 1)) ** 1.5
            value = (slow * 4.2 + (medium - slow) * 0.24) * swell
            value += (noise - medium) * 0.018 * swell * (0.5 + 0.5 * math.sin(23 * t))
        elif name == "forest_fruit":
            # Inharmonic bronze partials and a woody contact: no pitched phrase.
            value = sum(amp * math.sin(math.tau * hz * t) * math.exp(-decay * t)
                        for amp, hz, decay in [(0.52, 1247, 16), (0.25, 2081, 22), (0.12, 3157, 33)])
            value += medium * 0.5 * math.exp(-85 * t)
        else:
            # Dry, irregular fibre tension; no instrument/voice recording.
            phase = math.tau * (190 * t + 240 * t * t)
            value = (medium - slow) * 1.1 + math.sin(phase) * 0.13
            value *= math.exp(-5.7 * t) * (0.65 + 0.35 * math.sin(97 * t) ** 2)
        signal.append(value * fade)
    peak_target = {"forest_wind": 0.16, "forest_fruit": 0.46, "forest_web": 0.28}[name]
    gain = peak_target / max(abs(value) for value in signal)
    pcm = array.array("h", (round(max(-1.0, min(1.0, value * gain)) * 32767) for value in signal))
    if sys.byteorder != "little":
        pcm.byteswap()
    output = io.BytesIO()
    with wave.open(output, "wb") as stream:
        stream.setparams((1, 2, RATE, count, "NONE", "not compressed"))
        stream.writeframes(pcm.tobytes())
    return output.getvalue()


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def manifest() -> dict:
    rows = []
    for name in SEEDS:
        data = render(name)
        with wave.open(io.BytesIO(data), "rb") as stream:
            samples = array.array("h", stream.readframes(stream.getnframes()))
            if sys.byteorder != "little":
                samples.byteswap()
        peak = max(abs(value) for value in samples) / 32768
        rms = math.sqrt(sum((value / 32768) ** 2 for value in samples) / len(samples))
        rows.append({"path": f"assets/forest_bible_v2/audio/{name}.wav", "sha256": sha(data),
                     "seed": SEEDS[name], "frames": len(samples), "sample_rate": RATE,
                     "channels": 1, "bits_per_sample": 16, "duration_seconds": len(samples) / RATE,
                     "peak_dbfs": round(20 * math.log10(peak), 4),
                     "rms_dbfs": round(20 * math.log10(rms), 4), "loop": False})
    return {"schema_version": 1, "task": "FOREST-BIBLE-V2-01", "bible_id": "thorn_forest_v2",
            "bible_version": "2.0", "bible_path": BIBLE, "bible_sha256": sha((ROOT / BIBLE).read_bytes()),
            "method": "original offline procedural noise/modal synthesis; no external samples, music, image generation or human recording",
            "creator": "OpenAI Codex session, 2026-10-21", "external_sources": [],
            "rights_note": "Generated from this repository script; no third-party sample/license claim is made.",
            "generator": "tools/generate_forest_bible_sfx.py", "generator_sha256": sha(Path(__file__).read_bytes()),
            "reproducibility": "Fixed LCG seeds, Python stdlib; PCM byte verification is authoritative on this host.",
            "consumer": "GameAudio bounded 12-voice service; non-looping regional cues",
            "audio_listening_status": "unverified", "normal_speed_av_status": "unverified", "files": rows}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Read-only byte and metadata reproducibility verification")
    args = parser.parse_args()
    expected = manifest()
    if args.check:
        failures = [row["path"] for row in expected["files"]
                    if not (ROOT / row["path"]).is_file() or (ROOT / row["path"]).read_bytes() != render(Path(row["path"]).stem)]
        if not (DEST / "provenance.json").is_file() or json.loads((DEST / "provenance.json").read_text()) != expected:
            failures.append("provenance.json")
        print(json.dumps({"check": "forest_bible_sfx_reproducibility", "passed": not failures, "failures": failures}))
        return int(bool(failures))
    DEST.mkdir(parents=True, exist_ok=True)
    for name in SEEDS:
        (DEST / f"{name}.wav").write_bytes(render(name))
    (DEST / "provenance.json").write_text(json.dumps(expected, indent=2, ensure_ascii=False) + "\n")
    print(json.dumps({"generated": [row["path"] for row in expected["files"]]}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
