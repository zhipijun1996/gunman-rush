(() => {
  const contexts = new Map(), taps = new WeakSet();
  const originalConnect = AudioNode.prototype.connect;
  AudioNode.prototype.connect = function (...args) {
    const result = originalConnect.apply(this, args);
    if (args[0] instanceof AudioDestinationNode && !taps.has(this)) {
      const context = this.context;
      if (!contexts.has(context)) {
        const analyser = context.createAnalyser(); analyser.fftSize = 2048;
        // A consumed recording sink pulls the analyser without a zero-gain
        // optimization and without sending a second signal to the speakers.
        const sink = context.createMediaStreamDestination();
        taps.add(analyser); taps.add(sink);
        originalConnect.call(analyser, sink);
        const recorder = new MediaRecorder(sink.stream); const chunks = [];
        const row = {analyser, sink, recorder, chunks, bytes: 0,
          states: [{state: context.state, time: performance.now()}]};
        recorder.ondataavailable = event => { row.bytes += event.data.size; row.chunks.push(event.data); };
        contexts.set(context, row);
        recorder.start(500);
        context.addEventListener('statechange', () => row.states.push({state: context.state, time: performance.now()}));
      }
      originalConnect.call(this, contexts.get(context).analyser);
    }
    return result;
  };
  window.__feedbackStopRecordings = async () => {
    const results=[];
    for (const [context,row] of contexts) {
      await new Promise(resolve => {row.recorder.addEventListener('stop',resolve,{once:true});row.recorder.stop();});
      const blob=new Blob(row.chunks,{type:row.recorder.mimeType});
      const encoded=await new Promise(resolve=>{const r=new FileReader();r.onload=()=>resolve(r.result);r.readAsDataURL(blob);});
      results.push({sample_rate:context.sampleRate,mime:row.recorder.mimeType,bytes:blob.size,data:encoded.split(',')[1]});
    } return results;
  };
  Object.defineProperty(window, '__fourLineNativeAudio', {value: () => Array.from(contexts, ([context, row]) => {
    const samples = new Float32Array(row.analyser.fftSize);
    row.analyser.getFloatTimeDomainData(samples);
    let square = 0, peak = 0;
    for (const value of samples) { square += value * value; peak = Math.max(peak, Math.abs(value)); }
    return {state: context.state, current_time: context.currentTime, sample_rate: context.sampleRate,
      rms: Math.sqrt(square / samples.length), peak, states: row.states,
      recording_state: row.recorder.state, captured_bytes: row.bytes};
  })});
})();
