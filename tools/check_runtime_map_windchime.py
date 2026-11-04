"""Complete real-content windchime consumers, with one aggregate time limit."""
import re
import time
from run_tests import run_engine

def main():
    deadline = time.monotonic() + 240
    def run(arguments, maximum):
        remaining = min(maximum, deadline - time.monotonic())
        if remaining <= 0:
            raise RuntimeError("Windchime aggregate 240s deadline exhausted")
        return run_engine(arguments, remaining)
    run(["--headless", "--audio-driver", "Dummy", "--path", ".", "--editor", "--quit"], 90)
    for script, pattern in [
        ("tests/runtime_map_windchime_provider_runner.gd", r"^RUNTIME_MAP_WINDCHIME_PROVIDER checks=[1-9][0-9]* failures=0$"),
        ("tests/runtime_map_windchime_runtime_runner.gd", r"^RUNTIME MAP WINDCHIME MECHANISMS: [1-9][0-9]* assertions, 0 failures$"),
        ("tests/runtime_map_windchime_generated_runner.gd", r"^RUNTIME_MAP_WINDCHIME_GENERATED checks=[1-9][0-9]* failures=0$"),
    ]:
        output = run(["--headless", "--audio-driver", "Dummy", "--fixed-fps", "60", "--path", ".", "--script", script], 240)
        if re.search(r"^ERROR: Resumed function .*class instance is gone", output, re.MULTILINE):
            raise RuntimeError("Windchime consumer resumed after its owner was freed")
        if re.search(pattern, output, re.MULTILINE) is None:
            raise RuntimeError("Windchime consumer is missing its complete success marker: " + script)

if __name__ == "__main__":
    main()
