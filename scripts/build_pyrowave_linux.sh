#!/usr/bin/env bash
set -euo pipefail

readonly pyrowave_revision="509e4f887b585a3f97471fcc804e9de649f2c16f"
readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly source_dir="$(cd -- "${script_dir}/.." && pwd)"
readonly pyrowave_source_dir="${PYROWAVE_SOURCE_DIR:-${source_dir}/cmake-build-pyrowave-src}"
readonly pyrowave_build_dir="${PYROWAVE_BUILD_DIR:-${source_dir}/cmake-build-pyrowave}"
readonly pyrowave_prefix="${PYROWAVE_PREFIX:-${source_dir}/cmake-build-pyrowave-prefix}"
readonly sunshine_build_dir="${SUNSHINE_BUILD_DIR:-${source_dir}/cmake-build-linux}"
readonly build_jobs="${BUILD_JOBS:-$(nproc)}"

if [[ ! -d "${pyrowave_source_dir}/.git" ]]; then
  git clone https://github.com/Themaister/pyrowave.git "${pyrowave_source_dir}"
fi

if [[ -n "$(git -C "${pyrowave_source_dir}" status --short)" ]]; then
  echo "PyroWave source tree is dirty: ${pyrowave_source_dir}" >&2
  echo "Commit, stash, or remove those changes before running this script." >&2
  exit 1
fi

git -C "${pyrowave_source_dir}" fetch origin "${pyrowave_revision}"
git -C "${pyrowave_source_dir}" checkout --detach "${pyrowave_revision}"
git -C "${pyrowave_source_dir}" submodule update --init --recursive

cmake \
  -S "${pyrowave_source_dir}" \
  -B "${pyrowave_build_dir}" \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="${pyrowave_prefix}" \
  -DPYROWAVE_DEVEL=OFF
cmake --build "${pyrowave_build_dir}" -j "${build_jobs}"
cmake --install "${pyrowave_build_dir}"

pyrowave_pc_file="$(find "${pyrowave_prefix}" -name pyrowave-shared.pc -print -quit)"
if [[ -z "${pyrowave_pc_file}" ]]; then
  echo "The PyroWave pkg-config file was not installed under ${pyrowave_prefix}." >&2
  exit 1
fi

pyrowave_pc_dir="$(dirname -- "${pyrowave_pc_file}")"
pyrowave_lib_dir="$(
  PKG_CONFIG_PATH="${pyrowave_pc_dir}${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}" \
    pkg-config --variable=libdir pyrowave-shared
)"

PKG_CONFIG_PATH="${pyrowave_pc_dir}${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}" \
  cmake \
    -S "${source_dir}" \
    -B "${sunshine_build_dir}" \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_BUILD_RPATH="${pyrowave_lib_dir}" \
    -DSUNSHINE_ENABLE_PYROWAVE=ON \
    "$@"
cmake --build "${sunshine_build_dir}" --target sunshine -j "${build_jobs}"

echo
echo "Sunshine with PyroWave was built at:"
echo "  ${sunshine_build_dir}/sunshine"
echo
echo "PyroWave runtime library directory:"
echo "  ${pyrowave_lib_dir}"
