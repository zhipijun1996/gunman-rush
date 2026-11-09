// Exercise the emitted startup state machine, without pretending to run WebGL.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

const page = readFileSync(process.argv[2] || 'build/workbench/site/index.html', 'utf8');
const script = page.match(/<script>\s*(const GODOT_CONFIG = [\s\S]*?)<\/script>/)?.[1];
assert.ok(script, 'actual exported engine startup script exists');

function element() {
    return {
        children: [], style: {}, removed: false,
        get lastChild() { return this.children.at(-1); },
        get textContent() { return this.children.map(child => child.textContent || '').join(''); },
        appendChild(child) { this.children.push(child); },
        removeChild(child) { this.children.splice(this.children.indexOf(child), 1); },
        removeAttribute() {},
        remove() { this.removed = true; },
    };
}

async function scenario({ready = true, gzip = true, missing = [], failure = null}) {
    const nodes = new Map(['status', 'status-progress', 'status-notice', 'playtest-download'].map(id => [id, element()]));
    const messages = [];
    let starts = 0;
    class Engine {
        static getMissingFeatures() { return missing; }
        startGame() { starts++; return failure ? Promise.reject(new Error(failure)) : Promise.resolve(); }
    }
    const context = {
        Engine, Promise, Error, console: {error() {}},
        document: {
            getElementById: id => nodes.get(id),
            createTextNode: text => ({textContent: text}),
            createElement: () => ({textContent: ''}),
        },
        location: {origin: 'https://workbench.test'}, navigator: {},
        window: {PLAYTEST_CACHE_READY: Promise.resolve(ready), parent: {postMessage(message, origin) {
            assert.equal(origin, 'https://workbench.test'); messages.push(message);
        }}},
    };
    if (gzip) context.DecompressionStream = class {};
    vm.runInNewContext(script, context);
    await new Promise(resolve => setImmediate(resolve));
    return {starts, messages, nodes, window: context.window};
}

for (const args of [{ready: false}, {gzip: false}, {missing: ['WebGL2']}]) {
    const result = await scenario(args);
    assert.equal(result.starts, 0, 'missing transport/graphics never starts a raw runtime download');
    assert.equal(result.messages.length, 1, 'one actionable startup failure reaches the parent');
    assert.equal(result.messages[0].channel, 'gunman-workbench');
    assert.equal(result.messages[0].type, 'error');
    assert.equal(result.messages[0].code, 'runtime_startup_failed');
    assert.ok(result.messages[0].detail.includes(args.missing ? 'WebGL 2' : '试玩'));
    assert.ok(result.nodes.get('status-notice').textContent.length, 'original iframe diagnostic retained');
}
const failedEngine = await scenario({failure: 'WASM initialization rejected'});
assert.equal(failedEngine.starts, 1);
assert.equal(failedEngine.messages[0].diagnostic, 'WASM initialization rejected');
const successfulStart = await scenario({});
assert.equal(successfulStart.starts, 1);
assert.equal(successfulStart.messages.length, 0, 'successful startup sends no false error');
assert.equal(successfulStart.window.PLAYTEST_LOADING_DONE, true);
console.log(JSON.stringify({scenarios: 5, denied_transport_has_no_raw_fallback: true, webgl_failure_forwarded: true, failed: 0}));
