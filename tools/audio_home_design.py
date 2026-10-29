#!/usr/bin/env python3
"""Quiet Home life details from CC0 recordings; reference the selected bed unchanged."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

import numpy as np

import audio_ambience_design as processing

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "config/audio_director/home"
DEST = ROOT / "assets/audio/ambience_v1/home"
IDS = {"home_" + family + "_" + str(take) for family in ["cloth", "wood", "tools", "page"] for take in [1, 2]}


def read(path: Path):
    return json.loads(path.read_text())


def write(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def path_for(name: str) -> Path:
    path = ROOT / name.removeprefix("res://")
    if path.is_symlink() or not path.resolve().is_relative_to(ROOT.resolve()):
        raise ValueError("Path escapes repository")
    return path


def bindings() -> dict:
    return {"recipe_sha256": processing.sha(CONFIG / "recipes.json"),
            "sources_sha256": processing.sha(CONFIG / "sources.json"),
            "pipeline_sha256": processing.sha(Path(__file__)),
            "processing_library_sha256": processing.sha(ROOT / "tools/audio_ambience_design.py")}


def check_inputs() -> tuple[dict, dict]:
    recipe = read(CONFIG / "recipes.json")
    if recipe.get("version") != "audio-ambience-v1" or recipe.get("content_version") != "audio-home-v1":
        raise ValueError("Unsupported Home recipe identity")
    if len(recipe["details"]) != 8 or {row["id"] for row in recipe["details"]} != IDS:
        raise ValueError("Home requires eight unique detail IDs")
    for name, fingerprint in recipe["locked_inputs"].items():
        path = path_for(name)
        if not path.is_file() or processing.sha(path) != fingerprint:
            raise ValueError("Selected/BGM input drift: " + name)
    sources = read(CONFIG / "sources.json")["sources"]
    for sid, source in sources.items():
        if source["license"] != "CC0-1.0" or source["commercial_use"] is not True or source["attribution_required"] is not False:
            raise ValueError("Unreviewed Home source: " + sid)
        for key, hash_key in [("path", "sha256"), ("source_page_path", "source_page_sha256"),
                              ("license_path", "license_sha256")]:
            path = path_for(source[key])
            if not path.is_file() or processing.sha(path) != source[hash_key]:
                raise ValueError("Home source/license drift: " + sid)
        if path_for(source["path"]).stat().st_size != source["bytes"]:
            raise ValueError("Home original size drift: " + sid)
        if "source_registry_path" in source:
            registry = path_for(source["source_registry_path"])
            if processing.sha(registry) != source["source_registry_sha256"]:
                raise ValueError("Inherited source registry drift: " + sid)
            original = read(registry)["sources"][source["source_registry_id"]]
            for key, value in original.items():
                if source.get(key) != value:
                    raise ValueError("Inherited source metadata differs: " + sid)
    return recipe, sources


def bed_reference(recipe: dict) -> dict:
    return {"path": recipe["bed"]["path"], "sha256": recipe["bed"]["sha256"],
            "selection_path": "config/audio_director/ambience/user-selected.json",
            "selection_sha256": recipe["locked_inputs"]["config/audio_director/ambience/user-selected.json"],
            "manifest_path": "assets/audio/ambience_v1/manifest.json",
            "manifest_sha256": recipe["locked_inputs"]["assets/audio/ambience_v1/manifest.json"],
            "scope": "Byte-identical selected quiet-02 plains_a; borrowed bed, no new bed render"}


def runtime(recipe: dict) -> dict:
    details = [{"id": row["id"], "path": "res://assets/audio/ambience_v1/home/" + row["id"] + ".wav",
                "gain_db": row["gain_db"], "min_interval": row["min_interval"], "max_distance": row["max_distance"]}
               for row in recipe["details"]]
    return {"home": {"profiles": {"A": {"candidate_id": recipe["bed"]["candidate_id"],
            "bed": recipe["bed"]["path"], "gain_db": recipe["bed"]["gain_db"], "details": details}}}}


def events(recipe: dict) -> list:
    return [{"id": "ambience_home", "region": "home", "candidates": [{
        "id": recipe["bed"]["candidate_id"], "profile": "A", "title": "家园 · 平静与日常",
        "path": recipe["bed"]["path"], "loop": True, "duration": 24.0,
        "source_ids": [], "renders": [], "bed_reference": bed_reference(recipe)}]}]


def point_catalog(recipe: dict, renders: list) -> list:
    indexed = {take["id"]: take for take in renders}
    return [{**indexed[row["id"]], "event": row["id"], "title": row["title"],
             "slot": row["slot"], "source_window": {"start": row["start"], "duration": row["duration"]},
             "scope": "Nearby workshop interior activity; no synchronized NPC gesture is claimed"}
            for row in recipe["details"]]


def render(row: dict, sources: dict, sample_rate: int, destination: Path) -> dict:
    filters = "highpass=f=%s,lowpass=f=%s" % (row["highpass_hz"], row["lowpass_hz"])
    samples = processing.decode(path_for(sources[row["source"]]["path"]), sample_rate,
                                start=row["start"], seconds=row["duration"], filters=filters)
    if abs(len(samples) / sample_rate - row["duration"]) > 0.004:
        raise ValueError("Home source window is incomplete: " + row["id"])
    fade_in = min(round(row["fade_in_seconds"] * sample_rate), len(samples) // 2)
    fade_out = min(round(row["fade_out_seconds"] * sample_rate), len(samples) // 2)
    samples[:fade_in] *= np.linspace(0, 1, fade_in)[:, None]
    samples[-fade_out:] *= np.linspace(1, 0, fade_out)[:, None]
    samples = processing.normalize(samples, row["target_rms_dbfs"], row["peak_ceiling_dbfs"] - 0.1)
    path = destination / (row["id"] + ".wav")
    processing.encode(samples, path, sample_rate)
    return {"id": row["id"], "path": "res://assets/audio/ambience_v1/home/" + path.name,
            "sha256": processing.sha(path), "bytes": path.stat().st_size,
            "source_ids": [row["source"]], "metrics": processing.metrics(processing.decode(path, sample_rate))}


def build() -> None:
    before = bindings()
    recipe, sources = check_inputs()
    stage_root = ROOT / "build/audio_home_01"
    stage_root.mkdir(parents=True, exist_ok=True)
    (stage_root / ".gdignore").write_text("")
    with tempfile.TemporaryDirectory(prefix="render-", dir=stage_root) as folder:
        stage = Path(folder)
        renders = [render(row, sources, recipe["sample_rate"], stage) for row in recipe["details"]]
        # Re-read actual original bytes, selected files, music and license proofs,
        # not just the hashes claimed by the source registry.
        check_inputs()
        if bindings() != before:
            raise ValueError("Home inputs changed during rendering")
        manifest = {"schema_version": 1, "version": recipe["version"],
                    "content_version": recipe["content_version"], "mix_revision": recipe["mix_revision"],
                    "task": recipe["task"], **before, "sample_rate": recipe["sample_rate"],
                    "channels": 2, "subjective_status": "awaiting-user", "device_status": "unverified",
                    "runtime_default": "original", "regions": runtime(recipe), "events": events(recipe),
                    "bed_reference": bed_reference(recipe), "point_events": point_catalog(recipe, renders),
                    "renders": renders, "sources": sources,
                    "locked_inputs": recipe["locked_inputs"],
                    "ffmpeg_version": subprocess.check_output(["ffmpeg", "-version"], text=True).splitlines()[0],
                    "scope": "Developer audition of quiet Home bed and sparse workshop life details; no formal rollout or audible quality approval"}
        DEST.mkdir(parents=True, exist_ok=True)
        for take in renders:
            shutil.move(str(stage / Path(take["path"]).name), DEST / Path(take["path"]).name)
        write(DEST / "manifest.json", manifest)
    validate()


def validate() -> None:
    manifest = read(DEST / "manifest.json")
    for key, fingerprint in bindings().items():
        if manifest.get(key) != fingerprint:
            raise ValueError("Home fingerprint drift: " + key)
    recipe, sources = check_inputs()
    for key in ["version", "content_version", "mix_revision", "task", "sample_rate", "channels"]:
        if manifest.get(key) != recipe[key]:
            raise ValueError("Home manifest identity drift: " + key)
    if manifest.get("runtime_default") != "original":
        raise ValueError("Home default profile changed")
    if manifest.get("sources") != sources or manifest.get("locked_inputs") != recipe["locked_inputs"]:
        raise ValueError("Home provenance snapshot differs")
    if manifest.get("regions") != runtime(recipe) or manifest.get("events") != events(recipe) or manifest.get("bed_reference") != bed_reference(recipe):
        raise ValueError("Home runtime/catalog reference drift")
    renders = manifest["renders"]
    if len(renders) != 8 or [take["id"] for take in renders] != [row["id"] for row in recipe["details"]]:
        raise ValueError("Home missing/duplicate/reordered renders")
    for take, row in zip(renders, recipe["details"]):
        expected_path = "res://assets/audio/ambience_v1/home/" + row["id"] + ".wav"
        if take["path"] != expected_path or take["source_ids"] != [row["source"]]:
            raise ValueError("Home render source/path drift")
        path = path_for(take["path"])
        if processing.sha(path) != take["sha256"] or path.stat().st_size != take["bytes"]:
            raise ValueError("Home output byte drift: " + row["id"])
        measured = processing.metrics(processing.decode(path, recipe["sample_rate"]))
        if measured != take["metrics"]:
            raise ValueError("Home measured metadata drift")
        if measured["peak_dbfs"] > row["peak_ceiling_dbfs"] or not -60 < measured["rms_dbfs"] <= -39:
            raise ValueError("Home level out of bounds")
        if abs(measured["frames"] / recipe["sample_rate"] - row["duration"]) > 0.004:
            raise ValueError("Home duration mismatch")
    if manifest.get("point_events") != point_catalog(recipe, renders):
        raise ValueError("Home point identity/catalog drift")
    print("AUDIO_HOME_VALIDATION_OK bed=borrowed_unchanged details=8 selected_and_bgm_locked=true")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["build", "validate"])
    args = parser.parse_args()
    {"build": build, "validate": validate}[args.command]()


if __name__ == "__main__":
    main()
