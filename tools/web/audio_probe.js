/* Read-only diagnostic fan-out. Leaves the game's destination connection intact. */
(() => {
  window.PLAINS_AUDIO_PROBE = {connections: 0, samples: 0, peak: 0, contexts: []};
  const nativeConnect = AudioNode.prototype.connect;
  AudioNode.prototype.connect = function (...args) {
    const result = nativeConnect.apply(this, args);
    if (args[0] instanceof AudioDestinationNode && !this.__plainsAudioProbe) {
      this.__plainsAudioProbe = true;
      const analyser = this.context.createAnalyser();
      analyser.fftSize = 2048;
      nativeConnect.call(this, analyser);
      const data = new Float32Array(analyser.fftSize);
      const probe = window.PLAINS_AUDIO_PROBE;
      probe.connections++;
      probe.contexts.push(this.context);
      function sample() {
        analyser.getFloatTimeDomainData(data);
        probe.samples++;
        for (const value of data) probe.peak = Math.max(probe.peak, Math.abs(value));
        requestAnimationFrame(sample);
      }
      requestAnimationFrame(sample);
    }
    return result;
  };
})();
