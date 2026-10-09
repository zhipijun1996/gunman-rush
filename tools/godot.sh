#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
toolchain_root="${GUNMAN_TOOLCHAIN_ROOT:-$(dirname "$repo_root")/toolchains}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$toolchain_root/user-config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$toolchain_root/cache}"
export ANDROID_HOME="${ANDROID_HOME:-$toolchain_root/android-sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export JAVA_HOME="${JAVA_HOME:-$toolchain_root/jdk17}"
export XDG_DATA_HOME="${GUNMAN_DATA_HOME:-$toolchain_root/user-data}"
engine="${GODOT_BIN:-$toolchain_root/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64}"
if [[ ! -x "$engine" ]]; then
  engine="$(command -v godot || command -v godot4 || true)"
fi
if [[ -z "$engine" || ! -x "$engine" ]]; then
  echo 'Godot unavailable: run bash tools/cloud_setup.sh or set GODOT_BIN.' >&2
  exit 1
fi
actual_version="$("$engine" --version)"
if [[ "$actual_version" != 4.7.2.stable.official.* || "$actual_version" == *mono* ]]; then
  echo "Expected Godot 4.7.2 Standard; found $actual_version" >&2
  exit 1
fi
exec "$engine" "$@"
