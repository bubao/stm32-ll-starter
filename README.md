# stm32-ll-starter

> LL 驱动 + CMake 构建 + pyOCD 烧录调试。零硬编码路径，通过 `env.conf` + `cmake/boards/*.cmake` 把本机差异、板级常数、通用构建逻辑三层解耦，便于跨机器复用（详见 [docs/architecture.md](docs/architecture.md)）。

## 项目结构

```
.
├── CMakeLists.txt              # 构建主文件（动态读取 BOARD / Cube 路径）
├── build.sh                    # 一键编译 / 烧录脚本（读取 env.conf 后调用 CMake）
├── env.conf                    # 本机配置（gitignored：主机路径、工具链、板子选择）
├── env.conf.example            # 配置文件模板（提交到 git）
├── docs/                       # 深度文档
│   ├── architecture.md         # 三层架构 / 设计动机 / 数据流
│   ├── adding-boards.md        # 新增板子完整指南（含 LINKER 策略、PHDRS、排错清单）
│   └── config-reference.md     # env.conf + boards/.cmake 变量字典
├── cmake/
│   ├── toolchain-arm-none-eabi.cmake
│   └── boards/                 # 板级参数（纯芯片常数，不含本机路径）
│       ├── stm32f103c8t6.cmake
│       └── stm32f407vgtx.cmake
├── linker/                     # 工程内自建的链接脚本（F4 需要，Cube 包不提供通用模板）
│   └── STM32F407VGTx.ld
├── src/
│   ├── app/
│   │   ├── main.c              # 业务入口
│   │   └── board_defs.h.in     # 板级宏的头文件模板（CMake -> build/include/board_defs.h）
│   └── drivers/                # 外设驱动（uart, gpio, i2c 等）
└── .vscode/                    # VS Code 调试配置
```

LL 驱动、CMSIS、startup、system 不复制源码到工程中，通过 `env.conf` 中指明的本机 STM32Cube 包路径由 CMake 编译时引用。STM32Cube 固件包托管在 GitHub（ST 官方镜像）：

| F1 | https://github.com/STMicroelectronics/STM32CubeF1 |
|----|----------------------------------------------------|
| F4 | https://github.com/STMicroelectronics/STM32CubeF4 |

```bash
git clone https://github.com/STMicroelectronics/STM32CubeF1.git
git clone https://github.com/STMicroelectronics/STM32CubeF4.git
```

或作为 submodule（推荐，版本锁定）：

```bash
git clone --recurse-submodules <本项目的git地址>
git submodule update --init --recursive
```

## 1 快速开始（克隆后三步搞定）

```bash
# 1. 拷贝本机配置文件，然后编辑为自己机器的实际路径
cp env.conf.example env.conf
vim env.conf          # 修改 CUBE_F1_DIR / CUBE_F4_DIR / BOARD

# 2. 编译
./build.sh

# 3. 烧录（同时会自动编译）
./build.sh flash
```

> `env.conf` 已加入 `.gitignore`，每台机器各自维护一份，不会污染 git。

---

## 2 编译 & 烧录

### 使用 build.sh（推荐）

```bash
./build.sh           # 编译
./build.sh flash     # 编译 + pyOCD 烧录并复位
./build.sh clean     # 清理 build/
./build.sh rebuild   # 清理 + 重新编译
```

### 手动调用

```bash
cmake -S . -B build \
    -DCMAKE_TOOLCHAIN_FILE=cmake/toolchain-arm-none-eabi.cmake \
    -DBOARD=stm32f103c8t6 \
    -DCUBE_F1_DIR=/path/to/STM32CubeF1
cmake --build build
cmake --build build --target flash
```

---

## 3 安装依赖

### macOS

```bash
brew install cmake arm-none-eabi-gcc
pip3 install -U pyocd
brew install minicom          # 可选，用于串口
```

### Linux（Ubuntu / Debian）

```bash
sudo apt update
sudo apt install cmake gcc-arm-none-eabi libnewlib-arm-none-eabi
pip3 install -U pyocd
sudo apt install minicom      # 可选，用于串口
```

> Fedora / CentOS 等换用 `dnf`：`dnf install cmake arm-none-eabi-gcc-cs arm-none-eabi-newlib`

### Windows — MSYS2（推荐）

