"""Run the actual M35 runtime consumer through the shared native guard."""
from check_runtime_map_generated_identity import run_native


def main():
    run_native("tests/runtime_map_m35_runtime_runner.gd", "RUNTIME_MAP_M35_RUNTIME", 240)


if __name__ == "__main__":
    main()
