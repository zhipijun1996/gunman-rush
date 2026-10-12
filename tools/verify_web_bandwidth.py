"""Compare real starts with a server-enforced aggregate 1 MiB/s cap and 120 ms/request.
A reproducible weak-link simulation; does not measure China or GitHub availability.
"""
import argparse
import asyncio
import json
from pathlib import Path
import shutil
import threading
import time
from playwright.async_api import async_playwright
from verify_web_loading import MeasuredHandler, measure

class LimitedHandler(MeasuredHandler):
    lock = threading.Lock()
    next_send = 0
    def do_GET(self):
        time.sleep(0.12)
        super().do_GET()
    def copyfile(self, source, outputfile):
        count = 0
        while block := source.read(32 * 1024):
            with self.lock:
                now = time.monotonic()
                delay = max(now, LimitedHandler.next_send) - now
                LimitedHandler.next_send = max(now, LimitedHandler.next_send) + len(block) / 1048576
            time.sleep(delay)
            outputfile.write(block); count += len(block)
        self.server.transfers.append({'url': self.path, 'status': self.response_code, 'body_bytes': count})

async def main(args):
    async with async_playwright() as playwright:
        browser = await playwright.chromium.launch(executable_path=shutil.which('chromium'), headless=True,
            args=['--no-sandbox', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'])
        try:
            LimitedHandler.next_send = 0
            before = await measure(browser, args.before, handler=LimitedHandler)
            LimitedHandler.next_send = 0
            after = await measure(browser, args.after, handler=LimitedHandler)
        finally:
            await browser.close()
    assert after[0]['server_body_bytes'] < before[0]['server_body_bytes']
    assert after[0]['ready_seconds'] < before[0]['ready_seconds'], 'Simulated weak-link cold load did not improve'
    result = {'aggregate_bytes_per_second': 1048576, 'per_request_delay_seconds': 0.12,
              'before': before, 'after': after, 'failed': 0,
              'limitations': 'Artificial localhost bandwidth/latency with desktop Chromium, not China, mobile or actual Pages throughput. Times include standard 1.2s settle delay.'}
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'before_seconds': before[0]['ready_seconds'], 'after_seconds': after[0]['ready_seconds'], 'failed': 0}))

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--before', type=Path, required=True)
    parser.add_argument('--after', type=Path, required=True)
    parser.add_argument('--report', type=Path, default=Path('build/verification/web-loading-d083/bandwidth.json'))
    asyncio.run(asyncio.wait_for(main(parser.parse_args()), timeout=180))
