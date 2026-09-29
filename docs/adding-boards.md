# 新增板子指南

本文档的目标是：**模板已存在，你只想加一块新板子**——从头到尾的操作清单。

## 决策树

```
新板子的 STM32Cube 包是否自带在 gcc/linker/ 下提供的通用 .ld ?
  |
  +--- 是 (如 F1 的官方包自带 STM32F103XB_FLASH.ld)
  |     +--- 在 BOARD_LINKER_FILE 写文件名 (模板会直接拷贝 + 注入 PHDRS)
  |
  +--- 否 (如 F4 官方包只有 startup.s, 没有通用 .ld)
        +--- 在 linker/ 下自建一个 .ld
        +--- 在 BOARD_LINKER_IN 写工程内相对路径
```

## 前置确认清单

动手前先回答这几个问题（答案填进 `.cmake` 文件里）：

| # | 问题 | 示例 (F1) | 示例 (F4) |
|---|------|----------|----------|
| 1 | 怎么称呼这块板？(B  | stm32f103c8t6 | stm32f407vgtx |
| 2 | 芯片系列是 F 几？ | F1 | F4 |
| 3 | Cub 包里设备族目录名是 STM32F?xx？ | 1 | 4 |
| 4 | MCU 内核 | cortex-m3 | cortex-m4 |
| 5 | 浮点模式 | soft | hard |
| 6 | 头文件中的芯片宏 | STM32F103xB | STM32F407xx |
| 7 | 系统时钟 Hz | 72000000U | 168000000U |
| 8 | led 那一行的 APB clock en 调用 | LL_APB2... | LL_AHB1... |
| 9 | pyOCD 能识别的 target 名字 | stm32f103c8 | stm32f407vg |
| 10 | Cube 包里有通用 .ld？ | 有 -> BOARD_LINKER_FILE | 没有 -> BOARD_LINKER_IN + linker/<board>.ld |

## 正式操作 (4 步)

### Step 1 — 新建 `cmake/boards/<板子ID>.cmake`

复制最接近的那个已有文件，按上面的决策树只改数值：

```cmake
# <板子全称> 板级参数 (本机路径无关; STM32Cube 官网下载)
# 本机 Cube 根路径由 env.conf 注入：CUBE_F<FAMILY>_DIR
set(BOARD_NAME          "STM32F103C8T6")
set(BOARD_CHIP          "F1")
set(BOARD_CHIP_NUMBER   "1")
set(BOARD_LL_PREFIX     "stm32f1")
set(BOARD_MCU_CORE      "cortex-m3")
set(BOARD_MCU_FLOAT     "soft")
set(BOARD_MCU_DEFINE    "STM32F103xB")

# 链接脚本策略 (二选一, 详见下方 "链接脚本策略")
set(BOARD_LINKER_FILE   "STM32F103XB_FLASH.ld")
#set(BOARD_LINKER_IN    "${CMAKE_CURRENT_LIST_DIR}/../../linker/<board>.ld")

set(BOARD_LED_CLK_EN    "LL_APB2_GRP1_EnableClock(LL_APB2_GRP1_PERIPH_GPIOC)")
set(BOARD_SYS_CLK       72000000U)
set(BOARD_PYOCD_TARGET  "stm32f103c8")
```

> CMakeLists.txt 用 `BOARD_CHIP_NUMBER` 拼 Cube 子目录名。
> 如果不显式声明 `BOARD_CHIP_NUMBER`，会回退为与 `BOARD_CHIP` 相同，
> 比如 `F1` -> `STM32FF1xx`，导致路径错误。
> 所以**每个新文件都必须显式声明 `BOARD_CHIP_NUMBER`**。

### Step 2 — 链接脚本 (按决策树二选一)

#### 选项 A：包里有通用模板 (`BOARD_LINKER_FILE`)

类似 F1，你直接声明名字即可。CMake 会：

1. 把包里的原始文件拷贝到 `build/<BOARD_NAME>.ld`
2. 改 flash 长度 (如 F1 默认 128K -> 64K)
3. 注入 PHDRS 把 RWX 拆成独立 program header

**你不需要做任何额外工作**。

#### 选项 B：包里没有通用模板 (`BOARD_LINKER_IN`)

你需要**自己写一个 `.ld`**。最小骨架如下（以 STM32F407 为例）：

```ld
/* linker/STM32F407VGTx.ld */

/* Entry Point */
ENTRY(Reset_Handler)

/* Highest address of the user mode stack */
_estack = 0x20020000;    /* end of 112K RAM */
_Min_Heap_Size = 0x200;
_Min_Stack_Size = 0x400;

/* Memory regions */
MEMORY
{
  FLASH (rx)  : ORIGIN = 0x08000000, LENGTH = 1024K
  RAM   (xrw) : ORIGIN = 0x20000000, LENGTH = 112K
}

/*
  PHDRS: ELF program headers
  模板 CMake 会在 configure_file 之前自动注入,
  但提前写进去可以避免 CMake 注入不完整时出错。
*/
PHDRS
{
  flash PT_LOAD FLAGS(5); /* rx */
  ram   PT_LOAD FLAGS(6); /* rw */
}

/* Sections */
SECTIONS
{
  /* startup 必须放在 flash :flash 段 */
  .isr_vector : { . = ALIGN(4); KEEP(*(.isr_vector)) . = ALIGN(4); } >FLASH :flash

  .text : { . = ALIGN(4); *(.text*) *(.glue_7*) *(.eh_frame*) . = ALIGN(4); } >FLASH :flash
  .rodata : { . = ALIGN(4); *(.rodata*) . = ALIGN(4); } >FLASH :flash

  .ARM.extab : { *(.ARM.extab*) } >FLASH :flash
  .ARM : { *(.ARM.exidx*) } >FLASH :flash

  /* .data 段：加载地址在 flash，运行地址在 ram */
  _sidata = LOADADDR(.data);
  .data : {
    . = ALIGN(4);
    _sdata = .;
    *(.data*)
    . = ALIGN(4);
    _edata = .;
  } >RAM AT> FLASH :ram

  /* .bss */
  .bss : {
    . = ALIGN(4);
    _sbss = .;
    __bss_start__ = _sbss;
    *(.bss*)
    *(COMMON)
    . = ALIGN(4);
    _ebss = .;
    __bss_end__ = _ebss;
  } >RAM :ram

  ._user_heap_stack : { ... } >RAM :ram
}
```

模板 `CMakeLists.txt` 里**如果检测到 linker 里还没有 PHDRS，会自动注入**，
并把 `} >FLASH` 改成 `} >FLASH :flash`、`} >RAM` 改成 `} >RAM :ram`、
`AT> FLASH` 改成 `AT> FLASH :ram`。所以你完全可以只写一个"普通"的 `.ld`，
不用关心 PHDRS 的语法。

### Step 3 — 检查 board_defs.h.in

`src/app/board_defs.h.in` 定义了 CMake 在生成 `build/include/board_defs.h` 时会被替换的宏。
一般不需要改，除非你要新启用一种外设（比如该板子上有一颗 QSIP flash，需要加 `BOARD_HAS_QSPI`）。

如果不需要新宏，**跳过**。

### Step 4 — 启用新板子

编辑 `env.conf`，把 `BOARD=` 改成新板子的 ID：

```diff
- BOARD="stm32f103c8t6"
+ BOARD="stm32f407vgtx"
```

然后：

```bash
./build.sh
```

## 新增板子后常见问题

| 现象 | 原因 | 解决 |
|------|------|------|
| `Neither BOARD_LINKER_IN nor BOARD_LINKER_FILE` | 两个 LINKER 变量都没设，或多个都设了 | 板级 `.cmake` 里只选一个 |
| `STM32FF1xx` 路径找不到 | 设了 `BOARD_CHIP` 但没设 `BOARD_CHIP_NUMBER` | 加 `set(BOARD_CHIP_NUMBER "1")` |
| `section .data can't be allocated in segment 0` | 没有 PHDRS 分配 `.data` 到 RAM | 要么建一个带 PHDRS 的 `.ld`，要么依赖 CMake 自动注入 |
| `KEEP(*(` 语法错误 | 手写 linker 时 `KEEP` 写成了 `K(` | 改回 `KEEP(*(…))` |
| `pyocd ... not found` | `BOARD_PYOCD_TARGET` 值在 pyOCD 里没有对应 | 执行 `pyocd pack --install stm32f1` 或 `stm32f4` |

## 测试清单

写完新板子后，确认：

- [ ] `./build.sh rebuild` 输出没有 RWX warning
- [ ] 生成的 `build/<board>.ld` 包含 `PHDRS` 块
- [ ] ./build.sh flash 烧录成功，板上 led 实际闪烁
- [ ] arm-none-eabi-size build/app.elf 显示的 flash/ram 数值与芯片手册一致
