# 配置变量字典

本文档是 `env.conf` 和 `cmake/boards/*.cmake` 两款配置文件的完全变量清单。

---

## env.conf — 本机差异

此文件 gitignored，每台机器一份。

### 必须填写

| 变量 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `BOARD` | 字符串 | 选用的板子 ID，匹配 `cmake/boards/<BOARD>.cmake` 文件 | `"stm32f103c8t6"` |
| `CUBE_F1_DIR` | 本机绝对路径 | STM32CubeF1 固件包位置 | `"/Users/you/STM32CubeF1"` |
| `CUBE_F4_DIR` | 本机绝对路径 | STM32CubeF4 固件包位置 | `"/Users/you/STM32CubeF4"` |

### 可选填写

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `TOOLCHAIN_PREFIX` | `arm-none-eabi-` | GCC 工具链前缀，如 STM32CubeIDE 自带链可能为 `"arm-none-eabi-"` |
| `PYOCD_TARGET` | 自动推导 (按 BOARD) | 目标芯片标识；一般不需要填 |
| `PYOCD_F1_TARGET` | `"stm32f103c8"` | 若 `stm32f103c8t6` 自动推导的值不符合你的板子，覆盖它 |
| `PYOCD_F4_TARGET` | `"stm32f407vg"` | 同上 |

### BOARD -> PYOCD_TARGET 推导表

| BOARD | 推导结果 |
|-------|---------|
| `stm32f103c8t6` | `stm32f103c8` |
| `stm32f407vgtx` | `stm32f407vg` |

其他 BOARD 目前不支持自动推导，需手动在 `env.conf` 中写 `PYOCD_TARGET=...`。

---

## cmake/boards/*.cmake — 板级常数

此文件 git 跟踪，一份大家共享。新增板子时加文件即可。

### 必须填写 (每个 .cmake 都必须有)

| 变量 | 类型 | 说明 |
|------|------|------|
| `BOARD_NAME` | 字符串 | 板子全称 (用于 build/ 命名和 log) |
| `BOARD_CHIP` | 字符串 | 芯片系列：`"F1"` / `"F2"` / `"F4"` / `"H7"` ... |
| `BOARD_CHIP_NUMBER` | 字符串 | 芯片数字(防止拼错成 STM32FF1xx)：`"1"` / `"4"` ... |
| `BOARD_LL_PREFIX` | 小写字符串 | LL 驱动源/头文件前缀，如 `"stm32f1"`、`"stm32f4"` |
| `BOARD_MCU_CORE` | 字符串 | CPU 内核，如 `"cortex-m0"` / `"cortex-m3"` / `"cortex-m4"` / `"cortex-m7"` |
| `BOARD_MCU_FLOAT` | 字符串 | `"soft"` 或 `"hard"` |
| `BOARD_MCU_DEFINE` | 字符串 | 芯片宏定义，如 `"STM32F103xB"`、`"STM32F407xx"` |
| `BOARD_LL_PREFIX` | 小写字符串 | LL 驱动文件名前缀 |
| `BOARD_PYOCD_TARGET` | 字符串 | pyOCD 芯片 target 名 |
| `BOARD_LED_CLK_EN` | C 表达式 | 该板子上 LED 对应的外设时钟使能调用 |
| `BOARD_SYS_CLK` | 整数 + U 后缀 | 系统时钟，如 `72000000U`、`168000000U` |

### 链接脚本 (二选一)

| 变量 | 说明 |
|------|------|
| `BOARD_LINKER_FILE` | Cube 包里自带的通用 linker 模板文件名 (e.g. `"STM32F103XB_FLASH.ld"`) |
| `BOARD_LINKER_IN` | 工程内自建 linker 的绝对/相对路径 (e.g. `"${CMAKE_CURRENT_LIST_DIR}/../../linker/STM32F407VGTx.ld"`) |

### 可选

| 变量 | 说明 |
|------|------|
| `BOARD_HAS_SD` | 填写任意值表示该板子支持 SD 卡驱动 |
| 任何 `BOARD_HAS_*` 前缀 | 在 `src/app/board_defs.h.in` 中用 `@BOARD_MACRO@` 替换，用于条件编译 |

### 变量在 CMakeLists.txt 里的使用路径

```
BOARDS .cmake
  |
  +-- CUBE_F{FAMILY}_DIR  (由 env.conf)
  +-- CUBE_LIB_DIR        (按 BOARD_CHIP 选择)
  +-- BOARD_CHIP_NUMBER   (拼子目录名: STM32F{BOARD_CHIP_NUMBER}xx)
  |
  +-- 子路径:
  |     +-- STM32F{N}xx_HAL_Driver   (LL 头文件、源文件)
  |     +-- CMSIS/Include             (cmsis_gcc.h etc)
  |     +-- Device/ST/STM32F{N}xx     (stm32f{N}xx.h, system_*.c, startup_*.s)
  |
  +-- board_LED_CLK_EN     -> 进入 build/include/board_defs.h
  +-- board_sys_clk        -> 进入 build/include/board_defs.h
  +-- BOARD_LINKER_FILE/IN -> build/<BOARD_NAME>.ld  (产物)
```

## board_defs.h.in 占位符

`src/app/board_defs.h.in` 定义了 CMake 在生成 `build/include/board_defs.h` 时会被替换的宏。
这些宏必须在 `cmake/boards/*.cmake` 中 `set(...)` 对应变量。

```
@BOARD_LED_CLK_EN@       -> BOARD_LED_CLK_EN
@BOARD_SYS_CLK@         -> BOARD_SYS_CLK
```

在 `main.c` 中用 `#include "board_defs.h"` 即可。

## 目录与产物速查

```
build/
├── app.elf                  <- 最终产物 (gitignored)
├── app.bin                  <- POST_BUILD 自动生成
├── app.hex
├── app.map
├── <BOARD_NAME>.ld           <- 从 Cube 模板或工程内  → configure_file 复制过来, PHDRS 注入
└── include/
    └── board_defs.h          <- configure_file(src/app/board_defs.h.in)
```
