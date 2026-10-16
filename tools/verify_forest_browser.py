"""Real mouse/touch canvas clicks into all four Plains/Forest debug maps.

Screenshot OCR locates rendered controls. No engine mutation or JS gameplay hooks.
Native traversal and campaign reward gates are separate evidence.
"""
from __future__ import annotations
import argparse
import asyncio
import csv
import io
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
from urllib.parse import urljoin, urlparse
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


def validate_identity(info, worker_text, pack, expected_commit, expected_build_id):
    if not isinstance(info, dict) or info.get("source_commit") != expected_commit:
        raise AssertionError("Actual build-info source_commit differs from expected frozen commit")
    if info.get("build_id") != expected_build_id:
        raise AssertionError("Actual build-info build_id differs from expected build")
    name = info.get("pack")
    if name != f"index.{expected_build_id}.pck":
        raise AssertionError("Actual build-info pack filename differs from expected build")
    match = re.search(r"const RESOURCE_MAP = (\{[^\n]+\});", worker_text)
    if not match:
        raise AssertionError("Actual cache worker resource map missing")
    resources = json.loads(match.group(1))
    resource = resources.get(name, {})
    digest = hashlib.sha256(pack).hexdigest()
    if resource.get("sha256") != digest or digest[:12] != expected_build_id:
        raise AssertionError("Actual full PCK SHA256 differs from worker/expected build")
    if info.get("pack_bytes") != len(pack) or resource.get("bytes") != len(pack):
        raise AssertionError("Actual full PCK byte count differs from metadata/worker")
    return {"source_commit":expected_commit,"build_id":expected_build_id,"pack":name,"pack_sha256":digest,"pack_bytes":len(pack)}


async def fetch_identity(request, url, expected_commit, expected_build_id):
    async def fetch(path):
        response = await request.get(urljoin(url,path),headers={"Cache-Control":"no-cache"},timeout=60000)
        if not response.ok:
            raise AssertionError(f"Actual identity fetch failed: {path}: HTTP {response.status}")
        return response
    info = await (await fetch("build-info.json")).json()
    worker = await (await fetch("index.cache-sw.js")).text()
    # Only the expected basename is fetched, never an arbitrary metadata URL.
    pack = await (await fetch(f"index.{expected_build_id}.pck")).body()
    return validate_identity(info,worker,pack,expected_commit,expected_build_id)


async def touch_scroll(page, report, prefix):
    session = await page.context.new_cdp_session(page)
    try:
        await session.send("Input.dispatchTouchEvent",{"type":"touchStart","touchPoints":[{"x":900,"y":570,"id":0,"radiusX":8,"radiusY":8,"force":1}]})
        for step in range(1,9):
            await session.send("Input.dispatchTouchEvent",{"type":"touchMove","touchPoints":[{"x":900,"y":570-step*29,"id":0,"radiusX":8,"radiusY":8,"force":1}]})
            await page.wait_for_timeout(25)
        await session.send("Input.dispatchTouchEvent",{"type":"touchEnd","touchPoints":[]})
        report["gestures"].append({"case":prefix,"kind":"CDP_real_DOM_touch_scroll","from":[900,570],"to":[900,338]})
    finally:
        await session.detach()


async def verify(url: str, folder: Path, expected_commit: str, expected_build_id: str):
    folder.mkdir(parents=True, exist_ok=False)
    report = {"scope":"all_four_region_map_entries_with_actual_mouse_and_emulated_DOM_touch; GUI_only", "url":url, "checks":[], "events":[], "errors":[], "gestures":[], "identities":[], "expected_commit":expected_commit, "expected_build_id":expected_build_id, "physical_devices":"unverified", "natural_reward_and_next_region_gui":"unverified; native actual progression evidence is separate", "whole_browser_route":"unverified"}
    async with async_playwright() as p:
        browser = await p.chromium.launch(executable_path=shutil.which("chromium") or shutil.which("chromium-browser"),headless=True,args=["--no-sandbox","--use-angle=swiftshader","--enable-unsafe-swiftshader"])
        try:
            for touch in (False,True):
                device = "touch" if touch else "mouse"
                for region, map_index in (("plains",1),("plains",2),("thorn_forest",1),("thorn_forest",2)):
                    prefix = f"{device}-{region}-map{map_index}"
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
                    identity = await fetch_identity(context.request,url,expected_commit,expected_build_id)
                    if report["identities"] and identity != report["identities"][0]["identity"]:
                        raise AssertionError("Actual PCK/source identity changed between GUI cases")
                    report["identities"].append({"case":prefix,"identity":identity})
                    response = await page.goto(url,wait_until="networkidle",timeout=60000)
                    if response is None or not response.ok:
                        raise AssertionError("Actual game HTML did not load successfully")
                    match = re.search(r"const GODOT_CONFIG = (\{[^\n]+\});",await response.text())
                    if not match or json.loads(match.group(1)).get("mainPack") != identity["pack"]:
                        raise AssertionError("Actual game HTML loads a different PCK than verified metadata")
                    await page.wait_for_function("window.PLAYTEST_LOADING_DONE===true",timeout=60000)
                    await page.wait_for_timeout(500)
                    badge = page.locator("#playtest-version")
                    badge_build = await badge.get_attribute("data-build-id")
                    if badge_build != expected_build_id:
                        raise AssertionError("Actual loaded canvas build badge differs from expected build")
                    report["build_id"] = badge_build
                    report["pack_sha256"] = identity["pack_sha256"]
                    report["source_commit"] = identity["source_commit"]
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
                                if touch:
                                    await touch_scroll(page,report,prefix)
                                else:
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
                    await click_text(f"{region.upper()} MAP {map_index}","region")
                    await page.wait_for_timeout(900)
                    entry = await capture("entry")
                    expected = [e for e in report["events"] if e.get("device")==device and e.get("event")=="debug_entry" and e.get("region")==region and e.get("map_index")==map_index and e.get("natural_progression") is False]
                    if len(expected) != 1: raise AssertionError(f"{prefix}: real debug button did not accept exactly once: {expected}")
                    locate(entry,"THORN FOREST" if region=="thorn_forest" else "WINDCHIME PLAINS")
                    report["checks"].append(prefix+": actual rendered debug menu enters selected map once; native capability proof is separate")
                    await click_text("MENU","pause-button")
                    await page.wait_for_timeout(250)
                    await click_text("RESUME","pause")
                    await capture("resumed")
                    report["checks"].append(prefix+": actual "+device+" pause and resume buttons remain usable")
                    final_identity = await fetch_identity(context.request,url,expected_commit,expected_build_id)
                    if final_identity != identity:
                        raise AssertionError("Actual PCK/source identity changed during GUI case")
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
    parser.add_argument("--expected-commit",required=True)
    parser.add_argument("--expected-build-id",required=True)
    args = parser.parse_args()
    if not re.fullmatch(r"[0-9a-f]{40}",args.expected_commit):
        parser.error("expected commit must be a complete lowercase Git SHA")
    if not re.fullmatch(r"[0-9a-f]{12}",args.expected_build_id):
        parser.error("expected build ID must be a complete 12-character PCK content ID")
    if urlparse(args.url).scheme not in ("http","https"):
        parser.error("URL must use HTTP or HTTPS")
    asyncio.run(asyncio.wait_for(verify(args.url,args.output_dir,args.expected_commit,args.expected_build_id),timeout=480))


if __name__ == "__main__": main()
