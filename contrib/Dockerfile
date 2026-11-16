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

ARG BASE_IMAGE="nvcr.io/nvidia/cuda-dl-base"
ARG BASE_IMAGE_TAG="25.10-cuda13.0-devel-ubuntu24.04"

FROM ${BASE_IMAGE}:${BASE_IMAGE_TAG}

ARG ARCH="x86_64"
ARG DEFAULT_PYTHON_VERSION="3.12"
ARG RDMA_CORE_PREFIX="/usr"
ARG NIXL_PREFIX="/usr/local/nixl"
ARG NIXL_PLUGIN_DIR="$NIXL_PREFIX/lib/$ARCH-linux-gnu/plugins"
ARG NPROC
ARG BUILD_TYPE="release"
ARG ABSL_TAG="lts_2025_08_14"
ARG GRPC_TAG="v1.73.0"
ARG APT_MIRROR=""

# Optional apt mirror override, e.g. for CI environments with an internal
# Ubuntu mirror. Empty (default) keeps the public archive/ports.ubuntu.com.
RUN if [ -n "$APT_MIRROR" ]; then \
        . /etc/os-release && \
        printf '%s\n' \
            'Types: deb' \
            "URIs: $APT_MIRROR" \
            "Suites: $VERSION_CODENAME $VERSION_CODENAME-updates $VERSION_CODENAME-backports $VERSION_CODENAME-security" \
            'Components: main restricted universe multiverse' \
            'Trusted: yes' > /etc/apt/sources.list.d/ubuntu.sources && \
        grep -rlE 'archive\.ubuntu\.com|security\.ubuntu\.com|ports\.ubuntu\.com' /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null | xargs -r rm -f; \
    fi

# Install build dependencies from Ubuntu repository
RUN apt-get update -y && \
    apt-get install -y ubuntu-keyring && \
    apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive apt-get -y install \
    ninja-build \
    libclang-dev \
    cmake \
    libgflags-dev \
    libprotobuf-dev \
    libcpprest-dev \
    etcd-server \
    etcd-client \
    libz-dev \
    libgtest-dev \
    build-essential \
    python3.12-dev \
    clang \
    pkg-config \
    # gRPC SSL provider
    libssl-dev zlib1g-dev

# Reinstall RDMA build deps (libibverbs for the UCCL verbs transport).
# --reinstall because apt skips equal versions.
RUN DEBIAN_FRONTEND=noninteractive apt-get -y install \
    --reinstall libibverbs-dev rdma-core ibverbs-utils libibumad-dev \
    libnuma-dev librdmacm-dev ibverbs-providers

WORKDIR /workspace

# Force CMake to always copy files in install directives, rather than skip based on file modification timestamp.
# File modification timestamp check in CMake uses 1 second resolution.
# This causes problems for fast builds that install, patch then reinstall the same file, as the final install step
# may be incorrectly skipped.
ENV CMAKE_INSTALL_ALWAYS=1

# Build Abseil from source (required for absl/log).
RUN git clone https://github.com/abseil/abseil-cpp.git && \
    cd abseil-cpp && \
    git fetch --depth 1 origin ${ABSL_TAG} && \
    git checkout ${ABSL_TAG} && \
    mkdir -p build && cd build && \
    cmake .. \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_CXX_STANDARD=20 \
        -DBUILD_SHARED_LIBS=ON \
        -DABSL_PROPAGATE_CXX_STD=ON \
        -DABSL_ENABLE_INSTALL=ON && \
    make -j${NPROC:-$(nproc)} && \
    make install && \
    ldconfig

# Build gRPC from source against system/install-prefix Abseil.
RUN git clone --recurse-submodules -b ${GRPC_TAG} --depth 1 --shallow-submodules https://github.com/grpc/grpc && \
    cd grpc && \
    mkdir -p cmake/build && \
    cd cmake/build && \
    export CMAKE_PREFIX_PATH="/usr/local${CMAKE_PREFIX_PATH:+:$CMAKE_PREFIX_PATH}" && \
    export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/local/lib/${ARCH}-linux-gnu/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}" && \
    cmake ../.. \
        -DgRPC_INSTALL=ON \
        -DgRPC_BUILD_TESTS=OFF \
        -DBUILD_SHARED_LIBS=ON \
        -DCMAKE_CXX_STANDARD=20 \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DCMAKE_PREFIX_PATH=/usr/local \
        -Dabsl_DIR=/usr/local/lib/cmake/absl \
        -DgRPC_SSL_PROVIDER=package \
        -DgRPC_ABSL_PROVIDER=package \
        -DgRPC_PROTOBUF_PROVIDER=module \
        -DgRPC_ZLIB_PROVIDER=package && \
    make -j${NPROC:-$(nproc)} && \
    make install && \
    ldconfig

