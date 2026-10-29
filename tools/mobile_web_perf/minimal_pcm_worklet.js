/* Two-second opt-in PCM recording for the minimal reproduction only. */
class MinimalPCM extends AudioWorkletProcessor {
  constructor() {
    super();
    this.frames = 0;
    this.blocks = 0;
    this.zeros = 0;
    this.zeroRun = 0;
    this.longestZero = 0;
    this.energy = 0;
    this.samples = 0;
    this.peak = 0;
    this.interval = 0;
    this.recording = null;
    this.port.onmessage = event => {
      if (event.data?.cmd !== "minimal_begin") return;
      const length = Math.min(Math.round(sampleRate * 2), Math.max(128, event.data.frames));
      this.recording = {id: event.data.id, length, written: 0, channels: 2,
        start_frame: null, samples: new Float32Array(length * 2)};
      this.port.postMessage({cmd: "minimal_ready", id: event.data.id});
    };
  }
  process(inputs, outputs) {
    const channels = inputs[0] || [];
    const frames = channels[0]?.length || outputs[0]?.[0]?.length || 128;
    let zero = true;
    for (const channel of channels) for (const value of channel) {
      zero = zero && value === 0;
      this.energy += value * value; this.samples++;
      this.peak = Math.max(this.peak, Math.abs(value));
    }
    this.frames += frames; this.blocks++; this.interval += frames;
    if (zero) { this.zeros++; this.zeroRun += frames; this.longestZero = Math.max(this.longestZero, this.zeroRun); }
    else this.zeroRun = 0;
    const record = this.recording;
    if (record) {
      if (record.start_frame === null) record.start_frame = currentFrame;
      const count = Math.min(frames, record.length - record.written);
      for (let i = 0; i < count; i++) for (let ch = 0; ch < 2; ch++) {
        record.samples[(record.written + i) * 2 + ch] = channels[ch]?.[i] || 0;
      }
      record.written += count;
      if (record.written === record.length) {
        this.port.postMessage({cmd: "minimal_recording", id: record.id,
          sample_rate: sampleRate, channels: 2, frames: record.length,
          start_audio_frame: record.start_frame, end_audio_frame: record.start_frame + record.length,
          samples: record.samples}, [record.samples.buffer]);
        this.recording = null;
      }
    }
    if (this.interval >= sampleRate * 0.1) {
      this.port.postMessage({audio_seconds: currentTime, audio_frame: currentFrame,
        sample_rate: sampleRate, input_channels: channels.length,
        total_frames: this.frames, total_blocks: this.blocks, exact_zero_blocks: this.zeros,
        current_zero_run_ms: this.zeroRun / sampleRate * 1000,
        longest_zero_run_ms: this.longestZero / sampleRate * 1000,
        rms: Math.sqrt(this.energy / Math.max(1, this.samples)), peak: this.peak,
        scope: "Actual observed destination branch sum; no hardware speaker claim."});
      this.interval = 0; this.energy = 0; this.samples = 0; this.peak = 0;
    }
    return true;
  }
}
registerProcessor("mobile-web-perf-pcm", MinimalPCM);
