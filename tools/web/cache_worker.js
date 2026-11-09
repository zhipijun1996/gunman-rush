/* Immutable resource cache and same-origin Web thread isolation. Saves are never touched. */
const RESOURCE_MAP = __RESOURCE_MAP__;
const WORKER_ID = __WORKER_ID__;
const CACHE_NAME = 'gunman-rush-runtime-v1';
const CHUNK_CACHE = 'gunman-rush-chunks-v1';
const inFlight = new Map();
self.addEventListener('install', event => event.waitUntil(self.skipWaiting()));
self.addEventListener('activate', event => event.waitUntil(self.clients.claim()));
self.addEventListener('message', event => {
    if (event.data?.type === 'playtest-cache-version' && event.ports[0]) {
        event.ports[0].postMessage({id: WORKER_ID, packs: Object.keys(RESOURCE_MAP).filter(name => name.endsWith('.pck'))});
    }
});
const digest = async bytes => Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', bytes)), b => b.toString(16).padStart(2, '0')).join('');
// Bound storage to one current build (plus the historic minimum), rather than
// a fixed cap smaller than the package itself. The last production PCK exceeded
// 128 MiB; previously its completed write evicted the engine and stored nothing.
function cacheBudgets(resources) {
    let complete = 0;
    const chunks = new Map();
    for (const info of Object.values(resources)) {
        complete += Number(info.bytes) || 0;
        for (const part of info.chunks || []) {
            chunks.set(part.url, Math.max(chunks.get(part.url) || 0, Number(part.bytes) || 0));
        }
    }
    return {
        complete: Math.max(128 * 1048576, complete),
        chunks: Math.max(80 * 1048576, [...chunks.values()].reduce((sum, size) => sum + size, 0)),
    };
}
const CACHE_BUDGETS = cacheBudgets(RESOURCE_MAP);
const cacheHandles = new Map();
const cacheIndexes = new WeakMap();
let cacheWrites = Promise.resolve();

async function runtimeCache(name) {
    // Reuse the handle so the in-memory FIFO index has one owner per cache.
    if (!cacheHandles.has(name)) {
        const pending = caches.open(name).catch(error => {
            cacheHandles.delete(name);
            throw error;
        });
        cacheHandles.set(name, pending);
    }
    return cacheHandles.get(name);
}

async function cacheIndex(cache) {
    if (cacheIndexes.has(cache)) return cacheIndexes.get(cache);
    const index = {sizes: new Map(), total: 0};
    for (const item of await cache.keys()) {
        const old = await cache.match(item);
        if (!old) continue;
        const size = Number(old.headers.get('Content-Length')) || 0;
        index.sizes.set(item.url, size);
        index.total += size;
    }
    cacheIndexes.set(cache, index);
    return index;
}

