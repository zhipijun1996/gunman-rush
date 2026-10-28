#!/usr/bin/env python3
"""Current main canvas smoke, operated from actual captured pixels; no game API.

Launch only with the parent's browser lease. Append JSON commands to commands.jsonl
after viewing the latest PNG. Every input and visual confirmation names that PNG's
SHA256. Fresh 300s run per device; original scripts and their assertions unchanged.
"""
import argparse
import asyncio
import hashlib
import json
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from verify_forest_browser import fetch_identity
from playwright.async_api import async_playwright

CHECKPOINTS = ("title", "home", "plains", "backpack", "page_left", "page_right", "resumed")
TOKENS = ("SCRIPT ERROR", "SHADER ERROR", "Parse Error", "ERROR:", "Shader compilation failed")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git_head():
    return subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()


def git_status():
    return subprocess.check_output(["git", "status", "--porcelain", "--untracked-files=no"], cwd=ROOT, text=True).strip()


def foundry_overlay_snapshot():
    paths = subprocess.check_output(["git", "diff", "--name-only"], cwd=ROOT, text=True).splitlines()
    if not paths or any(not path.startswith("resources/foundry/") for path in paths):
        raise AssertionError("Explicit preflight overlay must contain only original resources/foundry leaves")
    return {path: sha(ROOT / path) for path in paths}


