# Drivers

外设驱动目录。每个驱动是一个独立的 `.c` 文件（配对应的 `.h`），通过 CMake 的 `GLOB_RECURSE` 自动加入构建。

## 目录规范

```
src/drivers/
├── README.md       # 本文件
├── uart1.c         # USART1 驱动（示例）
├── uart1.h
└── ...
```

## 添加新驱动

1. 新建 `xxx.c` / `xxx.h`（可选）到本目录
2. 重新 `cmake --build build` 即可，无需修改 CMakeLists.txt
3. 驱动文件顶部使用统一的 LL 头文件引用方式：

```c
#include STM32_LL_GPIO_H
#include STM32_LL_BUS_H
#include "stm32f1xx_ll_usart.h"  // 按需
```

## 当前驱动

| 文件 | 功能 | 状态 |
|------|------|------|
| —    |      | 待添加 |
