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

project('nixl', 'CPP', version: '1.5.2',
    default_options: ['buildtype=release',
                'werror=true',
                'cpp_std=c++20',
                'prefix=/opt/nvidia/nvda_nixl'],
    meson_version: '>= 0.64.0'
)

enable_plugins_opt = get_option('enable_plugins')
disable_plugins_opt = get_option('disable_plugins')
is_explicit_enable = enable_plugins_opt != ''

if enable_plugins_opt != '' and disable_plugins_opt != ''
    error('Cannot specify both enable_plugins and disable_plugins options')
endif

all_plugins = ['UCCL']

enabled_plugins = {}

if enable_plugins_opt != ''
    enabled_plugins_list = []
    foreach p : enable_plugins_opt.split(',')
        p_stripped = p.strip()
        if p_stripped not in all_plugins
            error('Requested plugin "' + p_stripped + '" is not available. Available plugins are: ' + ', '.join(all_plugins))
        endif
        enabled_plugins_list += [p_stripped]
    endforeach

    foreach plugin : all_plugins
        enabled_plugins += {plugin: plugin in enabled_plugins_list}
    endforeach

    message('Building only selected plugins: ' + enable_plugins_opt)
elif disable_plugins_opt != ''
    disabled_plugins_list = []
    foreach p : disable_plugins_opt.split(',')
        p_stripped = p.strip()
        if p_stripped not in all_plugins
            error('Cannot exclude unknown plugin "' + p_stripped + '". Available plugins are: ' + ', '.join(all_plugins))
        endif
        disabled_plugins_list += [p_stripped]
    endforeach

    foreach plugin : all_plugins
        enabled_plugins += {plugin: plugin not in disabled_plugins_list}
    endforeach

    message('Building all plugins except: ' + disable_plugins_opt)
else
    foreach plugin : all_plugins
        enabled_plugins += {plugin: true}
    endforeach

    message('Building all available plugins')
endif

# set up some global vars for compiler, platform, configuration, etc.
cpp = meson.get_compiler('cpp')
fs = import('fs')

dl_dep = cpp.find_library('dl', required: true)
rt_dep = cpp.find_library('rt', required: true)
thread_dep = dependency('threads')

# Forced to ignore this error due to:
# https://github.com/abseil/abseil-cpp/issues/1779
# This must be global since subprojects cannot be assigned with arguments.
# Adding this configuration only for release build to consider it while developing.
# NOTE: Must be declared before any subproject fallback that builds a target
# (e.g. the abseil-cpp wrap), because Meson forbids add_global_arguments after targets.
if get_option('buildtype') == 'release'
  abseil_flags = cpp.get_supported_arguments('-Wno-error=maybe-uninitialized', '-Wno-maybe-uninitialized')
  add_global_arguments(abseil_flags, language: 'cpp')
endif

# Sanitizer build, selected with -Dsanitizer=. Maps to -fsanitize and folds in
# the third-party build workarounds so a plain `-Dsanitizer=...` build compiles:
#  - undefined: GCC's UBSan null checks break Abseil's constexpr function-pointer
#    comparison (GCC #71962, abseil-cpp#1634); drop those sub-checks. ASan still
#    catches real null dereferences at runtime.
#  - thread: TSan cannot instrument some atomics in third-party headers
#    and -Werror turns the -Wtsan warning fatal; downgrade it.
sanitizer = get_option('sanitizer')
if sanitizer != 'none'
  sanitizer_flag = '-fsanitize=' + sanitizer
  add_project_arguments(sanitizer_flag, language: 'cpp')
  add_project_link_arguments(sanitizer_flag, language: 'cpp')
  sanitizer_parts = sanitizer.split(',')
  if sanitizer_parts.contains('address')
    add_project_arguments('-fno-omit-frame-pointer', language: 'cpp')
  endif
  if sanitizer_parts.contains('undefined')
    add_project_arguments(cpp.get_supported_arguments('-fno-sanitize=null,nonnull-attribute,returns-nonnull-attribute'), language: 'cpp')
  endif
  if sanitizer_parts.contains('thread')
    add_project_arguments(cpp.get_supported_arguments('-Wno-error=tsan'), language: 'cpp')
  endif
endif

