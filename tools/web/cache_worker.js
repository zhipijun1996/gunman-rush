/* Generated immutable-resource cache. Never intercept saves, HTML or build-info. */
const RESOURCE_MAP = __RESOURCE_MAP__;
const CACHE_NAME = 'gunman-rush-runtime-v1';
self.addEventListener('install', event => event.waitUntil(self.skipWaiting()));
self.addEventListener('activate', event => event.waitUntil(self.clients.claim()));
async function immutableResponse(request, name) {
    let cache;
    try {
        cache = await caches.open(CACHE_NAME);
        const found = await cache.match(request);
        if (found) return found;
    } catch (_) { /* Private mode/storage denial must not prevent playing. */ }
    const info = RESOURCE_MAP[name];
    let response;
    if (info && info.gzip && typeof DecompressionStream !== 'undefined') {
        try {
            const compressed = await fetch(new URL(info.gzip, self.registration.scope));
            if (!compressed.ok) throw new Error('Compressed runtime unavailable');
            // Some hosts already send Content-Encoding:gzip; fetch then exposes
            // decoded bytes, so avoid decompressing twice. Pages need no such header.
            const decoded = /gzip/i.test(compressed.headers.get('Content-Encoding') || '')
                ? await compressed.arrayBuffer()
                : await new Response(compressed.body.pipeThrough(new DecompressionStream('gzip'))).arrayBuffer();
            if (decoded.byteLength !== info.bytes) throw new Error('Runtime size mismatch');
            const hash = Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', decoded)), b => b.toString(16).padStart(2, '0')).join('');
            if (hash !== info.sha256) throw new Error('Runtime checksum mismatch');
            response = new Response(decoded, {headers: {'Content-Type': 'application/wasm', 'Content-Length': String(info.bytes)}});
        } catch (_) { /* Corrupt gzip/older browser: use the unmodified official WASM. */ }
    }
    if (!response) response = await fetch(request);
    if (response.ok && response.type !== 'opaque' && cache) {
        try { await cache.put(request, response.clone()); } catch (_) { /* Quota exceeded: play without persistent cache. */ }
    }
    return response;
}
self.addEventListener('fetch', event => {
    if (event.request.method !== 'GET') return;
    const url = new URL(event.request.url);
    if (url.origin !== self.location.origin || !url.href.startsWith(self.registration.scope)) return;
    const name = url.pathname.slice(new URL(self.registration.scope).pathname.length);
    // Older open clients retain their immutable resources across a new deployment.
    // Missing uncached old files fail normally; never substitute a newer pack.
    if (RESOURCE_MAP[name] || /^index\.[a-f0-9]{12}(?:\.engine)?\.(?:pck|wasm|js|audio\.worklet\.js|audio\.position\.worklet\.js)$/.test(name)) {
        event.respondWith(immutableResponse(event.request, name));
    }
});
