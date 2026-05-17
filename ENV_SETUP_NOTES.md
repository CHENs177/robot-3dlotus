# robot-3dlotus 环境配置记录（本次会话）

本文档根据一次完整的环境配置过程整理，对应官方说明见 [README.md](README.md) 与 [INSTALL.md](INSTALL.md)。若你更换机器或重装环境，可按顺序对照；遇到编译错误时可优先查看「常见问题」一节。

---

## 1. 目标环境概览

| 项目 | 版本 / 说明 |
|------|-------------|
| Conda 环境名 | `gembench` |
| Python | 3.10 |
| PyTorch | 2.3.0+cu121（GPU 为 RTX 3060，计算能力 8.6） |
| CUDA（PyTorch 侧） | 12.1 |
| 系统 | WSL2 + Ubuntu，工程路径在 **`/home/chens_177/robot-3dlotus`**（Linux 原生磁盘，非 `/mnt/c/`） |

---

## 2. 已执行的主要操作（按大致顺序）

### 2.1 Conda 与 PyTorch

1. `conda create -n gembench python=3.10`
2. `conda install nvidia/label/cuda-12.1.0::cuda`（体积较大，下载需较长时间）
3. 安装 PyTorch cu121 轮子：`pip install torch==2.3.0 torchvision==0.18.0 torchaudio==2.3.0 --index-url https://download.pytorch.org/whl/cu121`
4. **`torch-scatter`**：源码编译会因 conda 中 **nvcc 与 PyTorch 所用 CUDA 版本声明不一致**失败；改用 PyG 官方 wheel：  
   `pip install torch-scatter==2.1.2 -f https://data.pyg.org/whl/torch-2.3.0+cu121.html`
5. 安装 **`requirements.txt`**（可先去掉 `flash_attn` 一行，最后再装 flash-attn）
6. **`pip install -e .`** 安装本项目包 `genrobo3d`

### 2.2 对齐 nvcc 与 PyTorch（CUDA 12.1）

- 初始 conda 环境下 **`nvcc` 为 12.1**，但 **`targets/.../cuda_runtime_api.h` 中 `CUDART_VERSION` 曾为 13.x**，与 nvcc 12.1 混用会导致 CCCL/Thrust 报「编译器与头文件不兼容」。
- 通过 **`conda install cuda-nvcc=12.1.105 -c nvidia`** 等方式保证命令行 **`nvcc --version`** 为 **12.1**，并与 PyTorch **2.3+cu121** 一致。

### 2.3 编译扩展用的 GCC（重要）

- 宿主机 **GCC 13** 超出 CUDA 12.1 nvcc 官方支持的上限（一般为 GCC ≤12）；仅用 `-allow-unsupported-compiler` 仍可能与 **glibc / libstdc++** 组合出 `_Float32` 等错误。
- **处理**：在 `gembench` 环境中安装 **conda-forge 的 GCC/G++ 12**，例如：  
  `conda install -y -c conda-forge "gcc_linux-64=12.*" "gxx_linux-64=12.*"`  
  编译时使用：  
  `CC=$CONDA_PREFIX/bin/x86_64-conda-linux-gnu-gcc`，  
  `CXX=$CONDA_PREFIX/bin/x86_64-conda-linux-gnu-g++`。

### 2.4 RLBench / CoppeliaSim / PyRep

- 在仓库下创建 **`dependencies/`**，按 [INSTALL.md](INSTALL.md)：
  - 下载并解压 **CoppeliaSim Edu V4_1_0 Ubuntu20_04**
  - `git clone` **PyRep**（`cshizhe/PyRep`）、**RLBench**（`rjgpinel/RLBench`）
- 设置环境变量后安装：
  - `export COPPELIASIM_ROOT=<解压目录>`
  - `export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$COPPELIASIM_ROOT`
  - `export QT_QPA_PLATFORM_PLUGIN_PATH=$COPPELIASIM_ROOT`
  - 分别在 PyRep、RLBench 目录：`pip install -r requirements.txt && pip install .`

### 2.5 chamferdist、PointNet2、llama3

- 在 `dependencies/` 下克隆：
  - `chamferdist`（`cshizhe/chamferdist`）
  - `Pointnet2_PyTorch`（`cshizhe/Pointnet2_PyTorch`）
  - `llama3`（`cshizhe/llama3`）
