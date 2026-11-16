#!/bin/bash

# SPDX-FileCopyrightText: Copyright (c) 2025-2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

PYTHON_VERSION="3.12"
ARCH=$(uname -m)
WHL_PLATFORM="manylinux_2_39_$ARCH"
OUTPUT_DIR="dist"

while [[ $# -gt 0 ]]; do
    case $1 in
        --python-version)
            PYTHON_VERSION=$2
            shift
            shift
            ;;
        --platform)
            WHL_PLATFORM=$2
            shift
            shift
            ;;
        --output-dir)
            OUTPUT_DIR=$2
            shift
            shift
            ;;
        --help)
            echo "Usage: $0 [--python-version <python-version>] [--platform <platform>] [--output-dir <output-dir>]"
            echo "  --python-version: Python version to build the wheel for (default: $PYTHON_VERSION)"
            echo "  --platform: Platform to build the wheel for (default: $WHL_PLATFORM)"
            echo "  --output-dir: Directory to output the wheel to (default: $OUTPUT_DIR)"
            echo "  --help: Show this help message"
            echo ""
            echo "Must be executed from the root of the NIXL repository."
            exit 0
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
done

set -e
set -x

TMP_DIR=$(mktemp -d)

CUDA_MAJOR=$(nvcc --version | grep -Eo 'release [0-9]+\.[0-9]+' | cut -d' ' -f2 | cut -d'.' -f1)
# Must be 12 or 13
if [ "$CUDA_MAJOR" -ne 12 ] && [ "$CUDA_MAJOR" -ne 13 ]; then
    echo "Invalid CUDA_MAJOR: '$CUDA_MAJOR'"
    exit 1
fi
AUDITWHEEL_EXCLUDES="--exclude libcuda* --exclude libcufile* --exclude libssl* --exclude libcrypto* --exclude libtorch* --exclude libc10* --exclude liblz4*"

PKG_NAME="nixl-cu${CUDA_MAJOR}"
CU_TAG="cu$(nvcc --version | grep -Eo 'release [0-9]+\.[0-9]+' | cut -d' ' -f2 | tr -d .)"
./contrib/tomlutil.py --wheel-name $PKG_NAME pyproject.toml


# Build deps for the per-iteration venv; torch is installed separately.
BUILD_DEPS=(
    "meson"
    "meson-python"
    "pybind11"
    "patchelf"
    "pyyaml"
    "types-PyYAML"
    "setuptools>=80.9.0"
)

# Slugify a dotted version (e.g. "2.13" -> "213", "3.10" -> "310") so it can
# be used unambiguously as a path component.
slug() { echo "${1//./}"; }


# Path for the build venv. Lives in /workspace, not /tmp, so it inherits
# the image's UV_CACHE_DIR layout and is visible to debugging.
venv_path() {
    echo "/workspace/venv-py$(slug "$PYTHON_VERSION")"
}


destroy_torch_venv() {
    rm -rf "$(venv_path)"
}

# Build the wheel for the current PYTHON_VERSION. Each build uses a fresh
# venv so the environment never leaks across runs.
build_wheel() {
    local OUT_DIR=$1

    local VENV_PATH
    VENV_PATH=$(venv_path)
    rm -rf "$VENV_PATH"
    uv venv "$VENV_PATH" --python "$PYTHON_VERSION"

    echo "=== Provisioning ${VENV_PATH} (python ${PYTHON_VERSION}) ==="
    uv pip install --python "$VENV_PATH/bin/python" "${BUILD_DEPS[@]}"

    # Activate so meson's `find_installation('python3')` resolves to this
    # venv's interpreter (which has the right torch).
    # shellcheck disable=SC1091
    source "$VENV_PATH/bin/activate"

    local BUILD_ARGS=(
        --wheel
        --no-build-isolation
        --out-dir "$OUT_DIR"
        --python "$VENV_PATH/bin/python"
    )
    uv build "${BUILD_ARGS[@]}"

    deactivate
    # torch + nvidia-* in each venv is several GB; tear down so the docker
    # layer does not get too large across the (python, torch) matrix.
    destroy_torch_venv
}

repair_wheel() {
    local IN_DIR=$1
    local OUT_DIR=$2
    mkdir -p "$OUT_DIR"
    auditwheel repair $AUDITWHEEL_EXCLUDES "$IN_DIR"/nixl*.whl --plat "$WHL_PLATFORM" --wheel-dir "$OUT_DIR"
}

# Echo the path of the single .whl in $1, or exit if the count is not 1.
get_wheel_path() {
    local dir=$1 wheels
    shopt -s nullglob
    wheels=("$dir"/*.whl)
    shopt -u nullglob
    if [ ${#wheels[@]} -ne 1 ]; then
        echo "expected 1 wheel in $dir, got ${#wheels[@]}: ${wheels[*]}" >&2
        exit 1
    fi
    echo "${wheels[0]}"
}

build_wheel "$TMP_DIR"
repair_wheel "$TMP_DIR" "$TMP_DIR/dist"
cp "$(get_wheel_path "$TMP_DIR/dist")" "$OUTPUT_DIR"

# Clean up
rm -rf "$TMP_DIR"
