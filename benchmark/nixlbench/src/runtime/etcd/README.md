# ETCD Python Runtime

This directory contains the ETCD-based runtime implementation that replaces the MPI Python runtime with a new Python API that uses C++ etcd functions.

## Overview

The ETCD runtime provides distributed coordination and communication using etcd as the backend instead of MPI. This includes:

- **C++ Runtime** (`etcd_rt.cpp/h`): Core ETCD-based communication primitives
- **Python Bindings** (`python_bindings.cpp`): pybind11 bindings to expose C++ functions to Python

## Features

- Point-to-point communication (sendInt, recvInt, sendChar, recvChar)
- Collective operations (broadcast, reduce)
- Barrier synchronization
- Distributed rank management
- Object serialization for Python data structures

## Building

### Prerequisites

- etcd server running (default: `http://localhost:2379`)
- etcd-cpp-api library
- pybind11
- Python 3.6+

### Option 1: Using Meson (Recommended)

The Python bindings are automatically built as part of the main meson build if pybind11 and Python dependencies are found.

```bash
# From the main build directory
meson setup builddir
ninja -C builddir
```

### Option 2: Using setuptools

```bash
cd /path/to/etcd
pip install pybind11
python setup.py build_ext --inplace
```

## Usage

The Python bindings expose the C++ ETCD-based runtime directly as the
`etcd_runtime` extension module (the higher-level `_EtcdDistUtils` Python
runtime previously shipped in `benchmark/kvbench/runtime/`, which was removed
from this tree):

```python
import etcd_runtime

# Use the pybind11-exposed C++ runtime API for rank management,
# barriers, and collective operations.
```

## Configuration

Environment variables:
- `ETCD_ENDPOINTS`: Comma-separated list of etcd endpoints (default: "http://localhost:2379")
- `WORLD_SIZE`: Number of distributed processes (default: 1)

## Architecture

```
Python Application
       ↓
etcd_runtime (pybind11)
       ↓
xferBenchEtcdRT (C++)
       ↓
etcd-cpp-api
       ↓
ETCD Server
```

## Limitations

1. **Data Size**: Character data transfer has practical size limits
2. **Reduce Operations**: Only SUM and AVG are fully implemented (MIN/MAX use placeholders)
3. **Error Handling**: Basic error handling with timeouts and retries
4. **Performance**: May be slower than native MPI for high-frequency operations

## Future Improvements

- Implement proper MIN/MAX reduce operations
- Add support for custom serialization protocols
- Optimize data transfer for large objects
- Add connection pooling and reconnection logic
- Support for hierarchical barriers and reductions
