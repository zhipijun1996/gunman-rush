/* Install before the engine. Diagnostic fan-out only; never changes game gains. */
(() => {
  "use strict";
  if (window.MOBILE_AUDIO_PROBE) return;
  const nativeConnect = AudioNode.prototype.connect;
  const nativeDisconnect = AudioNode.prototype.disconnect;
  const nativeStart = AudioBufferSourceNode.prototype.start;
  const nativeStop = AudioBufferSourceNode.prototype.stop;
  const NativeWorkletNode = window.AudioWorkletNode;
  const scriptURL = document.currentScript?.src || location.href;
  const workletURL = window.MOBILE_AUDIO_PROBE_WORKLET_URL ||
    new URL("pcm_worklet.js", scriptURL).href;
  const contexts = new Map();
  const destinations = new Map();
  const streams = [];
  const starts = [];
  const created = [];
  const ended = [];
  const stops = [];
  const observedSources = new WeakSet();
  const stoppedSources = new WeakSet();
  const errors = [];
  const sourceIDs = new WeakMap();
  const connections = new Set();
  let nextSource = 0;
  let startsTotal = 0;
  let stopsTotal = 0;
  let createdTotal = 0;
  let endedTotal = 0;
  const now = () => performance.now();
  const ring = (array, value, limit = 256) => {
    array.push(value);
    if (array.length > limit) array.splice(0, array.length - limit);
  };
  const error = (where, err) => ring(errors, {
    performance_ms: now(), where, name: String(err?.name || "Error")
  }, 32);
  function context(ctx) {
    if (!contexts.has(ctx)) {
      if (contexts.size >= 32) return {id: null};
      const row = {id: contexts.size + 1, ctx, states: []};
      const state = () => ring(row.states, {
        performance_ms: now(), audio_seconds: ctx.currentTime, state: ctx.state
      }, 64);
      contexts.set(ctx, row);
      state();
      ctx.addEventListener("statechange", state);
    }
    return contexts.get(ctx);
  }
  function sourceID(node) {
    if (!sourceIDs.has(node)) sourceIDs.set(node, ++nextSource);
    return sourceIDs.get(node);
  }
  function observeSource(node, entry) {
    if (observedSources.has(node)) return;
    observedSources.add(node);
    createdTotal++;
    ring(created, {sequence: createdTotal, source_id: sourceID(node), entry,
      context_id: context(node.context).id, performance_ms: now(),
      audio_seconds: node.context.currentTime});
    node.addEventListener?.("ended", function () {
      endedTotal++;
      ring(ended, {sequence: endedTotal, source_id: sourceID(this),
        context_id: context(this.context).id, performance_ms: now(),
        audio_seconds: this.context.currentTime, stop_requested: stoppedSources.has(this)});
    });
  }
  function isDestination(node) {
    return node instanceof AudioDestinationNode;
  }
  function attach(edge) {
    if (!connections.has(edge) || !edge.destination.tap || edge.attached) return;
    try {
      nativeConnect.call(edge.source, edge.destination.tap, edge.output, 0);
      edge.attached = true;
    } catch (err) { error("tap_connect", err); }
  }
  function destination(node) {
    if (destinations.has(node)) return destinations.get(node);
    if (destinations.size >= 16) return null;
    const row = {
      id: destinations.size + 1, context_id: context(node.context).id,
      node, tap: null, meter: null, status: "loading", messages: []
    };
    destinations.set(node, row);
    const ctx = node.context;
    if (!ctx.audioWorklet || !NativeWorkletNode) {
      row.status = "unavailable_audio_worklet";
      return row;
    }
    ctx.audioWorklet.addModule(workletURL).then(() => {
      const tap = new NativeWorkletNode(ctx, "mobile-web-perf-pcm", {
        numberOfInputs: 1, numberOfOutputs: 1,
        outputChannelCount: [node.channelCount], channelCount: node.channelCount,
        channelCountMode: "explicit", channelInterpretation: node.channelInterpretation,
        processorOptions: {report_seconds: 0.1}
      });
      const silent = ctx.createGain();
      silent.gain.value = 0;
      // Bypass our hook: this private sink must never create another tap.
      nativeConnect.call(tap, silent);
      nativeConnect.call(silent, node);
      row.tap = tap;
      row.silent = silent;
      tap.port.addEventListener("message", event => {
        row.meter = event.data;
        ring(row.messages, {...event.data, received_performance_ms: now()}, 128);
      });
      tap.port.start();
      row.status = "metering";
      for (const edge of connections) if (edge.destination === row) attach(edge);
    }).catch(err => { row.status = "module_failed"; error("tap_module", err); });
    return row;
  }
  AudioNode.prototype.connect = function (...args) {
    const result = nativeConnect.apply(this, args);
    try { if (isDestination(args[0])) {
      const row = destination(args[0]);
      if (row) {
        const output = args[1] ?? 0;
        if (![...connections].some(e => e.source === this &&
            e.destination === row && e.output === output)) {
          const edge = {source: this, destination: row, output, attached: false};
          connections.add(edge);
          attach(edge);
        }
      }
    } } catch (err) { error("destination_observer", err); }
    return result;
  };
  AudioNode.prototype.disconnect = function (...args) {
    const result = nativeDisconnect.apply(this, args);
    for (const edge of [...connections]) {
      if (edge.source !== this) continue;
      const all = args.length === 0;
      const outputOnly = typeof args[0] === "number" && args[0] === edge.output;
      const target = args[0] === edge.destination.node &&
        (args.length < 2 || args[1] === edge.output);
      if (!all && !outputOnly && !target) continue;
      if (edge.attached && !all && !outputOnly) {
        try { nativeDisconnect.call(this, edge.destination.tap, edge.output, 0); }
        catch (_) { /* A completed source may already have disconnected. */ }
      }
      connections.delete(edge);
    }
    return result;
  };
  function bufferSummary(buffer) {
    if (!buffer) return null;
    let peak = 0, energy = 0, examined = 0, nonzero = 0;
    const budget = 65536;
    for (let ch = 0; ch < buffer.numberOfChannels && examined < budget; ch++) {
      const values = buffer.getChannelData(ch);
      const count = Math.min(values.length, budget - examined);
      for (let i = 0; i < count; i++) {
        const value = values[i];
        peak = Math.max(peak, Math.abs(value));
        energy += value * value;
        if (value !== 0) nonzero++;
      }
      examined += count;
    }
    const complete = examined === buffer.length * buffer.numberOfChannels;
    return {
      duration_seconds: buffer.duration, frames: buffer.length,
      channels: buffer.numberOfChannels, sample_rate: buffer.sampleRate,
      examined_samples: examined, complete_scan: complete,
      scanned_nonzero_samples: nonzero,
      nonzero: nonzero > 0 ? true : complete ? false : null,
      scanned_peak: peak, scanned_rms: Math.sqrt(energy / Math.max(1, examined))
    };
  }
  AudioBufferSourceNode.prototype.start = function (...args) {
    // Native exceptions and scheduling behavior remain intact.
    const result = nativeStart.apply(this, args);
    startsTotal++;
    try {
      observeSource(this, "start_fallback");
      ring(starts, {
        sequence: startsTotal, source_id: sourceID(this),
        context_id: context(this.context).id, performance_ms: now(),
        audio_seconds: this.context.currentTime, context_state: this.context.state,
        when: args[0] ?? 0, offset: args[1] ?? 0, duration: args[2] ?? null,
        playback_rate: this.playbackRate.value, loop: this.loop,
        buffer: bufferSummary(this.buffer), native_start_succeeded: true
      });
    } catch (err) { error("start_summary", err); }
    return result;
  };
  AudioBufferSourceNode.prototype.stop = function (...args) {
    const result = nativeStop.apply(this, args);
    stopsTotal++;
    stoppedSources.add(this);
    ring(stops, {sequence: stopsTotal, source_id: sourceID(this),
      performance_ms: now(), audio_seconds: this.context.currentTime});
    return result;
  };
  const NativeBufferSource = window.AudioBufferSourceNode;
  window.AudioBufferSourceNode = new Proxy(NativeBufferSource, {
    construct(target, args, newTarget) {
      const node = Reflect.construct(target, args, newTarget);
      try { observeSource(node, "constructor"); } catch (err) { error("source_created", err); }
      return node;
    }
  });
  const wrappedContextPrototypes = new WeakSet();
  for (const name of ["AudioContext", "webkitAudioContext"]) {
    const prototype = window[name]?.prototype;
    if (!prototype || wrappedContextPrototypes.has(prototype)) continue;
    wrappedContextPrototypes.add(prototype);
    const create = prototype.createBufferSource;
    if (typeof create !== "function") continue;
    prototype.createBufferSource = function (...args) {
      const node = create.apply(this, args);
      try { observeSource(node, "createBufferSource"); } catch (err) { error("source_created", err); }
      return node;
    };
  }
  function observeStream(node, name) {
    if (name !== "godot-processor" || streams.length >= 16) return;
    const row = {
      id: streams.length + 1, context_id: context(node.context).id,
      mode: "not_started", sent_samples: 0, consumed_samples: 0,
      read_messages: 0, chunk_messages: 0, initial_samples: 0, messages: []
    };
    streams.push(row);
    const post = node.port.postMessage;
    node.port.postMessage = function (...args) {
      const result = post.apply(this, args);
      try {
        const message = args[0];
        const cmd = message?.cmd;
        if (cmd === "start_nothreads") {
          row.mode = "no_threads";
          row.initial_samples = message.data?.[0]?.length || 0;
          row.sent_samples = row.initial_samples;
          row.consumed_samples = 0;
        } else if (cmd === "start") row.mode = "threads";
        else if (cmd === "stop") row.mode = "stopped";
        else if (cmd === "chunk") {
          row.chunk_messages++;
          row.sent_samples += message.data?.length || 0;
        }
        if (["start_nothreads", "start", "stop", "chunk"].includes(cmd)) {
          ring(row.messages, {direction: "to_worklet", cmd,
            samples: cmd === "chunk" ? message.data?.length || 0 : null,
            performance_ms: now(), audio_seconds: node.context.currentTime}, 128);
        }
      } catch (err) { error("stream_post_summary", err); }
      return result;
    };
    node.port.addEventListener("message", event => {
      if (event.data?.cmd === "mobile_perf_stream_stats") {
        // Installed before Godot's onmessage: diagnostic messages must not reach
        // its unknown-command error branch. Original read/input events pass on.
        event.stopImmediatePropagation?.();
        const stats = event.data.data;
        if (!stats || stats.instrumented_worklet !== true ||
            !Number.isFinite(stats.total_requested_frames) ||
            !Number.isFinite(stats.read_frames) || !Number.isFinite(stats.underrun_frames)) return;
        row.underrun_stats = {...stats, received_performance_ms: now(),
          received_audio_seconds: node.context.currentTime};
        if (!row.underrun_history) row.underrun_history = [];
        ring(row.underrun_history, {...row.underrun_stats}, 128);
        return;
      }
      if (event.data?.cmd !== "read") return;
      const count = event.data.data;
      if (!Number.isFinite(count) || count < 0) return;
      row.read_messages++;
      row.consumed_samples += count;
      ring(row.messages, {direction: "from_worklet", cmd: "read", samples: count,
        performance_ms: now(), audio_seconds: node.context.currentTime}, 128);
    });
    node.port.start();
  }
  if (NativeWorkletNode) {
    window.AudioWorkletNode = new Proxy(NativeWorkletNode, {
      construct(target, args, newTarget) {
        const node = Reflect.construct(target, args, newTarget);
        try { observeStream(node, args[1]); }
        catch (err) { error("stream_observer", err); }
        return node;
      }
    });
  }
  for (const name of ["AudioContext", "webkitAudioContext"]) {
    const Constructor = window[name];
    if (!Constructor) continue;
    window[name] = new Proxy(Constructor, {
      construct(target, args, newTarget) {
        const ctx = Reflect.construct(target, args, newTarget);
        try { context(ctx); } catch (err) { error("context_observer", err); }
        return ctx;
      }
    });
  }
  window.MOBILE_AUDIO_PROBE = Object.freeze({
    snapshot() {
      return {
        version: "mobile-web-perf-audio-v1", timestamp: new Date().toISOString(),
        performance_ms: now(), worklet_url: workletURL,
        scope: "Mixed destination graph PCM only; no cue attribution or speaker audibility proof. STREAM branch statistics, when present, identify a separate diagnostic worklet copy.",
        instrumented_worklet: streams.some(row => !!row.underrun_stats),
        installed_before_engine_required: true,
        native_starts_total: startsTotal, native_stops_total: stopsTotal,
        native_created_total: createdTotal, native_ended_total: endedTotal,
        native_created: created.map(row => ({...row})),
        native_ended: ended.map(row => ({...row})), native_stops: stops.map(row => ({...row})),
        native_starts: starts.map(row => ({...row, buffer: row.buffer && {...row.buffer}})),
        contexts: [...contexts.values()].map(row => {
          const ctx = row.ctx;
          let outputTimestamp = null;
          try { outputTimestamp = ctx.getOutputTimestamp?.() || null; } catch (_) {}
          return {id: row.id, state: ctx.state, audio_seconds: ctx.currentTime,
            sample_rate: ctx.sampleRate, base_latency: ctx.baseLatency ?? null,
            output_latency: ctx.outputLatency ?? null, output_timestamp: outputTimestamp,
            state_changes: row.states.map(value => ({...value}))};
        }),
        destinations: [...destinations.values()].map(row => ({
          id: row.id, context_id: row.context_id, status: row.status,
          connected_original_branches: [...connections].filter(e => e.destination === row).length,
          scope: "Sum of observed original direct-destination branches, before hardware output; starts after asynchronous meter attachment.",
          pcm: row.meter && {...row.meter}, history: row.messages.map(value => ({...value}))
        })),
        streams: streams.map(row => ({...row,
          queued_samples_main_thread_estimate: row.mode === "no_threads" ?
            row.sent_samples - row.consumed_samples : null,
          scope: "Main-thread port message accounting; messages may be delayed. Not render-thread ring occupancy.",
          instrumented_worklet: !!row.underrun_stats,
          exact_underrun: row.underrun_stats ? "available_in_underrun_stats_diagnostic_copy_only" :
            "unavailable_without_separately_identified_diagnostic_worklet",
          underrun_stats: row.underrun_stats ? {...row.underrun_stats} : null,
          underrun_history: (row.underrun_history || []).map(value => ({...value})),
          messages: row.messages.map(value => ({...value}))})),
        exact_stream_underrun: streams.some(row => !!row.underrun_stats) ?
          "available_for_instrumented_streams_only" : "unavailable_official_worklet_does_not_report_underflow",
        errors: errors.map(row => ({...row})),
        limits: {starts: 256, contexts: 32, destinations: 16, streams: 16,
          destination_history: 128, stream_history: 128, errors: 32}
      };
    }
  });
})();
