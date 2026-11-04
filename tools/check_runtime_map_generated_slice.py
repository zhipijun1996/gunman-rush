"""Run the actual generated slice consumer with strict native guards."""
from check_runtime_map_generated_identity import run_native


def main():
    run_native("tests/runtime_map_generated_slice_runner.gd", "RUNTIME_MAP_GENERATED_SLICE", 240)


if __name__ == "__main__":
    main()
