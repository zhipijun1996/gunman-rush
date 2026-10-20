"""One source-bound actual mouse Web fixture; CJK pixels need independent review.

Ignored-only supplemental case, budget120. Existing20/8 checker is unchanged.
Navigation/identity/heading guards reuse tools.verify_forest_browser helpers and
its finite real-OCR click sequence. No JS engine calls or gameplay state writes.
"""
from __future__ import annotations
import argparse
import asyncio
import datetime
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools"))
from verify_forest_browser import (fetch_identity, locate, validate_region_heading,
                                   validate_assembled_layout, async_playwright, environment_proxy)
from run_forest_depth_region import inventory


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


async def capture_case(args, report):
    folder = args.output_dir
    launch_options = {
        "executable_path": shutil.which("chromium") or shutil.which("chromium-browser"),
        "headless": True,
        "args": ["--no-sandbox", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"],
    }
    report["proxy"] = {"enabled": False, "hostname": None}
    if args.proxy_from_environment:
        launch_options["proxy"], report["proxy"] = environment_proxy()
    start = time.monotonic()

    def trace(kind, **values):
        report["input_trace"].append({"kind": kind, "elapsed_ms": round((time.monotonic()-start)*1000, 3), **values})

    async with async_playwright() as p:
        browser = await p.chromium.launch(**launch_options)
        context = None
        try:
            context = await browser.new_context(viewport={"width": 1280, "height": 720}, has_touch=False, is_mobile=False)
            page = await context.new_page()

            def console(message):
                text = message.text
                report["console"].append({"type": message.type, "text": text})
                if "FOREST_UI_EVENT " in text:
                    try:
                        report["events"].append({"device": "mouse", **json.loads(text.split("FOREST_UI_EVENT ", 1)[1])})
                    except json.JSONDecodeError:
                        report["errors"].append(text)
                if any(marker in text for marker in ("SCRIPT ERROR:", "Parse Error:", "SHADER ERROR:", "Shader compilation failed", "PAGE ERROR:")):
                    report["errors"].append(text)

            page.on("console", console)
            page.on("pageerror", lambda error: report["errors"].append(str(error)))
            page.on("requestfailed", lambda request: report["failed_requests"].append({"url": request.url, "failure": request.failure}))
            identity = await fetch_identity(context.request, args.url, args.expected_commit, args.expected_build_id)
            if identity["pack_sha256"] != args.expected_pck_sha256 or identity["pack_bytes"] != args.expected_pack_bytes:
                raise AssertionError("Actual full PCK differs from the explicitly supplied frozen F2 bundle")
            report["identity_before"] = identity
            response = await page.goto(args.url, wait_until="networkidle", timeout=60000)
            if response is None or not response.ok:
                raise AssertionError("Actual game HTML did not load successfully")
            match = re.search(r"const GODOT_CONFIG = (\{[^\n]+\});", await response.text())
            if not match or json.loads(match.group(1)).get("mainPack") != identity["pack"]:
                raise AssertionError("Actual game HTML loads a different PCK than verified metadata")
            await page.wait_for_function("window.PLAYTEST_LOADING_DONE===true", timeout=60000)
            await page.wait_for_timeout(500)
            badge = page.locator("#playtest-version")
            if await badge.get_attribute("data-build-id") != args.expected_build_id:
                raise AssertionError("Actual loaded canvas badge differs from expected build")
            report["badge_build_before"] = await badge.get_attribute("data-build-id")

            async def capture(name):
                path = folder / f"mouse-thorn_forest-map1-{name}.png"
                await page.screenshot(path=str(path))
                return path

            # Exact finite mouse navigation from verify_forest_browser.verify;
            # the only additions record the actual executed input/OCR provenance.
            async def click_text(phrase, name, scroll=False):
                failure = None
                for attempt in range(9 if scroll else 1):
                    path = await capture(f"{name}-{attempt}")
                    try:
                        point = locate(path, phrase)
                    except ValueError as error:
                        failure = error
                        if not scroll:
                            raise
                        trace("mouse_move", x=900, y=580, reason="existing finite navigation scroll")
                        await page.mouse.move(900, 580)
                        trace("mouse_wheel", dx=0, dy=230, reason="existing finite navigation scroll")
                        await page.mouse.wheel(0, 230)
                        await page.wait_for_timeout(150)
                        continue
                    trace("mouse_click", x=point[0], y=point[1], phrase=phrase,
                          source_screenshot=str(path.relative_to(ROOT)), point_source="existing locate(actual PNG OCR)")
                    await page.mouse.click(*point)
                    await page.wait_for_timeout(300)
                    return
                raise failure

            await click_text("DEVELOPMENT DEMOS", "title", scroll=True)
            await click_text("SELECT REGION", "home", scroll=True)
            await click_text("THORN_FOREST MAP 1", "region")
            await page.wait_for_timeout(900)
            closed = await capture("selector-closed")
            debug = [e for e in report["events"] if e.get("event") == "debug_entry" and e.get("region") == "thorn_forest" and e.get("map_index") == 1 and e.get("natural_progression") is False]
            if len(debug) != 1:
                raise AssertionError("Actual rendered ForestMap1 debug button must accept exactly once")
            assembled = [e for e in report["events"] if e.get("event") == "region_assembled" and e.get("region") == "thorn_forest" and e.get("map_index") == 1 and e.get("debug_entry") is True]
            if len(assembled) != 1:
                raise AssertionError("Exactly one actually assembled ForestMap1 consumer required")
            actual = assembled[0]
            validate_assembled_layout(actual, "forest-fruit-routes-v14")
            if actual.get("content_version") != "thorn-forest-region-v2" or not re.fullmatch(r"[0-9a-f]{64}", str(actual.get("manifest_hash", ""))) or actual.get("boss_definition") != "res://resources/bosses/rootbell_guardian_v2.tres" or actual.get("boss_scene") != "res://scenes/bosses/rootbell_guardian_v2.tscn" or actual.get("abilities") != ["grapple"]:
                raise AssertionError("Actual forest manifest/Boss/H-only build differs from current default")
            try:
                locate(closed, "THORN FOREST")
            except ValueError:
                validate_region_heading(closed, "thorn_forest", 1)
            else:
                validate_region_heading(closed, "thorn_forest", 1)
            report["checks"].append("Actual OCR navigation accepted one ForestMap1 v2/v14/H-only entry with complete heading")

            # Finite selector click derived from actual source offsets at1280x720:
            # x=1280+(-220-20)/2=1160; y=(126+162)/2=144.
            # No JS access to the Godot node, text, selection, popup or gameplay.
            trace("mouse_click", x=1160, y=144, target="actual AvatarSelector canvas control",
                  point_source="AvatarPresentation offsets and independently viewed original H screenshot")
            await page.mouse.click(1160, 144)
            await page.wait_for_timeout(500)
            popup = await capture("selector-popup")
            trace("keyboard_press", key="Escape", target="actual open popup through normal keyboard input")
            await page.keyboard.press("Escape")
            await page.wait_for_timeout(350)
            escaped = await capture("selector-escape-closed")
            report["three_original_screenshots"] = [str(p.relative_to(ROOT)) for p in (closed, popup, escaped)]
            report["checks"].append("Actual mouse selector click and Escape sent; three full1280x720 original screenshots captured; popup state/text require pixel review")
            final_identity = await fetch_identity(context.request, args.url, args.expected_commit, args.expected_build_id)
            if final_identity != identity:
                raise AssertionError("Actual PCK/source identity changed during supplemental selector case")
            report["identity_after"] = final_identity
            report["badge_build_after"] = await badge.get_attribute("data-build-id")
            if report["badge_build_after"] != args.expected_build_id:
                raise AssertionError("Actual loaded canvas build badge changed after Escape")
            if report["errors"]:
                raise AssertionError("Actual browser engine errors: " + str(report["errors"]))
            report["functional_identity_guards"] = "passed"
            report["status"] = "pixels_pending_independent_review"
        finally:
            if context is not None:
                await context.close()
            await browser.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("url")
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--expected-commit", required=True)
    parser.add_argument("--expected-build-id", required=True)
    parser.add_argument("--expected-pck-sha256", required=True)
    parser.add_argument("--expected-pack-bytes", required=True, type=int)
    parser.add_argument("--proxy-from-environment", action="store_true")
    args = parser.parse_args()
    if not re.fullmatch(r"[0-9a-f]{40}", args.expected_commit) or not re.fullmatch(r"[0-9a-f]{12}", args.expected_build_id) or not re.fullmatch(r"[0-9a-f]{64}", args.expected_pck_sha256):
        parser.error("Explicit complete frozen commit/build/PCK identities are required")
    if args.expected_pck_sha256[:12] != args.expected_build_id or args.expected_pack_bytes <= 0:
        parser.error("Expected PCK identity is inconsistent")
    if urlparse(args.url).scheme not in ("http", "https"):
        parser.error("URL must use HTTP or HTTPS")
    args.output_dir = args.output_dir.resolve()
    if not args.output_dir.is_relative_to(ROOT / "build") or args.output_dir.exists():
        parser.error("Preserve earlier evidence; use a fresh ignored folder under build")
    args.output_dir.mkdir(parents=True)
    report = {"scope": "One actual mouse ForestMap1 selector/popup/Escape Web pixel fixture; supplemental120-second case, original20/8 GUI480 unchanged", "url": args.url,
              "expected_commit": args.expected_commit, "expected_build_id": args.expected_build_id,
              "expected_pck_sha256": args.expected_pck_sha256, "expected_pack_bytes": args.expected_pack_bytes,
              "status": "running", "budget_seconds": 120, "functional_identity_guards": "unverified", "pixels": "pending_independent_review",
              "console": [], "events": [], "errors": [], "failed_requests": [], "input_trace": [], "checks": [],
              "physical_device": "unverified", "natural_campaign": "unverified", "font_cmap_as_web_proof": False,
              "selector_coordinate_scope": {"viewport": [1280,720], "center": [1160,144], "source": "scripts/art/avatar_presentation.gd offsets(-220,-20,126,162)", "reference": "actual independently reviewed H mouse-thorn_forest-map1 entry selector"}}
    started = time.monotonic()
    try:
        report["execution_utc"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
        report["source_head_before"] = head
        if head != args.expected_commit:
            raise AssertionError("Local frozen source HEAD must equal explicitly expected F2 before this local fixture")
        report["source_before"] = inventory()
        paths = ["tools/verify_forest_browser.py", "scripts/art/avatar_presentation.gd", "scripts/ui/menu_theme.gd", "resources/art/avatars.json", "assets/fonts/foundry_notes.otf"]
        report["source_bindings"] = {name:digest(ROOT/name) for name in paths}
        for name in paths:
            content = subprocess.check_output(["git", "show", args.expected_commit+":"+name], cwd=ROOT)
            if hashlib.sha256(content).hexdigest() != report["source_bindings"][name]:
                raise AssertionError("Fixture dependency differs from expected frozen commit: " + name)
        catalog = json.loads((ROOT / "resources/art/avatars.json").read_text())
        report["expected_pixel_text_reference_only"] = ["外观 · "+row["display_name"] for row in catalog["avatars"]]
        remaining = 120-(time.monotonic()-started)
        if remaining <= 0:
            raise TimeoutError("Supplemental120-second case exhausted during preflight")
        asyncio.run(asyncio.wait_for(capture_case(args, report), timeout=remaining))
        report["case_seconds_before_source_guard_finalization"] = time.monotonic()-started
    except BaseException as error:
        report["status"] = "failed"
        report["failure"] = type(error).__name__+": "+str(error)
    finally:
        report["source_after"] = inventory()
        report["source_head_after"] = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
        report["source_stable"] = report.get("source_before")==report["source_after"] and report.get("source_head_before")==report["source_head_after"]==args.expected_commit
        if not report["source_stable"]:
            report["status"] = "failed"
            report.setdefault("failure", "Frozen source changed")
        report["seconds"] = time.monotonic()-started
        report["driver_sha256"] = digest(Path(__file__))
        report["original_screenshot_artifacts"] = [{"path":str(p.relative_to(ROOT)), "sha256":digest(p), "bytes":p.stat().st_size} for p in sorted(args.output_dir.glob("*.png")) if "actual-heading" not in p.name and "actual-menu-roi" not in p.name]
        (args.output_dir / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2)+"\n")
        print(json.dumps({k:report[k] for k in ("status", "source_stable", "seconds")}))
    if report["status"] != "pixels_pending_independent_review":
        raise SystemExit(1)


if __name__ == "__main__":
    main()
