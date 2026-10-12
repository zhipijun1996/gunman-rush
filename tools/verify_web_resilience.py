"""Real browser cold/warm, partial resume, integrity, version update and compatibility checks.
Local HTTP fault injection only; no mainland latency/availability claim. Requires Playwright.
"""
import argparse
import asyncio
import functools
import gzip
from http.server import ThreadingHTTPServer
import json
from pathlib import Path
import re
import shutil
import tempfile
import time
import threading
from playwright.async_api import async_playwright
from verify_web_loading import MeasuredHandler, measure

class FaultHandler(MeasuredHandler):
    def end_headers(self):
        # Attribute resume to CacheStorage, not a separate fresh HTTP-cache copy.
        if self.path.startswith('/chunks/'):
            self.send_header('Cache-Control', 'no-store')
        super().end_headers()
    def do_GET(self):
        self.server.requests.append(self.path)
        if self.path == self.server.fault_path and self.server.failures > 0:
            self.server.failures -= 1
            if self.server.corrupt:
                # Equal length forces the SHA path, not merely a size rejection.
                body = gzip.compress(b'X' * self.server.corrupt_size)
                self.send_response(200)
                self.send_header('Content-Length', str(len(body)))
                self.end_headers()
                self.wfile.write(body)
            else:
                self.send_error(503, 'Injected weak-network interruption')
            return
        if self.server.delayed and self.path.startswith('/chunks/'):
            time.sleep(0.15)
        super().do_GET()

async def ready(page):
    await page.wait_for_function("document.querySelector('#status') === null", timeout=90000)
    assert await page.locator('#playtest-download').count() == 0

async def scenarios(browser, before, after, integrity_only=False):
    with tempfile.TemporaryDirectory(prefix='web-resilience-') as temporary:
        root = Path(temporary)
        shutil.copytree(after, root, dirs_exist_ok=True)
        worker = (root / 'index.cache-sw.js').read_text()
        resource_map = json.loads(re.search(r'const RESOURCE_MAP = (.*);', worker).group(1))
        pack = next(name for name in resource_map if name.endswith('.pck'))
        # Last pack chunk: completed earlier pieces must survive a failed start.
        fault_path = '/' + resource_map[pack]['chunks'][-1]['url']
        server = ThreadingHTTPServer(('127.0.0.1', 0), functools.partial(FaultHandler, directory=str(root)))
        server.transfers = []; server.requests = []; server.fault_path = fault_path
        server.failures = 0; server.corrupt = False; server.delayed = False
        threading.Thread(target=server.serve_forever, daemon=True).start()
        url = f'http://127.0.0.1:{server.server_port}/index.html'
        result = {}
        try:
            for corrupt, early in (((True, False),) if integrity_only else ((False, False), (True, False), (False, True))):
                server.delayed = early
                fault_path = "/" + resource_map[pack]["chunks"][0 if early else -1]["url"]
                server.fault_path = fault_path
                server.corrupt_size = resource_map[pack]['chunks'][0 if early else -1]['bytes']
                context = await browser.new_context()
                page = await context.new_page()
                server.failures = 12; server.corrupt = corrupt; server.requests.clear()
                await page.goto(url, wait_until='domcontentloaded')
                await page.wait_for_function("document.querySelector('#status-notice')?.textContent.length > 0", timeout=90000)
                assert server.failures == 0, 'Fault path did not exhaust the official four attempts × three chunk retries'
                await page.evaluate("localStorage.setItem('resilience-save', 'preserve')")
                initial = [name for name in server.requests if name.startswith('/chunks/') and name != fault_path]
                assert len(initial) == len(set(initial)), 'Failed first piece left orphaned duplicate downloads'
                await page.wait_for_timeout(500)
                saved_chunks = await page.evaluate("""async () => {
                    const cache = await caches.open('gunman-rush-chunks-v1');
                    return (await cache.keys()).map(key => new URL(key.url).pathname);
                }""")
                server.requests.clear()
                await page.get_by_text('连接中断？继续加载', exact=True).click()
                await ready(page)
                chunks = [name for name in server.requests if name.startswith('/chunks/')]
                assert not set(chunks).intersection(saved_chunks), f'Resume redownloaded completed chunks: {chunks}'
                assert len(chunks) == len(set(chunks)), 'Resume duplicated missing chunks'
                assert fault_path in chunks
                if not early:
                    assert chunks == [fault_path], f'Last-piece fault redownloaded unrelated pieces: {chunks}'
                assert not any(name.endswith(('.wasm', '.pck')) for name in server.requests), 'Failure reverted to full raw download'
                assert await page.evaluate("localStorage.getItem('resilience-save')") == 'preserve'
                # A poisoned full-pack cache must be rejected and rebuilt from verified pieces.
                await page.evaluate("""async ({pack, bytes}) => {
                    const cache = await caches.open('gunman-rush-runtime-v1');
                    await cache.put(new URL(pack, location.href), new Response(new Uint8Array(bytes), {headers: {'Content-Length': String(bytes)}}));
                }""", {'pack': pack, 'bytes': resource_map[pack]['bytes']})
                server.requests.clear()
                await page.reload(wait_until='domcontentloaded')
                await ready(page)
                assert not any(name.startswith('/chunks/') for name in server.requests), 'Poisoned full cache did not rebuild from saved chunks'
                # A corrupt saved piece is independently rejected, not reused.
                await page.evaluate("""async ({pack, chunk, bytes}) => {
                    const full = await caches.open('gunman-rush-runtime-v1');
                    await full.delete(new URL(pack, location.href));
                    const parts = await caches.open('gunman-rush-chunks-v1');
                    await parts.put(new URL(chunk, location.href), new Response(new Uint8Array(bytes), {headers: {'Content-Length': String(bytes)}}));
                }""", {'pack': pack, 'chunk': fault_path, 'bytes': server.corrupt_size})
                server.requests.clear()
                await page.reload(wait_until='domcontentloaded'); await ready(page)
                assert [name for name in server.requests if name.startswith('/chunks/')] == [fault_path], {'cached_chunk_recovery': server.requests, 'expected': fault_path, 'early': early, 'corrupt': corrupt}
                result['first_chunk_interruption' if early else ('corrupt_chunk' if corrupt else 'interrupted_download')] = {'resumed_requests': chunks, 'poisoned_full_cache_recovered': True, 'save_preserved': True}
                print("PASS recovery", {"early": early, "corrupt": corrupt}, flush=True)
                await context.close()
            if integrity_only:
                return result
            server.fault_path = ''; server.delayed = False
            context = await browser.new_context()
            pages = [await context.new_page(), await context.new_page()]
            server.requests.clear()
            await asyncio.gather(*(page.goto(url, wait_until='domcontentloaded') for page in pages))
            await asyncio.gather(*(ready(page) for page in pages))
            chunks = [name for name in server.requests if name.startswith('/chunks/')]
            assert len(chunks) == len(set(chunks)), 'Two cold tabs duplicated resource downloads'
            result['two_cold_tabs'] = {'chunk_requests': len(chunks), 'duplicate_requests': 0}
            await context.close()
            # Loader-only update: same PCK, different worker implementation ID.
            metadata = json.loads((root / 'build-info.json').read_text())
            loader = metadata['loader_id']
            for filename in ('index.html', 'index.cache-sw.js'):
                target = root / filename
                target.write_text(target.read_text().replace(loader, '000000000000'))
            context = await browser.new_context()
            page = await context.new_page()
            await page.goto(url, wait_until='domcontentloaded'); await ready(page)
            for filename in ('index.html', 'index.cache-sw.js'):
                shutil.copyfile(after / filename, root / filename)
            await page.reload(wait_until='domcontentloaded'); await ready(page)
            active = await page.evaluate("""() => new Promise(resolve => {
                const channel = new MessageChannel();
                channel.port1.onmessage = event => resolve(event.data);
                navigator.serviceWorker.controller.postMessage({type: 'playtest-cache-version'}, [channel.port2]);
            })""")
            assert active['id'] == loader, 'Same-pack update used the old worker implementation'
            result['same_pack_worker_upgrade'] = {'loader_id': active['id'], 'pack_unchanged': True}
            await context.close()
            # Keep same origin and browser storage while deploying a new worker/PCK.
            server.fault_path = ''; shutil.rmtree(root); shutil.copytree(before, root)
            context = await browser.new_context()
            page = await context.new_page()
            await page.goto(url, wait_until='domcontentloaded'); await ready(page)
            old_build = await page.locator('#playtest-version').get_attribute('data-build-id')
            shutil.rmtree(root); shutil.copytree(after, root)
            server.requests.clear()
            await page.reload(wait_until='domcontentloaded'); await ready(page)
            new_build = await page.locator('#playtest-version').get_attribute('data-build-id')
            assert old_build != new_build
            assert any(name.startswith('/chunks/') for name in server.requests), 'New build used stale worker/full raw download'
            assert not any(name.endswith(('.wasm', '.pck')) for name in server.requests)
            result['old_worker_upgrade'] = {'before': old_build, 'after': new_build, 'raw_downloads': 0}
            await context.close()
        finally:
            server.shutdown(); server.server_close()
        return result

