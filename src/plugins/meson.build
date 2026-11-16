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

# UCCL is the only backend plugin in this tree (v1.5.2-vacc lineage).
cc = meson.get_compiler('cpp')
libuccl_p2p = cc.find_library('uccl_p2p', required: false)
if enabled_plugins.get('UCCL')
    if not libuccl_p2p.found() and is_explicit_enable
        error('UCCL plugin requested but uccl_p2p library not found')
    elif libuccl_p2p.found()
        subdir('uccl')
    endif
endif
