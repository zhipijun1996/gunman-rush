#!/usr/bin/env python3
"""Audit committed audio bytes, source licenses and static references into build/."""
from __future__ import annotations

import argparse
import collections
import hashlib
import io
import json
import re
import subprocess
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AUDIO = {".wav", ".ogg", ".mp3", ".flac", ".aiff", ".aif", ".opus", ".m4a"}
SOURCE = {".gd", ".tscn", ".tres", ".godot", ".py", ".js", ".cfg"}


def git(*args: str) -> bytes:
    return subprocess.check_output(["git", "-C", str(ROOT), *args])


def blobs(ref: str, paths: list[str]) -> dict[str, bytes]:
    if not paths:
        return {}
    proc = subprocess.run(["git", "-C", str(ROOT), "cat-file", "--batch"],
                          input="".join(f"{ref}:{p}\n" for p in paths).encode(),
                          stdout=subprocess.PIPE, check=True)
    out, pos, result = proc.stdout, 0, {}
    for path in paths:
        end = out.index(b"\n", pos)
        header = out[pos:end].split()
        if len(header) != 3 or header[1] != b"blob":
            raise ValueError(f"Not a blob: {path}: {header!r}")
        size = int(header[2]); pos = end + 1
        result[path] = out[pos:pos+size]; pos += size + 1
    return result


def line_refs(texts: dict[str, str], needle: str, prefixes=()) -> list[dict]:
    return [{"path": p, "line": i, "code": line.strip()}
            for p, text in texts.items() if not prefixes or p.startswith(prefixes)
            for i, line in enumerate(text.splitlines(), 1) if needle in line]


def refstr(ref: dict) -> str:
    return f"`{ref['path']}:{ref['line']}`"


def resolve_source_paths(tree):
    """Resolve this audit's eight existing source roles inside the selected Git tree.

    These aliases are only historical/current file identities for the audit;
    they do not select game content. Never fall back to working-tree bytes.
    """
    aliases = {
        'scripts/audio/game_audio.gd': 'game/presentation/audio/game_audio.gd',
        'scripts/audio/game_music.gd': 'game/presentation/audio/game_music.gd',
        'scripts/demo/demo_app.gd': 'tests/fixtures/campaign_fixture.gd',
        'scripts/dev/player_presentation_01/motion_feel.gd': 'game/player/presentation/motion_feel.gd',
        'scripts/dev/player_presentation_01/weapon_feel.gd': 'game/combat/weapons/presentation/weapon_feel.gd',
        'scripts/dev/player_presentation_01/weapon_feel_v2.gd': 'game/combat/weapons/presentation/weapon_feel_v2.gd',
        'scripts/art/player_feedback.gd': 'game/presentation/actors/art/player_feedback.gd',
        'scripts/enemies/enemy_actor.gd': 'game/enemies/enemy_actor.gd',
    }
    resolved = {}
    for old, current in aliases.items():
        matches = [path for path in (old, current) if path in tree]
        if len(matches) != 1:
            raise ValueError("Missing/ambiguous audited source in selected Git tree: " + old)
        resolved[old] = matches[0]
    return resolved


