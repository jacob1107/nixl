# CUDA → VACC 替换点树

基线：`1.5.2-vacc` @ `53ea39d6`（2026-11-17，工作树干净）

图例：⭐必改 / ✂️建议删 / 🔁零改动机制现成 / ➖不动 / 📝文案级 / ⚠️风险点 / 🔧新增文件（有模板）

```
nixl @ 1.5.2-vacc (53ea39d6)   工作树：干净
│
├─ meson.build                       [L158-273 CUDA 探测+nvcc 段]  🔁 零改动（无 CUDA 走 L271 警告分支）
│                                     [L278-281 wheel_variant]        -Dwheel_variant=vacc → nixl_vacc
├─ meson_options.txt                 [cudapath×3、nixl_cuda_arch_list] ➖ 死选项无害
├─ pyproject.toml                    [name=nixl-cu12]               🔁 tomlutil --wheel-name nixl-vacc
├─ nixl.pc.in / README.md / LICENSE  [无 CUDA]                       ➖ 不动
│
├─ subprojects/ (3 wrap)             [abseil/asio/tomlplusplus，无 CUDA] ➖ 不动
│
├─ src/
│   ├─ api/cpp (16) + core (39) + utils (38) + infra (4)  [无 CUDA]  ➖ 不动
│   ├─ api/python/
│   │   ├─ meson.build               [L18-21 subdir: cuda_wheel_dir] 🔁 自动装进 nixl_vacc/
│   │   └─ _api.py                   [L269/L753 文案]               📝 可选 "vacc": VRAM_SEG 别名
│   ├─ plugins/uccl/
│   │   ├─ meson.build               [L23/L31 挂 cuda_dep]          ✂️ 删掉（源码零调用，2 行）
│   │   └─ uccl_backend.{cpp,h} + uccl_plugin.cpp  [零 CUDA 调用]   ➖ 不动
│   │       └ L154 VRAM_SEG / gpu_bdf 连接串 ➖；L360 GPU IPC 块 ⚠️ VACC 句柄格式不同才适配
│   └─ bindings/python/
│       ├─ meson.build + nixl_bindings/utils.cpp  [零 CUDA]         ➖ / 🔁 不动
│       └─ nixl-meta/                ⭐ 本仓必改代码 (~30 行)
│           ├─ nixl_meta_utils.py    ⭐ +detect_vacc()（torch_vacc→env→None）
│           ├─ nixl/__init__.py      ⭐ L37 链改 ("nixl_vacc","nixl_cu13","nixl_cu12")
│           ├─ nixl/meson.build      🔁 自动得 nixl-vacc==1.5.2
│           └─ pyproject.toml.in / README.md        📝 文案
│
├─ benchmark/
│   └─ nixlbench/ (42 件)
│       ├─ meson_options.txt         [cudapath×3、ucx_path、arch_list]  ⭐ 加 vaccpath_* 选项
│       ├─ meson.build
│       │   ├ L29-35  选项读取                     ⭐ 换/加 vaccpath 读取
│       │   ├ L60-96  CUDA 探测+fabric             ⭐ VACC 探测块 ~35 行；fabric 置 false
│       │   ├ L145-150 -DHAVE_CUDA/FABRIC          ⭐ 追加 -DHAVE_VACC
│       │   ├ L157-262 ucx_device/nvcc 块          ➖ 恒关门控（ucx_path 空必不 found）
│       │   └ L283    config.h 生成                ⭐ 追加 HAVE_VACC
│       ├─ src/utils/
│       │   ├─ utils.h              [L35-62 CHECK_CUDA_ERROR×2 宏]  ⭐ 加 #if HAVE_VACC 错误宏分支
│       │   ├─ utils.cpp            [L446 VMM 门控；L980-993 D2H]    ⭐ 三段式头插 vacc 分支变四段；
│       │   │                                                          VMM 加 VACC 拒绝
│       │   ├─ neuron.h / neuron.cpp [dlopen libnrt shim，零链接期]  🔧 模板：照抄出 vacc.h/cpp（~120 行）
│       │   └─ meson.build           [neuron.cpp 在源列表]           ➖ +vacc.cpp 一行
│       ├─ src/worker/nixl/nixl_worker.cpp  [L577-655 显存分配/释放＋  ⭐ 头插 vaccMalloc/Free 分支；
│       │                             L589-638 FABRIC；L666/686/868；   fabric 置空；SetDevice 处理；
│       │                             L1932-1971 计数器 D2H]            计数器换 vaccMemcpy
│       ├─ src/kernels/              [.cu/.cuh＋meson 门控]          ➖ 恒关不动（VACC 无设备 API）
│       ├─ main.cpp / worker.cpp / nixl_mem_region.cpp / raw_cli.cpp ➖ 不动（零 CUDA）
│       │   tests/* / runtime/* / subprojects 3 wrap
│       ├─ contrib/Dockerfile (自身) [8 处 cuda]                     📝 换瀚博基座+去 cuda 传参
│       ├─ contrib/build.sh (自身)   [2 处]                          📝 同步
│       └─ README.md                 [24 处]                         📝 VACC 语境＋修 --backend 旧文案
│
├─ contrib/ (11 件全跟踪)
│   ├─ Dockerfile / Dockerfile.manylinux  [cuda-dl-base 13.0 / NGC donor]  ➖ CUDA 线专用
│   ├─ build-container.sh / build-wheel.sh / tomlutil.py / README.md  🔁 复用（--wheel-name nixl-vacc）
│   │
│   │  ══ cu12 家族五件，同骨架；VACC 变体各件：donor 段→瀚博 SDK/删、COPY cuda+ENV→删、
│   │     stub 软链→删、nvcc 包装层→整段删、arch_list→删；etcd_stack 段 CUDA 无关→照抄 ══
│   ├─ Dockerfile.core_cuda12   [211 行  donor(48)→core(55)：NIXL 核心环境]
│   │   └ COPY cuda L69 / nvcc 包装 L135-155 / arch L198
│   ├─ Dockerfile.uccl_cuda12   [264 行  donor(51)→uccl(58)＋引擎(151)：NIXL+UCCL]
│   │   └ COPY L76 / stub L160-161 / nvcc L184-204 / arch L247
│   ├─ Dockerfile.wheels_cuda12 [330 行  donor(58)→wheels(65)＋引擎(173)：轮子矩阵]
│   │   └ COPY L83 / stub L182 / nvcc L206-226 / arch L269＋302
│   │       ＋ 定名 nixl-cu12→nixl-vacc、auditwheel 清单换 VACC 库
│   ├─ Dockerfile.bench_cuda12  [494 行  donor(52)→build(59)＋引擎(152)→etcd_stack(261，并行)
│   │   │                        →bench(424)：nixlbench 镜像]
│   │   └ COPY L77 / stub L161 / nvcc L185-205 / arch L248
│   │       ＋ L482 ldd 冒烟豁免 libcuda.so.1→换豁免 VACC 运行库；etcd_stack ➖ 复用
│   └─ Dockerfile.full_cuda12   [593 行  donor(65)→wheel_base(72)→etcd_stack(234，并行)
│                                 →wheel(399)→full(518)：全能力合并]
│       └ COPY L88-91 / stub L187 / nvcc L209-230 / arch L456/490
│         ＋ nixlbench 段按 benchmark 适配后安装
│
└─ (树外) libuccl_p2p.so             ⭐⭐⭐ 引擎仓：NCCL→瀚博集合通信、
                                      cuMem/driver API→VACC device API、
                                      CUDA-IPC→VACC IPC；ibverbs RDMA ➖ 保留
```