async def run(args, report):
    report["identity"] = None
    report["commands"] = []
    report["captures"] = []
    report["confirmations"] = []
    report["console"] = []
    report["events"] = []
    report["responses"] = []
    report["request_failures"] = []
    report["errors"] = []
    report["non_runtime_favicon404"] = []
    report["error_scope_rationale"] = "Parent explicitly accepts only default same-origin /favicon.ico console Failed to load resource +404 as non-runtime browser-default-icon warning; original desktop02 FAIL retained. All gameplay/script/shader/page/asset errors remain strict."
    phase = "identity"
    width, height = (1280, 720) if args.device == "desktop" else (960, 540)
    latest = None

    def persist():
        (args.output / "receipt.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")

    def require(ok, message):
        if not ok:
            raise AssertionError(message)

    async with async_playwright() as playwright:
        browser = await playwright.chromium.launch(
            executable_path=shutil.which("chromium"), headless=True, timeout=30000,
            args=["--no-sandbox", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"])
        context = await browser.new_context(
            viewport={"width": width, "height": height}, device_scale_factor=1,
            has_touch=args.device == "touch", is_mobile=args.device == "touch")
        page = await context.new_page()
        try:
            report["identity"] = await fetch_identity(context.request, args.url, args.commit, args.build_id)
            require(git_head() == args.commit, "Actual source checkout is not expected merged main")
            if args.foundry_overlay_preflight:
                report["foundry_overlay_before"] = foundry_overlay_snapshot()
                require(len(report["foundry_overlay_before"]) == 56, "Expected the explicitly authorized56leaf Foundry overlay")
            else:
                require(not git_status(), "Source checkout contains tracked changes before GUI smoke")

            def console(message):
                text = message.text
                report["console"].append({"phase": phase, "type": message.type, "text": text,
                                           "location": message.location})
                location = urlparse(message.location.get("url", ""))
                origin = urlparse(args.url)
                favicon = (message.type == "error" and "Failed to load resource" in text
                           and re.search(r"\b404\b", text) is not None
                           and location.scheme == origin.scheme and location.netloc == origin.netloc
                           and location.path == "/favicon.ico" and not location.query and not location.fragment
                           and not any(token in text for token in TOKENS))
                if favicon:
                    report["non_runtime_favicon404"].append(report["console"][-1].copy())
                elif message.type == "error" or any(token in text for token in TOKENS):
                    report["errors"].append(text)
                if "FOREST_UI_EVENT " in text:
                    try:
                        report["events"].append({"phase": phase, **json.loads(text.split("FOREST_UI_EVENT ", 1)[1])})
                    except json.JSONDecodeError:
                        report["errors"].append("Invalid actual FOREST_UI_EVENT JSON")

            def response(item):
                path = urlparse(item.url).path
                row = {"phase": phase, "url": item.url, "status": item.status,
                       "from_service_worker": item.from_service_worker,
                       "service_worker_owned": bool(item.request.service_worker),
                       "heavy": path.endswith((".pck", ".wasm", ".wasm.gz")) or "/chunks/" in path}
                report["responses"].append(row)
                if item.status >= 400:
                    report["errors"].append("HTTP %s %s" % (item.status, item.url))

            page.on("console", console)
            page.on("pageerror", lambda error: report["errors"].append("PAGE ERROR: " + str(error)))
            context.on("response", response)
            context.on("requestfailed", lambda request: report["request_failures"].append(
                {"phase": phase, "url": request.url, "failure": request.failure}))

            async def capture(label):
                nonlocal latest
                require(re.fullmatch(r"[a-z0-9_-]{1,60}", label), "Unsafe capture label")
                name = "%03d-%s.png" % (len(report["captures"]), label)
                path = args.output / name
                await page.screenshot(path=str(path), timeout=10000)
                latest = {"file": name, "sha256": sha(path), "label": label,
                          "phase": phase, "unix": time.time(), "viewport": [width, height]}
                report["captures"].append(latest)
                persist()
                print(json.dumps({"awaiting_actual_pixel_review": latest}, ensure_ascii=False), flush=True)

            async def ready():
                await page.wait_for_function("window.PLAYTEST_LOADING_DONE===true", timeout=60000)
                await page.wait_for_timeout(500)
                require(await page.locator("#playtest-version").get_attribute("data-build-id") == args.build_id,
                        "Rendered build badge differs from expected export")
                require(not report["errors"], "Strict browser/engine/HTTP error: " + str(report["errors"]))

            report["loads"] = []
            if args.cache_risk_reference:
                prior = json.loads(args.cache_risk_reference.read_text())
                require(prior.get("original_status") == "failed" and prior.get("observed_loads"), "Historical cache reference must retain actual prior FAIL")
                report["cache_zero_warm_network"] = {"passed": False, "current_warm_execution": "not-run",
                    "historical_reference": str(args.cache_risk_reference), "reference_sha256": sha(args.cache_risk_reference),
                    "historical_identity": prior.get("identity"), "historical_observed_loads": prior["observed_loads"],
                    "current_identity": report["identity"], "prior_bytes_are_not_current_measurement": True,
                    "rationale": "Parent authorizes cold-only currentmain GUI; original80MiB chunk/128MiBraw cache limit versus201MB package remains known risk, not a new warm PASS"}
            if args.prior_cache_report:
                prior = json.loads(args.prior_cache_report.read_text())
                require(prior.get("identity") == report["identity"], "Prior cold/warm observation is a different exact package")
                require(prior.get("original_status") == "failed" and prior.get("observed_loads"), "Prior cache result must retain original FAIL")
                report["cache_zero_warm_network"] = {"passed": False, "reused_observation_path": str(args.prior_cache_report),
                                                        "reused_observation_sha256": sha(args.prior_cache_report),
                                                        "observed_loads": prior["observed_loads"],
                                                        "rationale": "Same exact source/PCK/loader; parent instructed not to repeat known201MB warm transfer"}
            for phase in (("cold",) if (args.prior_cache_report or args.cache_risk_reference) else ("cold", "warm")):
                started = time.monotonic()
                if phase == "cold":
                    await page.goto(args.url, wait_until="domcontentloaded", timeout=45000)
                else:
                    await page.reload(wait_until="domcontentloaded", timeout=45000)
                await ready()
                resources = await page.evaluate("performance.getEntriesByType('resource').map(r=>({name:r.name,transferSize:r.transferSize,encodedBodySize:r.encodedBodySize,decodedBodySize:r.decodedBodySize}))")
                controlled = await page.evaluate("Boolean(navigator.serviceWorker.controller)")
                report["loads"].append({"phase": phase, "ready_seconds": time.monotonic() - started,
                                        "service_worker_controlled": controlled, "resources": resources})
                await capture(phase + "-title")
                if phase == "warm":
                    require(controlled, "Warm actual page is not service-worker controlled")
                    network = [row for row in report["responses"] if row["phase"] == "warm"
                               and row["heavy"] and not row["from_service_worker"]]
                    report["cache_zero_warm_network"] = {"passed": not network, "network_heavy_responses": network,
                                                        "assertion_timing": "deferred until after functional GUI; original failure threshold unchanged"}
            phase = "route"
            processed = 0
            while True:
                require(not report["errors"], "Strict browser/engine/HTTP error: " + str(report["errors"]))
                lines = (args.output / "commands.jsonl").read_text().splitlines()
                if processed == len(lines):
                    await asyncio.sleep(.1)
                    continue
                line = lines[processed]
                processed += 1
                if not line.strip():
                    continue
                command = json.loads(line)
                require(command.get("based_on_sha256") == latest["sha256"],
                        "Command must refer to latest actual PNG; inspect it before acting")
                report["commands"].append({"command": command, "based_on": latest.copy(), "unix": time.time()})
                op = command.get("op")
                if op == "confirm":
                    expected = CHECKPOINTS[len(report["confirmations"])]
                    require(command.get("checkpoint") == expected, "Wrong actual route confirmation order")
                    require(bool(str(command.get("observation", "")).strip()), "Visual confirmation needs actual observation")
                    if expected == "plains":
                        require(any(row.get("event") == "region_assembled" and row.get("region") == "plains"
                                    and row.get("map_index") == 1 and row.get("debug_entry") is False
                                    for row in report["events"]), "No real formal Plains map1 assembly event")
                    report["confirmations"].append({"checkpoint": expected, "capture": latest.copy(),
                                                    "observation": command["observation"],
                                                    "method": "operator inspected actual captured pixels"})
                elif op in ("click", "tap"):
                    x, y = float(command["x"]), float(command["y"])
                    require(0 <= x < width and 0 <= y < height, "Pointer outside actual canvas viewport")
                    if op == "tap":
                        require(args.device == "touch", "Tap requires real emulated touchscreen context")
                        await page.touchscreen.tap(x, y)
                    else:
                        await page.mouse.click(x, y)
                elif op == "key":
                    require(command["key"] in ("Escape", "ArrowLeft", "ArrowRight", "Enter", "w", "a", "d"), "Unexpected smoke key")
                    await page.keyboard.press(command["key"])
                elif op == "hold":
                    require(command["key"] in ("a", "d"), "Only actual bounded Home horizontal movement")
                    duration = int(command["duration_ms"])
                    require(1 <= duration <= 1800, "Home movement pulse exceeds original bounded input")
                    await page.keyboard.down(command["key"])
                    try:
                        await page.wait_for_timeout(duration)
                    finally:
                        await page.keyboard.up(command["key"])
                elif op != "capture":
                    raise AssertionError("Unknown command op")
                if len(report["confirmations"]) == len(CHECKPOINTS):
                    break
                if op == "confirm":
                    persist()
                    continue
                delay = int(command.get("wait_ms", 350))
                require(0 <= delay <= 1500, "Unbounded command settle wait")
                await page.wait_for_timeout(delay)
                await capture(command.get("label", "after-" + str(processed)))
            require(not report["errors"], "Strict errors present at completion")
            require(not report["request_failures"], "Actual requests failed: " + str(report["request_failures"]))
            require(git_head() == args.commit, "Source HEAD changed during actual GUI smoke")
            if args.foundry_overlay_preflight:
                report["foundry_overlay_after"] = foundry_overlay_snapshot()
                require(report["foundry_overlay_after"] == report["foundry_overlay_before"], "Explicit preflight Foundry overlay changed")
            else:
                require(not git_status(), "Source checkout contains tracked changes after GUI smoke")
            report["functional_passed"] = True
            report["game_errors"] = len(report["errors"])
            report["non_runtime_favicon404_count"] = len(report["non_runtime_favicon404"])
            require(report["cache_zero_warm_network"]["passed"], "Warm zero raw/chunk network failed; functional route evidence retained separately")
            report["status"] = "passed"
        finally:
            await context.close()
            await browser.close()
            persist()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", required=True)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--build-id", required=True)
    parser.add_argument("--device", choices=("desktop", "touch"), required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--cache-risk-reference", type=Path, help="Cold-only current package; old cache failure explicitly historical/not-run, never relabel old bytes as current")
    parser.add_argument("--prior-cache-report", type=Path, help="Reuse exact unchanged-package cold/warm observation as instructed; preserve original failed cache result")
    parser.add_argument("--foundry-overlay-preflight", action="store_true", help="Explicit authorized56leaf Foundry snapshot; branch preflight only, never clean main delivery")
    args = parser.parse_args()
    if args.prior_cache_report and args.cache_risk_reference:
        parser.error("Choose exact same-package cache reuse or historical risk reference, never both")
    if not re.fullmatch("[0-9a-f]{40}", args.commit) or not re.fullmatch("[0-9a-f]{12}", args.build_id):
        parser.error("Require exact full merged-main SHA and12-character exported build ID")
    if urlparse(args.url).scheme not in ("http", "https"):
        parser.error("Require actual HTTP(S) export URL")
    args.output = args.output.resolve()
    if not args.output.is_relative_to(ROOT / "build"):
        parser.error("Use a fresh output under build")
    args.output.mkdir(parents=True, exist_ok=False)
    (args.output / "commands.jsonl").write_text("")
    report = {"status": "failed", "source_commit": args.commit, "source_head_before": git_head(),
              "build_id": args.build_id, "device": args.device, "url": args.url, "started_unix": time.time(),
              "producer_sha256": sha(Path(__file__)), "identity_helper_sha256": sha(ROOT / "tools/verify_forest_browser.py"),
              "video": "not requested; actual PNG checkpoints only (Playwright ffmpeg dependency unavailable on first attempt)",
              "budget_seconds": 300, "branch_preflight_foundry_overlay": args.foundry_overlay_preflight,
              "main_delivery": False if args.foundry_overlay_preflight else "not inferred by GUI runner",
              "scope": "Actual screenshot-reviewed title/Home/formalPlains/pause/backpack/pages/resume through browser input only; software Chromium touch emulation is not a physical Android device or gameplay completion"}
    try:
        asyncio.run(asyncio.wait_for(run(args, report), timeout=300))
    except BaseException as error:
        report["error"] = str(error) or type(error).__name__
        raise
    finally:
        report["ended_unix"] = time.time()
        report["duration_seconds"] = report["ended_unix"] - report["started_unix"]
        report["source_head_after"] = git_head()
        (args.output / "receipt.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
        print(json.dumps({key: report.get(key) for key in ("status", "device", "duration_seconds", "error")}), flush=True)


if __name__ == "__main__":
    main()