# Search for Abseil dependencies in the system first
absl_base_dep = dependency('absl_base', required: false)
absl_log_dep = dependency('absl_log', required: false)
absl_log_initialize_dep = dependency('absl_log_initialize', required: false)
absl_flat_hash_map_dep = dependency('absl_flat_hash_map', required: false)
absl_status_dep = dependency('absl_status', required: false)
absl_statusor_dep = dependency('absl_statusor', required: false)
absl_strings_dep = dependency('absl_strings', required: false)
absl_synchronization_dep = dependency('absl_synchronization', required: false)
absl_time_dep = dependency('absl_time', required: false)

if absl_base_dep.found() and not absl_log_dep.found()
  error('Your Abseil version is too old: found absl_base but missing support for absl_log. ' +
        'Cannot fallback to subproject because that would result in a mix of Abseil versions at runtime. ' +
        'Please install a recent Abseil from source on your system and remove old libabsl & libabsl-dev packages.')
endif

if not (absl_log_dep.found() and
        absl_log_initialize_dep.found() and
        absl_flat_hash_map_dep.found() and
        absl_status_dep.found() and
        absl_statusor_dep.found() and
        absl_strings_dep.found() and
        absl_synchronization_dep.found() and
        absl_time_dep.found())
  message('System Abseil missing required components; using subproject fallback')
  abseil_proj = subproject('abseil-cpp')
  absl_log_dep = abseil_proj.get_variable('absl_log_dep')
  absl_log_initialize_dep = absl_log_dep
  absl_flat_hash_map_dep = abseil_proj.get_variable('absl_container_dep')
  absl_status_dep = abseil_proj.get_variable('absl_status_dep')
  absl_statusor_dep = absl_status_dep
  absl_strings_dep = abseil_proj.get_variable('absl_strings_dep')
  absl_synchronization_dep = abseil_proj.get_variable('absl_synchronization_dep')
  absl_time_dep = abseil_proj.get_variable('absl_time_dep')
  summary({'Abseil source': 'subproject'}, section: 'Dependencies')
else
  message('Using system Abseil dependencies')
  summary({'Abseil source': 'system'}, section: 'Dependencies')
endif

cuda_inc_path = get_option('cudapath_inc')
cuda_lib_path = get_option('cudapath_lib')
cuda_stub_path = get_option('cudapath_stub')

if cuda_lib_path == ''
    cuda_dep = dependency('cuda', required : false, modules : [ 'cudart', 'cuda' ])
    if not cuda_dep.found()
        # Meson is not detecting CUDA reliably on ARM, fallback to default
        cuda_home = run_command('bash', '-c', 'echo $CUDA_HOME').stdout().strip()
        if cuda_home == ''
            cuda_home = '/usr/local/cuda'
        endif
        cuda_lib = cuda_home + '/lib64'
        cuda_inc = cuda_home + '/include'
        cuda_stub = cuda_lib + '/stubs'
        if fs.exists(cuda_lib) and fs.exists(cuda_inc)
            cuda_dep = declare_dependency(
              link_args : ['-L' + cuda_lib, '-L' + cuda_stub, '-lcuda', '-lcudart'],
              include_directories : include_directories(cuda_inc))
            if cuda_dep.found()
                message('Found CUDA installation through fallback method:', cuda_home)
            endif
        endif
    endif
else
    message('cuda lib path ', cuda_lib_path)
    if cuda_stub_path == ''
        cuda_stub_path = cuda_lib_path + '/stubs'
    endif
    cuda_dep = declare_dependency(
    link_args : ['-L' + cuda_lib_path, '-L' + cuda_stub_path, '-lcuda', '-lcudart'],
    include_directories : include_directories(cuda_inc_path))
endif

