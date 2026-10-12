// Exercise the production FIFO policy without allocating fake hundreds of MB.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const source = fs.readFileSync('tools/web/cache_worker.js', 'utf8')
  .replace('__RESOURCE_MAP__', '{}').replace('__WORKER_ID__', '"probe"');
const context = vm.createContext({Response, Request, URL, Map, Promise, Number,
  self: {addEventListener() {}}, crypto: globalThis.crypto});
vm.runInContext(source + '\nglobalThis.storeProbe = storeBounded;', context);
const rows = new Map();
const cache = {
  keys: async () => [...rows.keys()].map(url => ({url})),
  match: async item => rows.get(typeof item === 'string' ? item : item.url)?.clone(),
  delete: async item => rows.delete(typeof item === 'string' ? item : item.url),
  put: async (key, value) => rows.set(key, value.clone()),
};
const value = size => new Response('fixture', {headers: {'Content-Length': String(size)}});
for (let index = 0; index < 3; index++) rows.set('https://game.test/old' + index, value(65 * 1048576));
await context.storeProbe(cache, 'https://game.test/new', value(20 * 1048576), 128 * 1048576);
assert.equal(rows.size, 2);
assert(!rows.has('https://game.test/old0') && !rows.has('https://game.test/old1'));
rows.clear();
for (let index = 0; index < 160; index++) rows.set('https://game.test/chunk' + index, value(524288));
await Promise.all(Array.from({length: 6}, (_, index) =>
  context.storeProbe(cache, 'https://game.test/add' + index, value(524288), 80 * 1048576)));
const total = [...rows.values()].reduce((sum, response) => sum + Number(response.headers.get('Content-Length')), 0);
assert.equal(total, 80 * 1048576);
assert.equal(rows.size, 160);
assert(!rows.has('https://game.test/chunk0') && rows.has('https://game.test/add5'));
console.log(JSON.stringify({complete_budget_checked: true, concurrent_chunk_budget_bytes: total, failed: 0}));
