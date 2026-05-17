#!/usr/bin/env bash
# CUDA nvcc 12.1 不支持宿主 GCC>12；通过 PyTorch 的 PYTORCH_NVCC 注入兼容选项。
exec "${CUDA_HOME:?CUDA_HOME unset}/bin/nvcc" -allow-unsupported-compiler "$@"
