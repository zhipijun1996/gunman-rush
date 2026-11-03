"""Run the actual generation-job lifecycle consumer with strict native guards."""
from check_runtime_map_generated_identity import run_native


def main():
    run_native("tests/runtime_map_generation_job_runner.gd", "RUNTIME_MAP_GENERATION_JOB", 240)


if __name__ == "__main__":
    main()
