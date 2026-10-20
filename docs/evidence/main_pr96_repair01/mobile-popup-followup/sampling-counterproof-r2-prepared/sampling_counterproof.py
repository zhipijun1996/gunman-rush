"""Finite actual-Web sampling controls; not the original three-consumer acceptance."""
import argparse
import asyncio
from functools import partial
import hashlib
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from threading import Thread
import time


def require(ok, message):
    if not ok:
        raise AssertionError(message)


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def args():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--repo-root", type=Path, required=True)
    p.add_argument("--expected-source-sha", required=True)
    p.add_argument("--web-dir", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--worker", action="store_true", help=argparse.SUPPRESS)
    a = p.parse_args()
    require(re.fullmatch(r"[0-9a-f]{40}", a.expected_source_sha), "Explicit full frozen source SHA required")
    a.repo_root = a.repo_root.resolve()
    a.web_dir = a.web_dir.resolve()
    a.output = a.output.resolve()
    require(a.output.is_relative_to(a.repo_root / "build"), "New ignored build output required")
    return a


async def case(browser, a, name, url, hook_y, deadzone):
    from studio_gui_pointer import enter_action_studio, select_weapon, weapon_row_y
    folder = a.output / name
    folder.mkdir()
    cwd = folder / "browser-cwd"
    cwd.mkdir()
    os.chdir(cwd)  # Original navigator retains its own unmodified screenshot/OCR evidence.
    events, errors, operations = [], [], []
    result = {"case": name, "status": "failed", "expected_criterion": name == "positive"}
    context = await browser.new_context(viewport={"width": 1280, "height": 720})
    page = await context.new_page()

    def mark(operation):
        operations.append({"operation": operation, "monotonic": time.monotonic(), "event_count": len(events)})

    def log(message):
        with (folder / "console.log").open("a") as out:
            out.write(message.text + "\n")
        if "STUDIO_EVENT " in message.text:
            try:
                e = json.loads(message.text.split("STUDIO_EVENT ", 1)[1])
                events.append(e)
                with (folder / "events.jsonl").open("a") as out:
                    out.write(json.dumps({"sequence": len(events) - 1, "received_monotonic": time.monotonic(), "event": e}) + "\n")
            except json.JSONDecodeError:
                errors.append(message.text)
        if any(x in message.text for x in ("SCRIPT ERROR", "Parse Error", "ERROR:")):
            errors.append(message.text)

    async def wait(predicate):
        end = time.monotonic() + 5  # Original real kick/free/equip/entity wait, never extended.
        while time.monotonic() < end:
            if predicate():
                return True
            await page.wait_for_timeout(50)
        return False

    async def fire():
        await page.mouse.move(650, 670)
        await page.mouse.down()
        await page.wait_for_timeout(40)
        await page.mouse.up()

    page.on("console", log)
    page.on("pageerror", lambda e: errors.append(str(e)))
    try:
        await page.goto(url, wait_until="networkidle")
        # Original loader-only readiness; no DOM/game-state read, mutation or injected input.
        await page.wait_for_function("window.PLAYTEST_LOADING_DONE===true", timeout=60000)
        await page.wait_for_timeout(600)
        await enter_action_studio(page, between_clicks_ms=300)
        await page.wait_for_timeout(600)
        await page.mouse.click(710, await weapon_row_y(page))
        await page.wait_for_timeout(250)
        n = len(events)
        await select_weapon(page, 6)
        require(await wait(lambda: any(e["action"] == "weapon_equipped" for e in events[n:])), "No actual choose6 equip")
        equip = next(e for e in events[n:] if e["action"] == "weapon_equipped")
        require(equip["weapon"] == "remote_boomerang", "Actual choose6 weapon identity mismatch")
        await page.mouse.click(330, await weapon_row_y(page))
        await page.wait_for_timeout(300)
        # This additional clock check needs real air time, independently of H.
        # The original three consumers retain their unmodified hook sequence.
        n = len(events)
        mark("ordinary_jump_setup")
        await page.keyboard.down(" ")
        await page.wait_for_timeout(160)
        await page.keyboard.up(" ")
        require(await wait(lambda: any(e["action"] == "jump" for e in events[n:])), "No actual ordinary setup jump")
        jump = next(e for e in events[n:] if e["action"] == "jump")
        require(jump["detail"]["used"] == 1, "Setup was not the first actual jump")
        start = len(events)
        mark("before_original_fire650670")
        await fire()
        require(await wait(lambda: any(e["action"] == "weapon_entities" and e["detail"]["entities"] for e in events[start:])), "No actual released entity")
        born = next(e for e in events[start:] if e["action"] == "weapon_entities" and e["detail"]["entities"])
        require(born["position"][1] < jump["position"][1] - 20, "Actual entity release did not occur in the air")
        packet = born["packet"]
        require(type(packet) is int and packet > 0 and born["weapon"] == "remote_boomerang", "Actual entity packet identity missing")
        require(len(born["detail"]["entities"]) == 1 and born["detail"]["entities"][0]["kind"] == "boomerang", "Expected one real same-packet boomerang")
        mark("entity_released")
        if name == "positive":
            await page.mouse.move(790, 250)
            await page.mouse.down()
            mark("focus_down")
            await page.wait_for_timeout(1300)
            await page.keyboard.press(" ")
            mark("original_jump_between_holds")
            await page.wait_for_timeout(1300)
        elif name == "short-focus":
            await page.mouse.move(790, 250)
            await page.mouse.down()
            mark("focus_down")
            await page.wait_for_timeout(700)
            await page.mouse.up()
            mark("short_focus_up")
            await page.keyboard.press("f")
            mark("real_short_recall_F")
            require(await wait(lambda: any(e["action"] == "weapon_entity_transition" and e["detail"].get("packet") == packet and e["detail"].get("state") == "caught" for e in events[start:])), "Real short recall never caught the actual packet")
        else:
            mark("normal_no_focus_wait")
            await page.wait_for_timeout(2600)

        # Freeze the actual evaluation slice BEFORE any screenshot/cleanup await.
        cutoff = len(events)
        evaluated_at = time.monotonic()
        window = events[start:cutoff]
        rows = [e for e in window if e["action"] == "weapon_motion" and e["detail"]["entities"]]
        require(rows, "No real active motion evidence (empty negative is not accepted)")
        require(all(e["packet"] == packet and e["weapon"] == born["weapon"] and len(e["detail"]["entities"]) == 1 and e["detail"]["entities"][0]["kind"] == "boomerang" for e in rows), "Mixed/foreign entity packet in evaluation slice")
        require(all(b["real_usec"] > x["real_usec"] for x, b in zip(rows, rows[1:])), "Actual monotonic timestamps must increase")
        scaled = [e for e in rows if e["time_scale"] < .5]
        span = scaled[-1]["real_usec"] - scaled[0]["real_usec"] if scaled else 0
        criterion = len(scaled) >= 3 and scaled[-1]["real_usec"] - scaled[0]["real_usec"] > 2000000
        evaluation = {"event_start": start, "event_count_at_evaluation": cutoff, "evaluated_monotonic": evaluated_at, "packet": packet, "weapon": born["weapon"], "active_rows": len(rows), "scaled_indices_in_full_events": [i for i in range(start, cutoff) if events[i] in scaled], "scaled_rows": scaled, "scaled_real_span_usec": span, "criterion": criterion, "expected": name == "positive"}
        save(folder / "evaluation.json", evaluation)
        require(criterion == (name == "positive"), "Original real-duration criterion differs from requested control")
        require(not any(e["action"] == "practice_reset" for e in window), "Actual practice reset interrupted the episode")
        if name in ("positive", "short-focus"):
            require(len(scaled) >= 3, "Focused control lacks actual scaled samples; cannot prove the duration boundary")
        if name == "positive":
            require(scaled[-1]["detail"]["entities"][0]["position"][1] < scaled[0]["detail"]["entities"][0]["position"][1] - 20, "Real controlled blade did not turn upward")
        if name != "short-focus":
            await page.keyboard.press("f")
            mark("real_cleanup_F")
            if name == "positive":
                await page.mouse.up()
            require(await wait(lambda: any(e["action"] == "weapon_entity_transition" and e["detail"].get("packet") == packet and e["detail"].get("state") == "caught" for e in events[start:])), "Actual packet never caught after F")
        require(not errors, "Actual browser/runtime errors")
        result.update(status="passed", evaluation=evaluation)
    except Exception as e:
        result["error"] = {"type": type(e).__name__, "message": str(e)}
    finally:
        try:
            await page.screenshot(path=str(folder / "actual-final.png"), timeout=5000)
        except Exception as e:
            result["screenshot_error"] = {"type": type(e).__name__, "message": str(e)}
        try:
            await context.close()
        except Exception as e:
            result.update(status="failed", close_error={"type": type(e).__name__, "message": str(e)})
        if errors:
            result.update(status="failed", runtime_errors=errors)
        save(folder / "finally.json", {"result": result, "events": events, "errors": errors, "operations": operations, "evaluation_never_recomputed_from_late_events": True})
    return result


def worker(a):
    sys.path.insert(0, str(a.repo_root / "tools"))
    import harness
    from verify_ci_artifact_browser import inventory
    from playwright.async_api import async_playwright
    report = {"status": "failed", "expected_source": a.expected_source_sha, "scope": "Finite observer-clock controls only; not original three-consumer acceptance", "cases": []}
    server = None
    try:
        require(subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=a.repo_root, text=True).strip() == a.expected_source_sha, "Source is not the explicit frozen SHA")
        require(not subprocess.check_output(["git", "status", "--porcelain"], cwd=a.repo_root, text=True).strip(), "Frozen source worktree must be clean")
        report["source_before"] = harness.source_inventory()
        require(not any(p.is_symlink() for p in a.web_dir.rglob("*")), "Full bundle may not contain symlinks")
        report["bundle_before"] = inventory(a.web_dir)
        info = json.loads((a.web_dir / "build-info.json").read_text())
        require(info["source_commit"] == a.expected_source_sha, "Bundle source SHA differs from explicit source")
        require(report["bundle_before"][info["pack"]].startswith(info["build_id"]), "Actual pack fingerprint differs from build metadata")
        report["build_info"] = info
        traversal = (a.repo_root / "resources/player/traversal.tres").read_text()
        kick = re.search(r"^hook_kick = Vector2\(([-\d.]+),\s*([-\d.]+)\)$", traversal, re.M)
        dead = re.search(r"^hook_vertical_kick_deadzone = ([\d.]+)$", traversal, re.M) or re.search(r"\bvar hook_vertical_kick_deadzone := ([\d.]+)", (a.repo_root / "scripts/player/traversal_definition.gd").read_text())
        require(kick and dead, "Actual traversal resource contract missing")
        class Quiet(SimpleHTTPRequestHandler):
            def log_message(self, *_args):
                pass
        server = ThreadingHTTPServer(("127.0.0.1", 0), partial(Quiet, directory=str(a.web_dir)))
        Thread(target=server.serve_forever, daemon=True).start()
        url = f"http://127.0.0.1:{server.server_port}/"
        async def run():
            async with async_playwright() as p:
                browser = await p.chromium.launch(executable_path=shutil.which("chromium"), args=["--no-sandbox", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"])
                try:
                    for name in ("positive", "short-focus", "normal"):
                        report["cases"].append(await case(browser, a, name, url, float(kick[2]), float(dead[1])))
                finally:
                    await browser.close()
        asyncio.run(run())
        report["status"] = "passed" if len(report["cases"]) == 3 and all(c["status"] == "passed" for c in report["cases"]) else "failed"
    except Exception as e:
        report["error"] = {"type": type(e).__name__, "message": str(e)}
    finally:
        if server:
            server.shutdown()
            server.server_close()
        try:
            report["source_after"] = harness.source_inventory()
            report["bundle_after"] = inventory(a.web_dir)
            report["source_stable"] = report.get("source_before") == report["source_after"]
            report["bundle_stable"] = report.get("bundle_before") == report["bundle_after"]
            report["actual_end_source"] = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=a.repo_root, text=True).strip()
            report["actual_end_git_status"] = subprocess.check_output(["git", "status", "--porcelain"], cwd=a.repo_root, text=True)
            if not (report["source_stable"] and report["bundle_stable"] and report["actual_end_source"] == a.expected_source_sha and not report["actual_end_git_status"].strip()):
                report["status"] = "failed"
        except Exception as e:
            report.update(status="failed", guard_error=str(e))
        save(a.output / "report.json", report)
    print("SAMPLING COUNTERPROOF: " + report["status"], flush=True)
    return 0 if report["status"] == "passed" else 1


def main():
    a = args()
    if a.worker:
        return worker(a)
    a.output.mkdir(parents=True, exist_ok=False)
    (a.output / ".gdignore").touch()
    sys.path.insert(0, str(a.repo_root / "tools"))
    import harness
    command = [sys.executable, str(Path(__file__).resolve()), *sys.argv[1:], "--worker"]
    result = harness.run_check({"argv": command, "timeout_seconds": 300, "success_pattern": "^SAMPLING COUNTERPROOF: passed$"}, a.output / "driver.log", root=a.repo_root)
    save(a.output / "invocation.json", {"argv": command, "driver_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(), "expected_source": a.expected_source_sha, "cap_seconds": 300, "result": result, "scope": "Finite sampling counterproof, not original-three acceptance"})
    return 0 if result["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
