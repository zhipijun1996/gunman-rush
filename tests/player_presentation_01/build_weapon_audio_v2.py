"""Rebuild the task-only sampled-game weapon bank from retained Freedoom bytes.

No oscillator or random source is generated.  All PCM is a deterministic edit of
the upstream BSD-3-Clause game samples in sources/freedoom-originals.zip.  The
smpl chunk declares forward loops; Godot's default Detect From WAV import reads
it, which should also be checked after a fresh import.
"""
from __future__ import annotations

import array
import hashlib
import io
import json
import math
from pathlib import Path
import struct
import wave
import zipfile

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/player_presentation_01/weapon_audio_v2"
SOURCES = OUT / "sources"
RATE = 48000

# (source name, gain, source offset seconds, playback rate, reverse, lowpass Hz)
# These are offline edits of actual game samples, not substitute synthesized
# gunfire.  The machine layer shares its source attack with pistol intentionally;
# the existing accepted round cadence determines sustained machine fire.
RECIPES = {
    "pulse": (.23, False, [("dspistol", 1., 0., 1., False, 0.)]),
    "machine": (.14, False, [("dspistol", .85, 0., 1.15, False, 0.),
                              ("dsshotgn", .3, 0., 1.2, False, 0.)]),
    "blade": (.16, False, [("dsskeswg", 1., 0., 1.2, False, 0.)]),
    "hit": (.13, False, [("dspunch", 1., 0., 1.15, False, 0.)]),
    "wall": (.12, False, [("dstink", 1., 0., 1., False, 0.)]),
    "blast": (.72, False, [("dsbarexp", .75, 0., 1., False, 0.),
                            ("dsrxplod", .55, 0., 1.1, False, 0.)]),
    "ion_start": (.24, False, [("dsplasma", 1., 0., 1., False, 0.),
                                ("dsbfg", .25, .35, .95, False, 0.)]),
    "ion_loop": (.48, True, [("dsplasma", .85, .12, .85, False, 0.),
                              ("dsbfg", .45, .5, 1., False, 1900.)]),
    "ion_tail": (.28, False, [("dsplasma", .8, .4, .7, False, 3600.)]),
    "blackhole_start": (.48, False, [("dstelept", .8, 0., .7, True, 1800.),
                                       ("dsrlaunc", .35, .1, .6, True, 1000.)]),
    "blackhole_loop": (.64, True, [("dsboscub", .7, .15, .55, False, 1400.),
                                    ("dstelept", .6, .1, .48, True, 700.)]),
    "blackhole_burst": (.85, False, [("dsboscub", .5, .1, .65, True, 1700.),
                                       ("dsrxplod", .65, 0., .65, False, 900.)]),
    "mine_beep": (.075, False, [("dsradio", 1., .02, 1.1, False, 0.)]),
    "boomerang_return": (.2, False, [("dsskeswg", .9, 0., 1.35, False, 0.),
                                       ("dsskeswg", .3, .015, .8, True, 0.)]),
}


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def decode_source(data: bytes) -> list[float]:
    with wave.open(io.BytesIO(data)) as source:
        assert source.getnchannels() == 1 and source.getsampwidth() == 1
        rate = source.getframerate()
        samples = [(v - 128) / 128 for v in source.readframes(source.getnframes())]
    # Strip only very quiet leading/trailing PCM so a weapon attack begins when
    # the accepted action begins.  Exact threshold is part of this recipe.
    active = [i for i, x in enumerate(samples) if abs(x) > .012]
    assert active
    samples = samples[max(0, active[0] - 2):min(len(samples), active[-1] + 3)]
    result = []
    for i in range(math.floor(len(samples) * RATE / rate)):
        position = i * rate / RATE
        j = int(position)
        fraction = position - j
        result.append(samples[j] * (1 - fraction) + samples[min(j + 1, len(samples) - 1)] * fraction)
    return result


def lowpass(samples: list[float], cutoff: float) -> list[float]:
    if cutoff <= 0:
        return samples
    coefficient = 1 - math.exp(-math.tau * cutoff / RATE)
    previous = 0.
    result = []
    for value in samples:
        previous += coefficient * (value - previous)
        result.append(previous)
    return result


