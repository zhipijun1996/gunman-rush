(() => {
  "use strict";
  const records = [], errors = [];
  const Native = window.AudioWorkletNode;
  function shared(view) {
    return typeof SharedArrayBuffer !== "undefined" && ArrayBuffer.isView(view) &&
      view.buffer instanceof SharedArrayBuffer;
  }
  function describe(view) {
    return {type: Object.prototype.toString.call(view), shared: shared(view),
      byte_length: Number(view?.byteLength || 0), length: Number(view?.length || 0)};
  }
  window.AudioWorkletNode = new Proxy(Native, {
    construct(target, args, newTarget) {
      const node = Reflect.construct(target, args, newTarget);
      if (args[1] !== "godot-processor") return node;
      const post = node.port.postMessage;
      node.port.postMessage = function (...messages) {
        const result = post.apply(this, messages);
        try {
          const message = messages[0];
          if (message?.cmd === "start" || message?.cmd === "start_nothreads") {
            records.push({cmd: message.cmd, threads: message.cmd === "start",
              performance_ms: performance.now(), audio_seconds: node.context.currentTime,
              views: Array.isArray(message.data) ? message.data.map(describe) : [],
              shared_ring_observed: message.cmd === "start" &&
                message.data?.length === 3 && message.data.every(shared)});
            if (records.length > 16) records.shift();
          }
        } catch (err) {
          errors.push(String(err?.name || "Error"));
          if (errors.length > 16) errors.shift();
        }
        return result;
      };
      return node;
    }
  });
  window.MOBILE_THREADED_DIAGNOSTIC = Object.freeze({snapshot() {
    const audio = window.MOBILE_AUDIO_PROBE.snapshot();
    return {version: "official-threaded-audio-v1", timestamp: new Date().toISOString(),
      cross_origin_isolated: window.crossOriginIsolated === true,
      shared_array_buffer_available: typeof SharedArrayBuffer !== "undefined",
      controller_script: navigator.serviceWorker?.controller?.scriptURL || null,
      expected_service_worker_scope: new URL("./", location.href).href,
      threads: records.some(row => row.threads),
      shared_ring_observed: records.some(row => row.shared_ring_observed),
      start_messages: records.map(row => ({...row, views: row.views.map(v => ({...v}))})),
      observer_errors: errors.slice(), audio,
      timing: window.MOBILE_STREAM_TIMING?.snapshot() || null,
      timing_mode: "raf_and_longtask_only_no_threaded_audio_callback_hooks",
      selected_sfx: window.SELECTED_SFX_SNAPSHOT || null,
      selected_ambience: window.SELECTED_AMBIENCE_SNAPSHOT || null,
      scope: "Diagnostic threaded official engine; separate counter-only worklet. Mixed destination PCM is not cue attribution or speaker/phone acceptance."};
  }});
})();
