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

SOURCE_DIR=$(dirname "$(readlink -f "$0")")
BUILD_CONTEXT=$(dirname "$(readlink -f "$SOURCE_DIR")")
DOCKER_FILE="${SOURCE_DIR}/Dockerfile"
commit_id=$(git rev-parse --short HEAD)

# Get latest TAG and add COMMIT_ID for dev
latest_tag=$(git describe --tags --abbrev=0 $(git rev-list --tags --max-count=1 main) | sed 's/^v//') || true
if [[ -z ${latest_tag} ]]; then
    latest_tag="0.0.1"
    echo "No git release tag found, setting to unknown version: ${latest_tag}"
fi
VERSION=v$latest_tag.dev.$commit_id

# Unset by default (not a generic fallback): different Dockerfiles declare
# their own BASE_IMAGE/BASE_IMAGE_TAG ARG defaults (e.g. Dockerfile.manylinux
# needs an el8/ubi8 CUDA devel donor to match the AlmaLinux-8 base), and those
# must win when the caller doesn't override them with --base-image/--base-image-tag.
BASE_IMAGE=${BASE_IMAGE:-}
BASE_IMAGE_TAG=${BASE_IMAGE_TAG:-}
MANYLINUX_IMAGE=quay.io/pypa/manylinux_2_28
MANYLINUX_IMAGE_TAG=2026.06.06-1
ARCH=$(uname -m)
[ "$ARCH" = "arm64" ] && ARCH="aarch64"
WHL_BASE=manylinux_2_39
WHL_PLATFORM=${WHL_BASE}_${ARCH}
WHL_PYTHON_VERSIONS="3.12"
OS="ubuntu24"
NPROC=${NPROC:-$(nproc)}
GRPC_NPROC=${GRPC_NPROC:-$(nproc)}
BUILD_TYPE="release"
# CUDA MAJOR.MINOR for the manylinux wheel build — drives the torch cuXXX index
# and the cu12/cu13 meta-wheel split. Applies whenever --cuda-version isn't given.
CUDA_VERSION_DEFAULT="13.2"
CUDA_VERSION=${CUDA_VERSION:-}
APT_MIRROR=""
BUILD_OPTIONS_FILE=""

get_options() {
    while :; do
        case $1 in
        -h | -\? | --help)
            show_help
            exit
            ;;
        --base-image)
            if [ "$2" ]; then
                BASE_IMAGE="$2"
                shift
            else
                missing_requirement $1
            fi
        ;;
        --base-image-tag)
            if [ "$2" ]; then
                BASE_IMAGE_TAG=$2
                shift
            else
                missing_requirement $1
            fi
            ;;
        --wheel-base)
            if [ "$2" ]; then
                WHL_BASE=$2
                shift
            else
                missing_requirement $1
            fi
            ;;
        --os)
            if [ "$2" ]; then
                OS=$2
                shift
            else
                missing_requirement $1
            fi
            ;;
        --apt-mirror)
            if [ "$2" ]; then
                APT_MIRROR=$2
                shift
            else
                missing_requirement $1
            fi
            ;;
        --no-cache)
            NO_CACHE=" --no-cache"
            ;;
        --build-type)
            if [ "$2" ]; then
                BUILD_TYPE=$2
                shift
            else
                missing_requirement $1
            fi
            ;;
        --tag)
            if [ "$2" ]; then
                TAG="--tag $2"
                shift
            else
                missing_requirement $1
            fi
            ;;
        --dockerfile)
            if [ "$2" ]; then
                DOCKER_FILE="$2"
                shift
            else
                missing_requirement $1
            fi
            ;;
        --python-versions)
            if [ "$2" ]; then
                WHL_PYTHON_VERSIONS=$2
                shift
            else
                missing_requirement $1
            fi
            ;;
        --cuda-version)
            if [ "$2" ]; then
                CUDA_VERSION=$2
                shift
            else
                missing_requirement $1
            fi
            ;;
        --manylinux-image)
            if [ "$2" ]; then
                MANYLINUX_IMAGE=$2
                shift
            else
                missing_requirement $1
            fi
            ;;
        --manylinux-image-tag)
            if [ "$2" ]; then
                MANYLINUX_IMAGE_TAG=$2
                shift
            else
                missing_requirement $1
            fi
            ;;
        --arch)
            if [ "$2" ]; then
                ARCH=$2
                shift
            else
                missing_requirement $1
            fi
            ;;
        --wheel-base-image)
            if [ "$2" ]; then
                WHEEL_BASE_IMAGE=$2
                shift
            else
                missing_requirement $1
            fi
            ;;
        --build-options-file)
            if [ "$2" ]; then
                BUILD_OPTIONS_FILE=$2
                shift
            else
                missing_requirement $1
            fi
            ;;
        --)
            shift
            break
            ;;
         -?*)
            error 'ERROR: Unknown option: ' $1
            ;;
         ?*)
            error 'ERROR: Unknown option: ' $1
            ;;
        *)
            break
            ;;
        esac
        shift
    done

    if [[ $OS == "ubuntu22" ]]; then
        BASE_IMAGE=nvidia/cuda
        BASE_IMAGE_TAG=13.0.1-devel-ubuntu22.04
        WHL_BASE=${WHL_BASE:-manylinux_2_34}
    fi

    WHL_PLATFORM=${WHL_BASE}_${ARCH}

    if [ -z "$TAG" ]; then
        TAG="--tag nixl:${VERSION}"
    fi
}