def layer_sample(source: list[float], length: int, offset: float, speed: float) -> list[float]:
    result = []
    for i in range(length):
        position = offset * RATE + i * speed
        j = int(position)
        fraction = position - j
        result.append(source[j] * (1 - fraction) + source[j + 1] * fraction if j + 1 < len(source) else 0.)
    return result


def write_wav(path: Path, values: list[float], loop: bool) -> dict:
    samples = array.array("h", (round(max(-.98, min(.98, v)) * 32767) for v in values))
    if struct.pack("=I", 1) != struct.pack("<I", 1):
        samples.byteswap()
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(samples.tobytes())
    raw = buffer.getvalue()
    if loop:
        # WAV sampler header and one infinite forward loop (sample indices).
        sampler = struct.pack("<9I", 0, 0, round(1e9 / RATE), 60, 0, 0, 0, 1, 0)
        sampler += struct.pack("<6I", 0, 0, 0, len(values) - 1, 0, 0)
        raw = raw[:4] + struct.pack("<I", len(raw) - 8 + 8 + len(sampler)) + raw[8:]
        raw += b"smpl" + struct.pack("<I", len(sampler)) + sampler
    path.write_bytes(raw)
    return {"path": str(path.relative_to(ROOT)), "sha256": sha(raw), "bytes": len(raw),
            "frames": len(values), "duration": len(values) / RATE,
            "peak": max(abs(v) for v in samples) / 32767,
            "loop": "forward smpl metadata" if loop else "disabled",
            "seam_delta_pcm16": abs(samples[-1] - samples[0]) if loop else None}


