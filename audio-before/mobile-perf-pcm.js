/* Independent meter. It never receives or modifies the official stream ring. */
class MobileWebPerfPCM extends AudioWorkletProcessor {
  constructor(options) {
    super();
    this.reportFrames = Math.max(128, sampleRate *
      (options.processorOptions?.report_seconds || 0.1));
    this.totalFrames = 0;
    this.totalBlocks = 0;
    this.zeroBlocks = 0;
    this.zeroRunFrames = 0;
    this.longestZeroFrames = 0;
    this.intervalFrames = 0;
    this.energy = 0;
    this.samples = 0;
    this.peak = 0;
    this.clipSamples = 0;
  }
  process(inputs, outputs) {
    const channels = inputs[0] || [];
    const frames = channels[0]?.length || outputs[0]?.[0]?.length || 128;
    let zero = true;
    for (const channel of channels) {
      for (const value of channel) {
        const absolute = Math.abs(value);
        if (value !== 0) zero = false;
        this.energy += value * value;
        this.samples++;
        this.peak = Math.max(this.peak, absolute);
        if (absolute >= 1) this.clipSamples++;
      }
    }
    this.totalBlocks++;
    this.totalFrames += frames;
    this.intervalFrames += frames;
    if (zero) {
      this.zeroBlocks++;
      this.zeroRunFrames += frames;
      this.longestZeroFrames = Math.max(this.longestZeroFrames, this.zeroRunFrames);
    } else this.zeroRunFrames = 0;
    // Outputs remain zero. A zero-gain sink keeps this branch scheduled.
    if (this.intervalFrames >= this.reportFrames) {
      this.port.postMessage({
        audio_seconds: currentTime, audio_frame: currentFrame,
        quantum_end_seconds: (currentFrame + frames) / sampleRate,
        sample_rate: sampleRate, input_channels: channels.length,
        total_frames: this.totalFrames, total_blocks: this.totalBlocks,
        exact_zero_blocks: this.zeroBlocks, exact_zero_threshold: 0,
        current_zero_run_ms: this.zeroRunFrames / sampleRate * 1000,
        longest_zero_run_ms: this.longestZeroFrames / sampleRate * 1000,
        interval_frames: this.intervalFrames,
        rms: Math.sqrt(this.energy / Math.max(1, this.samples)),
        peak: this.peak, clipping_samples: this.clipSamples,
        scope: "Mixed observed destination PCM; exact-zero blocks include intentional silence and are not underrun counts."
      });
      this.intervalFrames = 0;
      this.energy = 0;
      this.samples = 0;
      this.peak = 0;
      this.clipSamples = 0;
    }
    return true;
  }
}
registerProcessor("mobile-web-perf-pcm", MobileWebPerfPCM);
