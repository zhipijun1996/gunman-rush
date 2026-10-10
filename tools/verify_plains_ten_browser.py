"""Bounded real GUI smoke of the generated ten-room plains Web consumer.

Uses rendered pixels/OCR and ordinary touch/keyboard events. A separately
labelled browser-storage fixture supplies 9 notes for the persistence/upgrade
probe; it is not evidence of collecting notes or completing ten rooms. No
engine-state reads, engine injection, teleport, or lowered historical probes.
Run from repo root, optional deployed URL; local build/web is served on 8774.
Requires Playwright, Chromium, Pillow and Tesseract. Entire run <=240 seconds.
"""
import asyncio
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

from PIL import ImageChops
from playwright.async_api import async_playwright
import verify_random_stage_browser as helpers

FOLDER = Path("build/verification/plains-ten-browser")
helpers.FOLDER = FOLDER
WEB_KEY = "gunman_rush.plains_meta.v2"


def storage_fixture():
    payload = {"notes": 9, "upgrades": {}, "receipts": {}, "settled": {},
               "completed_runs": 0, "failed_runs": 0, "completed_biomes": 0,
               "last_summary": {}}
    envelope = {"schema_version": 2, "content_version": "plains_meta_1",
                "profile_id": "local", "profile_revision": 1, "payload": payload}
    compact = json.dumps(envelope, sort_keys=True, separators=(",", ":"))
    envelope["checksum"] = hashlib.sha256(compact.encode()).hexdigest()
    return json.dumps(envelope, separators=(",", ":"))



def read_progress(name):
    text = helpers.ocr(name, (10, 158, 1080, 187)).upper()
    route = re.search(r"ROUTE\s+(\d+)\s*[/|]\s*(\d+)", text)
    world = re.search(r"WORLD\s+X\s+([+-]?\d+)", text)
    camera = re.search(r"CAMERA\s+X\s+([+-]?\d+)", text)
    flow = re.search(r"FLOW\s+(LEFT|RIGHT)", text)
    if not all((route, world, camera, flow)):
        raise RuntimeError("Cannot read generated progress from actual pixels: " + text)
    return {"route": int(route[1]), "total": int(route[2]), "world_x": int(world[1]),
            "camera_x": int(camera[1]), "flow": flow[1], "text": text.strip()}


def painted_probe(name):
    image = helpers.picture(name)
    world = image.crop((0, 170, 1070, 710))
    sky = image.crop((0, 170, 1000, 400))
    values = {"world_unique_rgb": len(world.getcolors(world.width * world.height)),
              "sky_unique_rgb": len(sky.getcolors(sky.width * sky.height))}
    # Rich painted sky/meadow texture, independently observed in actual asset
    # integration captures. These do not assert final user style approval.
    if values["world_unique_rgb"] < 40000 or values["sky_unique_rgb"] < 5000:
        raise RuntimeError("Actual render lacks the latest textured painted plains: " + str(values))
    return values