- **chamferdist** 与 **pointnet2_ops**：在对应子目录执行 `python setup.py install`（INSTALL 写法）；**llama3** 使用 `pip install -e .`。

### 2.6 CUDA 头文件路径（`CPATH`，见下文「问题解决」）

编译 **chamferdist / pointnet2** 等扩展时，**不要**把整个  
`$CONDA_PREFIX/targets/x86_64-linux/include`  
无条件放在 `CPATH` 最前：其中包含 **CUDA 13** 时代的头文件，与 **nvcc 12.1** 混用会触发 `cuda_fp6.hpp`、`cublas_api.h` 等错误。

**可行做法**：优先使用 **PyTorch 随 wheels 安装的 `site-packages/nvidia/*/include`**（与 cu121 一致），并仅追加 **`targets/.../include/cccl`** 以提供 **Thrust**（`thrust/complex.h`）。项目中已添加脚本：

- **`scripts/env_cuda_build.sh`**  
  用法：`conda activate gembench && source /path/to/robot-3dlotus/scripts/env_cuda_build.sh`  
  再执行需要编译的命令。

### 2.7 flash_attn

- `requirements.txt` 中的 **`flash_attn==2.5.9.post1`** 若从源码编译，耗时长且对网络（下载依赖）、头文件、GCC 版本敏感。
- 本次在网络恢复后，安装过程 **自动匹配并下载了 GitHub 上的预编译 wheel**，未在本地完整走一遍编译；最终 **`flash_attn 2.5.9.post1`** 可正常 `import`。

### 2.8 Shell 持久化（CoppeliaSim）

在 **`~/.bashrc`** 末尾增加（路径按本机解压目录修改）：

```bash
export COPPELIASIM_ROOT=/home/chens_177/robot-3dlotus/dependencies/CoppeliaSim_Edu_V4_1_0_Ubuntu20_04
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:+${LD_LIBRARY_PATH}:}${COPPELIASIM_ROOT}"
export QT_QPA_PLATFORM_PLUGIN_PATH="${COPPELIASIM_ROOT}"
```

新开终端或 `source ~/.bashrc` 后生效。

### 2.9 辅助脚本

- **`scripts/env_cuda_build.sh`**：统一 `CPATH`、`CC`/`CXX`（GCC 12）、`CUDA_HOME`、`TORCH_CUDA_ARCH_LIST` 等，便于重复编译扩展。
- **`scripts/nvcc_allow_gcc.sh`**（可选）：在无法安装 GCC 12、必须用宿主 GCC 13 时，给 nvcc 增加 `-allow-unsupported-compiler`；**优先推荐仍使用 conda GCC 12**，矛盾更少。

---

## 3. 注意事项（强烈建议）

1. **WSL2 路径**  
   大规模编译（flash-attn、CUDA 扩展）务必在 **Linux 家目录**（如 `/home/用户名/...`）下进行，避免在 **`/mnt/c/`**（Windows 盘）上编译，否则 I/O 极慢且易表现为「卡死」。

2. **INSTALL.md 中的路径占位**  
   文档中的 **`$HOME/codes/robot-3dlotus`**、`sbatch` 脚本里的 **`cd $HOME/codes/robot-3dlotus`** 需改为你本机仓库路径（例如 `/home/chens_177/robot-3dlotus`），或建立符号链接。

3. **Singularity / 无头运行**  
   [INSTALL.md](INSTALL.md) 第 4、5 节与 [DATAGEN.md](DATAGEN.md) 中的 **`nvcuda_v2.sif`、`SCRATCH`** 等多为集群场景；本机 WSL 若不用 Singularity，只需按需配置 **xvfb** 等。

4. **验证导入时的当前目录**  
   不要在 **`dependencies/Pointnet2_PyTorch/pointnet2_ops_lib`** 下直接 `python -c "import pointnet2_ops"`：会优先加载源码树里的包，找不到已安装到 site-packages 的 **`_ext`**，触发 JIT，且 JIT 可能使用过时架构列表导致失败。请在项目根目录或 **`/tmp`** 等无关路径下测试。

5. **粗暴杀进程**  
   不建议随意执行 `pkill -9 python`，以免误杀其他任务；应针对具体 PID 结束异常安装进程。

---

## 4. 遇到的问题与解决情况

