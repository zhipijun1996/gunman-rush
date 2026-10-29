/* Diagnostic only; load before the engine. No readback, finish(), or blocking wait.
 * Queries are OFF unless MOBILE_GPU_PROBE_ENABLED === true. Capture every
 * MOBILE_GPU_PROBE_CAPTURE_EVERY eligible render callbacks (default30). RAF
 * IDs include non-render callbacks; separate render_frame IDs count callbacks
 * containing tracked, timer-capable draws while enabled.
 * One TIME_ELAPSED query spans first draw -> end of its requestAnimationFrame
 * callback. The interval includes intervening GPU command work and may include
 * GPU idle bubbles caused by CPU submission. It is not pure shader execution.
 * Canvas/drawingBuffer sizes and draw-time viewport are reported separately;
 * a viewport rectangle alone does not prove an attached texture's dimensions.
 */
(function installMobileGpuProbe(root) {
  "use strict";
  if (root.MOBILE_GPU_PROBE) return;
  const LIMIT = 8, SAMPLE_LIMIT = 240, ERROR_LIMIT = 16;
  const contexts = [], states = new WeakMap(), pending = [], frames = [];
  const samples = [], errors = [];
  let nextFrame = 0, nextRenderFrame = 0, activeCount = 0, skippedCapacity = 0;
  let validCount = 0, invalidCount = 0, outsideRafDraws = 0;
  const now = () => root.performance ? root.performance.now() : null;
  const queryEnabled = () => root.MOBILE_GPU_PROBE_ENABLED === true;
  function captureEvery() {
    const value = Number(root.MOBILE_GPU_PROBE_CAPTURE_EVERY);
    return Number.isFinite(value) && value >= 1 ? Math.min(1000000, Math.floor(value)) : 30;
  }
  function boundedPush(list, value, limit) {
    list.push(value);
    if (list.length > limit) list.shift();
  }
  function failure(error) {
    boundedPush(errors, String(error), ERROR_LIMIT);
  }
  function safely(action) {
    try { return action(); } catch (error) { failure(error); return undefined; }
  }
  function parameter(gl, key) {
    return key === undefined ? null : gl.getParameter(key);
  }
  function release(state, query) {
    safely(() => state.native.deleteQuery.call(state.gl, query));
  }
  function invalidate(state, item, reason) {
    invalidCount++;
    state.invalid++;
    state.lastInvalidReason = reason;
    release(state, item.query);
  }
  function disjoint(state) {
    return Boolean(state.gl.getParameter(state.ext.GPU_DISJOINT_EXT));
  }
  function poll() {
    if (!pending.length) return;
    const disjointContexts = new Set();
    const pendingContexts = new Set(pending.map(item => item.state));
    for (const state of pendingContexts) {
      if (!state.ext) continue;
      if (state.gl.isContextLost && state.gl.isContextLost()) {
        disjointContexts.add(state);
        state.enabled = false;
        state.disabledReason = "context_lost";
      } else if (disjoint(state)) disjointContexts.add(state);
    }
    for (const state of disjointContexts) {
      if (state.active) state.active.invalidReason = state.disabledReason === "context_lost" ? "context_lost" : "gpu_disjoint";
    }
    for (let i = pending.length - 1; i >= 0; i--) {
      const item = pending[i], state = item.state, gl = state.gl;
      if (disjointContexts.has(state)) {
        pending.splice(i, 1);
        invalidate(state, item, state.disabledReason === "context_lost" ? "context_lost" : "gpu_disjoint");
        continue;
      }
      if (!state.native.getQueryParameter.call(gl, item.query, gl.QUERY_RESULT_AVAILABLE)) continue;
      const ns = state.native.getQueryParameter.call(gl, item.query, gl.QUERY_RESULT);
      pending.splice(i, 1);
      const gpuDisjoint = disjoint(state);
      if (gpuDisjoint) {
        disjointContexts.add(state);
        if (state.active) state.active.invalidReason = "gpu_disjoint";
      }
      if (typeof ns !== "number" || !Number.isFinite(ns) || ns < 0 || gpuDisjoint) {
        invalidate(state, item, gpuDisjoint ? "gpu_disjoint" : "invalid_query_result");
        continue;
      }
      validCount++;
      state.valid++;
      boundedPush(samples, {
        context: state.id, frame: item.frame, render_frame: item.renderFrame, gpu_ms: ns / 1000000,
        draw_calls: item.drawCalls, draw_viewport: item.viewport,
        framebuffer: item.framebuffer, callback_timestamp: item.timestamp
      }, SAMPLE_LIMIT);
      release(state, item.query);
    }
  }
  function stopOwned(state, reason) {
    const item = state.active;
    if (!item) return;
    // Never end someone else's query if external code has changed GL state.
    const current = state.native.getQuery.call(state.gl, state.ext.TIME_ELAPSED_EXT, state.gl.CURRENT_QUERY);
    if (current === item.query) state.native.endQuery.call(state.gl, state.ext.TIME_ELAPSED_EXT);
    state.active = null;
    activeCount--;
    invalidate(state, item, reason);
  }
  function externalTimer(state) {
    if (!state || !state.ext) return;
    stopOwned(state, "external_timer_query");
    state.enabled = false;
    state.disabledReason = "external_timer_query";
  }
  function beforeDraw(gl) {
    if (!queryEnabled()) return;
    const state = states.get(gl);
    if (!state || !state.enabled) return;
    const frame = frames[frames.length - 1];
    if (!frame) { outsideRafDraws++; return; }
    if (frame.renderNumber === null) {
      frame.renderNumber = ++nextRenderFrame;
      frame.captureEligible = frame.renderNumber % captureEvery() === 0;
    }
    if (!frame.captureEligible) return;
    if (state.active) { state.active.drawCalls++; return; }
    if (state.lastFrame === frame.id) return;
    if (pending.length + activeCount >= LIMIT) { skippedCapacity++; return; }
    if (gl.isContextLost && gl.isContextLost()) return;
    if (disjoint(state)) return;
    if (state.native.getQuery.call(gl, state.ext.TIME_ELAPSED_EXT, gl.CURRENT_QUERY)) {
      externalTimer(state);
      return;
    }
    state.lastFrame = frame.id;
    const query = state.native.createQuery.call(gl);
    if (!query) return;
    const viewport = Array.from(gl.getParameter(gl.VIEWPORT));
    const framebuffer = gl.getParameter(gl.FRAMEBUFFER_BINDING) === null ? "default" : "offscreen";
    state.native.beginQuery.call(gl, state.ext.TIME_ELAPSED_EXT, query);
    if (state.native.getQuery.call(gl, state.ext.TIME_ELAPSED_EXT, gl.CURRENT_QUERY) !== query) {
      invalidate(state, {query}, "begin_query_rejected");
      return;
    }
    const item = {state, query, frame: frame.id, renderFrame: frame.renderNumber, timestamp: frame.timestamp,
      drawCalls: 1, viewport, framebuffer, invalidReason: null};
    state.active = item;
    activeCount++;
    frame.started.push(state);
  }
  function endFrame(frame) {
    for (const state of frame.started) {
      const item = state.active;
      if (!item || item.frame !== frame.id) continue;
      const current = state.native.getQuery.call(state.gl, state.ext.TIME_ELAPSED_EXT, state.gl.CURRENT_QUERY);
      if (current !== item.query) { stopOwned(state, "query_ownership_changed"); continue; }
      state.native.endQuery.call(state.gl, state.ext.TIME_ELAPSED_EXT);
      state.active = null;
      activeCount--;
      if (item.invalidReason || disjoint(state)) invalidate(state, item, item.invalidReason || "gpu_disjoint");
      else pending.push(item);
    }
  }
  function register(gl) {
    if (!gl || states.has(gl) || contexts.length >= LIMIT) return;
    const native = {};
    for (const name of ["beginQuery", "endQuery", "getQuery", "createQuery", "deleteQuery", "getQueryParameter"]) {
      native[name] = originals[name] || gl[name];
    }
    const ext = gl.getExtension("EXT_disjoint_timer_query_webgl2");
    const debug = gl.getExtension("WEBGL_debug_renderer_info");
    const state = {gl, native, ext, id: contexts.length + 1, enabled: Boolean(ext),
      disabledReason: ext ? null : "extension_unavailable", active: null,
      lastFrame: -1, valid: 0, invalid: 0, lastInvalidReason: null,
      renderer: parameter(gl, debug ? debug.UNMASKED_RENDERER_WEBGL : gl.RENDERER),
      vendor: parameter(gl, debug ? debug.UNMASKED_VENDOR_WEBGL : gl.VENDOR)};
    states.set(gl, state);
    contexts.push(state);
  }
  function wrapMethod(prototype, name, makeWrapper) {
    if (!prototype) return;
    const descriptor = Object.getOwnPropertyDescriptor(prototype, name);
    if (!descriptor || typeof descriptor.value !== "function") return;
    Object.defineProperty(prototype, name, {...descriptor, value: makeWrapper(descriptor.value)});
  }
  const originals = {};
  const glPrototype = root.WebGL2RenderingContext && root.WebGL2RenderingContext.prototype;
  if (glPrototype) {
    for (const name of ["beginQuery", "endQuery", "getQuery", "createQuery", "deleteQuery", "getQueryParameter"]) originals[name] = glPrototype[name];
    for (const name of ["drawArrays", "drawElements", "drawArraysInstanced", "drawElementsInstanced", "drawRangeElements"]) {
      safely(() => wrapMethod(glPrototype, name, original => function () {
        if (queryEnabled()) safely(() => beforeDraw(this));
        return original.apply(this, arguments);
      }));
    }
    for (const name of ["beginQuery", "endQuery"]) {
      safely(() => wrapMethod(glPrototype, name, original => function (target) {
        const state = states.get(this);
        if (state && state.ext && target === state.ext.TIME_ELAPSED_EXT) safely(() => externalTimer(state));
        return original.apply(this, arguments);
      }));
    }
  }
  for (const constructor of [root.HTMLCanvasElement, root.OffscreenCanvas]) {
    safely(() => wrapMethod(constructor && constructor.prototype, "getContext", original => function (type) {
      const gl = original.apply(this, arguments);
      if (type === "webgl2" || type === "experimental-webgl2") safely(() => register(gl));
      return gl;
    }));
  }
  const nativeRaf = root.requestAnimationFrame;
  if (typeof nativeRaf === "function") {
    root.requestAnimationFrame = function (callback) {
      if (typeof callback !== "function") return nativeRaf.apply(this, arguments);
      const args = Array.from(arguments);
      args[0] = function (timestamp) {
        const id = ++nextFrame;
        // Default/off path has no GL inspection, query calls, or frame arrays.
        // Pending queries still drain safely after collection is switched off.
        if (!queryEnabled() && !pending.length && !activeCount) return callback.apply(this, arguments);
        const frame = {id, timestamp, started: [], renderNumber: null, captureEligible: false};
        safely(poll);
        frames.push(frame);
        try { return callback.apply(this, arguments); }
        finally {
          safely(() => endFrame(frame));
          frames.pop();
          safely(poll);
        }
      };
      return nativeRaf.apply(this, args);
    };
  }
  function percentile(sorted, p) {
    return sorted.length ? sorted[Math.ceil(p * sorted.length) - 1] : null;
  }
  root.MOBILE_GPU_PROBE = Object.freeze({snapshot() {
    safely(poll);
    const values = samples.map(sample => sample.gpu_ms).sort((a, b) => a - b);
    return {
      version: "mobile-gpu-probe-v2", sampled_at: now(),
      query_enabled: queryEnabled(), capture_every: captureEvery(),
      capture_basis: "every Nth eligible render callback; frame IDs include all RAF callbacks, render_frame IDs count timer-capable draw callbacks while enabled",
      raf_callbacks_total: nextFrame, render_callbacks_total: nextRenderFrame,
      scope: "first draw through RAF callback finally; GPU command interval including possible CPU-submission idle bubbles, not pure shader time",
      exact_gpu_available: contexts.some(state => state.ext && state.enabled),
      gpu_ms_p50: percentile(values, 0.5), gpu_ms_p95: percentile(values, 0.95),
      gpu_ms_mean: values.length ? values.reduce((a, b) => a + b, 0) / values.length : null,
      valid_samples_total: validCount, invalid_samples_total: invalidCount,
      pending: pending.length, active: activeCount, pending_limit: LIMIT,
      samples_limit: SAMPLE_LIMIT, skipped_capacity: skippedCapacity,
      draws_outside_raf: outsideRafDraws, errors: errors.slice(),
      contexts: contexts.map(state => ({
        id: state.id, extension: state.ext ? "EXT_disjoint_timer_query_webgl2" : null,
        enabled: state.enabled, query_enabled: queryEnabled() && state.enabled, disabled_reason: state.disabledReason,
        renderer: state.renderer, vendor: state.vendor,
        canvas_backing: state.gl.canvas ? [state.gl.canvas.width, state.gl.canvas.height] : null,
        drawing_buffer: [state.gl.drawingBufferWidth, state.gl.drawingBufferHeight],
        valid_samples: state.valid, invalid_samples: state.invalid,
        last_invalid_reason: state.lastInvalidReason
      })), samples: samples.map(sample => ({...sample, draw_viewport: sample.draw_viewport.slice()}))
    };
  }});
})(typeof window !== "undefined" ? window : globalThis);
