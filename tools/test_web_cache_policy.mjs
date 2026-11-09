// Exercise real package sizes through metadata, without allocating hundreds of MB.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const source = fs.readFileSync('tools/web/cache_worker.js', 'utf8')
  .replace('__RESOURCE_MAP__', '{}').replace('__WORKER_ID__', '"probe"');
let opened = 0;
const context = vm.createContext({Response, Request, URL, Map, Promise, Number,
  self: {addEventListener() {}}, crypto: globalThis.crypto,
  caches: {open: async () => { opened++; return {}; }}});
vm.runInContext(source + '\nObject.assign(globalThis, {storeProbe: storeBounded, budgetProbe: cacheBudgets, openProbe: runtimeCache});', context);
const value = size => new Response('fixture', {headers: {'Content-Length': String(size)}});
function fixture(entries = []) {
  const rows = new Map(entries.map(([url, size]) => [url, value(size)]));
  const calls = {keys: 0, match: 0, put: 0, deleted: 0};
  const cache = {
    keys: async () => { calls.keys++; return [...rows.keys()].map(url => ({url})); },
    match: async item => {
      calls.match++;
      return rows.get(typeof item === 'string' ? item : item.url)?.clone();
    },
    delete: async item => { calls.deleted++; return rows.delete(typeof item === 'string' ? item : item.url); },
    put: async (key, response) => {
      calls.put++;
      rows.set(typeof key === 'string' ? key : key.url, response.clone());
    },
  };
  return {rows, calls, cache};
}
const MiB = 1048576;

// Preserve FIFO eviction for old builds.
const old = fixture(Array.from({length: 3}, (_, i) => ['https://game.test/old' + i, 65 * MiB]));
await context.storeProbe(old.cache, 'https://game.test/new', value(20 * MiB), 128 * MiB);
assert.equal(old.rows.size, 2);
assert(!old.rows.has('https://game.test/old0') && !old.rows.has('https://game.test/old1'));

// Concurrent writes share one metadata scan; the 80 MiB bound is still exact.
const chunked = fixture(Array.from({length: 160}, (_, i) => ['https://game.test/chunk' + i, 524288]));
await Promise.all(Array.from({length: 6}, (_, i) =>
  context.storeProbe(chunked.cache, 'https://game.test/add' + i, value(524288), 80 * MiB)));
const total = [...chunked.rows.values()].reduce((sum, response) => sum + Number(response.headers.get('Content-Length')), 0);
assert.equal(total, 80 * MiB);
assert.equal(chunked.rows.size, 160);
assert(!chunked.rows.has('https://game.test/chunk0') && chunked.rows.has('https://game.test/add5'));
assert.equal(chunked.calls.keys, 1, 'Every chunk write must not rescan CacheStorage');
assert.equal(chunked.calls.match, 160, 'Only the initial cache inventory reads old metadata');

// An object larger than a caller's budget must not empty a useful cache.
const oversized = fixture([['https://game.test/engine', 51_222_107]]);
await context.storeProbe(oversized.cache, 'https://game.test/large.pck', value(237_144_744), 128 * MiB);
assert(oversized.rows.has('https://game.test/engine'));
assert(!oversized.rows.has('https://game.test/large.pck'));
assert.equal(oversized.calls.deleted, 0);
assert.equal(oversized.calls.keys, 0);

// Real deployed build e767187d427f: the old 128/80 MiB limits were both too small.
function parts(prefix, bytes) {
  const out = [];
  for (let offset = 0; offset < bytes; offset += 524288) {
    out.push({url: prefix + offset, bytes: Math.min(524288, bytes - offset)});
  }
  return out;
}
const production = {
  'game.pck': {bytes: 237_144_744, chunks: parts('pack-', 237_144_744)},
  'engine.wasm': {bytes: 51_222_107, chunks: parts('wasm-', 51_222_107)},
};
const budgets = context.budgetProbe(production);
assert.equal(budgets.complete, 288_366_851);
assert.equal(budgets.chunks, 288_366_851);
const current = fixture();
await context.storeProbe(current.cache, 'https://game.test/engine.wasm', value(production['engine.wasm'].bytes), budgets.complete);
await context.storeProbe(current.cache, 'https://game.test/game.pck', value(production['game.pck'].bytes), budgets.complete);
assert.equal(current.rows.size, 2, 'The full current runtime must remain cached');
assert(current.rows.has('https://game.test/engine.wasm') && current.rows.has('https://game.test/game.pck'));
assert.equal(current.calls.keys, 1);

// Content-identical chunks shared by resources consume the budget only once.
const shared = context.budgetProbe({
  a: {bytes: 90 * MiB, chunks: [{url: 'same', bytes: 90 * MiB}]},
  b: {bytes: 100 * MiB, chunks: [{url: 'same', bytes: 90 * MiB}, {url: 'tail', bytes: 10 * MiB}]},
});
assert.equal(shared.chunks, 100 * MiB);

// Replacing a key updates accounting without evicting it or losing the bound.
await context.storeProbe(current.cache, 'https://game.test/engine.wasm', value(60 * MiB), budgets.complete);
assert.equal(current.rows.size, 1);
assert(current.rows.has('https://game.test/engine.wasm'));

// Open one handle per cache so concurrent resources share the same FIFO index.
await Promise.all([context.openProbe('runtime'), context.openProbe('runtime'), context.openProbe('runtime')]);
assert.equal(opened, 1);

// A quota failure still resolves; a subsequent write rebuilds the inventory.
const denied = fixture();
const put = denied.cache.put;
denied.cache.put = async () => { throw new Error('QuotaExceededError'); };
await context.storeProbe(denied.cache, 'https://game.test/denied', value(10), 100);
denied.cache.put = put;
await context.storeProbe(denied.cache, 'https://game.test/retry', value(10), 100);
assert(denied.rows.has('https://game.test/retry'));
assert.equal(denied.calls.keys, 2);

console.log(JSON.stringify({
  complete_budget_checked: true, concurrent_chunk_budget_bytes: total,
  production_pack_bytes: production['game.pck'].bytes,
  current_build_cache_budget_bytes: budgets.complete,
  chunk_metadata_scans: chunked.calls.keys,
  oversized_preserves_engine: true, quota_recovery: true, failed: 0,
}));