if cuda_dep.found()
    add_languages('CUDA')
    cuda = import('unstable-cuda')
    nvcc = meson.get_compiler('cuda')

    cuda_arch_list = get_option('nixl_cuda_arch_list').strip()
    if cuda_arch_list == 'auto'
        cuda_arch_list = '80,86,89,90,100,103,120'
    endif

    nvcc_flags = []
    nvcc_flags_link = []
    nvcc_ptx_arch_num = 0
    selected_cuda_archs = []
    foreach cuda_arch : cuda_arch_list.split(',')
        cuda_arch = cuda_arch.strip()
        if cuda_arch == ''
            continue
        endif
        if cuda_arch.startswith('sm_')
            cuda_arch = cuda_arch.replace('sm_', '')
        endif

        cuda_arch_num = cuda_arch.to_int()
        if cuda_arch_num > nvcc_ptx_arch_num
            nvcc_ptx_arch_num = cuda_arch_num
        endif

        cuda_compute_arch = 'compute_' + cuda_arch
        cuda_sm_arch = 'sm_' + cuda_arch
        nvcc_flags += ['-gencode', 'arch=' + cuda_compute_arch + ',code=' + cuda_sm_arch]
        nvcc_flags_link += ['-gencode=arch=' + cuda_compute_arch + ',code=' + cuda_sm_arch]
        selected_cuda_archs += [cuda_sm_arch]
    endforeach

    if selected_cuda_archs.length() == 0
        error('No CUDA targets selected')
    endif

    nvcc_ptx_arch = 'compute_' + nvcc_ptx_arch_num.to_string()
    nvcc_flags += ['-gencode', 'arch=' + nvcc_ptx_arch + ',code=' + nvcc_ptx_arch]
    nvcc_flags_link += ['-gencode=arch=' + nvcc_ptx_arch + ',code=' + nvcc_ptx_arch]

    add_project_arguments(nvcc_flags, language: 'cuda')

    # Refer to https://mesonbuild.com/Cuda-module.html
    add_project_arguments('-forward-unknown-to-host-compiler', language: 'cuda')
    add_project_arguments('-rdc=true', language: 'cuda')
    # Build all CUDA targets with C++20 to match the core's standard and ABI.
    add_project_arguments('-std=c++20', language: 'cuda')

    add_project_link_arguments(nvcc_flags_link, language: 'cuda')

    # When a sanitizer is enabled, forward its runtime to the nvcc-driven link so
    # mixed C++/CUDA executables get libasan/libubsan/libtsan directly on their
    # link line: the sanitizer flag (added for language 'cpp' above) never
    # reaches an nvcc-driven link while its C++ TUs were compiled with
    # -fsanitize, producing "undefined reference to __asan_unregister_globals
    # ... libasan.so: DSO missing from command line". nvcc's -Xcompiler treats
    # commas as argument separators, so forward each sanitizer part on its own
    # -Xcompiler instead of -fsanitize=address,undefined.
    if sanitizer != 'none'
        foreach _san_part : sanitizer_parts
            add_project_link_arguments('-Xcompiler=-fsanitize=' + _san_part, language: 'cuda')
        endforeach
    endif
    message('nvcc version: ' + nvcc.version())
    message('CUDA targets: ' + ', '.join(selected_cuda_archs) + ' + ' + nvcc_ptx_arch)

    # Set the Python CUDA-specific wheel directory
    cuda_version_major = nvcc.version().split('.')[0]
    if cuda_version_major == '12'
        cuda_wheel_dir = 'nixl_cu12'
    elif cuda_version_major == '13'
        cuda_wheel_dir = 'nixl_cu13'
    else
        error('Unsupported CUDA version: ' + cuda_version_major)
    endif
else
    warning('CUDA not found. Building without CUDA support.')
    cuda_wheel_dir = 'nixl_cu12'
endif

# Allow callers (e.g. the VACC build) to override the wheel variant suffix
# without otherwise affecting the build. Non-empty value wins over the
# autodetected CUDA-major value above: e.g. -Dwheel_variant=vacc -> nixl_vacc.
wheel_variant = get_option('wheel_variant').strip()
if wheel_variant != ''
    cuda_wheel_dir = 'nixl_' + wheel_variant
endif

# Check for etcd-cpp-api - use multiple methods for discovery
etcd_dep = dependency('etcd-cpp-api', required : false)
etcd_inc_path = get_option('etcd_inc_path')
etcd_lib_path = get_option('etcd_lib_path')
if not etcd_dep.found() and etcd_lib_path != ''
    etcd_lib = cpp.find_library('etcd-cpp-api', dirs: etcd_lib_path)
    if etcd_lib.found()
        if cpp.has_header('etcd/Client.hpp', args : '-I' + etcd_inc_path)
            etcd_inc = include_directories(etcd_inc_path, is_system: true)
            etcd_dep = declare_dependency(
                        include_directories : etcd_inc,
                        dependencies : etcd_lib)
        endif
    endif
