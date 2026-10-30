#!/usr/bin/env python3
"""Make a separately identified STREAM diagnostic copy; never rewrite the source.

Usage: python3 tools/mobile_web_perf/instrument_worklet.py OFFICIAL DIAGNOSTIC --self-test
The stdout JSON identifies both files. Unknown official bytes fail closed.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile


OFFICIAL_SHA256 = "5b476a9c9ce642c0ee4256436d1bc31d9c38f868aca0f9a8e2a57c18d2dec2a3"
COMMAND = "mobile_perf_stream_stats"
SCOPE = (
    "Separate diagnostic worklet copy: counters only in ready output read/underflow "
    "branches. Original samples, ring reads/writes, notifications and original port "
    "messages unchanged. Added statistics are not part of the official baseline."
)

METHOD = """
	_mobile_perf_record_stream(output, chunk, available, did_read) {
		const frames = output[0].length;
		const end_frame = currentFrame + frames;
		if (!this._mobile_perf_stream_stats) {
			this._mobile_perf_stream_stats = {
				instrumented_worklet: true,
				diagnostic_version: 'mobile-perf-stream-v1',
				official_source_sha256: '__SOURCE_SHA__',
				sample_rate: sampleRate,
				threads: this.threads,
				first_sample_frame: currentFrame,
				last_sample_frame: currentFrame,
				observed_audio_end_frame: end_frame,
				channels: output.length,
				total_requested_frames: 0, total_requested_blocks: 0,
				read_frames: 0, read_blocks: 0,
				underrun_frames: 0, underrun_blocks: 0,
				total_requested_samples: 0, read_samples: 0, underrun_samples: 0,
				buffer_samples_min: available, buffer_samples_max: available,
				consecutive_underrun_frames: 0, longest_underrun_frames: 0
			};
			this._mobile_perf_next_report_frame = currentFrame + Math.ceil(sampleRate * 0.25);
		}
		const stats = this._mobile_perf_stream_stats;
		stats.last_sample_frame = currentFrame;
		stats.observed_audio_end_frame = end_frame;
		stats.channels = output.length;
		stats.threads = this.threads;
		stats.total_requested_frames += frames;
		stats.total_requested_blocks += 1;
		stats.total_requested_samples += chunk;
		stats.buffer_samples_min = Math.min(stats.buffer_samples_min, available);
		stats.buffer_samples_max = Math.max(stats.buffer_samples_max, available);
		if (did_read) {
			stats.read_frames += frames;
			stats.read_blocks += 1;
			stats.read_samples += chunk;
			stats.consecutive_underrun_frames = 0;
		} else {
			stats.underrun_frames += frames;
			stats.underrun_blocks += 1;
			stats.underrun_samples += chunk;
			stats.consecutive_underrun_frames += frames;
			stats.longest_underrun_frames = Math.max(stats.longest_underrun_frames, stats.consecutive_underrun_frames);
		}
		if (end_frame >= this._mobile_perf_next_report_frame) {
			this.port.postMessage({ cmd: 'mobile_perf_stream_stats', data: { ...stats } });
			this._mobile_perf_next_report_frame = end_frame + Math.ceil(sampleRate * 0.25);
		}
	}
