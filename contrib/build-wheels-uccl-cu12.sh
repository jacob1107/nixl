#!/usr/bin/env bash
# NIXL UCCL/CUDA12 轮子两步构建：
#   步骤一（基座）：引擎文件 Dockerfile.uccl_engine_cuda12 只建到
#     wheel_base 阶段 → 产出"含 UCCL 引擎 + nvcc 包装"的基座镜像。引擎 commit/
#     依赖/该文件基座层变化时 BuildKit 自动只重建受影响层，平时全部缓存命中、
#     秒级过，因此默认每次都跑、无需手动管理缓存。
#   步骤二（轮子）：轮子文件 Dockerfile.manylinux_uccl_cuda12（维护主体）注入基座
#     → meson 自动探测命中引擎，UCCL 插件连同 libuccl_p2p 一起 vendor 进轮子。
#     NIXL 源码每次改动只重跑这一步。
# 两步日志分别 tee 到仓库根 build-base.log / build-wheels.log，便于按轮回溯。
#
# 用法（任意目录均可，脚本自动定位仓库根）：
#   bash contrib/build-wheels-uccl-cu12.sh                            # 全流程
#   SKIP_BASE=1 bash contrib/build-wheels-uccl-cu12.sh                # 基座已在，只重出轮子
#   WHL_PYTHON_VERSIONS=3.12 bash contrib/build-wheels-uccl-cu12.sh  # 缩小矩阵（必须含 3.12：
#                                                                     # 轮子层冒烟固定装 cp312 轮）
# 可覆盖：BASE_TAG / WHEELS_TAG / DIST_OUT
set -euo pipefail

# ---- 定位仓库根（docker build 的上下文必须是仓库根）------------------------------------
REPO_ROOT=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
cd "$REPO_ROOT"
[ -f meson.build ] || { echo "ERROR: 仓库根定位失败（meson.build 不在）：$REPO_ROOT"; exit 1; }

BASE_TAG="${BASE_TAG:-nixl-wheel-base:uccl-cu12}"
WHEELS_TAG="${WHEELS_TAG:-nixl-wheels:cu12}"
DIST_OUT="${DIST_OUT:-$REPO_ROOT/dist-uccl-cu12}"
PYVERS="${WHL_PYTHON_VERSIONS:-3.10,3.11,3.12,3.13,3.14}"
SKIP_BASE="${SKIP_BASE:-0}"
# 基座构建器（冻结：仅引擎/依赖变化才动）；轮子构建 = 维护主体，日常改动都落这里
BASE_DOCKERFILE="contrib/Dockerfile.uccl_engine_cuda12"
WHEELS_DOCKERFILE="contrib/Dockerfile.manylinux_uccl_cuda12"

echo "== 仓库根:   $REPO_ROOT"
echo "== 基座镜像: $BASE_TAG（$([ "$SKIP_BASE" = 1 ] && echo '跳过构建、仅自检' || echo '将构建')）"
echo "== 轮子镜像: $WHEELS_TAG"
echo "== Python:   $PYVERS"
echo "== 轮子导出: $DIST_OUT"

# ---- 步骤一：含引擎基座（引擎文件，--target wheel_base）--------------------------------
if [ "$SKIP_BASE" != 1 ]; then
    docker build \
        -f "$BASE_DOCKERFILE" \
        --target wheel_base \
        -t "$BASE_TAG" \
        . 2>&1 | tee "$REPO_ROOT/build-base.log"
fi

# 基座自检：引擎与 nvcc 包装都在——不在就别浪费步骤二的时间
docker run --rm "$BASE_TAG" ls -l /usr/local/lib/libuccl_p2p.so
docker run --rm "$BASE_TAG" sh -c \
    'test -x /workspace/.venv/bin/nvcc && /workspace/.venv/bin/nvcc --version | tail -n1'

# ---- 步骤二：轮子（轮子文件，注入基座）--------------------------------------------------
docker build \
    -f "$WHEELS_DOCKERFILE" \
    --build-arg wheel_base="$BASE_TAG" \
    --build-arg WHL_PYTHON_VERSIONS="$PYVERS" \
    -t "$WHEELS_TAG" \
    . 2>&1 | tee "$REPO_ROOT/build-wheels.log"

# 引擎命中标记必须出现：基座注入静默失效时轮子层照样"成功"，只是打一行 NOTE——
# 那样产出的是没有传输后端的轮子，必须在这里挡下。
grep -q 'UCCL plugin built (engine found in wheel_base)' "$REPO_ROOT/build-wheels.log" || {
    echo 'ERROR: 轮子层未报 "UCCL plugin built"——基座注入未生效，产物无传输后端；查 build-wheels.log'
    exit 1
}

# ---- 导出轮子 ---------------------------------------------------------------------------
rm -rf "$DIST_OUT" && mkdir -p "$DIST_OUT"
CID=$(docker create "$WHEELS_TAG")
docker cp "$CID":/workspace/nixl/dist/. "$DIST_OUT"/
docker rm "$CID" >/dev/null
ls -l "$DIST_OUT"

# ---- 抽查：轮子里确实带着 UCCL 插件与引擎 -----------------------------------------------
if command -v unzip >/dev/null; then
    W=$(ls "$DIST_OUT"/nixl_cu12-*.whl | head -1)
    echo "== $W =="
    unzip -l "$W" | grep -iE 'libplugin_UCCL|libuccl_p2p' \
        || { echo 'ERROR: 轮子里没有 UCCL 条目'; exit 1; }
fi

echo "== 完成：$DIST_OUT =="
