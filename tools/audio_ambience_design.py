#!/usr/bin/env python3
"""Reproduce candidate environmental beds from fingerprinted CC0 recordings.

Complete source recordings live in an ignored cache, never the runtime PCK.
`fetch` restores their exact original bytes. No oscillator/noise synthesis is used.
Requires ffmpeg and numpy; all audio edits are explicit recipe parameters.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import subprocess
import tempfile
import urllib.request

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "config/audio_director/ambience"
DEST = ROOT / "assets/audio/ambience_v1"
VERSION = "audio-ambience-v1"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path: Path):
    return json.loads(path.read_text())


def write(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def checked_path(name: str) -> Path:
    path = ROOT / name
    if path.is_symlink() or not path.resolve().is_relative_to(ROOT.resolve()):
        raise ValueError("Source/output path escapes repository")
    return path


def bindings() -> dict:
    return {"recipe_sha256": sha(CONFIG / "recipes.json"),
            "sources_sha256": sha(CONFIG / "sources.json"),
            "pipeline_sha256": sha(Path(__file__))}


def check_sources(require_originals: bool = False) -> dict:
    sources = read(CONFIG / "sources.json")["sources"]
    for key, source in sources.items():
        if source["license"] != "CC0-1.0" or source["commercial_use"] is not True or source["attribution_required"] is not False:
            raise ValueError("Unreviewed commercial source: " + key)
        for path_key, hash_key in [("source_page_path", "source_page_sha256"), ("license_path", "license_sha256")]:
            path = checked_path(source[path_key])
            if not path.is_file() or sha(path) != source[hash_key]:
                raise ValueError("License evidence changed: " + key)
        original = checked_path(source["path"])
        if require_originals or original.exists():
            if not original.is_file() or original.stat().st_size != source["bytes"] or sha(original) != source["sha256"]:
                raise ValueError("Original missing/changed: " + key + "; run fetch for missing originals")
    return sources


def fetch() -> None:
    sources = check_sources()
    for key, source in sources.items():
        path = checked_path(source["path"])
        path.parent.mkdir(parents=True, exist_ok=True)
        (path.parent / ".gdignore").write_text("")
        if path.is_file():
            continue
        # A failed download never replaces a known original or the final name.
        temp = path.with_suffix(path.suffix + ".download")
        urllib.request.urlretrieve(source["download_url"], temp)
        if sha(temp) != source["sha256"] or temp.stat().st_size != source["bytes"]:
            raise ValueError("Downloaded source fingerprint mismatch: " + key)
        temp.replace(path)
    check_sources(require_originals=True)
    print("AUDIO_AMBIENCE_FETCH_OK sources=" + str(len(sources)))


def decode(path: Path, rate: int, *, start=0, seconds=None, filters="") -> np.ndarray:
    command = ["ffmpeg", "-v", "error", "-ss", str(start), "-i", str(path)]
    if seconds is not None:
        command += ["-t", str(seconds)]
    if filters:
        command += ["-af", filters]
    command += ["-ar", str(rate), "-ac", "2", "-f", "f32le", "pipe:1"]
    data = np.frombuffer(subprocess.check_output(command), dtype="<f4").copy()
    if not len(data) or len(data) % 2 or not np.isfinite(data).all():
        raise ValueError("Broken decoded audio")
    return data.reshape((-1, 2))


def periodic_crossfade(samples: np.ndarray, frames: int, overlap: int) -> np.ndarray:
    if not 0 < overlap < frames or len(samples) < frames + overlap:
        raise ValueError("Loop source too short for full overlap")
    # Tail -> head in the first overlap, followed by original middle. At wrap,
    # the original final sample continues to the original tail's first sample.
    ramp = np.linspace(0.0, 1.0, overlap, endpoint=False, dtype=np.float64)[:, None]
    cross = samples[frames:frames + overlap] * (1.0 - ramp) + samples[:overlap] * ramp
    return np.concatenate((cross, samples[overlap:frames])).astype(np.float32)


def metrics(samples: np.ndarray) -> dict:
    if not np.isfinite(samples).all() or not samples.size:
        raise ValueError("Nonfinite or empty audio")
    peak = float(np.max(np.abs(samples)))
    rms = float(np.sqrt(np.mean(samples.astype(np.float64) ** 2)))
    if rms <= 1e-9:
        raise ValueError("Silent audio")
    steps = np.abs(np.diff(samples, axis=0))
    return {"peak_dbfs": 20 * math.log10(max(peak, 1e-12)),
            "rms_dbfs": 20 * math.log10(rms),
            "dc": [float(x) for x in np.mean(samples, axis=0)],
            "loop_boundary_step": float(np.max(np.abs(samples[-1] - samples[0]))),
            "interior_step_p999": float(np.quantile(steps, 0.999)),
            "frames": len(samples)}


def normalize(samples: np.ndarray, target: float, ceiling: float) -> np.ndarray:
    measured = metrics(samples)
    gain = min(target - measured["rms_dbfs"], ceiling - measured["peak_dbfs"])
    return (samples * 10 ** (gain / 20)).astype(np.float32)


def encode(samples: np.ndarray, path: Path, rate: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    command = ["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(rate),
               "-ac", "2", "-i", "pipe:0", "-map_metadata", "-1", "-fflags", "+bitexact", "-flags:a", "+bitexact"]
    if path.suffix == ".ogg":
        command += ["-c:a", "libvorbis", "-q:a", "5"]
    else:
        command += ["-c:a", "pcm_s16le"]
    subprocess.run(command + [str(path)], input=samples.astype("<f4").tobytes(), check=True)


def layer_decode(row: dict, sources: dict, rate: int, seconds: float) -> np.ndarray:
    filters = "highpass=f=%s,lowpass=f=%s" % (row["highpass_hz"], row["lowpass_hz"])
    return decode(checked_path(sources[row["source"]]["path"]), rate,
                  start=row["start"], seconds=seconds, filters=filters)


def build() -> None:
    before = bindings()
    sources = check_sources(require_originals=True)
    recipe = read(CONFIG / "recipes.json")
    if recipe["version"] != VERSION:
        raise ValueError("Unsupported recipe version")
    rate = recipe["sample_rate"]
    frames = round(recipe["loop_seconds"] * rate)
    overlap = round(recipe["crossfade_seconds"] * rate)
    regions = {region: {"profiles": {}} for region in ["plains", "forest"]}
    events = {region: {"id": "ambience_" + region, "region": region, "candidates": []} for region in regions}
    rendered = []
    for row in recipe["beds"]:
        mixed = np.zeros((frames, 2), dtype=np.float32)
        for layer in row["layers"]:
            samples = layer_decode(layer, sources, rate, (frames + overlap) / rate)
            loop = periodic_crossfade(samples, frames, overlap)
            loop = normalize(loop, layer["layer_rms_dbfs"], -6.0)
            mixed += loop * 10 ** (layer["gain_db"] / 20)
        mixed = normalize(mixed, row["target_rms_dbfs"], recipe["peak_ceiling_dbfs"] - 0.5)
        mixed *= 10 ** (row.get("output_gain_db", 0.0) / 20)
        path = DEST / (row["id"] + ".ogg")
        encode(mixed, path, rate)
        measured = metrics(decode(path, rate))
        take = {"id": row["id"], "path": "res://" + str(path.relative_to(ROOT)),
                "sha256": sha(path), "bytes": path.stat().st_size,
                "source_ids": list(dict.fromkeys(x["source"] for x in row["layers"])),
                "metrics": measured}
        rendered.append(take)
        events[row["region"]]["candidates"].append({"id": row["id"], "profile": row["profile"],
            "title": row["title"], "path": take["path"], "loop": True,
            "duration": len(mixed) / rate, "source_ids": take["source_ids"], "renders": [take]})
        regions[row["region"]]["profiles"][row["profile"]] = {
            "candidate_id": row["id"], "bed": take["path"], "gain_db": 0.0, "details": []}
    points = []
    for row in recipe["details"]:
        samples = layer_decode(row, sources, rate, row["duration"])
        if row["rate"] != 1:
            # Sample playback-rate edit, then return to fixed export sample rate.
            pos = np.arange(0, len(samples) - 1, row["rate"])
            samples = np.stack([np.interp(pos, np.arange(len(samples)), samples[:, ch]) for ch in range(2)], axis=1).astype(np.float32)
        fade_in = min(round(0.015 * rate), len(samples) // 2)
        fade_out = min(round(0.25 * rate), len(samples) // 2)
        samples[:fade_in] *= np.linspace(0, 1, fade_in)[:, None]
        samples[-fade_out:] *= np.linspace(1, 0, fade_out)[:, None]
        samples = normalize(samples, row["target_rms_dbfs"], recipe["peak_ceiling_dbfs"] - 0.5)
        samples *= 10 ** (row.get("output_gain_db", 0.0) / 20)
        path = DEST / (row["id"] + ".wav")
        encode(samples, path, rate)
        take = {"id": row["id"], "path": "res://" + str(path.relative_to(ROOT)),
                "sha256": sha(path), "bytes": path.stat().st_size,
                "source_ids": [row["source"]], "metrics": metrics(decode(path, rate))}
        rendered.append(take)
        points.append({**take, "event": row["event"], "title": row["title"]})
        for region in row["regions"]:
            for profile in row["profiles"]:
                regions[region]["profiles"][profile]["details"].append({
                    "id": row["event"], "path": take["path"], "gain_db": 0.0,
                    "min_interval": row["min_interval"], "max_distance": row["max_distance"]})
    if bindings() != before:
        raise ValueError("Inputs changed during rendering")
    # The recipe registry is insufficient: a cached recording can change while
    # ffmpeg is reading it without changing its declared source fingerprint.
    check_sources(require_originals=True)
    manifest = {"schema_version": 1, "version": VERSION, "task": recipe["task"],
                "mix_revision": recipe.get("mix_revision", "initial-01"),
                **before, "sample_rate": rate, "channels": 2,
                "peak_ceiling_dbfs": recipe["peak_ceiling_dbfs"],
                "subjective_status": "awaiting-user", "device_status": "unverified",
                "runtime_default": "original", "regions": regions, "events": list(events.values()),
                "point_events": points, "renders": rendered, "sources": sources,
                "ffmpeg_version": subprocess.check_output(["ffmpeg", "-version"], text=True).splitlines()[0],
                "loop_method": "24s recorded material; first 2s linear tail/head overlap; no silence fades at wrap; lossy seam separately measured",
                "assessment_limits": "License and waveform checks do not prove pleasantness, absence of distant public-park traffic/voices, or commercial quality. Listen with BGM and actions."}
    write(DEST / "manifest.json", manifest)
    validate()


def validate() -> None:
    manifest = read(DEST / "manifest.json")
    for key, value in bindings().items():
        if manifest.get(key) != value:
            raise ValueError("Fingerprint drift: " + key + "; full build required")
    sources = check_sources()
    if manifest.get("sources") != sources:
        raise ValueError("Source snapshot differs")
    recipe = read(CONFIG / "recipes.json")
    if manifest.get("mix_revision", "initial-01") != recipe.get("mix_revision", "initial-01"):
        raise ValueError("Mix revision changed")
    if manifest.get("version") != VERSION or manifest.get("sample_rate") != recipe["sample_rate"] or manifest.get("channels") != 2 or manifest.get("runtime_default") != "original":
        raise ValueError("Manifest identity/configuration changed")
    expected = {row["id"] for row in recipe["beds"] + recipe["details"]}
    if {row["id"] for row in manifest["renders"]} != expected or len(manifest["renders"]) != len(expected):
        raise ValueError("Incomplete/duplicate render set")
    for take in manifest["renders"]:
        path = checked_path(take["path"].removeprefix("res://"))
        if sha(path) != take["sha256"] or path.stat().st_size != take["bytes"]:
            raise ValueError("Output fingerprint changed: " + take["id"])
        measured = metrics(decode(path, manifest["sample_rate"]))
        if measured != take["metrics"]:
            raise ValueError("Measured output metadata changed: " + take["id"])
        row = next(row for row in recipe["beds"] + recipe["details"] if row["id"] == take["id"])
        output_gain = row.get("output_gain_db", 0.0)
        # Preserve the original pre-trim fault bounds; deliberate output trim
        # also lowers the peak ceiling. Peak-constrained transients need not
        # reach the requested normalization RMS.
        if type(output_gain) not in (int, float) or not -24 <= output_gain <= 0 or measured["peak_dbfs"] > manifest["peak_ceiling_dbfs"] + output_gain or not -45 < measured["rms_dbfs"] - output_gain < -20 or measured["rms_dbfs"] > row["target_rms_dbfs"] + output_gain + 0.5:
            raise ValueError("Output level out of bounds: " + take["id"])
        if max(abs(x) for x in measured["dc"]) > 0.003:
            raise ValueError("DC offset: " + take["id"])
        if path.suffix == ".ogg":
            if measured["frames"] != round(recipe["loop_seconds"] * manifest["sample_rate"]):
                raise ValueError("Incomplete loop duration")
            # Reject a discontinuity over 6x ordinary high-percentile motion;
            # this is a fault guard, never a perceptual 'inaudible seam' claim.
            if measured["loop_boundary_step"] > max(0.005, 6 * measured["interior_step_p999"]):
                raise ValueError("Excessive decoded loop boundary jump")
    for region in ["plains", "forest"]:
        if set(manifest["regions"][region]["profiles"]) != {"A", "B"}:
            raise ValueError("Missing region profile")
    indexed = {take["id"]: take for take in manifest["renders"]}
    expected_events = {region: {"id": "ambience_" + region, "region": region, "candidates": []}
                       for region in ["plains", "forest"]}
    expected_regions = {region: {"profiles": {}} for region in ["plains", "forest"]}
    for row in recipe["beds"]:
        take = indexed[row["id"]]
        source_ids = list(dict.fromkeys(layer["source"] for layer in row["layers"]))
        if take["source_ids"] != source_ids or take["path"] != "res://assets/audio/ambience_v1/" + row["id"] + ".ogg":
            raise ValueError("Bed source identity changed")
        expected_events[row["region"]]["candidates"].append({"id": row["id"], "profile": row["profile"],
            "title": row["title"], "path": take["path"], "loop": True,
            "duration": recipe["loop_seconds"], "source_ids": source_ids, "renders": [take]})
        profile = manifest["regions"][row["region"]]["profiles"][row["profile"]]
        candidates = [candidate for event in manifest["events"] if event["region"] == row["region"]
                      for candidate in event["candidates"] if candidate["profile"] == row["profile"]]
        if len(candidates) != 1 or candidates[0]["renders"] != [take] or candidates[0]["path"] != take["path"]:
            raise ValueError("Catalog render reference changed")
        if profile["bed"] != take["path"] or profile["candidate_id"] != row["id"] or profile["gain_db"] != 0:
            raise ValueError("Runtime bed reference changed")
        expected_details = [{"id": detail["event"], "path": indexed[detail["id"]]["path"], "gain_db": 0.0,
                             "min_interval": detail["min_interval"], "max_distance": detail["max_distance"]}
                            for detail in recipe["details"] if row["region"] in detail["regions"] and row["profile"] in detail["profiles"]]
        if profile["details"] != expected_details:
            raise ValueError("Runtime detail reference changed")
        expected_regions[row["region"]]["profiles"][row["profile"]] = {
            "candidate_id": row["id"], "bed": take["path"], "gain_db": 0.0, "details": expected_details}
    if manifest["events"] != list(expected_events.values()):
        raise ValueError("Catalog identity/reference changed")
    if manifest["regions"] != expected_regions:
        raise ValueError("Runtime identity/reference changed")
    expected_points = []
    for row in recipe["details"]:
        take = indexed[row["id"]]
        if take["source_ids"] != [row["source"]] or take["path"] != "res://assets/audio/ambience_v1/" + row["id"] + ".wav":
            raise ValueError("Point source identity changed")
        expected_points.append({**take, "event": row["event"], "title": row["title"]})
    if manifest["point_events"] != expected_points:
        raise ValueError("Point catalog reference changed")
    print("AUDIO_AMBIENCE_VALIDATION_OK beds=4 details=4 files=" + str(len(expected)))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["fetch", "build", "validate"])
    args = parser.parse_args()
    {"fetch": fetch, "build": build, "validate": validate}[args.command]()


if __name__ == "__main__":
    main()