1. 下载安装 [MSYS2](https://www.msys2.org/)
2. 在 UCRT64 终端：

```bash
pacman -S mingw-w64-ucrt-x86_64-cmake mingw-w64-ucrt-x86_64-arm-none-eabi-gcc
pip install -U pyocd
pacman -S mingw-w64-ucrt-x86_64-toolchain   # 含 make 等常用工具
```

### Windows — 备选

不装 MSYS2 也照样能用，三条路任选：

| 路径 | 操作 | 使用的命令 |
|------|------|-----------|
| **WSL2** | 装好 Ubuntu 子系统后完全照抄上方 Linux 章节 | 原生 `bash ./build.sh` |
| **STM32CubeIDE 自带链** | 工具链已集成在 IDE 里，拿过来用 | `TOOLCHAIN_PREFIX` 填 CubeIDE 内 gcc 路径 |
| **arm-gnu-toolchain 直装包** | 从 [developer.arm](https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads) 下解压包扔到本地 | 同上 |

> **项目只有 `build.sh`，没有 `.cmd` / `.psi` 脚本**——不是因为忘了写，而是：MSYS2、WSL2、原生 Linux、macOS 全部都是 Bash 入口，一份 `build.sh` 到处跑。CMD/PowerShell 外加一个三行的 wrapper 即可打通，无需维护多份副本造成真相漂移。

如果你执着于原生 Windows CMD，一个最小 `build.cmd` 示例：

```batch
@echo off
where cmake >nul 2>&1 || (echo [ERROR] cmake not in PATH & exit /b 1)
C:\msys64\usr\bin\bash.exe -lc "cd '%~dp0' && ./build.sh %*"
```

前提：装了 MSYS2，替换 `C:\msys64\...` 为你本机 bash 路径，其余不变。

插上板子后运行 `pyocd list`，应能识别板载 ST-Link / DAPLink。

> 如果提示缺少芯片包：
```bash
pyocd pack --update
pyocd pack --install stm32f1
pyocd pack --install stm32f4
```

---

## 4 调试

### VS Code Cortex-Debug（按 F5）

自动后台启动 `pyocd gdbserver`，支持断点、单步、寄存器查看。

### 纯终端调试

终端 1 — 启动 GDB server：
```bash
pyocd gdbserver -t stm32f103c8
```

终端 2 — 连接 GDB：
```bash
arm-none-eabi-gdb build/app.elf
(gdb) target remote localhost:3333
(gdb) monitor reset halt
(gdb) load
(gdb) continue
```

### 串口监控

ST-Link 自带虚拟 CDC 串口（USART1 PA9/PA10）：
```bash
ls /dev/tty.usbmodem*
minicom -D /dev/tty.usbmodemXXXX -b 115200
```

---

## 5 切换调试器

**不需要改 CMake，不需要改 launch.json。** pyOCD 自动识别当前插上的 probe。

---

## 换芯片 / 增板子

详细操作指南见 [docs/adding-boards.md](docs/adding-boards.md)，下面是一份摘要。

### 切换到已有板子

改 `env.conf` 一行 `BOARD="stm32f407vgtx"`，再 `./build.sh` 即可。

### 增加新板子

1. 新建 `cmake/boards/<板子ID>.cmake`（参考已有文件）。
2. 若 Cube 包不带通用 linker（如 F4），需并在工程下 `linker/<板子>.ld` 自建 linker，在板级 cmake 里用 `BOARD_LINKER_IN` 指定路径（模板会自动注入 PHDRS）。
3. `env.conf` 改 `BOARD="<板子ID>"`。
4. `./build.sh`。

> 新增必读：[docs/adding-boards.md](docs/adding-boards.md)（含 LINKER 策略决策树、PHDRS 解释、测试清单、常见报错解决）。

---

## 配置与变量字典

- `env.conf` 变量：[CUBE_F1_DIR / CUBE_F4_DIR / TOOLCHAIN_PREFIX / BOARD / PYOCD_* 等](docs/config-reference.md#envconf--本机差异)
- `cmake/boards/*.cmake` 变量：[BOARD_NAME / CHIP / MCU_CORE / LINKER_FILE / LINKER_IN 等](docs/config-reference.md)
- `board_defs.h.in` 占位符如何被替换：[config-reference 中 board_defs 一节](docs/config-reference.md#board_defshin-占位符)

---

## pyOCD vs OpenOCD

**pyOCD 优点**
- 不用维护 `.cfg` 脚本
- ST-Link / DAPLink 自动识别，换硬件零改动
- CMSIS-Pack 内置寄存器 SVD，调试看寄存器方便

**pyOCD 缺点**
- 依赖 Python 环境
- 冷门芯片支持弱（但 STM32F1/F4 完全没问题）