RUN git clone --depth 1 https://github.com/etcd-cpp-apiv3/etcd-cpp-apiv3.git && \
    cd etcd-cpp-apiv3 && \
    sed -i '/^find_dependency(cpprestsdk)$/d' etcd-cpp-api-config.in.cmake && \
    mkdir build && cd build && \
    cmake .. -DBUILD_ETCD_CORE_ONLY=ON -DCMAKE_BUILD_TYPE=Release -DETCD_CMAKE_CXX_STANDARD=20 -DCMAKE_CXX_STANDARD=20 -DCMAKE_PREFIX_PATH=/usr/local && \
    make -j${NPROC:-$(nproc)} && make install

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Keep uv's cache in /workspace, not /root (some hosts mount $HOME over /root).
ENV UV_CACHE_DIR=/workspace/.cache/uv
RUN mkdir -p $UV_CACHE_DIR
# Disable build isolation, i.e. uv should not create a new virtual environment for
# building wheels. This is faster as it skips installing dependencies twice.
ENV UV_NO_BUILD_ISOLATION=1
# Disable syncing, i.e. uv will not download packages outside uv pip commands.
ENV UV_NO_SYNC=1
# Allow installs into PEP 668 externally-managed system Python.
ENV UV_BREAK_SYSTEM_PACKAGES=1
# All uv pip commands target the system interpreter.
ENV UV_PYTHON=python${DEFAULT_PYTHON_VERSION}
# Build tools into system Python (no venv).
RUN uv pip install --system --upgrade \
    meson meson-python pybind11 patchelf pyYAML click tabulate auditwheel tomlkit
# Use system torch if present (>=2.7), else install it.
RUN if /usr/bin/python${DEFAULT_PYTHON_VERSION} -c "import torch; v=torch.__version__.split('.')[:2]; assert (int(v[0]),int(v[1])) >= (2,7)" 2>/dev/null; then \
        echo "Using PyTorch from system site-packages"; \
    else \
        export UV_INDEX="https://download.pytorch.org/whl/cu$(echo $CUDA_VERSION | cut -d. -f1,2 | tr -d .)" && \
        uv pip install --system torch torchvision torchaudio; \
    fi
# setuptools for PEP 639 license metadata
RUN uv pip install --system --upgrade 'setuptools>=80.9.0'

WORKDIR /workspace/nixl
COPY . /workspace/nixl

ENV LD_LIBRARY_PATH=/usr/local/lib:$RDMA_CORE_PREFIX/lib:$LD_LIBRARY_PATH

# Install pybind11 via apt
RUN apt-get update && apt-get install -y --no-install-recommends pybind11-dev

# Set PKG_CONFIG_PATH for NIXL dependencies (rdma-core)
ENV PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/local/lib/$ARCH-linux-gnu/pkgconfig
ENV PKG_CONFIG_PATH=$RDMA_CORE_PREFIX/lib/$ARCH-linux-gnu/pkgconfig:$PKG_CONFIG_PATH

ENV NIXL_PREFIX=$NIXL_PREFIX
RUN rm -rf build && \
    mkdir build && \
    meson setup build/ --prefix=$NIXL_PREFIX --buildtype=$BUILD_TYPE && \
    cd build && \
    ninja -j${NPROC:-$(nproc)} && \
    ninja install

RUN echo "$NIXL_PREFIX/lib/$ARCH-linux-gnu" > /etc/ld.so.conf.d/nixl.conf && \
    echo "$NIXL_PLUGIN_DIR" >> /etc/ld.so.conf.d/nixl.conf && \
    ldconfig

ENV NIXL_PLUGIN_DIR=$NIXL_PLUGIN_DIR

# Install the python bindings from source, built against the container's own
# torch - works on any base, no dependency on public torch wheels.
# Redistributable wheels are produced by the wheel CI pipelines, not here.
RUN CUDA_MAJOR=$(echo "${CUDA_VERSION}" | cut -d. -f1) && \
    ./contrib/tomlutil.py --wheel-name "nixl-cu${CUDA_MAJOR}" pyproject.toml && \
    uv pip install --system --no-build-isolation . && \
    uv pip install --system build/src/bindings/python/nixl-meta/nixl-*.whl
