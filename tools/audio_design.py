#!/usr/bin/env python3
"""Rebuild licensed sample-based SFX candidates; never changes BGM or game rules."""
from __future__ import annotations

import argparse
import array
import hashlib
import json
import math
import shutil
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RECIPES = ROOT / "config/audio_director/recipes.json"
SOURCES = ROOT / "config/audio_director/sources.json"
DEST = ROOT / "assets/audio/director_candidates"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def current_fingerprints() -> dict[str, str]:
    return {"recipe_sha256": digest(RECIPES), "sources_sha256": digest(SOURCES),
            "pipeline_sha256": digest(Path(__file__))}


def validate_fingerprints(manifest: dict) -> None:
    for key, actual in current_fingerprints().items():
        if manifest.get(key) != actual:
            raise ValueError(f"Manifest {key} changed; run a full build before validating or retaining other events")
    if manifest.get("sources") != read_json(SOURCES)["sources"]:
        raise ValueError("Manifest source snapshot differs from the current source registry; run a full build")


def run(args: list[str]) -> None:
    result = subprocess.run(args, capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(result.stderr[-6000:])


def measure(path: Path) -> dict:
    with wave.open(str(path), "rb") as stream:
        width = stream.getsampwidth()
        if stream.getnchannels() != 1 or width not in (2, 4):
            raise ValueError(f"Expected PCM16/32 mono: {path}")
        rate = stream.getframerate()
        samples = array.array("h" if width == 2 else "i", stream.readframes(stream.getnframes()))
    if sys.byteorder != "little":
        samples.byteswap()
    scale = 2 ** (width * 8 - 1)
    peak = max((abs(sample) / scale for sample in samples), default=0)
    rms = math.sqrt(sum((sample / scale) ** 2 for sample in samples) / max(1, len(samples)))
    return {
        "duration": round(len(samples) / rate, 6),
        "sample_rate": rate,
        "channels": 1,
        "format": f"PCM{width * 8} WAV",
        "peak_dbfs": round(20 * math.log10(max(peak, 1e-9)), 4),
        "rms_dbfs": round(20 * math.log10(max(rms, 1e-9)), 4),
        "sha256": digest(path),
        "bytes": path.stat().st_size,
    }


def alternate(source_id: str, sources: dict) -> str:
    # Alternate actual recorded takes, not a randomly synthesized waveform.
    swaps = {
        "wood_01.ogg": "wood_02.ogg", "wood_02.ogg": "wood_03.ogg",
        "metal_01.ogg": "metal_02.ogg", "lock_01.ogg": "lock_02.ogg",
        "chain_01.ogg": "chain_02.ogg", "item_coins_01.ogg": "item_coins_02.ogg",
        "item_gem_01.ogg": "item_gem_02.ogg", "blade_01.ogg": "blade_02.ogg",
        "creature_hurt_01.ogg": "creature_hurt_02.ogg", "book_01.ogg": "book_02.ogg",
        "cute_01.ogg": "cute_02.ogg",
    }
    prefix, name = source_id.rsplit("/", 1)
    replacement = prefix + "/" + swaps.get(name, name)
    return replacement if replacement in sources else source_id


def render(event: dict, candidate: dict, variant: int, sources: dict, config: dict, output: Path) -> dict:
    rate = int(config["sample_rate"])
    duration = float(event["duration"])
    inputs: list[str] = []
    filters: list[str] = []
    layers: list[dict] = []
    for index, original in enumerate(candidate["layers"]):
        layer = dict(original)
        source_id = alternate(layer["source"], sources) if variant else layer["source"]
        source = sources[source_id]
        path = ROOT / source["path"]
        if digest(path) != source["sha256"]:
            raise ValueError(f"Source fingerprint changed: {source_id}")
        inputs += ["-i", str(path)]
        pitch = float(layer["pitch"]) * (1.025 if variant else 1)
        chain = [
            f"aresample={rate}", "aformat=channel_layouts=mono",
            "silenceremove=start_periods=1:start_duration=0.002:start_threshold=-55dB",
            f"atrim=duration={float(layer['duration']):.6f}", "asetpts=PTS-STARTPTS",
        ]
        if layer.get("reverse"):
            chain += ["areverse"]
        chain += [
            f"asetrate={round(rate * pitch)}", f"aresample={rate}", f"atempo={float(layer.get('tempo', 1.0))}",
            f"highpass=f={layer['highpass_hz']}", f"lowpass=f={layer['lowpass_hz']}",
            "equalizer=f=2800:t=q:w=0.8:g=-2.5",
            f"afade=t=in:d=0.003", f"afade=t=out:st={max(0.005, float(layer['duration']) / pitch - 0.025):.6f}:d=0.025",
            f"volume={float(layer['gain']):.6f}",
            f"adelay={round(float(layer['delay']) * 1000)}:all=1",
        ]
        filters.append(f"[{index}:a]" + ",".join(chain) + f"[layer{index}]")
        layers.append({**layer, "resolved_source": source_id, "input_sha256": source["sha256"], "resolved_pitch": pitch})
    prefix = "".join(f"[layer{i}]" for i in range(len(layers)))
    filters.append(prefix + f"amix=inputs={len(layers)}:normalize=0:dropout_transition=0,"
                   "acompressor=threshold=0.2:ratio=2:attack=3:release=60:makeup=1,"
                   f"volume=0.125,apad,atrim=duration={duration},afade=t=out:st={duration - 0.035}:d=0.035[mix]")
    with tempfile.TemporaryDirectory(prefix="audio-director-") as temp:
        raw = Path(temp) / "mix.wav"
        mix_args = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", *inputs,
                    "-filter_complex", ";".join(filters), "-map", "[mix]", "-ar", str(rate), "-ac", "1", "-c:a", "pcm_s32le", str(raw)]
        run(mix_args)
        metrics = measure(raw)
        # Family RMS target with a hard sample-peak ceiling. This is not a LUFS quality score.
        gain_db = min(float(event["target_rms_dbfs"]) - metrics["rms_dbfs"],
                      float(config["peak_ceiling_dbfs"]) - metrics["peak_dbfs"])
        run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(raw), "-af", f"volume={gain_db:.9f}dB",
             "-ar", str(rate), "-ac", "1", "-c:a", "pcm_s16le", "-fflags", "+bitexact", "-flags:a", "+bitexact", str(output)])
    return {"path": "res://" + str(output.relative_to(ROOT)), "variant": variant + 1,
            "layers": layers, "ffmpeg_filter_complex": ";".join(filters), "normalization_gain_db": gain_db, **measure(output)}