| 现象 | 原因 | 处理 |
|------|------|------|
| `torch-scatter` 源码编译失败（build isolation 找不到 torch） | pip 默认隔离构建环境 | 使用 PyG 官方 wheel，或 `pip install --no-build-isolation` |
| `torch-scatter` / 扩展编译报 CUDA 版本不匹配 | conda 中 nvcc 与 PyTorch 期望的 CUDA 不一致 | 对齐 **nvcc 12.1** 与 **cu121** PyTorch；或使用预编译 wheel |
| `flash_attn` / CCCL 报 `thrust/complex.h` 找不到 | Thrust 位于 **`include/cccl`** 下，旧式仅 `include` 不够 | 在 **`CPATH` 中加入 `.../targets/x86_64-linux/include/cccl`**，且注意与下面「混版本」一起处理 |
| CCCL 报「CUDA compiler and CUDA toolkit headers are incompatible」 | **`CUDART_VERSION`（头文件）与 `nvcc` 主版本不一致**（例如头文件来自 13.x，nvcc 为 12.1） | **`CPATH` 优先使用 `site-packages/nvidia/cuda_runtime/include`**；不要单独依赖 conda `targets` 里整套 13.x 头文件与 nvcc 12.1 混编 |
| chamferdist / 扩展报 `cuda_fp6.hpp` / `cublas_api.h` 等错误 | 把整个 **`targets/.../include`** 加进 `CPATH` 引入了 **CUDA 13** 库头 | 仅用 **pip 的 nvidia 各包 `include` + `targets/.../include/cccl`**，见 **`scripts/env_cuda_build.sh`** |
| nvcc 报不支持 **GCC 13/14** | 宿主或 conda 默认 g++ 过新 | 安装并使用 **conda-forge GCC/G++ 12** |
| nvcc JIT / 宿主侧 `_Float32` 等与 glibc 相关错误 | 宿主 GCC 与 nvcc/CUDA 组合不当 | 同上，优先 **GCC 12**；必要时再考虑 nvcc 包装脚本 |
| `git clone` PyRep/RLBench 失败 `RPC failed` / `early EOF` | 网络不稳定 | 换网络或 `git -c http.version=HTTP/1.1 clone`，必要时多试几次 |
| `import pointnet2_ops` 失败并触发 JIT | 在 **pointnet2 源码目录**下导入，覆盖已安装包 | 在 **`/tmp` 或项目根** 等非源码遮蔽路径下验证 |
| `flash_attn` 首次本地编译失败 | 混用头文件、网络下载不完整、GCC 版本等叠加 | 网络恢复后 **wheel 直接安装成功**；若必须源码编译，请配合 **`env_cuda_build.sh`** 与 GCC 12 |

---

## 5. 解决后的状态（截至记录时）

- Conda 环境 **`gembench`** 可用；**PyTorch 2.3+cu121**、**requirements.txt** 主依赖、**`genrobo3d`（`pip install -e .`）** 已就绪。
- **PyRep、RLBench、CoppeliaSim** 已按 INSTALL 配置；**~/.bashrc** 已写入 **COPPELIASIM** 相关变量。
- **chamferdist、pointnet2_ops、llama3** 已安装。
- **flash_attn 2.5.9.post1** 已安装并可导入（本次以 **预编译 wheel** 为主）。
- 提供 **`scripts/env_cuda_build.sh`** 供后续任何 **CUDA 扩展** 编译前 `source`。

---

## 6. 建议的自检命令（在任意目录，先 `conda activate gembench`）

```bash
python -c "import torch; print(torch.__version__, torch.cuda.is_available())"
python -c "import flash_attn; import chamferdist; import pointnet2_ops._ext; print('ok')"
```

---

## 7. 相关仓库内其他文件（环境相关）

| 文件 | 说明 |
|------|------|
| [DATAGEN.md](DATAGEN.md) | 数据生成；含 Singularity、`SCRATCH`、`sif_image` 等 |
| [challenges/CONTAINER.md](challenges/CONTAINER.md) | Docker / Apptainer 挑战赛镜像（与本地 RLBench 全量安装不同） |
| [INSTALL.md](INSTALL.md) | 官方安装主文档 |

---

*文档随一次具体安装过程整理；若你升级 PyTorch/CUDA 或更换 GPU，部分版本号与 `CPATH` 策略需重新核对。*