show_build_options() {
    echo ""
    echo "Building NIXL Image"
    echo "Image Tag: ${TAG}"
    echo "Build Context: ${BUILD_CONTEXT}"
    # Each component is overridden independently; whichever is unset comes
    # from the Dockerfile's own ARG default.
    echo "Base Image: ${BASE_IMAGE:-<Dockerfile default>}:${BASE_IMAGE_TAG:-<Dockerfile default>}"
    echo "Container arch: ${ARCH}"
    echo "Python Versions for wheel build: ${WHL_PYTHON_VERSIONS}"
    echo "Wheel Platform: ${WHL_PLATFORM}"
    echo "Build Type: ${BUILD_TYPE}"
}

# Machine-readable counterpart to show_build_options(), written only when
# --build-options-file is passed. Consumed by CI to attach the resolved
# build config (base image, CUDA version, ...) as Artifactory
# properties on the published wheels.
write_build_options_file() {
    cat > "$BUILD_OPTIONS_FILE" <<EOF
BASE_IMAGE="${BASE_IMAGE}"
BASE_IMAGE_TAG="${BASE_IMAGE_TAG}"
ARCH="${ARCH}"
CUDA_VERSION="${CUDA_VERSION}"
BUILD_TYPE="${BUILD_TYPE}"
WHL_PYTHON_VERSIONS="${WHL_PYTHON_VERSIONS}"
WHL_PLATFORM="${WHL_PLATFORM}"
TAG="${TAG}"
EOF
}

show_help() {
    echo "usage: build-container.sh"
    echo "  [--base base image]"
    echo "  [--base-image-tag base image tag]"
    echo "  [--wheel-base base platform for wheel builds]"
    echo "  [--no-cache disable docker build cache]"
    echo "  [--os [ubuntu24|ubuntu22] to select Ubuntu version]"
    echo "  [--build-type [debug|release] to select build type (default: release)]"
    echo "  [--tag tag for image]"
    echo "  [--python-versions python versions to build for, comma separated]"
    echo "  [--arch [x86_64|aarch64] to select target architecture]"
    echo "  [--dockerfile path to a dockerfile to use]"
    echo "  [--cuda-version CUDA MAJOR.MINOR for the manylinux wheel build, e.g. 12.9 (default: ${CUDA_VERSION_DEFAULT})]
  [--manylinux-image PyPA manylinux image prefix (default: ${MANYLINUX_IMAGE})]
  [--manylinux-image-tag pinned PyPA manylinux image tag (default: ${MANYLINUX_IMAGE_TAG})]"
    echo "  [--wheel-base-image pre-built wheel base image URL; skips wheel_base stage and builds only the wheel stage]"
    echo "  [--apt-mirror base URL of an apt mirror to use instead of the public Ubuntu archive]"
    echo "  [--build-options-file path to write the resolved build options as KEY=VALUE lines]"
    exit 0
}

missing_requirement() {
    error "ERROR: $1 requires an argument."
}

error() {
    printf '%s %s\n' "$1" "$2" >&2
    exit 1
}

get_options "$@"

if [ -d "$NIXL_DIR/build" ]; then
    echo "Please delete the build directory before creating container"
    exit 1
fi

BUILD_ARGS+="${BASE_IMAGE:+ --build-arg BASE_IMAGE=$BASE_IMAGE}"
BUILD_ARGS+="${BASE_IMAGE_TAG:+ --build-arg BASE_IMAGE_TAG=$BASE_IMAGE_TAG}"
BUILD_ARGS+=" --build-arg MANYLINUX_IMAGE=$MANYLINUX_IMAGE --build-arg MANYLINUX_IMAGE_TAG=$MANYLINUX_IMAGE_TAG"
BUILD_ARGS+=" --build-arg WHL_PYTHON_VERSIONS=$WHL_PYTHON_VERSIONS"
CUDA_VERSION="${CUDA_VERSION:-$CUDA_VERSION_DEFAULT}"
BUILD_ARGS+=" --build-arg CUDA_VERSION=$CUDA_VERSION"
BUILD_ARGS+=" --build-arg WHL_PLATFORM=$WHL_PLATFORM"
BUILD_ARGS+=" --build-arg ARCH=$ARCH"
BUILD_ARGS+=" --build-arg NPROC=$NPROC"
BUILD_ARGS+=" --build-arg GRPC_NPROC=$GRPC_NPROC"
BUILD_ARGS+=" --build-arg BUILD_TYPE=$BUILD_TYPE"
BUILD_ARGS+="${APT_MIRROR:+ --build-arg APT_MIRROR=$APT_MIRROR}"

if [ -n "$WHEEL_BASE_IMAGE" ]; then
    BUILD_ARGS+=" --build-arg wheel_base=$WHEEL_BASE_IMAGE"
    # Not named BUILD_TARGET: Jenkins exports a BUILD_TARGET job parameter
    # (nixl/nixlbench) that would leak into the docker command line.
    DOCKER_BUILD_TARGET="--target wheel"
fi

show_build_options
[ -n "$BUILD_OPTIONS_FILE" ] && write_build_options_file

docker build --platform linux/$ARCH -f $DOCKER_FILE $BUILD_ARGS $TAG $NO_CACHE ${DOCKER_BUILD_TARGET:-} $BUILD_CONTEXT
