"""Real mouse/touch canvas clicks into both forest debug maps.

Screenshot OCR locates rendered controls. No engine mutation or JS gameplay hooks.
Native traversal and campaign reward gates are separate evidence.
"""
from __future__ import annotations
import argparse
import asyncio
import csv
import io
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
from playwright.async_api import async_playwright


def norm(text):
    return re.sub(r"[^A-Z0-9]", "", text.upper())


def locate(path: Path, phrase: str):
    output = subprocess.run(["tesseract", str(path), "stdout", "--psm", "11", "tsv"], capture_output=True, text=True, check=True, timeout=10, env={**os.environ,"OMP_THREAD_LIMIT":"1"})
    words = [r for r in csv.DictReader(io.StringIO(output.stdout), delimiter="\t") if norm(r.get("text", ""))]
    target = norm(phrase)
    for start in range(len(words)):
        combined = ""
        for end in range(start, min(start+12,len(words))):
            combined += norm(words[end]["text"])
            if combined == target:
                found = words[start:end+1]
                left = min(int(w["left"]) for w in found)
                top = min(int(w["top"]) for w in found)
                right = max(int(w["left"])+int(w["width"]) for w in found)
                bottom = max(int(w["top"])+int(w["height"]) for w in found)
                return (left+right)/2, (top+bottom)/2
            if not target.startswith(combined): break
    raise ValueError("Rendered UI text missing: " + phrase + "; OCR=" + " ".join(w["text"] for w in words))


async def verify(url: str, folder: Path):
    folder.mkdir(parents=True, exist_ok=False)
    report = {"scope":"actual_debug_menu_mouse_and_emulated_touch_only", "url":url, "checks":[], "events":[], "errors":[], "physical_devices":"unverified", "natural_reward_and_next_region_gui":"unverified; native actual progression evidence is separate", "whole_browser_route":"unverified"}
    async with async_playwright() as p:
        browser = await p.chromium.launch(executable_path=shutil.which("chromium") or shutil.which("chromium-browser"),headless=True,args=["--no-sandbox","--use-angle=swiftshader","--enable-unsafe-swiftshader"])
        try:
            for touch in (False,True):
                device = "touch" if touch else "mouse"
                for map_index in (1,2):
                    prefix = f"{device}-map{map_index}"
                    context = await browser.new_context(viewport={"width":1280,"height":720},has_touch=touch,is_mobile=touch)
                    page = await context.new_page()
                    def console(message):
                        text = message.text
                        if "FOREST_UI_EVENT " in text:
                            try: report["events"].append({"device":device, **json.loads(text.split("FOREST_UI_EVENT ",1)[1])})
                            except json.JSONDecodeError: report["errors"].append(text)
                        if any(marker in text for marker in ("SCRIPT ERROR:","Parse Error:","SHADER ERROR:","Shader compilation failed","PAGE ERROR:")): report["errors"].append(text)
                    page.on("console",console)
                    page.on("pageerror",lambda error: report["errors"].append(str(error)))
                    await page.goto(url,wait_until="networkidle",timeout=60000)
                    await page.wait_for_function("window.PLAYTEST_LOADING_DONE===true",timeout=60000)
                    await page.wait_for_timeout(500)
                    badge = page.locator("#playtest-version")
                    report["build_id"] = await badge.get_attribute("data-build-id")
                    async def capture(name):
                        path = folder / f"{prefix}-{name}.png"
                        await page.screenshot(path=str(path))
                        return path
                    async def click_text(phrase,name,scroll=False):
                        failure = None
                        for attempt in range(9 if scroll else 1):
                            path = await capture(f"{name}-{attempt}")
                            try: point = locate(path,phrase)
                            except ValueError as error:
                                failure = error
                                if not scroll: raise
                                await page.mouse.move(900,580)
                                await page.mouse.wheel(0,230)
                                await page.wait_for_timeout(150)
                                continue
                            if touch: await page.touchscreen.tap(*point)
                            else: await page.mouse.click(*point)
                            await page.wait_for_timeout(300)
                            return
                        raise failure
                    await click_text("DEVELOPMENT DEMOS","title")
                    await click_text("SELECT REGION","home",scroll=True)
                    await click_text(f"THORN_FOREST MAP {map_index}","region")
                    await page.wait_for_timeout(900)
                    entry = await capture("entry")
                    expected = [e for e in report["events"] if e.get("device")==device and e.get("event")=="debug_entry" and e.get("region")=="thorn_forest" and e.get("map_index")==map_index and e.get("natural_progression") is False]
                    if len(expected) != 1: raise AssertionError(f"{prefix}: real debug button did not accept exactly once: {expected}")
                    locate(entry,"THORN FOREST")
                    report["checks"].append(prefix+": actual rendered debug menu enters selected map once; native capability proof is separate")
                    await page.keyboard.press("Escape")
                    await page.wait_for_timeout(250)
                    await click_text("RESUME","pause")
                    await capture("resumed")
                    report["checks"].append(prefix+": actual pause and resume buttons remain usable")
                    await context.close()
            if report["errors"]: raise AssertionError("Actual browser engine errors: " + str(report["errors"]))
            report["status"] = "passed"
        except BaseException as error:
            report["status"] = "failed"
            report["failure"] = str(error)
            raise
        finally:
            (folder/"report.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n")
            await browser.close()
    print(json.dumps(report,ensure_ascii=False))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("url")
    parser.add_argument("--output-dir",type=Path,required=True)
    args = parser.parse_args()
    asyncio.run(asyncio.wait_for(verify(args.url,args.output_dir),timeout=240))


if __name__ == "__main__": main()
