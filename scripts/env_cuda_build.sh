# 在 gembench 环境中编译 CUDA 扩展前 source 此文件（与 PyTorch cu121 及 conda nvcc 12.1 对齐）。
# 用法: conda activate gembench && source /path/to/robot-3dlotus/scripts/env_cuda_build.sh
# 默认 TORCH_CUDA_ARCH_LIST=8.0（A800/A100）；RTX 30 系可 source 前执行: export TORCH_CUDA_ARCH_LIST=8.6

export CUDA_HOME="${CONDA_PREFIX:?先 conda activate gembench}"
_PY_SITE=$(python -c "import site; print(site.getsitepackages()[0])")
SP="$_PY_SITE/nvidia"
TI="$CUDA_HOME/targets/x86_64-linux/include"
export CPATH="$SP/cuda_runtime/include:$SP/cublas/include:$SP/cusparse/include:$SP/cusolver/include:$SP/cufft/include:$SP/curand/include:$SP/cuda_nvrtc/include:$SP/cudnn/include:$TI/cccl${CPATH:+:$CPATH}"
export LD_LIBRARY_PATH="$CUDA_HOME/targets/x86_64-linux/lib:${LD_LIBRARY_PATH:-}"
export PATH="$CUDA_HOME/bin:$PATH"
export CC="$CONDA_PREFIX/bin/x86_64-conda-linux-gnu-gcc"
export CXX="$CONDA_PREFIX/bin/x86_64-conda-linux-gnu-g++"
unset PYTORCH_NVCC
export TORCH_CUDA_ARCH_LIST="${TORCH_CUDA_ARCH_LIST:-8.0}"
