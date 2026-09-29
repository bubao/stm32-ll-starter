# 架构设计

## 三层分离原则

本模板把构建系统明确分成三个层次，每层只关心自己的职责，层与层之间通过**变量**解耦：

```
+--------------+        +--------------------+        +---------------------+
|  env.conf    |        | cmake/boards/*.cmke|        |   CMakeLists.txt    |
| (本机差异)   | -----> |   (板级常数)       | -----> |   (通用构建逻辑)    |
|              |  cmake |                  |  cmake |                   |
| CUBE_F1_DIR  |   -D   | BOARD_NAME       |  include| configure_file() |
| CUBE_F4_DIR  |  传授  | BOARD_MCU_CORE   |  传入   | add_executable()  |
| BOARD        |        | BOARD_LINKER_*   |        | target_*()        |
| TOOLCHAIN... |        | BOARD_SYS_CLK    |        | add_custom_target |
+--------------+        +--------------------+        +---------------------+
       ^                         ^                          ^
  gitignored                 git 跟踪                    git 跟踪
 (每台机器一份)           (一行一个板子即可复用)       (通用的，不用改)
```

| 层次 | 位置 | 谁维护 | 提交 git |
|------|------|--------|----------|
| 主机差异 | `env.conf` | 每位开发者各自 | gitignored |
| 板级常数 | `cmake/boards/*.cmake` | 新增板子时加文件 | 跟踪 |
| 通用逻辑 | `CMakeLists.txt`、`build.sh` | 模板作者 / 架构改动 | 跟踪 |

## 运行时数据流

```
./build.sh
  |
  v
读取 env.conf
  |
  +--- 解析 BOARD=xxx
  +--- 解析 CUBE_F<FAMILY>_DIR
  +--- 解析 PYOCD_TARGET (可选; 不填则按 BOARD 猜)
  |
  v
cmake -DBOARD=xxx -DCUBE_F1_DIR=... -DCUBE_F4_DIR=...
  |
  +-- CMakeLists.txt
  |     +-- include("cmake/boards/${BOARD}.cmake")
  |     |     +-- 拿到一切板级常数
  |     +-- 按 BOARD_CHIP 选择 CUBE_F<FAMILY>_DIR
  |     +-- 按 BOARD_CHIP_NUMBER 拼 Cube 子目录 (STM32F1xx / STM32F4xx, 避免 STM32FF1xx)
  |     +-- 按 BOARD_LINKER_* 选策略, 决定 linker 输入来源
  |     +-- 改 linker: 注入 PHDRS + RWX 段分配 (解决 RWX 警告)
  |     +-- 生成 build/include/board_defs.h
  |     +-- 构建 app.elf + flash target
  |
  v
build/ (产物全部 gitignored)
```

## 设计动机

| 如果没有分层 | 后果 |
|-------------|------|
| 把 Cube 路径硬编码在 CMakeLists.txt | 换台机器编译不通过；git 里全是个人路径 |
| 把板子参数写在 CMakeLists.txt | 每次换板子都要改 CMakeLists.txt，commit 污染 |
| 不区分 `BOARD_LINKER_FILE` / `BOARD_LINKER_IN` | 有人按 F4 逻辑填了 F1，路径拼错成 STM32FF1xx |

三层分离后：

- **模板作者** 只改通用逻辑（`CMakeLists.txt`、`build.sh`）。
- **板级支持作者** 只需在 `cmake/boards/` 加一个 `.cmake`，模板不动。
- **模板用户** 只关心 `env.conf`，模板代码一行不用改即可在自己机器上跑。

## 为什么不继续加 YAML / JSON 之类的配置格式

本项目的配置已经由两层分担：

| 配置内容 | 当前方案 | 没有采用 |
|---------|---------|---------|
| 本机路径选择 | shell `env.conf`，由 shell 原生 `source` | yaml / json（需要引入解析库） |
| 板级常数 | cmake script `*.cmake`，原生 `set(...)` | yaml / json（需要外部分析转到 cmake） |

对 stm32 这种 **"95% 板级信息都只有几个字符串键值"** 的场景，引入一个额外的数据格式栈**不会**降低复杂度，反而让人觉得"又多了两层抽象"。

## 相关文档

- [env.conf / boards/*.cmake 变量字典](./config-reference.md)
- [新增板子完整指南](./adding-boards.md)
