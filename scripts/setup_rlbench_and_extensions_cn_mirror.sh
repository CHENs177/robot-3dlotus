#!/usr/bin/env bash
# 在 setup_env_cn_mirror.sh 成功后执行：PyRep、RLBench、chamferdist、PointNet2、llama3。
# 需要: 已激活同一 conda 环境；已设置 COPPELIASIM_ROOT（及 INSTALL.md 中的 LD_LIBRARY_PATH / QT_QPA_PLATFORM_PLUGIN_PATH）。
# 可选: GITHUB_URL_PREFIX=https://ghproxy.com/https://github.com  （按机房规定使用）

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -z "${CONDA_PREFIX:-}" ]]; then
  echo "错误: 请先 conda activate 环境。" >&2
  exit 1
fi

if [[ -z "${COPPELIASIM_ROOT:-}" ]]; then
  echo "警告: 未设置 COPPELIASIM_ROOT。请先解压 CoppeliaSim 并 export，否则 PyRep/RLBench 可能无法正常导入。" >&2
  echo "  export COPPELIASIM_ROOT=/path/to/CoppeliaSim_Edu_V4_1_0_Ubuntu20_04" >&2
fi

export PIP_INDEX_URL="${PIP_INDEX_URL:-https://pypi.tuna.tsinghua.edu.cn/simple}"
GH="${GITHUB_URL_PREFIX:-https://github.com}"

export CUDA_HOME="${CONDA_PREFIX}"
export CPATH="${CUDA_HOME}/targets/x86_64-linux/include:${CPATH:-}"
export LD_LIBRARY_PATH="${CUDA_HOME}/targets/x86_64-linux/lib:${LD_LIBRARY_PATH:-}"
export PATH="${CUDA_HOME}/bin:${PATH}"

mkdir -p "${ROOT}/dependencies"
cd "${ROOT}/dependencies"

clone_or_skip() {
  local dir="$1"
  local url="$2"
  if [[ -d "$dir" ]]; then
    echo "已存在 ${dir}，跳过 clone。"
  else
    git clone --depth 1 "${url}" "${dir}"
  fi
}

echo ">>> PyRep"
clone_or_skip PyRep "${GH}/cshizhe/PyRep.git"
(
  cd PyRep
  pip install -r requirements.txt -i "${PIP_INDEX_URL}"
  pip install . -i "${PIP_INDEX_URL}"
)

echo ">>> RLBench（rjgpinel）"
clone_or_skip RLBench "${GH}/rjgpinel/RLBench.git"
(
  cd RLBench
  pip install -r requirements.txt -i "${PIP_INDEX_URL}"
  pip install . -i "${PIP_INDEX_URL}"
)

echo ">>> 编译前可选: source ${ROOT}/scripts/env_cuda_build.sh"
if [[ -f "${ROOT}/scripts/env_cuda_build.sh" ]]; then
  # shellcheck source=/dev/null
  source "${ROOT}/scripts/env_cuda_build.sh"
fi

echo ">>> chamferdist"
clone_or_skip chamferdist "${GH}/cshizhe/chamferdist.git"
(
  cd chamferdist
  python setup.py install
)

echo ">>> Pointnet2_PyTorch（pointnet2_ops_lib）"
clone_or_skip Pointnet2_PyTorch "${GH}/cshizhe/Pointnet2_PyTorch.git"
(
  cd Pointnet2_PyTorch/pointnet2_ops_lib
  python setup.py install
)

echo ">>> llama3（3D-LOTUS++）"
clone_or_skip llama3 "${GH}/cshizhe/llama3.git"
(
  cd llama3
  pip install -e . -i "${PIP_INDEX_URL}"
)

cd "${ROOT}"
echo ""
echo "=== 自检（在项目根目录执行 import）==="
python -c "import rlbench, pyrep; print('RLBench/PyRep ok')" || echo "若失败，检查 COPPELIASIM_ROOT 与 LD_LIBRARY_PATH。"
python -c "import chamferdist; import pointnet2_ops; print('chamferdist / pointnet2_ops ok')" || echo "若失败，检查 CUDA 编译日志并重试 source scripts/env_cuda_build.sh 后重装对应包。"
