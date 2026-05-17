#!/usr/bin/env bash
# 用 Singularity/Apptainer + xvfb 跑评测（适合无 sudo、宿主机 Mesa 易 signal 11 的环境）。
#
# 1) conda activate 你的 gembench
# 2) export SINGULARITY_SIF=/绝对路径/xxx.sif
# 3) export COPPELIASIM_ROOT=/绝对路径/CoppeliaSim_Edu_V4_1_0_Ubuntu20_04
# 4) 可选: export CUDA_VISIBLE_DEVICES=0
# 5) bash scripts/eval_via_singularity.example.sh smoke
#
# 可选: export CONTAINER_CMD=apptainer
# 可选: export SINGULARITY_BIND=/ssd/youwu,$HOME  （逗号分隔，会 bind 为 宿路径:宿路径）

set -euo pipefail

CMD="${CONTAINER_CMD:-singularity}"
if ! command -v "$CMD" &>/dev/null; then
  CMD="apptainer"
fi

: "${SINGULARITY_SIF:?请先 export SINGULARITY_SIF=/绝对路径/镜像.sif}"
: "${CONDA_PREFIX:?请先 conda activate 你的 gembench}"
: "${COPPELIASIM_ROOT:?请先 export COPPELIASIM_ROOT=.../CoppeliaSim_Edu_V4_1_0_Ubuntu20_04}"

REPO="${REPO:-/ssd/youwu/cs/robot-3dlotus}"
PYTHON_BIN="${PYTHON_BIN:-$CONDA_PREFIX/bin/python}"

unset LD_LIBRARY_PATH
export LD_LIBRARY_PATH="${COPPELIASIM_ROOT}:${CONDA_PREFIX}/lib"
if [[ -d "${CONDA_PREFIX}/targets/x86_64-linux/lib" ]]; then
  export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${CONDA_PREFIX}/targets/x86_64-linux/lib"
fi
export QT_QPA_PLATFORM_PLUGIN_PATH="${COPPELIASIM_ROOT}"

export SINGULARITYENV_LD_LIBRARY_PATH="${LD_LIBRARY_PATH}"
export SINGULARITYENV_COPPELIASIM_ROOT="${COPPELIASIM_ROOT}"
export SINGULARITYENV_QT_QPA_PLATFORM_PLUGIN_PATH="${COPPELIASIM_ROOT}"
export SINGULARITYENV_CUDA_VISIBLE_DEVICES="${CUDA_VISIBLE_DEVICES:-0}"
export SINGULARITYENV_HF_HOME="${HF_HOME:-$HOME/.cache/huggingface}"
[[ -n "${SSL_CERT_FILE:-}" ]] && export SINGULARITYENV_SSL_CERT_FILE="${SSL_CERT_FILE}"
[[ -n "${CLIP_PRETRAINED_PATH:-}" ]] && export SINGULARITYENV_CLIP_PRETRAINED_PATH="${CLIP_PRETRAINED_PATH}"

BIND="${SINGULARITY_BIND:-/ssd/youwu,$HOME}"
BIND_ARG=(--bind "$BIND")

MODE="${1:-smoke}"
cd "$REPO"

run_py() {
  "$CMD" exec --nv "${BIND_ARG[@]}" --pwd "$REPO" "$SINGULARITY_SIF" \
    xvfb-run -a "$PYTHON_BIN" "$@"
}

if [[ "$MODE" == "smoke" ]]; then
  echo '["push_button+13"]' > /tmp/taskvars_smoke.json
  run_py genrobo3d/evaluation/eval_simple_policy_server.py \
    --expr_dir data/experiments/gembench/3dlotus/v1 \
    --ckpt_step 150000 \
    --num_workers 1 \
    --taskvar_file /tmp/taskvars_smoke.json \
    --seed 200 \
    --num_demos 2 \
    --microstep_data_dir data/gembench/test_dataset/microsteps/seed200
elif [[ "$MODE" == "test_l2" ]]; then
  mkdir -p data/experiments/gembench/3dlotus/v1/videos_test_l2_seed200
  run_py genrobo3d/evaluation/eval_simple_policy_server.py \
    --expr_dir data/experiments/gembench/3dlotus/v1 \
    --ckpt_step 150000 \
    --num_workers 2 \
    --taskvar_file assets/taskvars_test_l2.json \
    --seed 200 \
    --num_demos 20 \
    --microstep_data_dir data/gembench/test_dataset/microsteps/seed200 \
    --record_video \
    --video_dir data/experiments/gembench/3dlotus/v1/videos_test_l2_seed200
else
  echo "用法: $0 smoke | test_l2"
  exit 1
fi
