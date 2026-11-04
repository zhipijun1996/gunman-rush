"""Run the actual M35 provider consumer through the shared native guard."""
from check_runtime_map_generated_identity import run_native


def main():
    run_native("tests/runtime_map_m35_provider_runner.gd", "RUNTIME_MAP_M35_PROVIDER", 180)


if __name__ == "__main__":
    main()
