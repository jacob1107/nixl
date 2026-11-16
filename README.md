<!--
SPDX-FileCopyrightText: Copyright (c) 2025-2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
SPDX-License-Identifier: Apache-2.0
-->

# NVIDIA Inference Xfer Library (NIXL)

NVIDIA Inference Xfer Library (NIXL) is targeted for accelerating point to point communications in AI inference frameworks such as NVIDIA Dynamo, while providing an abstraction over various types of memory (e.g., CPU and GPU) and storage (e.g., file, block and object store) through a modular plug-in architecture.

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![GitHub Release](https://img.shields.io/github/v/release/ai-dynamo/nixl)](https://github.com/ai-dynamo/nixl/releases/latest)

## Documentation and Resources

* [NIXLBench docs](https://github.com/ai-dynamo/nixl/blob/main/benchmark/nixlbench/README.md) - Benchmark usage guide (`benchmark/nixlbench/README.md`)

## Supported Platforms
NIXL is supported on a Linux environment only. It is tested on Ubuntu (22.04/24.04) and Fedora. macOS and Windows are not currently supported; use a Linux host or container/VM.

## Pre-build Distributions
### PyPI Wheel

The nixl python API and libraries are available directly through PyPI.
For example, if you have a GPU running on a Linux host, container, or VM, you can do the following install:

Install with:

```bash
pip install nixl
```

This installs both CUDA 12 and CUDA 13 backends. At runtime, the correct backend is selected automatically based on the CUDA version reported by PyTorch.

## Prerequisites for source build (Linux)

NIXL requires a C++20 compatible compiler (GCC >= 11 or Clang >= 14).

### Ubuntu:

`$ sudo apt install build-essential cmake pkg-config`

### Fedora:

`$ sudo dnf install gcc-c++ cmake pkg-config`

### Python

`$ pip3 install meson ninja pybind11 tomlkit`

### UCCL (required)

This tree ships the UCCL backend plugin only. The plugin is built when the
`uccl_p2p` library is discoverable (e.g. installed under `/usr/local/lib`):

```
$ ls /usr/local/lib/libuccl_p2p* /usr/local/lib/librdma_plugin*
```

If UCCL is installed elsewhere, make the path visible to the compiler
(`LIBRARY_PATH` / `LD_LIBRARY_PATH`), or request an explicit failure with
`-Denable_plugins=UCCL` when it cannot be found.

### ETCD (Optional)
NIXL can use ETCD for metadata distribution and coordination between nodes in distributed environments. To use ETCD with NIXL:
#### ETCD Server and Client
 ```
$ sudo apt install etcd etcd-server etcd-client

# Or use Docker
$ docker run -d -p 2379:2379 quay.io/coreos/etcd:v3.5.1
```

#### ETCD CPP API
Installed from https://github.com/etcd-cpp-apiv3/etcd-cpp-apiv3

```
$ sudo apt install libgrpc-dev libgrpc++-dev libprotobuf-dev protobuf-compiler-grpc
$ sudo apt install libcpprest-dev
$ git clone https://github.com/etcd-cpp-apiv3/etcd-cpp-apiv3.git
$ cd etcd-cpp-apiv3
$ mkdir build && cd build
$ cmake ..
$ make -j$(nproc) && make install
```

### Plugins

This tree builds a single backend plugin: [UCCL](src/plugins/uccl/README.md).
All other upstream plugins (UCX, POSIX, OBJ, GDS, GDS_MT, GPUNETIO, Mooncake,
HF3FS, GUSLI, Azure Blob, INFINIA, Libfabric, telemetry exporters and the NVTX
tracing backend) were removed in the v1.5.2-vacc lineage.

## Getting started
### Build & install

```
$ meson setup <name_of_build_dir>
$ cd <name_of_build_dir>
$ ninja
$ ninja install
```

### Build Options

#### Release build (default)

```bash
$ meson setup <name_of_build_dir>
```

#### Debug build

```bash
$ meson setup <name_of_build_dir> --buildtype=debug
```

#### NIXL-specific build options

```bash
# Example with custom options
$ meson setup <name_of_build_dir> \
    -Dinstall_headers=true        # Install development headers
```

Common build options:
- `install_headers`: Install development headers (default: true)
- `cudapath_inc`, `cudapath_lib`: Custom CUDA paths
- `static_plugins`: Comma-separated list of plugins to build statically
- `enable_plugins`: Comma-separated list of plugins to build (e.g. `-Denable_plugins=UCCL`). Cannot be used with `disable_plugins`.
- `disable_plugins`: Comma-separated list of plugins to exclude. Cannot be used with `enable_plugins`.
- `wheel_variant`: Override the Python wheel variant suffix (e.g. `-Dwheel_variant=vacc` yields `nixl_vacc`). Empty (default) = autodetect from the CUDA major version.

#### Environment Variables

There are a few environment variables that can be set to configure the build:
- `NIXL_NO_STUBS_FALLBACK`: If not set or 0, build NIXL stub library if the library build fails

### Python Interface

NIXL provides Python bindings through pybind11.

The preferred way to install the Python bindings is through pip from PyPI:

```bash
pip install nixl
```

This installs both CUDA 12 and CUDA 13 backends. At runtime, the correct backend is selected automatically based on the CUDA version reported by PyTorch.

#### Installation from source

Prerequisites:

- `uv`: https://docs.astral.sh/uv/getting-started/installation/
- `tomlkit`: https://pypi.org/project/tomlkit/
- `PyTorch`: https://pytorch.org/get-started/locally/

`uv` is always required *even if* you have another kind of Python virtual environment manager or if you are using a system-wide Python installation without using a virtual environment.

Example with `uv` Python virtual environment:

```
curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/.local/bin:${PATH}"

uv venv .venv --python 3.12
source .venv/bin/activate
uv pip install tomlkit
```

Example with python-virtualenv:

```
curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/.local/bin:${PATH}"

python3 -m venv .venv
source .venv/bin/activate
pip install tomlkit
```

Example with system-wide Python installation without using a virtual environment:

```
curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/.local/bin:${PATH}"

pip install tomlkit
```

Then install PyTorch following the instructions on the PyTorch website: https://pytorch.org/get-started/locally/

After installing the prerequisites, you can build and install the NIXL binaries and the Python bindings from source. You have to:

1. Build NIXL binaries and install them
2. Build and install the CUDA platform-specific package (`nixl-cu12` or `nixl-cu13`)
3. Build and install the `nixl` meta-package

**For CUDA 12:**

```
pip install .
meson setup build
ninja -C build install
pip install build/src/bindings/python/nixl-meta/nixl-*-py3-none-any.whl
```

**For CUDA 13:**

```
pip install .
./contrib/tomlutil.py --wheel-name nixl-cu13 pyproject.toml
meson setup build
ninja -C build install
pip install build/src/bindings/python/nixl-meta/nixl-*-py3-none-any.whl
```

To check if the installation is successful, you can run the following command:

```
python3 -c "import nixl; agent = nixl.nixl_agent('agent1')"
```

which should print:

```
2026-01-08 13:36:27 NIXL INFO    _api.py:363 Backend UCCL was instantiated
2026-01-08 13:36:27 NIXL INFO    _api.py:253 Initialized NIXL agent: agent1
```

### Other build options
See [contrib/README.md](contrib/README.md) for more build options.

### Building Docker container
To build the docker container, first clone the current repository. Also make sure you are able to pull docker images to your machine before attempting to build the container.

Run the following from the root folder of the cloned NIXL repository:
```
$ ./contrib/build-container.sh
```

By default, the container is built with Ubuntu 24.04. To build a container for Ubuntu 22.04 use the --os option as follows:
```
$ ./contrib/build-container.sh --os ubuntu22
```

To see all the options supported by the container use:
```
$ ./contrib/build-container.sh -h
```

The container has the NIXL python bindings preinstalled (built from source against the container's own PyTorch). For a redistributable python wheel, use the wheel build script below or install the published `nixl` package.

### Building the python wheel
The contrib folder also includes a script to build the python wheel. Note, that UCCL and other NIXL dependencies are required to be installed.
```
$ ./contrib/build-wheel.sh
```

## Running with ETCD
NIXL can use ETCD for metadata exchange between distributed nodes. This is especially useful in containerized or cloud-native environments.

### Environment Setup
To use ETCD with NIXL, set the following environment variables:

```bash
# Set ETCD endpoints (required) - replace localhost with the hostname of the etcd server
export NIXL_ETCD_ENDPOINTS="http://localhost:2379"

# Set ETCD namespace (optional, defaults to /nixl/agents)
export NIXL_ETCD_NAMESPACE="/nixl/agents"
```

### nixlbench Benchmark
For more comprehensive testing, the nixlbench benchmarking tool supports ETCD for worker coordination:

```bash
# Build nixlbench (see benchmark/nixlbench/README.md for details)
cd benchmark/nixlbench
meson setup build && cd build && ninja

# Run benchmark with ETCD
./nixlbench --etcd-endpoints http://localhost:2379 --backend UCCL --initiator_seg_type VRAM
```

## Third-Party Components

This project will download and install additional third-party open source software projects. Review the license terms of these open source projects before use.
