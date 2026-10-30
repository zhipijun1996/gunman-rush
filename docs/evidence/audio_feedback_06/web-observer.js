(() => {
  const contexts=new Map(), taps=new WeakSet(), connect=AudioNode.prototype.connect;
  AudioNode.prototype.connect=function(...args){
    if(args[0] instanceof AudioDestinationNode && !taps.has(this)){
      const context=this.context;
      if(!contexts.has(context)){
        const analyser=context.createAnalyser();analyser.fftSize=2048;taps.add(analyser);
        connect.call(analyser,args[0]);
        const row={analyser,states:[{state:context.state,time:performance.now()}]};
        contexts.set(context,row);context.addEventListener('statechange',()=>row.states.push({state:context.state,time:performance.now()}));
      }
      return connect.call(this,contexts.get(context).analyser,...args.slice(1));
    }
    return connect.apply(this,args);
  };
  window.__fourLineNativeAudio=()=>Array.from(contexts,([context,row])=>{
    const a=new Float32Array(row.analyser.fftSize);row.analyser.getFloatTimeDomainData(a);
    let sum=0,peak=0;for(const v of a){sum+=v*v;peak=Math.max(peak,Math.abs(v));}
    return {state:context.state,current_time:context.currentTime,sample_rate:context.sampleRate,rms:Math.sqrt(sum/a.length),peak,states:row.states};
  });
})();