def main() -> None:
    upstream = json.loads((SOURCES / "upstream.json").read_text())
    raw_archive = (SOURCES / "freedoom-originals.zip").read_bytes()
    assert sha(raw_archive) == upstream["source_archive_sha256"]
    decoded = {}
    with zipfile.ZipFile(io.BytesIO(raw_archive)) as archive:
        assert archive.testzip() is None
        for entry in upstream["files"]:
            if "member" not in entry:
                assert sha((ROOT / entry["path"]).read_bytes()) == entry["sha256"]
                continue
            raw = archive.read(entry["member"])
            assert sha(raw) == entry["sha256"]
            decoded[Path(entry["member"]).stem] = decode_source(raw)
    files, preloads = [], []
    for cue, (duration, loop, layers) in RECIPES.items():
        paths = []
        for variant, micro_rate in enumerate([.985, 1., 1.015]):
            length = round(duration * RATE)
            crossfade = round(.04 * RATE) if loop else 0
            values = [0.] * (length + crossfade)
            for name, gain, offset, speed, reverse, cutoff in layers:
                original = decoded[name][::-1] if reverse else decoded[name]
                clip = lowpass(layer_sample(original, len(values), offset, speed * micro_rate), cutoff)
                for i, sample in enumerate(clip):
                    values[i] += sample * gain
            dc = sum(values) / len(values)
            values = [v - dc for v in values]
            if loop:
                # x[K:N] followed by a smooth end->begin blend; both endpoints
                # meet the same underlying source neighborhood at x[K].
                end = values[length:length + crossfade]
                start = values[:crossfade]
                blend = []
                for i in range(crossfade):
                    weight = .5 - .5 * math.cos(math.pi * i / (crossfade - 1))
                    blend.append(end[i] * (1 - weight) + start[i] * weight)
                values = values[crossfade:length] + blend
            else:
                for i in range(length):
                    attack = min(1., i / (RATE * .001))
                    release = min(1., (length - 1 - i) / (RATE * min(.05, duration * .2)))
                    values[i] *= attack * release
            target_peak = (.55 if loop else .8) * [1., .96, .98][variant]
            gain = target_peak / max(abs(v) for v in values)
            values = [v * gain for v in values]
            record = write_wav(OUT / f"{cue}_{variant}.wav", values, loop)
            record.update(cue=cue, variant=variant)
            files.append(record)
            paths.append('preload("res://' + record["path"] + '")')
        preloads.append('\t&"' + cue + '": [' + ",".join(paths) + "],")
    resource = ROOT / "resources/player_presentation_01/weapon_sound_data_v2.gd"
    resource.write_text("extends RefCounted\n## BSD-3-Clause Freedoom PCM edits;loop metadata is in the WAV smpl chunk.\nconst CLIPS := {\n" + "\n".join(preloads) + "\n}\n")
    provenance_path = ROOT / "docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-v2-provenance.json"
    provenance = {"task": "PLAYER-PRESENTATION-01", "version": "weapon-audio-v2",
                  "source_project": "Freedoom", "source_commit": upstream["commit"],
                  "source_manifest": str((SOURCES / "upstream.json").relative_to(ROOT)),
                  "source_manifest_sha256": sha((SOURCES / "upstream.json").read_bytes()),
                  "source_archive": str((SOURCES / "freedoom-originals.zip").relative_to(ROOT)),
                  "source_archive_sha256": sha(raw_archive), "sources": upstream["files"],
                  "license": "BSD-3-Clause;original COPYING.adoc and CREDITS retained in asset sources",
                  "recipes": RECIPES, "files": files,
                  "processing": "48kHz mono16 PCM;actual upstream game samples;linear resample;optional single-pole lowpass/reverse/offline layers;DC removal;non-loop 1ms attack<=50ms tail;loops 40ms raised-cosine source crossfade+WAV smpl forward metadata;variant rates.985/1/1.015 and gains1/.96/.98;peak .8 nonloop/.55 loop;no additive oscillator or random source",
                  "source_quality_boundary": "Upstream actual retro game sound effects,mostly8bit PCM. Not claimed to be field-recorded firearms or physically realistic recordings. Sampling up to48k does not restore missing fidelity.",
                  "runtime_boundary": "Only presentation consumers;accepted release/committed enemy hit/wall contact/phase/lifetime events determine playback. Pulse and machine differ in clip envelope/layer plus real round cadence;not two gun mechanics.",
                  "loop_boundary": "ion_loop .48s and blackhole_loop .64s have infinite forward loop metadata. Consumer must stop them on accepted phase exit,cancel/equip/death/unload;metadata is not lifecycle proof. Validate imported AudioStreamWAV.loop_mode after fresh Godot import.",
                  "listening": "unverified;no audio-stream metadata or waveform measurement signs user hearing/taste/device output"}
    provenance_path.write_text(json.dumps(provenance, ensure_ascii=False, indent=2) + "\n")
    provenance_sha = sha(provenance_path.read_bytes())
    for item in files:
        asset_id = "PLAYER-PRESENTATION-01-WEAPON-V2-" + item["cue"].upper().replace("_", "-") + "-" + str(item["variant"])
        record = {"schema_version": 1, "asset_id": asset_id, "content_version": "weapon-feel-v2",
                  "source_path": item["path"], "source_sha256": item["sha256"],
                  "tool": "tests/player_presentation_01/build_weapon_audio_v2.py;Python deterministic sampled-game PCM editing",
                  "model": "not applicable", "prompt_or_reference": str(provenance_path.relative_to(ROOT)),
                  "processing": "Actual BSD Freedoom game PCM;exact offline layers/rates/filter/envelopes in provenance;no generated oscillator",
                  "usage_scope": "Task-only accepted weapon feedback;not production or listening acceptance",
                  "license_source": "assets/player_presentation_01/weapon_audio_v2/sources/COPYING.adoc;BSD-3-Clause Freedoom Contributors;full CREDITS retained",
                  "license_status": "verified", "runtime_paths": ["resources/player_presentation_01/weapon_sound_data_v2.gd", "scripts/dev/player_presentation_01/weapon_audio.gd"],
                  "user_acceptance_evidence": [], "visual_status": "unverified", "disposition": "limited_preview",
                  "associated_files": [{"path": str(provenance_path.relative_to(ROOT)), "sha256": provenance_sha, "role": "processing_record"},
                                       {"path": str((SOURCES / "freedoom-originals.zip").relative_to(ROOT)), "sha256": sha(raw_archive), "role": "reference"}]}
        (ROOT / "docs/quality/asset_records" / (asset_id + ".json")).write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"variants": len(files), "runtime_bytes": sum(v["bytes"] for v in files),
                      "loop_modes_require_import_check": ["ion_loop", "blackhole_loop"],
                      "source_commit": upstream["commit"], "provenance_sha256": provenance_sha}))


if __name__ == "__main__":
    main()
