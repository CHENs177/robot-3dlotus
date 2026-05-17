#!/usr/bin/env bash
# 使用国内镜像按 INSTALL.md 配置 Python / CUDA 侧依赖（robot-3dlotus 根目录执行）。
# 用法:
#   conda activate /path/to/gembench   # 或你的前缀环境
#   bash scripts/setup_env_cn_mirror.sh
#
# 可选环境变量:
#   SKIP_FLASH_ATTN=1        跳过 requirements 中的 flash_attn（装完其余后再单独处理）
#   PIP_INDEX_URL            默认清华 PyPI
#   PYTORCH_INDEX_URL        默认清华 PyTorch cu121 轮子索引
#   CONDA_NVIDIA_CUDA_CHANNEL / CONDA_FORGE_CHANNEL  可换中科大、阿里等镜像前缀

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -z "${CONDA_PREFIX:-}" ]]; then
  echo "错误: 请先 conda activate 你的环境（例如 /ssd/youwu/cs/conda-envs/gembench）。" >&2
  exit 1
fi

# ---------- 镜像（可覆盖）----------
export PIP_INDEX_URL="${PIP_INDEX_URL:-https://pypi.tuna.tsinghua.edu.cn/simple}"
# PyTorch CUDA 轮子：清华 pytorch 源；若解析失败可改为官方: https://download.pytorch.org/whl/cu121
export PYTORCH_INDEX_URL="${PYTORCH_INDEX_URL:-https://mirror.tuna.tsinghua.edu.cn/pytorch/whl/cu121}"
CONDA_NVIDIA_CUDA_LABEL="${CONDA_NVIDIA_CUDA_LABEL:-https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud/nvidia/label/cuda-12.1.0}"
CONDA_FORGE="${CONDA_FORGE:-https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud/conda-forge}"

echo ">>> [1/6] conda: CUDA 12.1 元包（nvidia label，走清华 Anaconda Cloud）"
conda install -y -c "${CONDA_NVIDIA_CUDA_LABEL}" cuda

echo ">>> [2/6] conda: GCC/G++ 12（编译 CUDA 扩展，conda-forge @ 清华）"
conda install -y -c "${CONDA_FORGE}" "gcc_linux-64=12.*" "gxx_linux-64=12.*"

echo ">>> [3/6] 环境变量: CUDA_HOME / PATH / LD_LIBRARY_PATH"
export CUDA_HOME="${CONDA_PREFIX}"
export CPATH="${CUDA_HOME}/targets/x86_64-linux/include:${CPATH:-}"
export LD_LIBRARY_PATH="${CUDA_HOME}/targets/x86_64-linux/lib:${LD_LIBRARY_PATH:-}"
export PATH="${CUDA_HOME}/bin:${PATH}"

echo ">>> [4/6] pip: PyTorch 2.3 + cu121（${PYTORCH_INDEX_URL}）"
pip install torch==2.3.0 torchvision==0.18.0 torchaudio==2.3.0 \
  --index-url "${PYTORCH_INDEX_URL}"

echo ">>> [5/6] pip: torch-scatter（PyG 官方 wheel 索引；国内暂无可靠替代时保留官方）"
pip install torch-scatter==2.1.2 -f https://data.pyg.org/whl/torch-2.3.0+cu121.html

REQ_FILE="${ROOT}/requirements.txt"
if [[ "${SKIP_FLASH_ATTN:-}" == "1" ]]; then
  echo ">>> [6/6] pip: requirements.txt（已跳过 flash_attn 行）"
  grep -v '^flash_attn' "${REQ_FILE}" > /tmp/robot3dlotus_req_no_flash.txt
  pip install -r /tmp/robot3dlotus_req_no_flash.txt -i "${PIP_INDEX_URL}"
else
  echo ">>> [6/6] pip: requirements.txt（清华 PyPI）。若 flash_attn 失败，请设 SKIP_FLASH_ATTN=1 重跑本脚本末尾两步。"
  pip install -r "${REQ_FILE}" -i "${PIP_INDEX_URL}" || {
    echo "requirements 安装失败。可尝试: SKIP_FLASH_ATTN=1 bash scripts/setup_env_cn_mirror.sh" >&2
    exit 1
  }
fi

echo ">>> pip install -e .（本项目 genrobo3d）"
pip install -e "${ROOT}" -i "${PIP_INDEX_URL}"

echo ""
echo "=== Python 侧依赖已完成 ==="
python -c "import torch; print('torch', torch.__version__, 'cuda', torch.cuda.is_available())" || true
python -c "import genrobo3d; print('genrobo3d ok')" || true

echo ""
echo "下一步（INSTALL.md）:"
echo "  1) 在 dependencies/ 下载并解压 CoppeliaSim，配置 COPPELIASIM_ROOT 等到 ~/.bashrc"
echo "  2) bash scripts/setup_rlbench_and_extensions_cn_mirror.sh"
echo "若编译 chamferdist/pointnet2 报 CUDA 头文件错误，编译前执行: source scripts/env_cuda_build.sh"