endif

if etcd_dep.found()
    add_project_arguments('-DHAVE_ETCD', language: 'cpp')
else
    message('ETCD CPP API library not found, will disable etcd support')
endif

prefix_path = get_option('prefix')
prefix_inc = prefix_path + '/include'

# Configure NDEBUG for release builds
if get_option('buildtype') == 'release'
    # Used by Abseil to strip DCHECK assertions and DVLOG at compile time
    add_project_arguments('-DNDEBUG', language: 'cpp')
endif

# ---- Tracing (nixl::trace) -------------------------------------------------
# The facade itself is always compiled into libnixl when with_trace is set.
# Backend trace plugins were removed with the plugin cleanup; external
# NIXL_TRACE_BACKENDS plugins may still be loaded at runtime by the caller.
nixl_trace_enabled = get_option('with_trace')
nixl_trace_nvtx_enabled = false

if nixl_trace_enabled
    # 'cuda' is only an enabled language when cuda_dep.found() (add_languages('CUDA')
    # above); passing it unconditionally breaks a non-CUDA with_trace configure.
    nixl_trace_arg_langs = ['cpp']
    if cuda_dep.found()
        nixl_trace_arg_langs += ['cuda']
    endif
    add_project_arguments('-DNIXL_TRACE_ENABLED', language: nixl_trace_arg_langs)

    summary({
        'Tracing facade'      : nixl_trace_enabled,
    }, section: 'Tracing', bool_yn: true)
endif

static_plugins = []

# Check for static plugins, then set compiler flags to enable
if get_option('static_plugins') != ''
    static_plugins = get_option('static_plugins').split(',')
    foreach p : static_plugins
        flagname = '-DSTATIC_PLUGIN_' + p
        add_project_arguments(flagname, language: 'cpp')
    endforeach
endif

# Define a specific plugin directory
plugin_install_dir = join_paths(get_option('libdir'), 'plugins')
plugin_build_dir = meson.current_build_dir()

# Add to global args so plugin managers can find it
if get_option('buildtype') == 'debug'
    add_project_arguments('-DNIXL_USE_PLUGIN_FILE="' + plugin_build_dir + '/pluginlist"',  language: 'cpp')
    plugfile = join_paths(plugin_build_dir, 'pluginlist')
    run_command('truncate', '-s 0', plugfile, check: true)
endif

nixl_inc_dirs = include_directories('src/api/cpp', 'src/api/cpp/backend', 'src/infra', 'src/core', 'src/core/telemetry')
plugins_inc_dirs = include_directories('src/plugins')
utils_inc_dirs = include_directories('src/utils')

subdir('src')

if get_option('install_headers')
  install_headers('src/api/cpp/nixl.h', install_dir: prefix_inc)
  install_headers('src/api/cpp/nixl_types.h', install_dir: prefix_inc)
  install_headers('src/api/cpp/nixl_params.h', install_dir: prefix_inc)
  install_headers('src/api/cpp/nixl_descriptors.h', install_dir: prefix_inc)
  install_headers('src/utils/serdes/serdes.h', install_dir: prefix_inc + '/utils/serdes')
  install_headers('src/utils/common/nixl_time.h', install_dir: prefix_inc + '/utils/common')
  install_headers('src/utils/common/nixl_log.h', install_dir: prefix_inc + '/utils/common')
  install_headers('src/api/cpp/backend/backend_engine.h', install_dir: prefix_inc + '/backend')
  install_headers('src/api/cpp/backend/backend_aux.h', install_dir: prefix_inc + '/backend')
  install_headers('src/api/cpp/backend/backend_plugin.h', install_dir: prefix_inc + '/backend')
  install_headers('src/core/transfer_request.h', install_dir: prefix_inc)
  install_headers('src/core/agent_data.h', install_dir: prefix_inc)
  install_headers('src/infra/mem_section.h', install_dir: prefix_inc)
  install_headers('src/core/telemetry/telemetry_event.h', install_dir: prefix_inc)
endif