async def main(args):
    async with async_playwright() as playwright:
        browser = await playwright.chromium.launch(executable_path=shutil.which('chromium'), headless=True,
            args=['--no-sandbox', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'])
        try:
            if args.integrity_only:
                checks = await scenarios(browser, args.before, args.after, integrity_only=True)
                args.report.parent.mkdir(parents=True, exist_ok=True)
                args.report.write_text(json.dumps({'equal_length_sha_rejection': checks, 'failed': 0}, indent=2) + '\n')
                print(json.dumps({'equal_length_sha_rejection': checks, 'failed': 0}))
                return
            before = await measure(browser, args.before)
            after = await measure(browser, args.after)
            blocked = await measure(browser, args.after, block_workers=True)
            checks = await scenarios(browser, args.before, args.after)
        finally:
            await browser.close()
    assert after[0]['server_body_bytes'] < before[0]['server_body_bytes']
    assert after[1]['service_worker_controlled']
    assert not any(row['url'].endswith(('.wasm', '.pck', '.gz')) for row in after[1]['server_requests'])
    assert any(row['url'].endswith('.wasm') for row in blocked[0]['server_requests'])
    report = {'before': before, 'after': after, 'workers_blocked': blocked, 'recovery': checks, 'failed': 0,
              'limitations': 'Local Chromium fault injection; no mainland connectivity or mobile device measurement. Before/after gameplay unchanged; only unused assets excluded. Save marker verifies storage preservation, not earned currency.'}
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'before_bytes': before[0]['server_body_bytes'], 'after_bytes': after[0]['server_body_bytes'], 'warm_bytes': after[1]['server_body_bytes'], 'recovery': checks, 'failed': 0}))

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--before', type=Path, required=True)
    parser.add_argument('--after', type=Path, required=True)
    parser.add_argument('--report', type=Path, default=Path('build/verification/web-loading-d083/report.json'))
    parser.add_argument('--integrity-only', action='store_true', help='Focused equal-length corrupt gzip/full-cache/chunk-cache SHA rejection')
    asyncio.run(asyncio.wait_for(main(parser.parse_args()), timeout=360))