async function storeBounded(cache, key, response, limit) {
    // CacheStorage only; Godot's IndexedDB/localStorage saves are never touched.
    // Refuse an oversized object before evicting otherwise useful cached files.
    const size = Number(response.headers.get('Content-Length')) || 0;
    if (size > limit) return;
    const url = typeof key === 'string' ? key : key.url;
    const task = cacheWrites.catch(() => {}).then(async () => {
        // Scan metadata once after worker startup. Re-scanning every existing
        // chunk before each write made a large download perform O(n²) cache IO.
        const index = await cacheIndex(cache);
        let total = index.total - (index.sizes.get(url) || 0) + size;
        for (const [oldUrl, oldSize] of index.sizes) {
            if (total <= limit) break;
            if (oldUrl === url) continue;
            await cache.delete(oldUrl);
            index.sizes.delete(oldUrl);
            index.total -= oldSize;
            total -= oldSize;
        }
        await cache.put(key, response);
        index.total = total;
        index.sizes.set(url, size);
    });
    cacheWrites = task;
    try { await task; } catch (_) {
        // Quota/storage denial must still allow playing. Re-read metadata if a
        // partial write or external deletion changed the underlying cache.
        cacheIndexes.delete(cache);
    }
}
async function fetchWithIdleTimeout(url) {
    const controller = new AbortController();
    let timer;
    const reset = () => { clearTimeout(timer); timer = setTimeout(() => controller.abort(), 30000); };
    reset();
    try {
        const response = await fetch(url, {signal: controller.signal});
        if (!response.ok) throw new Error('HTTP ' + response.status);
        const reader = response.body.getReader();
        const blocks = [];
        while (true) {
            const {done, value} = await reader.read();
            if (done) break;
            blocks.push(value); reset();
        }
        return new Response(new Blob(blocks), {headers: response.headers});
    } finally { clearTimeout(timer); }
}
async function chunkedResponse(info, clientId) {
    let cache;
    try { cache = await runtimeCache(CHUNK_CACHE); } catch (_) {}
    const blocks = new Array(info.chunks.length);
    let next = 0, loaded = 0, failed = false;
    const progress = async () => {
        const client = clientId && await self.clients.get(clientId);
        if (client) client.postMessage({type: 'playtest-download', loaded, total: info.bytes, mime: info.mime});
    };
    async function download() {
        while (next < info.chunks.length && !failed) {
            const index = next++, part = info.chunks[index];
            const url = new URL(part.url, self.registration.scope).href;
            let bytes, lastError;
            for (let attempt = 0; attempt < 3; attempt++) {
                try {
                    let response = cache && await cache.match(url);
                    const cached = Boolean(response);
                    if (response) {
                        bytes = await response.arrayBuffer();
                    } else {
                        response = await fetchWithIdleTimeout(url);
                        // Fetch automatically decodes hosts using Content-Encoding.
                        bytes = /gzip/i.test(response.headers.get('Content-Encoding') || '')
                            ? await response.arrayBuffer()
                            : await new Response(response.body.pipeThrough(new DecompressionStream('gzip'))).arrayBuffer();
                    }
                    if (bytes.byteLength !== part.bytes || await digest(bytes) !== part.sha256) throw new Error('Chunk checksum mismatch');
                    if (cache && !cached) await storeBounded(cache, url, new Response(bytes, {headers: {'Content-Length': String(bytes.byteLength)}}), CACHE_BUDGETS.chunks);
                    lastError = null; break;
                } catch (error) {
                    lastError = error;
                    if (cache) { try { await cache.delete(url); } catch (_) {} }
                    if (attempt < 2) await new Promise(resolve => setTimeout(resolve, 500 * (attempt + 1)));
                }
            }
            if (lastError) { failed = true; throw lastError; }
            blocks[index] = bytes; loaded += bytes.byteLength; await progress();
        }
    }
    // Finish existing requests before releasing inFlight. Otherwise Godot's
    // next resource retry can overlap with two orphaned download loops.
    const results = await Promise.allSettled([download(), download(), download()]);
    const error = results.find(result => result.status === 'rejected');
    if (error) throw error.reason;
    const bytes = await new Blob(blocks).arrayBuffer();
    if (bytes.byteLength !== info.bytes || await digest(bytes) !== info.sha256) throw new Error('Package checksum mismatch');
    return new Response(bytes, {headers: {'Content-Type': info.mime, 'Content-Length': String(info.bytes)}});
}
async function immutableResponse(request, name, clientId) {
    const info = RESOURCE_MAP[name];
    let cache;
    try {
        cache = await runtimeCache(CACHE_NAME);
        const found = await cache.match(request);
        if (found) {
            if (!info?.sha256) return found;
            const bytes = await found.arrayBuffer();
            if (bytes.byteLength === info.bytes && await digest(bytes) === info.sha256) {
                return new Response(bytes, {headers: found.headers});
            }
            await cache.delete(request);
        }
    } catch (_) { /* Private mode/storage denial must not prevent playing. */ }
    let response;
    if (info && info.chunks && typeof DecompressionStream !== 'undefined') {
        // Never turn a temporary weak-network failure into a full raw redownload.
        // Reload retries only missing chunks; corrupt data is never given to Godot.
        response = await chunkedResponse(info, clientId);
    } else if (info && info.gzip && typeof DecompressionStream !== 'undefined') {
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
        await storeBounded(cache, request, response.clone(), CACHE_BUDGETS.complete);
    }
    return response;
}
function isolatedResponse(response) {
    // Preserve opaque/redirect errors. These cannot be reconstructed safely.
    if (response.status === 0) return response;
    const headers = new Headers(response.headers);
    headers.set('Cross-Origin-Opener-Policy', 'same-origin');
    headers.set('Cross-Origin-Embedder-Policy', 'require-corp');
    return new Response(response.body, {status: response.status,
        statusText: response.statusText, headers});
}
self.addEventListener('fetch', event => {
    if (event.request.method !== 'GET') return;
    const url = new URL(event.request.url);
    if (url.origin !== self.location.origin || !url.href.startsWith(self.registration.scope)) return;
    const name = url.pathname.slice(new URL(self.registration.scope).pathname.length);
    // Older open clients retain their immutable resources across a new deployment.
    // Missing uncached old files fail normally; never substitute a newer pack.
    if (RESOURCE_MAP[name] || /^index\.[a-f0-9]{12}(?:\.engine)?\.(?:pck|wasm|js|audio\.worklet\.js|audio\.position\.worklet\.js)$/.test(name)) {
        // Two cold tabs share one verified download, with independent responses.
        if (!inFlight.has(url.href)) {
            const pending = immutableResponse(event.request, name, event.clientId);
            inFlight.set(url.href, pending);
            pending.finally(() => inFlight.delete(url.href)).catch(() => {});
        }
        event.respondWith(inFlight.get(url.href).then(response => isolatedResponse(response.clone())));
    } else {
        // HTML and worker scripts need isolation headers on GitHub Pages.
        // Pass through fresh: never cache a mutable page or build-info response.
        event.respondWith(fetch(event.request).then(isolatedResponse));
    }
});
