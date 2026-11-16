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

# Add dependency on the common utility library which brings in logging deps

nixl_lib_deps = [nixl_infra, serdes_interface, stream_interface, dl_dep, nixl_common_dep, thread_dep]

if etcd_dep.found()
    nixl_lib_deps += [ etcd_dep ]
endif

if 'UCCL' in static_plugins
    nixl_lib_deps += [ uccl_backend_interface ]
endif

# Tracing (nixl::trace). Only the facade (tracer.cpp) is compiled into libnixl;
# no tracing backend plugins ship in this tree (v1.5.2-vacc lineage).
nixl_lib_sources = [
    'nixl_agent.cpp',
    'nixl_enum_strings.cpp',
    'nixl_md_manager.cpp',
    'nixl_metadata_worker.cpp',
    'nixl_p2p_metadata_backend.cpp',
    'nixl_etcd_metadata_backend.cpp',
    'nixl_tcpstore_metadata_backend.cpp',
    'nixl_tcpstore_client.cpp',
    'nixl_plugin_manager.cpp',
    'telemetry/telemetry.cpp',
    'telemetry/telemetry_staging_queue.cpp',
    'telemetry/buffer_exporter.cpp',
    'telemetry/buffer_plugin.cpp',
    'telemetry/nop_plugin.cpp',
    'tracing/trace_context.cpp',
    'tracing/tracer.cpp',
]

nixl_lib = library('nixl',
                   nixl_lib_sources,
                   include_directories: [ nixl_inc_dirs, utils_inc_dirs, include_directories('tracing') ],
                   link_args: ['-lstdc++fs'],
                   dependencies: nixl_lib_deps,
                   install: true,
                   install_rpath: join_paths(get_option('prefix'), get_option('libdir')))

nixl_dep = declare_dependency(link_with: nixl_lib, include_directories: nixl_inc_dirs)