async def main(url):
    FOLDER.mkdir(parents=True, exist_ok=True)
    checks, logs = [], []
    report = {"url": url, "checks": checks, "failed": 1,
              "browser": "Chromium mobile touch emulation",
              "scope": "Room 1 actual GUI; first grounded seam only",
              "whole_ten_room_gui_traversal": "unverified; separate SceneTree evidence",
              "real_android": "unverified", "real_iphone_safari": "unverified",
              "notes_collection_gui": "unverified; storage fixture is a separate probe"}
    async with async_playwright() as playwright:
        browser = await playwright.chromium.launch(
            executable_path=shutil.which("chromium") or shutil.which("chromium-browser"),
            headless=True, args=["--no-sandbox", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"], timeout=30000)
        try:
            context = await browser.new_context(viewport={"width": 1280, "height": 720}, is_mobile=True, has_touch=True)
            # Install fixture once in this isolated browser profile. On reload
            # preserve the real game-written save, rather than reseeding it.
            await context.add_init_script("if(localStorage.getItem(%s)===null)localStorage.setItem(%s,%s);" %
                                          (json.dumps(WEB_KEY), json.dumps(WEB_KEY), json.dumps(storage_fixture())))
            page = await context.new_page()
            page.set_default_timeout(10000)
            page.on("console", lambda message: logs.append(message.text))
            page.on("pageerror", lambda error: logs.append("PAGE ERROR: " + str(error)))
            await page.goto(url, wait_until="networkidle", timeout=45000)
            await page.wait_for_timeout(800)
            report["build_id"] = await page.locator("#playtest-version").get_attribute("data-build-id")
            client = await context.new_cdp_session(page)

            async def capture(name):
                await page.screenshot(path=str(FOLDER / (name + ".png")), timeout=10000)

            async def touch(kind, points):
                await client.send("Input.dispatchTouchEvent", {"type": kind, "touchPoints": points})

            await capture("home")
            home_text = helpers.ocr("home").upper()
            if not re.search(r"NOTES\s+9\b", home_text) or "WINDCHIME" not in home_text:
                raise RuntimeError("Home does not show plains entry and correctly loaded note fixture: " + home_text)
            checks.append("Home renders the generated Windchime Plains entry and the separately seeded 9-note profile")
            await page.touchscreen.tap(*helpers.text_center("home", "SPEND NOTES"))
            await page.wait_for_timeout(300)
            await capture("purchased-upgrade")
            purchase_text = helpers.ocr("purchased-upgrade").upper()
            if not re.search(r"NOTES\s+4\b", purchase_text) or not re.search(r"PERMANENT\s+VITALITY\s+1\b", purchase_text):
                raise RuntimeError("Actual Home purchase did not spend 5 notes and grant vitality 1: " + purchase_text)
            checks.append("Real Home upgrade button spends 5 fixture notes and grants permanent vitality level 1")
            await page.reload(wait_until="networkidle", timeout=45000)
            await page.wait_for_timeout(800)
            await capture("reloaded-home")
            reload_text = helpers.ocr("reloaded-home").upper()
            if not re.search(r"NOTES\s+4\b", reload_text) or not re.search(r"PERMANENT\s+VITALITY\s+1\b", reload_text):
                raise RuntimeError("Browser reload lost the real purchased permanent upgrade: " + reload_text)
            checks.append("Actual page reload preserves game-written 4 notes and vitality level 1 via browser persistence")
            await page.touchscreen.tap(*helpers.text_center("reloaded-home", "WINDCHIME PLAINS"))
            await page.wait_for_timeout(800)
            await capture("room-one-entry")
            entry_text = helpers.ocr("room-one-entry", (0, 0, 1100, 170)).upper()
            if not re.search(r"ROOM\s+1\s+OF\s+10", entry_text) or "COMBAT" not in entry_text:
                raise RuntimeError("Plains entry does not start real combat room 1 of 10: " + entry_text)
            if not re.search(r"NOTES\s+4\b", entry_text) or not re.search(r"COINS\s+[0O]\b", entry_text):
                raise RuntimeError("Run coins and permanent notes are not shown independently: " + entry_text)
            if "JUMP" not in helpers.ocr("room-one-entry", (936, 647, 992, 668)).upper():
                raise RuntimeError("Mobile jump control is missing")
            report["painted_render"] = painted_probe("room-one-entry")
            checks.append("Real generated room 1/10 combat renders latest painted plains, mobile jump, separate 0 coins and 4 permanent notes")
            initial = read_progress("room-one-entry")
            if initial["route"] != 1 or initial["total"] < 8:
                raise RuntimeError("Generated room does not visibly contain multiple modules: " + str(initial))
            # Cancel held right aim at the safe initial board, before traversing.
            await touch("touchStart", [{"x": 1130, "y": 565, "id": 2}])
            await touch("touchMove", [{"x": 1190, "y": 565, "id": 2}])
            await page.wait_for_timeout(150)
            await page.keyboard.press("Escape")
            await page.wait_for_timeout(200)
            await touch("touchEnd", [])
            await capture("pause-held-aim")
            await page.wait_for_timeout(400)
            await capture("pause-frozen")
            if ImageChops.difference(helpers.picture("pause-held-aim"), helpers.picture("pause-frozen")).getbbox():
                raise RuntimeError("Pause did not freeze actual rendered scene")
            await page.touchscreen.tap(*helpers.text_center("pause-held-aim", "RESUME"))
            await page.wait_for_timeout(650)
            await capture("aim-cancelled")
            cancelled = read_progress("aim-cancelled")
            if abs(cancelled["world_x"] - initial["world_x"]) > 2:
                raise RuntimeError("Paused held aim produced unintended release recoil: " + str(cancelled))
            checks.append("Pause freezes actual scene; released cancelled aim causes no horizontal recoil after resume")
            sign = -1 if initial["flow"] == "LEFT" else 1
            moved = cancelled
            for _ in range(8):
                await touch("touchStart", [{"x": 160, "y": 565, "id": 1}])
                await touch("touchMove", [{"x": 160 + 60 * sign, "y": 565, "id": 1}])
                await page.wait_for_timeout(300)
                await touch("touchEnd", [])
                await page.wait_for_timeout(100)
                await capture("touch-first-seam")
                moved = read_progress("touch-first-seam")
                if moved["route"] >= 2 and sign * (moved["world_x"] - initial["world_x"]) >= 220:
                    break
            if moved["route"] < 2 or sign * (moved["world_x"] - initial["world_x"]) < 220:
                raise RuntimeError("Ordinary touch did not cross first direct module seam: " + str(moved))
            if abs(moved["camera_x"] - moved["world_x"]) > 630:
                raise RuntimeError("Camera lost real moving player")
            report["touch_progress"] = {"initial": initial, "after_touch": moved}
            checks.append("Real left-stick touch crosses first seamless module dock and bounded camera keeps actual player in view")
            if not any("Godot Engine v4.7.2" in line for line in logs):
                raise RuntimeError("Pinned Godot 4.7.2 did not start")
            if any(marker in line for line in logs for marker in ["SCRIPT ERROR:", "PAGE ERROR:", "Parse Error:", "SHADER ERROR:", "Shader compilation failed"]):
                raise RuntimeError("Browser engine error: " + str(logs))
            checks.append("Godot 4.7.2 runs without script/page/shader errors")
            report["failed"] = 0
            report["storage_fixture"] = {"initial_notes": 9, "real_button_spend": 5, "reloaded_notes": 4, "reloaded_vitality": 1,
                                         "disclaimer": "Fixture proves browser storage and real UI purchase, not gameplay earning"}
        except Exception as error:
            report["error"] = str(error)
            raise
        finally:
            report["logs"] = logs
            (FOLDER / "browser-report.json").write_text(json.dumps(report, indent=2) + "\n")
            print(json.dumps(report))
            await browser.close()


if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8774/"
    server = None
    if target.startswith("http://127.0.0.1:8774"):
        server = subprocess.Popen([sys.executable, "-m", "http.server", "8774", "--bind", "127.0.0.1", "--directory", "build/web"],
                                  stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        asyncio.run(asyncio.wait_for(main(target), timeout=240))
    finally:
        if server:
            server.terminate()
            server.wait(timeout=5)