def build(event_filter: str | None) -> None:
    config, source_config = read_json(RECIPES), read_json(SOURCES)
    fingerprints = current_fingerprints()
    sources = source_config["sources"]
    if event_filter and not any(event["id"] == event_filter for event in config["events"]):
        raise ValueError(f"Unknown event: {event_filter}")
    ffmpeg_version = subprocess.check_output(["ffmpeg", "-version"], text=True).splitlines()[0]
    DEST.mkdir(parents=True, exist_ok=True)
    prior_path = DEST / "manifest.json"
    prior = read_json(prior_path) if event_filter and prior_path.exists() else {"events": []}
    if event_filter and prior_path.exists():
        # Reject before rendering anything: changing one event cannot rebind the
        # other sixty files to recipes/tools with which they were never built.
        validate_fingerprints(prior)
        if prior.get("ffmpeg_version") != ffmpeg_version:
            raise ValueError("FFmpeg version changed; run a full build before retaining other events")
    built = []
    for event in config["events"]:
        if event_filter and event["id"] != event_filter:
            built += [entry for entry in prior["events"] if entry["id"] == event["id"]]
            continue
        entry = {key: value for key, value in event.items() if key != "candidates"}
        entry["candidates"] = []
        for candidate in event["candidates"]:
            takes = []
            for variant in range(config["variant_count"]):
                suffix = "" if variant == 0 else f"_v{variant + 1}"
                output = DEST / (candidate["id"] + suffix + ".wav")
                takes.append(render(event, candidate, variant, sources, config, output))
            used_ids = sorted({layer["resolved_source"] for take in takes for layer in take["layers"]})
            entry["candidates"].append({
                "id": candidate["id"], "label": candidate["label"], "design": candidate["design"],
                "version": config["version"], "path": takes[0]["path"], "variants": [take["path"] for take in takes],
                "source_ids": used_ids, "subjective_status": "awaiting-user",
                **{key: takes[0][key] for key in ["duration", "peak_dbfs", "rms_dbfs", "sha256"]},
                "renders": takes,
            })
            print(f"Rendered {candidate['id']}: {len(takes)} variants", flush=True)
        built.append(entry)
    if current_fingerprints() != fingerprints:
        raise ValueError("Recipe/source/pipeline changed during rendering; discard this run and do a full build")
    manifest = {"schema_version": 1, "version": config["version"], "task": "AUDIO-DIRECTOR-01",
                "sample_rate": config["sample_rate"], "peak_ceiling_dbfs": config["peak_ceiling_dbfs"],
                "subjective_status": "awaiting-user", "runtime_default": "legacy",
                **fingerprints, "ffmpeg_version": ffmpeg_version,
                "loudness_method": "whole-cue RMS target per event, sample-peak constrained; not integrated LUFS",
                "events": built, "sources": sources}
    prior_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    validate()


def validate() -> None:
    manifest = read_json(DEST / "manifest.json")
    validate_fingerprints(manifest)
    count = 0
    for event in manifest["events"]:
        for candidate in event["candidates"]:
            for take in candidate["renders"]:
                path = ROOT / take["path"].removeprefix("res://")
                metrics = measure(path)
                if metrics["sha256"] != take["sha256"]:
                    raise ValueError(f"Output fingerprint changed: {path}")
                if metrics["peak_dbfs"] > manifest["peak_ceiling_dbfs"] + 0.02:
                    raise ValueError(f"Peak ceiling exceeded: {path}")
                if metrics["rms_dbfs"] < -60 or metrics["duration"] <= 0.04:
                    raise ValueError(f"Silent or empty output: {path}")
                for layer in take["layers"]:
                    source = manifest["sources"][layer["resolved_source"]]
                    if source["license"] != "CC0-1.0" or digest(ROOT / source["path"]) != layer["input_sha256"]:
                        raise ValueError(f"Unlicensed or changed source: {path}")
                count += 1
    print(f"AUDIO_DESIGN_OK events={len(manifest['events'])} rendered_files={count}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["build", "validate", "list"])
    parser.add_argument("--event", help="Rebuild one recipe event; preserve other manifest entries")
    args = parser.parse_args()
    if not shutil.which("ffmpeg"):
        parser.error("ffmpeg is required")
    if args.command == "build":
        build(args.event)
    elif args.command == "validate":
        validate()
    else:
        for event in read_json(RECIPES)["events"]:
            if not args.event or event["id"] == args.event:
                print(event["id"], event["label"], ", ".join(item["id"] for item in event["candidates"]))


if __name__ == "__main__":
    main()
