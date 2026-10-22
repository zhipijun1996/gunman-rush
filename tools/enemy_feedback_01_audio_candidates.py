#!/usr/bin/env python3
"""Render task-only CC0 mechanical-shot auditions; never modifies game assets."""
import argparse
from array import array
import hashlib
import json
import math
from pathlib import Path
import struct
import subprocess
import sys
import wave

ROOT = Path(__file__).resolve().parents[1]
RATE = 48000


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def ffmpeg_layer(path, filters, commands):
    command = ["ffmpeg", "-v", "error", "-i", str(path), "-af", filters,
               "-ac", "1", "-ar", str(RATE), "-f", "f32le", "pipe:1"]
    commands.append(command)
    samples = array("f")
    samples.frombytes(subprocess.check_output(command, timeout=30))
    if sys.byteorder != "little": samples.byteswap()
    return list(samples)


def mix(layers, seconds):
    result = [0.0] * round(seconds * RATE)
    for samples, gain, delay in layers:
        offset = round(delay * RATE)
        for index, value in enumerate(samples[:max(0, len(result)-offset)]):
            result[index + offset] += value * gain
    return result


def measure(samples):
    first = samples[:round(.12 * RATE)]
    rms = math.sqrt(sum(value * value for value in first) / max(1, len(first)))
    peak = max((abs(value) for value in samples), default=0.0)
    return {"seconds": len(samples) / RATE, "peak_dbfs": 20 * math.log10(max(1e-12, peak)),
            "first_120ms_rms_dbfs": 20 * math.log10(max(1e-12, rms))}


def match(samples, target_dbfs=-26.0):
    measured = measure(samples)
    gain = 10 ** ((target_dbfs - measured["first_120ms_rms_dbfs"]) / 20)
    peak = max((abs(value) for value in samples), default=0.0)
    gain = min(gain, 10 ** (-2 / 20) / max(1e-12, peak))
    return [value * gain for value in samples], gain


