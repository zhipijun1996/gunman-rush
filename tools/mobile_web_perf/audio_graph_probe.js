/* Load before audio_probe.js and the engine. Observation only, never rewires audio. */
(function () {
  "use strict";
  function install(root) {
    if (root.MOBILE_AUDIO_GRAPH_PROBE) return root.MOBILE_AUDIO_GRAPH_PROBE;
    const LIMITS = {nodes: 1024, events: 256, edges: 4096, starts: 256,
      route_steps: 2048, route_depth: 48, paths_per_route: 4, cycles: 64};
    const ids = new WeakMap();
    const bufferIDs = new WeakMap();
    const nodes = new Map();
    const edges = new Map();
    const events = [];
    const starts = [];
    let nextID = 0, nextBuffer = 0, sequence = 0;
    let droppedNodes = 0, droppedEdges = 0, observerErrors = 0;
    const now = () => root.performance?.now?.() ?? Date.now();
    const push = (array, value, limit) => {
      array.push(value);
      if (array.length > limit) array.splice(0, array.length - limit);
    };
    const event = value => push(events, {sequence: ++sequence, performance_ms: now(), ...value}, LIMITS.events);
    const NativeNode = root.AudioNode;
    const NativeDestination = root.AudioDestinationNode;
    const NativeSource = root.AudioBufferSourceNode;
    const NativeWorklet = root.AudioWorkletNode;
    if (!NativeNode || !NativeSource || !root.WeakRef) {
      root.MOBILE_AUDIO_GRAPH_PROBE = Object.freeze({snapshot: () => ({
        version: "mobile-audio-graph-v1", status: "unavailable_requires_audio_nodes_and_weakref",
        nodes: [], edges: [], events: [], source_starts: [], source_routes: []
      })});
      return root.MOBILE_AUDIO_GRAPH_PROBE;
    }
    function nodeID(node, processorName) {
      if (ids.has(node)) {
        const id = ids.get(node);
        if (processorName && id !== null) nodes.get(id).processor_name = processorName;
        return id;
      }
      if (nodes.size >= LIMITS.nodes) {
        droppedNodes++;
        ids.set(node, null);
        return null;
      }
      const id = ++nextID;
      ids.set(node, id);
      nodes.set(id, {
        id, reference: new root.WeakRef(node), type: node.constructor?.name || "AudioNode",
        destination: !!NativeDestination && node instanceof NativeDestination,
        source: node instanceof NativeSource, processor_name: processorName || null
      });
      return id;
    }
    function observeError(operation, node, error) {
      try { event({operation, from: nodeID(node), native_exception: String(error?.name || "Error")}); }
      catch (_) { observerErrors++; }
    }
    const channelIndex = value => (Number(value) || 0) >>> 0;
    const nativeConnect = NativeNode.prototype.connect;
    NativeNode.prototype.connect = function (...args) {
      let result;
      try { result = nativeConnect.apply(this, args); }
      catch (error) { observeError("connect", this, error); throw error; }
      try {
        const from = nodeID(this);
        if (!(args[0] instanceof NativeNode)) {
          event({operation: "connect", from, to: null, target_kind: "non_audio_node"});
          return result;
        }
        const to = nodeID(args[0]);
        const output = channelIndex(args[1]);
        const input = channelIndex(args[2]);
        const key = `${from}/${to}/${output}/${input}`;
        if (from !== null && to !== null) {
          if (edges.has(key) || edges.size < LIMITS.edges) {
            edges.set(key, {from, to, output, input});
          } else droppedEdges++;
        }
        event({operation: "connect", from, to, output, input});
      } catch (_) { observerErrors++; }
      return result;
    };
    const nativeDisconnect = NativeNode.prototype.disconnect;
    NativeNode.prototype.disconnect = function (...args) {
      let result;
      try { result = nativeDisconnect.apply(this, args); }
      catch (error) { observeError("disconnect", this, error); throw error; }
      try {
        const from = nodeID(this);
        const all = args.length === 0;
        const outputOnly = !all && (typeof args[0] === "number" || args[0] === undefined);
        const destinationID = !all && !outputOnly && args[0] instanceof NativeNode ? nodeID(args[0]) : null;
        let removed = 0;
        for (const [key, edge] of edges) {
          if (edge.from !== from) continue;
          let matches = all;
          if (outputOnly) matches = edge.output === channelIndex(args[0]);
          else if (destinationID !== null) matches = edge.to === destinationID &&
            (args.length < 2 || edge.output === channelIndex(args[1])) &&
            (args.length < 3 || edge.input === channelIndex(args[2]));
          if (matches) { edges.delete(key); removed++; }
        }
        event({operation: "disconnect", from, to: destinationID, all,
          output: outputOnly ? channelIndex(args[0]) : args.length > 1 ? channelIndex(args[1]) : null,
          input: args.length > 2 ? channelIndex(args[2]) : null, removed_edges: removed});
      } catch (_) { observerErrors++; }
      return result;
    };
    const nativeStart = NativeSource.prototype.start;
    NativeSource.prototype.start = function (...args) {
      let result;
      try { result = nativeStart.apply(this, args); }
      catch (error) { observeError("start", this, error); throw error; }
      try {
        const buffer = this.buffer;
        if (buffer && !bufferIDs.has(buffer)) bufferIDs.set(buffer, ++nextBuffer);
        const summary = buffer ? {id: bufferIDs.get(buffer), frames: buffer.length,
          channels: buffer.numberOfChannels, sample_rate: buffer.sampleRate,
          duration_seconds: buffer.duration} : null;
        const row = {source: nodeID(this), performance_ms: now(),
          audio_seconds: this.context?.currentTime ?? null,
          when: args[0] ?? 0, offset: args[1] ?? 0, duration: args[2] ?? null,
          loop: this.loop, playback_rate: this.playbackRate?.value ?? null,
          buffer: summary};
        push(starts, row, LIMITS.starts);
        event({operation: "start", ...row});
      } catch (_) { observerErrors++; }
      return result;
    };
    if (NativeWorklet) {
      root.AudioWorkletNode = new Proxy(NativeWorklet, {
        construct(target, args, newTarget) {
          const node = Reflect.construct(target, args, newTarget);
          try { nodeID(node, String(args[1])); } catch (_) { observerErrors++; }
          return node;
        }
      });
    }
    function snapshot() {
      const values = new Map();
      for (const entry of nodes.values()) {
        // Node and AudioBuffer objects are only local temporaries during this call.
        const node = entry.reference.deref();
        let gain = null;
        try {
          if (node && node.gain && Number.isFinite(node.gain.value)) gain = node.gain.value;
        } catch (_) { observerErrors++; }
        values.set(entry.id, {id: entry.id, type: entry.type, available: !!node,
          gain, destination: entry.destination, source: entry.source,
          processor_name: entry.processor_name,
          observer_fanout_node: ["mobile-web-perf-pcm", "output-diagnostic-probe"].includes(entry.processor_name)});
      }
      const edgeRows = [...edges.values()].map(edge => ({...edge}));
      const adjacency = new Map();
      for (const edge of edgeRows) {
        if (!adjacency.has(edge.from)) adjacency.set(edge.from, []);
        adjacency.get(edge.from).push(edge.to);
      }
      const cycles = new Map();
      function rememberCycle(path) {
        const body = path.slice(0, -1);
        const minimum = Math.min(...body);
        const pivot = body.indexOf(minimum);
        const rotated = body.slice(pivot).concat(body.slice(0, pivot));
        const key = rotated.join("/");
        if (cycles.size < LIMITS.cycles && !cycles.has(key)) cycles.set(key, path);
      }
      // Include feedback components before a sample has started, or after its
      // source was collected. This traversal holds only numeric IDs.
      const colors = new Map();
      let cycleScanSteps = 0, cycleScanTruncated = false;
      for (const node of values.values()) {
        if (!node.available || colors.has(node.id)) continue;
        const stack = [{id: node.id, next: 0}];
        const positions = new Map([[node.id, 0]]);
        colors.set(node.id, 1);
        while (stack.length) {
          if (++cycleScanSteps > LIMITS.nodes + LIMITS.edges * 2) {
            cycleScanTruncated = true;
            break;
          }
          const top = stack[stack.length - 1];
          const neighbors = adjacency.get(top.id) || [];
          if (top.next >= neighbors.length) {
            colors.set(top.id, 2); positions.delete(top.id); stack.pop();
            continue;
          }
          const target = neighbors[top.next++];
          if (!values.get(target)?.available) continue;
          if (colors.get(target) === 1 && positions.has(target)) {
            rememberCycle(stack.slice(positions.get(target)).map(item => item.id).concat(target));
          } else if (!colors.has(target)) {
            if (stack.length >= LIMITS.route_depth) { cycleScanTruncated = true; continue; }
            positions.set(target, stack.length); colors.set(target, 1);
            stack.push({id: target, next: 0});
          }
        }
        if (cycleScanSteps > LIMITS.nodes + LIMITS.edges * 2) break;
      }
      function route(source) {
        const initial = values.get(source);
        if (!initial?.available) return {source, status: "unavailable_collected",
          nonzero_gain_destination_path_found: false, nonzero_gain_paths: [],
          zero_gain_paths: [], observer_fanout_paths: [], feedback_cycles: []};
        const pending = [{id: source, path: [], zero: false, observer: false}];
        const visited = new Set();
        const audible = [], zero = [], observer = [], localCycles = [];
        let steps = 0, truncated = false, unavailable = false;
        while (pending.length && steps++ < LIMITS.route_steps) {
          const item = pending.pop();
          const value = values.get(item.id);
          if (!value?.available) { unavailable = true; continue; }
          const path = item.path.concat(item.id);
          if (path.length > LIMITS.route_depth) { truncated = true; continue; }
          const isZero = item.zero || value.gain === 0;
          const isObserver = item.observer || value.observer_fanout_node;
          const key = `${item.id}/${isZero}/${isObserver}`;
          if (visited.has(key)) continue;
          visited.add(key);
          if (value.destination) {
            const target = isObserver ? observer : isZero ? zero : audible;
            if (target.length < LIMITS.paths_per_route) target.push(path);
            continue;
          }
          for (const target of adjacency.get(item.id) || []) {
            const previous = path.indexOf(target);
            if (previous >= 0) {
              const cycle = path.slice(previous).concat(target);
              if (localCycles.length < LIMITS.paths_per_route) localCycles.push(cycle);
              rememberCycle(cycle);
            } else pending.push({id: target, path, zero: isZero, observer: isObserver});
          }
        }
        if (pending.length) truncated = true;
        const incomplete = truncated || unavailable || droppedNodes > 0 || droppedEdges > 0;
        return {source, nonzero_gain_destination_path_found: audible.length > 0,
          status: audible.length ? "nonzero_gain_path_observed" : incomplete ?
            "unresolved_incomplete_observation" : "no_nonzero_gain_destination_path_observed",
          nonzero_gain_paths: audible, zero_gain_paths: zero,
          observer_fanout_paths: observer, feedback_cycles: localCycles,
          traversal_truncated: truncated, unavailable_node_on_path: unavailable};
      }
      const routes = [...values.values()].filter(node => node.source).map(node => route(node.id));
      return {
        version: "mobile-audio-graph-v1", timestamp: new Date().toISOString(), performance_ms: now(),
        scope: "Observed AudioNode topology/current gain only. A nonzero path is not rendered PCM or speaker audibility. No audio connections/gains rewritten.",
        installed_before_engine_required: true,
        nodes: [...values.values()], edges: edgeRows,
        events: events.map(row => ({...row, ...(row.buffer ? {buffer: {...row.buffer}} : {})})),
        source_starts: starts.map(row => ({...row, buffer: row.buffer ? {...row.buffer} : null})),
        source_routes: routes, feedback_cycles: [...cycles.values()].map(path => [...path]),
        feedback_cycle_scan_truncated: cycleScanTruncated,
        limits: {...LIMITS}, dropped_nodes: droppedNodes, dropped_edges: droppedEdges,
        observer_errors: observerErrors,
        observer_fanout_note: "Paths through known PCM observer worklets are separated; zero-gain sink branches never count as audible routes. Muting through gains is evaluated now; unobserved nodes, AudioParam modulation, channel cancellation and hardware output remain outside this graph proof."
      };
    }
    root.MOBILE_AUDIO_GRAPH_PROBE = Object.freeze({snapshot});
    return root.MOBILE_AUDIO_GRAPH_PROBE;
  }

  function selfTest() {
    const assert = require("assert");
    const vm = require("vm");
    function world() {
      const references = [];
      const sentinel = new TypeError("original exception");
      class AudioNode {
        constructor() { this.context = {currentTime: 1}; this.nativeEdges = []; }
        connect(target, output = 0, input = 0) {
          if (target === "throw") throw sentinel;
          this.nativeEdges.push([target, output, input]); return target;
        }
        disconnect(...args) {
          if (args[0] === "throw") throw sentinel;
          if (!args.length) this.nativeEdges = [];
          else this.nativeEdges = this.nativeEdges.filter(edge => {
            if (typeof args[0] === "number" || args[0] === undefined) return edge[1] !== (args[0] || 0);
            return !(edge[0] === args[0] && (args.length < 2 || edge[1] === args[1]) &&
              (args.length < 3 || edge[2] === args[2]));
          });
          return 71;
        }
      }
      class AudioDestinationNode extends AudioNode {}
      class GainNode extends AudioNode { constructor(value = 1) { super(); this.gain = {value}; } }
      class AudioBufferSourceNode extends AudioNode {
        constructor() { super(); this.buffer = {length: 44, numberOfChannels: 2,
          sampleRate: 44, duration: 1}; this.playbackRate = {value: 1}; this.loop = false; }
        start(when) { if (when === -1) throw sentinel; return 72; }
      }
      class AudioWorkletNode extends AudioNode {}
      class FakeWeakRef {
        constructor(node) { this.testOnlyTarget = node; references.push(this); }
        deref() { return this.testOnlyTarget; }
      }
      const root = {AudioNode, AudioDestinationNode, AudioBufferSourceNode, AudioWorkletNode,
        GainNode, WeakRef: FakeWeakRef, performance: {now: () => 1}};
      vm.runInNewContext(`(${install.toString()})(root)`, {root, console});
      return {root, references, sentinel};
    }
    {
      const {root, references, sentinel} = world();
      const source = new root.AudioBufferSourceNode();
      const gain = new root.GainNode(0.5), destination = new root.AudioDestinationNode();
      assert.strictEqual(source.connect(gain), gain);
      gain.connect(destination);
      assert.equal(source.start(), 72);
      let s = root.MOBILE_AUDIO_GRAPH_PROBE.snapshot();
      assert.equal(s.source_routes[0].nonzero_gain_destination_path_found, true);
      assert.equal(s.source_starts[0].buffer.duration_seconds, 1);
      assert.equal(s.nodes.find(n => n.type === "GainNode").gain, 0.5);
      assert.equal(gain.nativeEdges.length, 1, "probe must not introduce connections");
      const observer = new root.AudioWorkletNode({}, "mobile-web-perf-pcm");
      const silent = new root.GainNode(0);
      source.connect(observer); observer.connect(silent); silent.connect(destination);
      gain.disconnect(destination);
      s = root.MOBILE_AUDIO_GRAPH_PROBE.snapshot();
      assert.equal(s.source_routes[0].nonzero_gain_destination_path_found, false);
      assert.equal(s.source_routes[0].observer_fanout_paths.length, 1);
      source.connect(gain); gain.connect(destination); gain.gain.value = 0;
      s = root.MOBILE_AUDIO_GRAPH_PROBE.snapshot();
      assert.equal(s.source_routes[0].nonzero_gain_destination_path_found, false);
      assert.equal(s.source_routes[0].zero_gain_paths.length, 1);
      gain.gain.value = 1;
      assert.equal(root.MOBILE_AUDIO_GRAPH_PROBE.snapshot().source_routes[0].nonzero_gain_destination_path_found, true);
      assert.throws(() => source.connect("throw"), error => error === sentinel);
      assert.throws(() => source.disconnect("throw"), error => error === sentinel);
      assert.throws(() => source.start(-1), error => error === sentinel);
      assert.equal(source.disconnect(), 71);
      assert.equal(root.MOBILE_AUDIO_GRAPH_PROBE.snapshot().edges.filter(e => e.from === 1).length, 0);
      references.find(ref => ref.testOnlyTarget === source).testOnlyTarget = undefined;
      s = root.MOBILE_AUDIO_GRAPH_PROBE.snapshot();
      assert.equal(s.source_routes[0].status, "unavailable_collected");
      assert.equal(s.nodes.find(n => n.id === 1).available, false);
      console.log("PASS: complete nonzero path, current gains, observer zero sink, GC-unavailable and original calls/exceptions");
    }
    {
      const {root} = world();
      const a = new root.GainNode(), b = new root.GainNode();
      a.connect(b); b.connect(a);
      const s = root.MOBILE_AUDIO_GRAPH_PROBE.snapshot();
      assert.equal(s.source_routes.length, 0);
      assert.equal(s.feedback_cycles.length, 1);
      console.log("PASS: feedback component detected before any sample source exists");
    }
    {
      const {root} = world();
      const source = new root.AudioBufferSourceNode(), masterIn = new root.GainNode(),
        masterOut = new root.GainNode(), destination = new root.AudioDestinationNode();
      source.connect(masterIn); masterIn.connect(masterOut); masterOut.connect(destination);
      source.start();
      assert.equal(root.MOBILE_AUDIO_GRAPH_PROBE.snapshot().source_routes[0].nonzero_gain_destination_path_found, true);
      masterOut.disconnect(); masterOut.connect(masterIn);
      let s = root.MOBILE_AUDIO_GRAPH_PROBE.snapshot();
      assert.equal(s.source_routes[0].nonzero_gain_destination_path_found, false);
      assert.equal(s.feedback_cycles.length, 1);
      assert.equal(s.source_routes[0].feedback_cycles.length, 1);
      masterOut.disconnect(masterIn); masterOut.connect(destination);
      s = root.MOBILE_AUDIO_GRAPH_PROBE.snapshot();
      assert.equal(s.feedback_cycles.length, 0);
      assert.equal(s.source_routes[0].nonzero_gain_destination_path_found, true);
      masterOut.disconnect(destination, 0, 0);
      assert.equal(root.MOBILE_AUDIO_GRAPH_PROBE.snapshot().source_routes[0].nonzero_gain_destination_path_found, false);
      masterOut.connect(destination, 1, 0); masterOut.disconnect(1);
      assert.equal(root.MOBILE_AUDIO_GRAPH_PROBE.snapshot().edges.some(e => e.output === 1), false);
      console.log("PASS: Master self-send feedback candidate, cycle termination and all disconnect overloads");
    }
    {
      const {root} = world();
      const destination = new root.AudioDestinationNode();
      for (let i = 0; i < 1100; i++) {
        const source = new root.AudioBufferSourceNode(); source.connect(destination); source.start();
      }
      const s = root.MOBILE_AUDIO_GRAPH_PROBE.snapshot();
      assert.equal(s.nodes.length, 1024); assert.equal(s.events.length, 256);
      assert.equal(s.source_starts.length, 256); assert(s.dropped_nodes > 0);
      assert(s.edges.length <= 4096); assert.equal(s.observer_errors, 0);
      const old = s.source_starts[0].buffer.frames;
      s.source_starts[0].buffer.frames = -1;
      assert.equal(root.MOBILE_AUDIO_GRAPH_PROBE.snapshot().source_starts[0].buffer.frames, old);
      assert.doesNotThrow(() => JSON.stringify(s));
      console.log("PASS: <=1024 weak node records, <=256 events/starts, bounded edges and detached JSON snapshots");
    }
    console.log("PASS: audio graph pure Node mocks; no browser/engine started");
  }
  if (typeof module !== "undefined" && module.exports) {
    module.exports = {install};
    if (require.main === module && process.argv.includes("--self-test")) selfTest();
  } else install(window);
})();