""".replace("__SOURCE_SHA__", OFFICIAL_SHA256)


def diagnostic_bytes(raw: bytes) -> bytes:
    digest = hashlib.sha256(raw).hexdigest()
    if digest != OFFICIAL_SHA256:
        raise ValueError(f"Unsupported official source SHA256: {digest}; expected {OFFICIAL_SHA256}")
    source = raw.decode("utf-8")
    replacements = [
        ("\n\tprocess_notify() {", METHOD + "\n\tprocess_notify() {"),
        (
            "\t\t\tif (this.output.data_left() >= chunk) {\n\t\t\t\tthis.output.read(this.output_buffer);",
            "\t\t\tconst mobile_perf_available_samples = this.output.data_left();\n"
            "\t\t\tif (mobile_perf_available_samples >= chunk) {\n"
            "\t\t\t\tthis._mobile_perf_record_stream(output, chunk, mobile_perf_available_samples, true);\n"
            "\t\t\t\tthis.output.read(this.output_buffer);",
        ),
        (
            "\t\t\t\t// this.port.postMessage('Output buffer has not enough frames! Skipping output frame.');",
            "\t\t\t\tthis._mobile_perf_record_stream(output, chunk, mobile_perf_available_samples, false);\n"
            "\t\t\t\t// this.port.postMessage('Output buffer has not enough frames! Skipping output frame.');",
        ),
    ]
    if COMMAND in source or "_mobile_perf_" in source:
        raise ValueError("Official source unexpectedly already contains instrumentation")
    for needle, _ in replacements:
        if source.count(needle) != 1:
            raise ValueError("Official source replacement guard is not unique")
    for needle, replacement in replacements:
        source = source.replace(needle, replacement, 1)
    # Prove the source outside the three exact insertions remains byte-identical.
    restored = source
    for needle, replacement in reversed(replacements):
        if restored.count(replacement) != 1:
            raise ValueError("Diagnostic reverse-replacement guard is not unique")
        restored = restored.replace(replacement, needle, 1)
    if restored.encode("utf-8") != raw:
        raise ValueError("Diagnostic touched bytes outside the guarded insertions")
    return source.encode("utf-8")


MOCK_TEST = r"""
const fs = require('fs'), vm = require('vm'), assert = require('assert');
const original = fs.readFileSync(process.argv[1], 'utf8');
const diagnostic = fs.readFileSync(process.argv[2], 'utf8');
const command = 'mobile_perf_stream_stats';
function normalize(value) {
  if (ArrayBuffer.isView(value)) return Array.from(value);
  if (Array.isArray(value)) return value.map(normalize);
  if (value && typeof value === 'object') return Object.fromEntries(
    Object.entries(value).map(([key, item]) => [key, normalize(item)]));
  return value;
}
function setup(text) {
  let Processor;
  const sandbox = {
    sampleRate: 1024, currentFrame: 0, currentTime: 0,
    AudioWorkletProcessor: class {
      constructor() { this.messages = []; this.port = {
        postMessage: value => this.messages.push(normalize(value))
      }; }
    },
    registerProcessor(name, type) { assert.equal(name, 'godot-processor'); Processor = type; }
  };
  vm.createContext(sandbox); vm.runInContext(text, sandbox);
  return {sandbox, processor: new Processor()};
}
const cases = [
  {name: 'not_ready', ready: false, channels: 2},
  {name: 'stopped', stopped: true, channels: 2},
  {name: 'no_output', channels: 2, emptyOutput: true},
  {name: 'zero_available', channels: 2, available: 0},
  ...[false, true].flatMap(threads => [1, 2].flatMap(channels => [
    {name: `${threads ? 'thread' : 'nothread'}_${channels}_short`, threads, channels,
      available: 128 * channels - 1},
    {name: `${threads ? 'thread' : 'nothread'}_${channels}_read_refill`, threads, channels,
      available: 128 * channels, refill: true}
  ])),
  {name: 'nothread_input_passthrough', channels: 2, available: 256, input: true, refill: true},
  {name: 'thread_input_passthrough', threads: true, channels: 2, available: 256, input: true, refill: true}
];
for (const scenario of cases) {
  const pairs = [setup(original), setup(diagnostic)];
  const capacity = 128 * scenario.channels * 4;
  for (const run of pairs) {
    const p = run.processor;
    if (scenario.ready === false) continue;
    const buffer = Float32Array.from({length: capacity}, (_, i) => (i % 29 - 14) / 32);
    if (scenario.threads) {
      const state = new Int32Array(new SharedArrayBuffer(16));
      state[3] = scenario.available ?? 0;
      p.parse_message('start', [state, new Float32Array(capacity), buffer]);
      run.state = state;
    } else {
      p.parse_message('start_nothreads', [buffer]);
      p.output.avail = scenario.available ?? 0;
    }
    if (scenario.stopped) p.parse_message('stop');
  }
  let expectedBlocks = 0, expectedRead = 0, expectedUnder = 0;
  let expectedConsecutive = 0, expectedLongest = 0;
  const availableObservations = [];
  for (let step = 0; step < 12; step++) {
    const frames = 128;
    const reference = pairs[0].processor;
    const active = reference.running && reference.output !== null && !scenario.emptyOutput;
    if (active) {
      expectedBlocks++;
      const available = reference.output.data_left();
      availableObservations.push(available);
      if (available >= frames * scenario.channels) {
        expectedRead++;
        expectedConsecutive = 0;
      } else {
        expectedUnder++;
        expectedConsecutive += frames;
        expectedLongest = Math.max(expectedLongest, expectedConsecutive);
      }
    }
    const traces = [];
    for (const run of pairs) {
      run.sandbox.currentFrame = step * frames;
      run.sandbox.currentTime = step * frames / run.sandbox.sampleRate;
      const outputs = scenario.emptyOutput ? [] : [Array.from(
        {length: scenario.channels}, () => new Float32Array(frames))];
      const inputs = scenario.input ? [[new Float32Array(frames).fill(0.25)]] : [];
      const result = run.processor.process(inputs, outputs, {});
      traces.push({result, outputs: normalize(outputs),
        messages: run.processor.messages.filter(m => m.cmd !== command),
        outputAvail: run.processor.output?.data_left() ?? null,
        state: run.state ? Array.from(run.state) : null});
    }
    assert.deepStrictEqual(traces[1], traces[0], scenario.name + ': output/read/input/notify equivalence step' + step);
    if (scenario.refill && step % 3 === 1) {
      const chunk = new Float32Array(frames * scenario.channels).fill(0.375);
      for (const run of pairs) run.processor.parse_message('chunk', chunk);
    }
  }
  const p = pairs[1].processor;
  const stats = p._mobile_perf_stream_stats;
  if (!expectedBlocks) {
    assert.equal(stats, undefined, scenario.name + ': nonready/notoutput/stopped must not count');
    assert.equal(p.messages.filter(m => m.cmd === command).length, 0);
  } else {
    assert.equal(stats.total_requested_blocks, expectedBlocks);
    assert.equal(stats.total_requested_frames, expectedBlocks * 128);
    assert.equal(stats.read_blocks, expectedRead);
    assert.equal(stats.underrun_blocks, expectedUnder);
    assert.equal(stats.read_frames, expectedRead * 128);
    assert.equal(stats.underrun_frames, expectedUnder * 128);
    assert.equal(stats.buffer_samples_min, Math.min(...availableObservations));
    assert.equal(stats.buffer_samples_max, Math.max(...availableObservations));
    assert.equal(stats.consecutive_underrun_frames, expectedConsecutive);
    assert.equal(stats.longest_underrun_frames, expectedLongest);
    assert.equal(stats.total_requested_samples, expectedBlocks * 128 * scenario.channels);
    assert.equal(stats.total_requested_frames, stats.read_frames + stats.underrun_frames);
    assert.equal(stats.sample_rate, 1024); assert.equal(stats.threads, !!scenario.threads);
    assert.equal(stats.last_sample_frame, 11 * 128);
    assert.equal(stats.observed_audio_end_frame, 12 * 128);
    const messages = p.messages.filter(m => m.cmd === command);
    assert.equal(messages.length, 6, 'quarter-second cadence');
    for (const message of messages) {
      assert.equal(message.data.instrumented_worklet, true);
      assert.equal(message.data.total_requested_frames,
        message.data.read_frames + message.data.underrun_frames);
      assert.doesNotThrow(() => JSON.stringify(message));
    }
    assert.notEqual(messages[0].data.total_requested_blocks, messages.at(-1).data.total_requested_blocks,
      'posted counter snapshots must not alias the mutable counter object');
  }
  console.log('PASS: ' + scenario.name);
}
console.log('PASS: all' + cases.length + ' scenarios preserve original output/return/read/input/notify traces; exact branch counters');
"""


def self_test(source: Path, transformed: bytes) -> str:
    # Includes real source drift and non-unique replacement guard negatives.
    for bad in (source.read_bytes() + b"\n", transformed):
        try:
            diagnostic_bytes(bad)
        except ValueError:
            pass
        else:
            raise ValueError("Source SHA negative unexpectedly accepted")
    with tempfile.TemporaryDirectory(prefix="mobile-worklet-test-") as directory:
        diagnostic = Path(directory) / "diagnostic.worklet.js"
        diagnostic.write_bytes(transformed)
        result = subprocess.run(
            ["node", "-e", MOCK_TEST, str(source), str(diagnostic)],
            capture_output=True, text=True, timeout=30, check=False,
        )
    if result.returncode:
        raise ValueError("Mock equivalence tests failed:\n" + result.stdout + result.stderr)
    return result.stdout


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--self-test", action="store_true", help="Run pure Node mocks before producing any output")
    args = parser.parse_args()
    created_output = False
    try:
        source = args.source.resolve(strict=True)
        output = args.output.absolute()
        if output.resolve() == source or output.exists() or output.is_symlink():
            raise ValueError("Diagnostic output must be a new file distinct from the official source")
        if not any("diagnostic" in part.lower() for part in output.parts):
            raise ValueError("Output path must explicitly contain 'diagnostic'")
        raw = source.read_bytes()
        transformed = diagnostic_bytes(raw)
        test_log = self_test(source, transformed) if args.self_test else None
        # Open exclusively only after all source guards and requested tests pass.
        output.parent.mkdir(parents=True, exist_ok=True)
        with output.open("xb") as stream:
            created_output = True
            stream.write(transformed)
        if source.read_bytes() != raw:
            raise ValueError("Official source changed during diagnostic generation")
        receipt = {
            "status": "generated", "scope": SCOPE, "instrumented_worklet": True,
            "official_source": str(source), "official_source_sha256": hashlib.sha256(raw).hexdigest(),
            "diagnostic_output": str(output), "diagnostic_sha256": hashlib.sha256(transformed).hexdigest(),
            "official_bytes_unchanged": source.read_bytes() == raw,
            "guarded_replacements": 3, "stats_command": COMMAND,
            "report_seconds": 0.25, "counter_frames": "per-channel audio frames; samples are interleaved",
            "self_test": "passed" if args.self_test else "not_run", "self_test_output": test_log,
        }
        print(json.dumps(receipt, ensure_ascii=False, indent=2))
        return 0
    except (OSError, ValueError, subprocess.SubprocessError) as exc:
        if created_output:
            args.output.unlink(missing_ok=True)
        print(json.dumps({"status": "failed", "error": str(exc), "output_written": False}, ensure_ascii=False))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
