#!/usr/bin/env bash
# CoppeliaSim + RLBench 在无显示器服务器上跑评测时，减轻 Mesa swrast 与相机 GL 导致 signal 11 的环境变量。
#
# 用法（先 conda activate 你的 gembench）:
#   export COPPELIASIM_ROOT=/path/to/CoppeliaSim_Edu_V4_1_0_Ubuntu20_04
#   source /path/to/robot-3dlotus/scripts/rlbench_xvfb_mesa_env.sh
#
# 然后务必用带 GLX 的 Xvfb（见 XVFB_SCREEN_OPTS）:
#   xvfb-run -a -s "$XVFB_SCREEN_OPTS" python genrobo3d/evaluation/eval_simple_policy_server.py ...
#
# 若仍 signal 11，可尝试: export MESA_GL_VERSION_OVERRIDE=4.1 后重跑。

: "${CONDA_PREFIX:?请先 conda activate gembench}"
: "${COPPELIASIM_ROOT:?请先 export COPPELIASIM_ROOT=.../CoppeliaSim_Edu_V4_1_0_Ubuntu20_04}"

unset LD_LIBRARY_PATH
export LD_LIBRARY_PATH="${COPPELIASIM_ROOT}:${CONDA_PREFIX}/lib"
if [[ -d "${CONDA_PREFIX}/targets/x86_64-linux/lib" ]]; then
  export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${CONDA_PREFIX}/targets/x86_64-linux/lib"
fi
export QT_QPA_PLATFORM_PLUGIN_PATH="${COPPELIASIM_ROOT}"

export LP_NUM_THREADS="${LP_NUM_THREADS:-1}"
export mesa_glthread="${mesa_glthread:-false}"
export __GL_THREADED_OPTIMIZATIONS="${__GL_THREADED_OPTIMIZATIONS:-0}"
export LIBGL_ALWAYS_SOFTWARE="${LIBGL_ALWAYS_SOFTWARE:-1}"
export GALLIUM_DRIVER="${GALLIUM_DRIVER:-llvmpipe}"
export MESA_GL_VERSION_OVERRIDE="${MESA_GL_VERSION_OVERRIDE:-3.3}"

# 传给 xvfb-run -s "..."（双引号内原样使用）
export XVFB_SCREEN_OPTS='-screen 0 1280x1024x24+32 +extension GLX +render -noreset'

echo "[rlbench_xvfb_mesa_env] COPPELIASIM_ROOT=${COPPELIASIM_ROOT}"
echo "[rlbench_xvfb_mesa_env] MESA_GL_VERSION_OVERRIDE=${MESA_GL_VERSION_OVERRIDE}"
echo "[rlbench_xvfb_mesa_env] 请使用: xvfb-run -a -s \"\$XVFB_SCREEN_OPTS\" python ..."
