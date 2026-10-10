"""Measure real cold/warm Web transfers; fail on mixed runtime, reload loops or save loss.
Run: python3 tools/verify_web_loading.py --before DIR --after DIR
Local servers use ordinary Last-Modified/304 behavior, no artificial no-store header.
Playwright Chromium required; bounded outer run 180s. Never reads game engine state.
"""
import argparse
import asyncio
import functools
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import shutil
import threading
import time
from playwright.async_api import async_playwright

class MeasuredHandler(SimpleHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def send_response(self, code, message=None):
        self.response_code = code
        super().send_response(code, message)

    def copyfile(self, source, outputfile):
        count = 0
        while True:
            block = source.read(64 * 1024)
            if not block:
                break
            outputfile.write(block)
            count += len(block)
        self.server.transfers.append({"url": self.path, "status": self.response_code, "body_bytes": count})

async def measure(browser, directory, *, block_workers=False):
    server = ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(MeasuredHandler, directory=str(directory.resolve())))
    server.transfers = []
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    url = f"http://127.0.0.1:{server.server_port}/index.html"
    context = await browser.new_context(viewport={"width": 1280, "height": 720}, service_workers="block" if block_workers else "allow")
    page = await context.new_page()
    errors = []
    page.on("pageerror", lambda error: errors.append(str(error)))
    reports = []
    try:
        for phase in ("cold", "warm"):
            server.transfers.clear()
            started = time.monotonic()
            if phase == "cold":
                await page.goto(url, wait_until="domcontentloaded", timeout=45000)
            else:
                await page.reload(wait_until="domcontentloaded", timeout=45000)
            await page.wait_for_function("document.querySelector('#status') === null", timeout=60000)
            await page.wait_for_timeout(1200)
            if phase == "cold":
                await page.evaluate("localStorage.setItem('web_loading_probe_save', 'preserve-me')")
            else:
                assert await page.evaluate("localStorage.getItem('web_loading_probe_save')") == 'preserve-me', 'Reload lost browser save storage'
            resources = await page.evaluate("performance.getEntriesByType('resource').map(r => ({name:r.name.split('/').pop(), transferSize:r.transferSize, encodedBodySize:r.encodedBodySize, decodedBodySize:r.decodedBodySize}))")
            reports.append({"phase": phase, "ready_seconds": round(time.monotonic() - started, 3),
                            "server_body_bytes": sum(row["body_bytes"] for row in server.transfers),
                            "server_requests": list(server.transfers), "browser_resources": resources,
                            "build_id": await page.locator('#playtest-version').get_attribute('data-build-id'),
                            "service_worker_controlled": await page.evaluate("Boolean(navigator.serviceWorker.controller)")})
        assert reports[0]["build_id"] == reports[1]["build_id"], 'Cold/warm crossed gameplay packages'
        assert not errors, 'Browser JS errors: ' + repr(errors)
        return reports
    finally:
        await context.close()
        server.shutdown()
        server.server_close()

async def main(args):
    async with async_playwright() as playwright:
        browser = await playwright.chromium.launch(executable_path=shutil.which("chromium") or shutil.which("chromium-browser"),
            headless=True, args=["--no-sandbox", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"], timeout=30000)
        try:
            before = await measure(browser, args.before)
            after = await measure(browser, args.after)
            recovery = {}
            if args.recovery_checks:
                recovery["blocked_service_worker"] = await measure(browser, args.after, block_workers=True)
                assert not recovery["blocked_service_worker"][0]["service_worker_controlled"]
                assert any(row["url"].endswith(".wasm") for row in recovery["blocked_service_worker"][0]["server_requests"])
                gzip_path = next(args.after.glob('index.*.engine.wasm.gz'))
                original = gzip_path.read_bytes()
                try:
                    gzip_path.write_bytes(b'corrupt-gzip-recovery-probe')
                    recovery["corrupt_compressed_runtime"] = await measure(browser, args.after)
                    assert any(row["url"].endswith(".wasm") for row in recovery["corrupt_compressed_runtime"][0]["server_requests"])
                    assert not any(row["url"].endswith(".wasm") for row in recovery["corrupt_compressed_runtime"][1]["server_requests"])
                finally:
                    gzip_path.write_bytes(original)
        finally:
            await browser.close()
    assert after[0]["server_body_bytes"] < before[0]["server_body_bytes"], 'Cold transfer did not decrease'
    assert after[1]["service_worker_controlled"], 'Warm page was not controlled by cache worker'
    assert not any(row["url"].endswith((".pck", ".wasm", ".wasm.gz")) for row in after[1]["server_requests"]), 'Warm reload redownloaded gameplay/runtime'
    report = {"before": before, "after": after, "recovery": recovery, "failed": 0,
              "limitations": "Local Chromium, same old gameplay pack: final integrated pack and deployed/iPhone behavior require separate validation. Server body bytes exclude HTTP headers; wall time is localhost CPU/storage, not mobile-network speed."}
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({"cold_before_bytes": before[0]["server_body_bytes"], "cold_after_bytes": after[0]["server_body_bytes"],
                      "warm_before_bytes": before[1]["server_body_bytes"], "warm_after_bytes": after[1]["server_body_bytes"], "failed": 0}))

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--before', type=Path, required=True)
    parser.add_argument('--after', type=Path, required=True)
    parser.add_argument('--recovery-checks', action='store_true')
    parser.add_argument('--report', type=Path, default=Path('build/verification/web-loading/report.json'))
    try:
        asyncio.run(asyncio.wait_for(main(parser.parse_args()), timeout=180))
    except Exception as error:
        print('Web loading check failed:', error)
        raise SystemExit(1)
