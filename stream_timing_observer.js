/* Install before the separately instrumented engine. No audio graph changes. */
(() => {
  "use strict";
  if (globalThis.MOBILE_STREAM_TIMING) return;
  const LIMIT = 256, PENDING_LIMIT = 64, RAF_LIMIT = 1024;
  const rows = [], raf = [], longTasks = [], pending = new Map();
  const contextIDs = new WeakMap(), streamIDs = new WeakMap(), contexts = new Map();
  let nextContext = 0, nextStream = 0, begun = 0, acknowledged = 0;
  let pendingEvicted = 0, unmatched = 0, rafCount = 0, longTaskCount = 0;
  const push = (array, value, limit = LIMIT) => {
    array.push(value);
    if (array.length > limit) array.splice(0, array.length - limit);
  };
  const now = () => performance.now();
  const key = row => `${row.stream_id}:${row.seq}`;
  function rememberContext(ctx) {
    if (!contextIDs.has(ctx)) contextIDs.set(ctx, ++nextContext);
    const id = contextIDs.get(ctx);
    contexts.set(id, {id, sample_rate: ctx.sampleRate, state: ctx.state,
      audio_seconds: ctx.currentTime, base_latency: ctx.baseLatency ?? null,
      output_latency: ctx.outputLatency ?? null});
    while (contexts.size > 16) contexts.delete(contexts.keys().next().value);
    return id;
  }
  function begin(meta, ctx, node) {
    if (!meta || meta.version !== 1 || !Number.isSafeInteger(meta.seq) ||
        meta.seq < 1 || meta.seq % 32 !== 1 || !Number.isFinite(meta.request_frame) ||
        !(meta.sample_rate > 0)) return null;
    if (!streamIDs.has(node)) streamIDs.set(node, ++nextStream);
    const row = {...meta, stream_id: streamIDs.get(node), context_id: rememberContext(ctx),
      main_receive_ms: now(), main_receive_audio_s: ctx.currentTime};
    begun++;
    if (pending.size >= PENDING_LIMIT) {
      pending.delete(pending.keys().next().value);
      pendingEvicted++;
    }
    pending.set(key(row), row);
    return row;
  }
  function mark(row, stage, ctx) {
    row[stage + "_ms"] = now();
    row[stage + "_audio_s"] = ctx.currentTime;
  }
  function ack(meta, ctx, node) {
    if (!meta || meta.version !== 1 || !Number.isSafeInteger(meta.seq)) return;
    const streamID = streamIDs.get(node);
    if (streamID !== meta.stream_id) { unmatched++; return; }
    const id = key(meta), start = pending.get(id);
    if (!start) { unmatched++; return; }
    pending.delete(id);
    const row = {...meta, ...start,
      chunk_receive_frame: meta.chunk_receive_frame,
      chunk_receive_sample_rate: meta.chunk_receive_sample_rate,
      chunk_ring_before_samples: meta.chunk_ring_before_samples,
      chunk_ring_after_samples: meta.chunk_ring_after_samples,
      chunk_write_succeeded: meta.chunk_write_succeeded,
      ack_main_receive_ms: now(), ack_main_receive_audio_s: ctx.currentTime};
    row.roundtrip_audio_ms = 1000 *
      (row.chunk_receive_frame / row.chunk_receive_sample_rate - row.request_frame / row.sample_rate);
    row.worklet_to_main_ms_estimate = 1000 *
      (row.main_receive_audio_s - row.request_frame / row.sample_rate);
    row.request_main_ms_estimate = row.main_receive_ms - row.worklet_to_main_ms_estimate;
    row.mix_sync_ms = row.mix_end_ms - row.mix_start_ms;
    row.chunk_post_ms = row.chunk_post_end_ms - row.chunk_post_start_ms;
    row.main_receive_to_post_ms = row.chunk_post_start_ms - row.main_receive_ms;
    row.post_to_worklet_ms_estimate = 1000 *
      (row.chunk_receive_frame / row.chunk_receive_sample_rate - row.chunk_post_start_audio_s);
    acknowledged++;
    push(rows, row);
    rememberContext(ctx);
  }
  const nativeRAF = globalThis.requestAnimationFrame;
  if (typeof nativeRAF === "function") {
    globalThis.requestAnimationFrame = function (callback) {
      // Invalid callbacks retain the native validation/exception path.
      if (typeof callback !== "function") return nativeRAF.apply(this, arguments);
      return nativeRAF.call(this, function () {
        const start = now();
        try { return callback.apply(this, arguments); }
        finally {
          try {
            const end = now(); rafCount++;
            push(raf, {start_ms: start, end_ms: end, duration_ms: end - start,
              timestamp_ms: arguments[0]}, RAF_LIMIT);
          } catch (_) { /* Observing must not replace a callback exception. */ }
        }
      });
    };
  }
  let longTaskStatus = "unsupported", observer = null;
  if (typeof PerformanceObserver === "function") {
    try {
      observer = new PerformanceObserver(list => {
        for (const entry of list.getEntries()) {
          if (entry.entryType !== "longtask") continue;
          longTaskCount++;
          push(longTasks, {start_ms: entry.startTime, duration_ms: entry.duration,
            end_ms: entry.startTime + entry.duration, name: entry.name}, 128);
        }
      });
      observer.observe({type: "longtask", buffered: true});
      longTaskStatus = "observing";
    } catch (_) { longTaskStatus = "unavailable"; }
  }
  function summary(array, field) {
    const values = array.map(row => row[field]).filter(Number.isFinite).sort((a, b) => a - b);
    const percentile = q => values.length ? values[Math.ceil(values.length * q) - 1] : null;
    return {retained_count: values.length, p50: percentile(0.5), p95: percentile(0.95),
      max: values.length ? values[values.length - 1] : null};
  }
  globalThis.MOBILE_STREAM_TIMING = Object.freeze({
    begin, mark, ack,
    snapshot() {
      const retained = rows.map(row => {
        const start = row.main_receive_ms, end = row.chunk_post_end_ms;
        return {...row,
          request_to_main_raf_overlaps_estimate: raf.filter(r =>
            r.end_ms >= row.request_main_ms_estimate && r.start_ms <= start).length,
          request_to_main_long_task_overlaps_estimate: longTasks.filter(r =>
            r.end_ms >= row.request_main_ms_estimate && r.start_ms <= start).length,
          raf_overlaps: raf.filter(r => r.end_ms >= start && r.start_ms <= end).length,
          long_task_overlaps: longTasks.filter(r => r.end_ms >= start && r.start_ms <= end).length};
      });
      return {version: "stream-timing-v1", sample_every_successful_read: 32,
        performance_ms: now(), begun, acknowledged, unmatched_acks: unmatched,
        pending_evicted: pendingEvicted, rows: retained,
        pending: [...pending.values()].map(row => ({...row})),
        contexts: [...contexts.values()].map(row => ({...row})),
        summaries_ms: Object.fromEntries(["roundtrip_audio_ms", "worklet_to_main_ms_estimate",
          "mix_sync_ms", "chunk_post_ms", "main_receive_to_post_ms", "post_to_worklet_ms_estimate"]
          .map(field => [field, summary(rows, field)])),
        raf: {callbacks_total: rafCount, rows: raf.map(row => ({...row})),
          retained_start_ms: raf[0]?.start_ms ?? null,
          retained_end_ms: raf[raf.length - 1]?.end_ms ?? null,
          duration_ms: summary(raf, "duration_ms")},
        long_tasks: {status: longTaskStatus, total: longTaskCount,
          retained_start_ms: longTasks[0]?.start_ms ?? null,
          retained_end_ms: longTasks[longTasks.length - 1]?.end_ms ?? null,
          rows: longTasks.map(row => ({...row}))},
        limits: {rows: LIMIT, pending: PENDING_LIMIT, raf: RAF_LIMIT, long_tasks: 128, contexts: 16},
        scope: "Separate diagnostic JS/worklet. Audio-frame roundtrip is worklet read request to actual chunk arrival. Main timestamps use performance.now; AudioContext comparisons are estimates with render-quantum/timestamp quantization and may be negative. Synchronous out_callback includes WASM mixing/decoding; it cannot isolate decoding. RAF callback envelopes include synchronous submission, not GPU execution. Overlap counts cover retained intervals only; a blocked request may precede main_receive and must also be compared with preceding RAF/LongTask intervals. No PCM, gain, queue, scheduling or graph changes; no hardware-speaker or phone-performance claim."};
    }
  });
})();