def music_app_refs(texts, path, cue):
    """Keep the baseline's exact window; locate the moved consumer by function."""
    references = line_refs(texts, '&"' + cue + '"', (path,))
    if path == "scripts/demo/demo_app.gd":
        return [row for row in references if 1365 <= row["line"] <= 1376 or row["line"] == 116]
    source = texts[path].splitlines()
    starts = [i for i, line in enumerate(source) if line.startswith("func _sync_music(")]
    if len(starts) != 1:
        raise ValueError("Missing/ambiguous actual CampaignFixture music selector in selected Git tree")
    start = starts[0]
    end = next((i for i in range(start + 1, len(source))
                if source[i] and not source[i][0].isspace()), len(source))
    if not any("_music.request_track(" in line for line in source[start:end]):
        raise ValueError("Actual CampaignFixture music selector no longer delegates to GameMusic")
    return [row for row in references if start + 1 <= row["line"] <= end
            or "_music.request_track(" in row["code"]]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ref", default="HEAD", help="Committed source to audit; defaults to HEAD")
    parser.add_argument("--output", type=Path, default=ROOT / "build/audio_inventory")
    args = parser.parse_args()
    if args.output.resolve().is_relative_to(ROOT) and not args.output.resolve().is_relative_to(ROOT / "build"):
        parser.error("Repository reports must be written under build/")
    ref = git("rev-parse", args.ref).decode().strip()
    tree = {}
    # Never use ls-tree -l here: obtaining omitted blob sizes in a partial clone
    # causes Git to lazily fetch every historical evidence blob.
    for line in git("ls-tree", "-r", ref).decode().splitlines():
        meta, path = line.split("\t", 1)
        mode, kind, oid = meta.split()
        if kind == "blob":
            tree[path] = {"git_oid": oid, "bytes": None}
    runtime_paths = resolve_source_paths(tree)
    code_paths = [p for p in tree if Path(p).suffix in SOURCE
                  and p.startswith(("game/", "scripts/", "scenes/", "resources/", "tests/", "tools/", "assets/", "config/"))]
    texts = {p: b.decode("utf-8", errors="replace") for p, b in blobs(ref, code_paths).items()}
    metadata_paths = [p for p in tree if p.endswith(".json") and
                      ("provenance" in p or p.endswith(("/sources.json", "/upstream.json")))
                      and p.startswith(("game/", "scripts/", "scenes/", "resources/", "tests/", "tools/", "assets/", "config/"))]
    metadata = {p: json.loads(b) for p, b in blobs(ref, metadata_paths).items()}
    audio_paths = [p for p in tree if p.startswith("assets/") and Path(p).suffix.lower() in AUDIO]
    imports = {p: b.decode("utf-8",errors="replace") for p,b in blobs(ref,[p+".import" for p in audio_paths if p+".import" in tree]).items()}
    measured_paths = audio_paths
    audio_bytes = blobs(ref, measured_paths)
    kenney = metadata["assets/audio/kenney/sources.json"]
    bgm = metadata["assets/audio/bgm/provenance.json"]
    timer = metadata["assets/player_presentation_01/mine_beep_v3/provenance.json"]
    records = []
    for path in audio_paths:
        row = {"path": path, **tree[path], "extension": Path(path).suffix.lower(),
               "technical_status": "verified" if path in audio_bytes else "unknown",
               "listening_status": "subjective_pending", "references": line_refs(texts, path),
               "metadata_status": "verified_repository_claim", "download_date": "unknown"}
        row["godot_import_settings"] = {k:v for line in imports.get(path+".import", "").splitlines()
            if "=" in line for k,v in [line.split("=",1)] if not k.startswith(("path","dest_files","source_file","uid","importer","type"))}
        if path in audio_bytes:
            raw = audio_bytes[path]
            row["bytes"] = len(raw)
            row["sha256"] = hashlib.sha256(raw).hexdigest()
            with tempfile.NamedTemporaryFile(suffix=Path(path).suffix) as file:
                file.write(raw); file.flush()
                result = subprocess.run(["ffprobe", "-v", "error", "-show_entries",
                    "stream=codec_name,sample_rate,channels,bits_per_sample:format=duration", "-of", "json", file.name],
                    capture_output=True, text=True, check=True)
                row["media"] = json.loads(result.stdout)
        else:
            row["sha256"] = None
            row["media"] = None
            row["unknown_reason"] = "Sparse historical evidence media intentionally not fetched; Git tree presence/object ID verified; byte size unknown"
        if path.startswith("assets/audio/kenney/"):
            source = kenney[Path(path).stem]
            row.update(source_url=source["source"], author="Kenney", original_file=source["original"],
                       license=source["license"], commercial_use="allowed", attribution="not_required",
                       download_date="2026-10-11 (repository README)", source_manifest="assets/audio/kenney/sources.json",
                       classification="formal_shared_or_fallback", family="central_sfx")
            row["source_sha256_matches"] = row["sha256"] == source["sha256"]
            row["references"] += line_refs(texts, 'load("res://assets/audio/kenney/%s.ogg"')
        elif path.startswith("assets/audio/bgm/"):
            source = next(s for s in bgm["tracks"] if s["runtime_path"] == path)
            row.update(source_url="user_supplied_attachments", author=bgm["author"], original_file=source["attachment_name"],
                       license="project_specific_user_authorization", commercial_use="game_and_demo_only_authorized; broader rights unknown",
                       attribution="unknown_no_separate_license_supplied", download_date=bgm["provided_at"],
                       source_manifest="assets/audio/bgm/provenance.json", classification="formal_bgm", family="bgm")
            row["source_sha256_matches"] = row["sha256"] == source["sha256"]
        elif "/feel_audio_v1/" in path or "/weapon_audio_v1/" in path:
            motion = "/feel_audio_v1/" in path
            prov = "assets/player_presentation_01/provenance/" + ("feel-audio-provenance.json" if motion else "weapon-audio-provenance.json")
            row.update(source_url="derived_from_existing_Kenney_CC0_samples", author="Kenney; project processing", original_file="see recipe and sources in manifest",
                       license="CC0-1.0 source derivatives", commercial_use="allowed", attribution="not_required",
                       source_manifest=prov, classification="formal_motion" if motion else "dormant_parent_default_and_dev_bank",
                       family="motion" if motion else "weapon_v1")
            cue = Path(path).stem.rsplit("_", 1)[0]
            inputs = [layer[0] for layer in metadata[prov]["recipes"][cue][1]]
            row["original_file"] = " + ".join(kenney[key]["original"] for key in inputs)
            row["source_urls"] = sorted({kenney[key]["source"] for key in inputs})
            expected = next(item for item in metadata[prov]["files"] if item["path"]==path)
            row["source_sha256_matches"] = row["sha256"] == expected["sha256"]
            if not inputs:
                row.update(original_file="Original procedural beam; tests/player_presentation_01/build_weapon_audio.py",
                           source_url="repository:tests/player_presentation_01/build_weapon_audio.py", author="project generator",
                           license="project_generated_no_external_samples", commercial_use="no_third_party_samples; project rights claim only",
                           attribution="no_external_attribution_claim")
        elif "/weapon_audio_v2/" in path:
            row.update(source_url="https://github.com/freedoom/freedoom/tree/3ac019628d70b812ffb722f7f2365771b76a9d29/sounds",
                       author="Freedoom contributors; per-sample attribution retained in CREDITS", original_file="see per-family recipe/upstream archive",
                       license="BSD-3-Clause", commercial_use="allowed_with_license_and_copyright_retention_no_endorsement",
                       attribution="retain_COPYING_and_CREDITS_in_distribution", source_manifest="assets/player_presentation_01/provenance/weapon-audio-v2-provenance.json",
                       classification="loaded_but_replaced_by_timer_v3" if "/mine_beep_" in path else "formal_weapon", family="weapon_v2")
            cue = Path(path).stem.rsplit("_", 1)[0]
            inputs = [layer[0] for layer in metadata[row["source_manifest"]]["recipes"][cue][2]]
            row["original_file"] = " + ".join("sounds/"+key+".wav" for key in inputs)
            row["source_urls"] = ["https://raw.githubusercontent.com/freedoom/freedoom/3ac019628d70b812ffb722f7f2365771b76a9d29/sounds/"+key+".wav" for key in dict.fromkeys(inputs)]
            expected = next(item for item in metadata[row["source_manifest"]]["files"] if item["path"]==path)
            row["source_sha256_matches"] = row["sha256"] == expected["sha256"]
        elif "/mine_beep_v3/" in path:
            source = timer["source"]
            row.update(source_url=source["page"], author=source["author"], original_file="536420_4921277-hq.mp3 (HQ preview; not original WAV)",
                       license="CC0-1.0", commercial_use="allowed", attribution="not_required",
                       source_manifest="assets/player_presentation_01/mine_beep_v3/provenance.json",
                       classification="source_cache_not_runtime" if "/sources/" in path else "formal_timer", family="timer")
            row["source_sha256_matches"] = row["sha256"] == (source["sha256"] if "/sources/" in path else timer["output"]["sha256"])
        elif path.startswith("assets/forest_bible_v2/audio/"):
            row.update(source_url="repository:tools/generate_forest_bible_sfx.py", author="OpenAI Codex project session",
                       original_file=Path(path).name, license="project_generated_no_third_party_sample_claim",
                       commercial_use="no_external_samples; project rights claim only", attribution="no_external_attribution_claim",
                       source_manifest="assets/forest_bible_v2/audio/provenance.json", classification="formal_regional_synthesis", family="regional")
            expected = next(item for item in metadata[row["source_manifest"]]["files"] if item["path"]==path)
            row["source_sha256_matches"] = row["sha256"] == expected["sha256"]
        elif path == "assets/audio/enemy_feedback_01/death_burst.wav":
            row.update(source_url="https://kenney.nl/assets/impact-sounds", author="Kenney; project processing/synthesis",
                       original_file="impactWood_light_000.ogg + impactWood_heavy_000.ogg + impactSoft_medium_000.ogg + original synthesis",
                       license="CC0-1.0 source derivatives + original project synthesis", commercial_use="allowed_source_license",
                       attribution="not_required_for_CC0_sources", source_manifest="assets/audio/enemy_feedback_01/provenance.json",
                       classification="dormant_legacy_death_helper_not_default", family="enemy_death")
            row["source_sha256_matches"] = row["sha256"] == metadata[row["source_manifest"]]["asset_sha256"]
        elif path in {"assets/audio/windchime_open.wav", "assets/audio/plains_shot.wav", "assets/audio/plains_armour.wav", "assets/audio/plains_core.wav", "assets/audio/windkeeper_roar.wav"}:
            generator = "tools/generate_windchime_audio.py" if "windchime_open" in path else "tools/generate_plains_combat_audio.py"
            row.update(source_url="repository:"+generator, author="project procedural generator", original_file=Path(path).name,
                       license="project_generated_no_external_samples", commercial_use="no_third_party_samples; no standalone license asserted",
                       attribution="no_external_attribution_claim", source_manifest=generator,
                       classification="retained_legacy_synthesis_no_runtime_reference", family="legacy_synthesis")
        else:
            row.update(source_url="unknown_source_manifest_needed", author="unknown", original_file=Path(path).name,
                       license="unknown", commercial_use="unknown", attribution="unknown",
                       source_manifest="unknown", classification="unknown_requires_audit", family="unknown")
        records.append(row)
    hashes = collections.defaultdict(list)
    for row in records:
        if row["sha256"]: hashes[row["sha256"]].append(row["path"])
    archive = "assets/player_presentation_01/weapon_audio_v2/sources/freedoom-originals.zip"
    archived = []
    with zipfile.ZipFile(io.BytesIO(blobs(ref, [archive])[archive])) as file:
        for name in file.namelist():
            if Path(name).suffix.lower() in AUDIO:
                raw = file.read(name)
                archived.append({"archive": archive, "member": name, "bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest(),
                                 "license": "BSD-3-Clause", "classification": "preserved_source_not_runtime", "listening_status": "subjective_pending"})
    callsites = []
    call_pattern = re.compile(r"GameAudio\.cue\(|\.motion_cue\(|\.weapon_cue\(|\b_sound\(|\b_cue\(|\b_loop\(|\.request_track\(|\.play\(|\bplay\(&\"")
    for path, text in texts.items():
        for i, line in enumerate(text.splitlines(), 1):
            if call_pattern.search(line) and not line.lstrip().startswith(("#", "func ", "def ")):
                callsites.append({"path": path, "line": i, "code": line.strip(), "scope":
                                  "test_or_tool" if path.startswith(("tests/", "tools/")) else
                                  "dev_or_formal_shared_requires_assembly_evidence" if path.startswith("scripts/dev/") else "runtime_source"})
    cue_ids = re.findall(r'&"([a-z_]+)"', next(line for line in texts[runtime_paths['scripts/audio/game_audio.gd']].splitlines() if "const CUES :=" in line))
    descriptions = {"focus_start":"慢瞄开始／二跳／钩索释放／旧武器阶段共享", "focus_end":"慢瞄结束", "enemy_defeat":"敌人接受死亡（可被DeathAudio替换）", "door":"已接受关卡／区域门转换", "warning":"敌人／Boss攻击预告或封门", "boss_impact":"Boss动作冲击及DefeatBurst", "click":"全部BaseButton pressed自动点击", "confirm":"接受交易、资源恢复和部分动作成功共享", "coin":"金币及普通奖励", "note":"音符／其他拾取", "victory":"运行成功／区域完成", "jump":"经典主角起跳／蹬墙／钩索踢出及旧动作", "land":"经典主角落地", "step":"主角累计移动距离脚步", "hurt":"敌人普通受击和主角受伤共享", "shot":"旧版主角射击（新正式WeaponFeel委派关闭）", "impact":"旧弹体接触／钩索接触踢出／武器后备", "armour":"护甲／无效伤害反馈", "core":"Boss铃芯有效受击", "enemy_shot":"敌方攻击发射", "heal":"接受生命拾取／生命奖励", "death":"主角死亡和运行失败共享", "bell":"机关射铃／钩索连接／部分种子接触共享", "denied":"UI拒绝／射击拒绝／钩索失败共享", "roar":"牧风者阶段咆哮"}
    events = []
    for cue in cue_ids + ["forest_wind", "forest_fruit", "forest_web"]:
        refs = [c for c in callsites if f'&"{cue}"' in c["code"] and
                ("GameAudio.cue(" in c["code"] or re.search(r"\b_cue\(",c["code"]) or
                 c["path"]==runtime_paths['scripts/audio/game_audio.gd'] and "play(" in c["code"])]
        asset = next((r for r in records if r["path"] == f"assets/audio/kenney/{cue}.ogg" or r["path"] == f"assets/forest_bible_v2/audio/{cue}.wav"), None)
        events.append({"event_id": "cue."+cue, "description": descriptions.get(cue,{"forest_wind":"森林每9秒风声（首次3秒）", "forest_fruit":"800wu内接受果枝钩索", "forest_web":"800wu内真实蛛网生长状态进入"}.get(cue,cue)),
                       "route": "GameAudio.cue → local game_audio service → shared 12-voice pool", "assets": [asset["path"]] if asset else [],
                       "references": refs, "mapping_status": "verified_static", "listening_status":"subjective_pending"})
    for cue in ["jump", "land", "heavy"]:
        motion_refs = line_refs(texts,'audio.motion_cue(&"jump"' if cue=="jump" else 'audio.motion_cue(&"heavy"',(runtime_paths['scripts/dev/player_presentation_01/motion_feel.gd'],))
        motion_refs += line_refs(texts,'visual.motion_jump.connect' if cue=="jump" else 'visual.motion_land.connect',(runtime_paths['scripts/dev/player_presentation_01/motion_feel.gd'],))
        events.append({"event_id":"motion."+cue, "description":{"jump":"新版主角接受起跳", "land":"新版主角轻落地", "heavy":"新版主角重落地"}[cue],
                       "route":"PlayerMotionFeel → PlayerMotionAudio.motion_cue → same 12-voice pool", "assets":[r["path"] for r in records if r["family"]=="motion" and Path(r["path"]).stem.startswith(cue+"_")],
                       "references":motion_refs,
                       "mapping_status":"verified_static", "listening_status":"subjective_pending"})
    weapon_ids = ["pulse","machine","blade","hit","wall","blast","ion_start","ion_loop","ion_tail","blackhole_start","blackhole_loop","blackhole_burst","mine_beep","boomerang_return"]
    for cue in weapon_ids:
        refs = [c for c in callsites if f'&"{cue}"' in c["code"] and c["path"].startswith(("scripts/", "game/", "experiments/"))]
        if cue in ["pulse","machine","blade"]:
            refs += line_refs(texts,'var cue: StringName',(runtime_paths['scripts/dev/player_presentation_01/weapon_feel.gd'],))
        if cue in ["blast","blackhole_burst"]:
            refs += line_refs(texts,'var cue: StringName',(runtime_paths['scripts/dev/player_presentation_01/weapon_feel_v2.gd'],))
            refs += line_refs(texts,'_sound(cue,',(runtime_paths['scripts/dev/player_presentation_01/weapon_feel_v2.gd'],))
        assets = [r["path"] for r in records if r["family"]=="weapon_v2" and Path(r["path"]).stem.startswith(cue+"_")]
        if cue=="mine_beep": assets=["assets/player_presentation_01/mine_beep_v3/timer_beep.wav"]
        events.append({"event_id":"weapon."+cue, "description":{"pulse":"接受普通枪及默认弹体射击／反冲同帧反馈", "machine":"接受机枪弹次", "blade":"手里剑／扇刃／实体掷出", "hit":"确认敌方HP伤害提交；不是固体接触", "wall":"真实地形接触或地雷附着", "blast":"接受爆炸", "ion_start":"光束开始／蓄力／炮释放", "ion_loop":"光束持续阶段", "ion_tail":"光束结束", "blackhole_start":"奇点启动", "blackhole_loop":"奇点持续阶段", "blackhole_burst":"奇点爆发", "mine_beep":"真实地雷age/fuse节奏提示", "boomerang_return":"回旋镖返回／自动接住"}[cue],
                       "route":"PlayerWeaponFeelV2 + accepted controller/runtime events → weapon_cue → shared 12-voice pool", "assets":assets,
                       "references":refs, "mapping_status":"verified_static", "listening_status":"subjective_pending"})
    for cue in ["home","plains","plains_boss","forest","forest_boss"]:
        events.append({"event_id":"music."+cue,"description":"用户原BGM；由CampaignFixture真实状态选择", "route":"CampaignFixture._sync_music → GameMusic.request_track → two crossfade voices",
                       "assets":[r["path"] for r in records if r["family"]=="bgm" and (cue=="home" and "kindred" in r["path"] or cue=="plains" and "path_bends" in r["path"] or cue=="plains_boss" and "wooden_sails" in r["path"] or cue=="forest" and "beneath" in r["path"] or cue=="forest_boss" and "knotted" in r["path"])],
                       "references":line_refs(texts,'&"'+cue+'"',(runtime_paths['scripts/audio/game_music.gd'],))+music_app_refs(texts, runtime_paths['scripts/demo/demo_app.gd'], cue),"mapping_status":"verified_static","listening_status":"subjective_pending"})
    generators=[]
    for p, text in texts.items():
        if p.endswith(".py") and ("wave.open" in text or "ffmpeg" in text) and re.search(r"audio|sound|sfx",p,re.I):
            generators.append({"path":p,"sha256":hashlib.sha256(text.encode()).hexdigest(),"references":[{"path":p,"line":i,"code":line.strip()} for i,line in enumerate(text.splitlines(),1) if re.search(r"wave.open|sin\(|noise|ffmpeg|CUES\s*=|TARGET\s*=|DEST\s*=",line)][:20]})
    player_nodes=[{"path":p,"line":i,"code":line.strip()} for p,text in texts.items() for i,line in enumerate(text.splitlines(),1) if re.search(r"AudioStreamPlayer(?:2D|3D)?(?:\.new|\")|AudioServer|\.bus\s*=",line)]
    inventory={"schema_version":1,"task":"AUDIO-DIRECTOR-01","source_commit":ref,"scope":"All tracked standalone audio extensions; archived source member ledger; all nonhistorical code/resource audio references. No gameplay execution/listening claim.",
               "status_vocabulary":{"verified":"Observed bytes/static source at pinned commit", "subjective_pending":"Must be heard and accepted by user", "unknown":"No evidence; never assume permission or non-use"},
               "summary":{"standalone_audio_files":len(records),"measured_files":len(audio_bytes),"families":dict(collections.Counter(r["family"] for r in records)),"archived_source_members":len(archived)},
               "assets":records,"archived_source_members":archived,"duplicate_sha256_groups":[{"sha256":k,"paths":v} for k,v in hashes.items() if len(v)>1],
               "generators":generators,"audio_nodes_and_bus_references":player_nodes,
               "unknowns":["Static reachability is not an observed play session; per-event audible coverage awaits Godot/browser evidence", "Historical evidence archive internals beyond the tracked audio files are not runtime sources and are not expanded", "Source download dates missing from old provenance remain unknown", "BGM author/broader commercial redistribution license is not supplied; retain project authorization boundary", "No subjective quality, real device latency or loudness balance has been accepted"]}
    catalog={"schema_version":1,"task":"AUDIO-DIRECTOR-01","source_commit":ref,"events":events,"all_audio_callsites":callsites,
             "missing_or_collapsed_event_semantics":[{"event":"hook.release / hook.connect / hook.pull / hook.miss","state":"existing shared cues, no dedicated family or sustained pull loop","references":line_refs(texts,'GameAudio.cue',(runtime_paths['scripts/art/player_feedback.gd'],))},
                {"event":"player.hurt vs enemy.hurt","state":"same cue.hurt; independent scopes collide with global cooldown","references":line_refs(texts,'&"hurt"',(runtime_paths['scripts/art/player_feedback.gd'],runtime_paths['scripts/enemies/enemy_actor.gd']))},
                {"event":"recoil","state":"accepted shot supplies feedback; no standalone recoil audio layer observed","references":line_refs(texts,'var cue: StringName',(runtime_paths['scripts/dev/player_presentation_01/weapon_feel.gd'],))},
                {"event":"plains wind / gears / pendulum / material-specific footsteps / enemy species vocal identity","state":"no dedicated runtime event mapping found in audited source; not proof every future design requires one","references":[]}],
             "conflicts":["Nonlethal enemy HP hit may trigger shared hurt plus weapon.hit; this is observed static layering, not a claim of audible clipping", "All BaseButton pressed emits click; explicit confirm/denied can layer on the same interaction", "Shared global cue cooldown can suppress unrelated origins (e.g. player.hurt after enemy.hurt)", "motion and weapon serials cycle deterministically; no shuffle bag or per-family no-repeat policy", "Most SFX have no spatial attenuation; forest has binary 800wu gate and standalone bell has 2D attenuation", "Parent V1 bank and V2 timer files stay loaded although formal V2 replaces their playback mapping"]}
    # Old phase-one prose is not current evidence; emit measured facts only.
    catalog.pop("missing_or_collapsed_event_semantics", None)
    catalog.pop("conflicts", None)
    args.output.mkdir(parents=True,exist_ok=True)
    (args.output/"inventory.json").write_text(json.dumps(inventory,ensure_ascii=False,indent=2)+"\n")
    (args.output/"event_catalog.json").write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+"\n")
    render_inventory(args.output,inventory)
    render_catalog(args.output,catalog)
    print(json.dumps({"source_commit":ref,**inventory["summary"],"events":len(events),"callsites":len(callsites)},ensure_ascii=False))


def render_inventory(out: Path, inventory: dict) -> None:
    rows = ["# Audio inventory", "", f"Source commit: `{inventory['source_commit']}`.", "",
            "Generated static audit; no listening or device acceptance. Details: [inventory.json](inventory.json).", "",
            "| Asset | Classification | Source / license |", "| --- | --- | --- |"]
    for row in inventory["assets"]:
        rows.append(f"| `{row['path']}` | {row['classification']} | `{row['source_manifest']}` / {row['license']} |")
    (out / "inventory.md").write_text("\n".join(rows) + "\n")


def render_catalog(out: Path, catalog: dict) -> None:
    rows = ["# Audio event references", "", f"Source commit: `{catalog['source_commit']}`.", "",
            "Static callsites only; dynamic routes require runtime verification. Details: [event_catalog.json](event_catalog.json).", ""]
    for event in catalog["events"]:
        rows.append(f"- `{event['event_id']}`: " + ", ".join(refstr(ref) for ref in event["references"]))
    (out / "event_catalog.md").write_text("\n".join(rows) + "\n")


if __name__ == "__main__":
    main()