def write_wav(path, samples):
    pcm = b"".join(struct.pack("<h", round(max(-1.0, min(1.0, value)) * 32767)) for value in samples)
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    allowed = (ROOT / "build/enemy_feedback_01_audio").resolve()
    if output != allowed and allowed not in output.parents:
        raise ValueError("Auditions must stay under build/enemy_feedback_01_audio")
    output.mkdir(parents=True, exist_ok=False)
    source_root = ROOT / "assets/audio/kenney"
    sources = json.loads((source_root / "sources.json").read_text())
    commands = []
    source_rows = {}
    for cue in ("shot", "impact", "hurt", "armour", "confirm"):
        path = source_root / (cue + ".ogg")
        actual = sha(path)
        if actual != sources[cue]["sha256"]: raise ValueError("Source license ledger mismatch: " + cue)
        source_rows[cue] = {**sources[cue], "path": str(path.relative_to(ROOT)), "sha256": actual}
    def layer(cue, filters):
        return ffmpeg_layer(source_root / (cue + ".ogg"), filters, commands)
    def fade(duration, tail):
        return f"afade=t=in:d=0.0006,afade=t=out:st={duration-tail}:d={tail},atrim=duration={duration}"
    # All actual gun candidate layers are licensed physical impacts. The laser
    # is retained only as the original audition reference, never pitch-shifted.
    wood_attack = layer("impact", "highpass=f=850,lowpass=f=6800," + fade(.065, .035))
    punch_body = layer("hurt", "asetrate=39690,aresample=48000,highpass=f=65,lowpass=f=1800," + fade(.16, .11))
    metal_tick = layer("armour", "highpass=f=2700,lowpass=f=6200," + fade(.035, .02))
    heavy_body = layer("hurt", "asetrate=35280,aresample=48000,highpass=f=55,lowpass=f=1050," + fade(.21, .15))
    short_wood = layer("impact", "highpass=f=1250,lowpass=f=5900," + fade(.045, .025))
    a_raw = mix([(wood_attack, .85, 0), (punch_body, .72, .002), (metal_tick, .10, .001)], .18)
    b_raw = mix([(short_wood, .65, 0), (heavy_body, 1.0, .002), (metal_tick, .055, .001)], .23)
    a, a_gain = match(a_raw)
    b, b_gain = match(b_raw)
    original = layer("shot", "anull")
    original, original_gain = match(original)
    impact = layer("impact", "anull")
    hurt = layer("hurt", "anull")
    confirm = layer("confirm", "anull")
    # Current cluster follows the actual service's shared -10.098 dB setting.
    service_gain = .7 * 10 ** (-7 / 20)
    cluster = mix([(impact, service_gain, 0), (hurt, service_gain, 0), (confirm, service_gain, 0)], .65)
    cluster, cluster_gain = match(cluster)
    # Audition hypothesis: one physical body plus very quiet short contact
    # texture, no UI confirm overlay. This is NOT installed in the game.
    hurt_compact = layer("hurt", "highpass=f=75,lowpass=f=3200," + fade(.16, .10))
    impact_texture = layer("impact", "highpass=f=950,lowpass=f=4700," + fade(.07, .04))
    proposed_hit = mix([(hurt_compact, 1.0, 0), (impact_texture, .16, .003)], .20)
    proposed_hit, hit_gain = match(proposed_hit)
    write_wav(output / "shot-a-compact-mechanical.wav", a)
    write_wav(output / "shot-b-weighted-mechanical.wav", b)
    sequence = [0.0] * (25 * RATE)
    chapters = []
    for index, (name, samples) in enumerate([
        ("Current laser2 gun cue", original), ("A compact mechanical candidate", a),
        ("B weighted mechanical candidate", b), ("Current impact+hurt+confirm cluster", cluster),
        ("Proposed compact hit body+quiet contact, no confirm", proposed_hit)]):
        start = index * 5
        chapters.append({"from_seconds": start, "to_seconds": start + 5, "name": name,
                         "events_at_seconds": [start + .5, start + 2, start + 3.5], "effect_measurement": measure(samples)})
        for when in (.5, 2, 3.5):
            offset = round((start + when) * RATE)
            for sample_index, value in enumerate(samples): sequence[offset + sample_index] += value
    write_wav(output / "audio-comparison-25s.wav", sequence)
    report = {"task": "ENEMY-FEEDBACK-01", "status": "audition_candidates_only", "producer": "audio_audit",
              "source_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
              "producer_script_sha256": sha(Path(__file__)),
              "ffmpeg_version": subprocess.check_output(["ffmpeg", "-version"], text=True).splitlines()[0],
              "sample_rate": RATE, "format": "mono PCM16 WAV", "sources": source_rows, "ffmpeg_commands": commands,
              "layers": {"A": "wood transient .85 + lowpassed physical punch .72 + short metal .10",
                         "B": "short wood .65 + lower physical punch1.0 + short metal .055",
                         "proposed_hit": "compact punch1.0 + quiet contact .16; confirm omitted only in offline audition"},
              "normalization": {"method": "first120ms RMS matched to -26dBFS, ceiling -2dBFS; not perceived LUFS/device equality",
                                "gains": {"original": original_gain, "A": a_gain, "B": b_gain, "current_hit_cluster": cluster_gain, "proposed_hit": hit_gain}},
              "chapters": chapters, "files": {},
              "production_audio_changed": False,
              "limits": ["Offline sound-only audition, no fake gameplay footage or in-game acceptance",
                         "No claim these candidates are better until the user listens",
                         "No shared event/stream/volume/budget changes; integration requires controller-owned write allocation"]}
    for path in output.glob("*.wav"):
        report["files"][path.name] = {"sha256": sha(path), "bytes": path.stat().st_size}
    (output / "manifest.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    (output / "README.md").write_text("# Task-only audio auditions\n\nNo production audio changed. CC0 sources and all processing are in manifest.json.\n\n"
        "Listen to audio-comparison-25s.wav: 0–5s current laser cue; 5–10s A compact mechanical; 10–15s B weighted mechanical; "
        "15–20s current impact+hurt+confirm cluster; 20–25s proposed physical hit body without confirm. Each section repeats at +0.5/+2/+3.5s.\n\n"
        "Effects share first120ms RMS (-26dBFS target), not a subjective loudness guarantee. The two shot WAVs are separate audition candidates. "
        "The hit reduction is an offline hypothesis, not an installed event change. User listening and actual in-game comparison remain unverified.\n")
    print("ENEMY FEEDBACK AUDIO CANDIDATES: 2 shot WAVs, 25s comparison, sources and recipe; production unchanged")


if __name__ == "__main__": main()
