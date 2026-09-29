cmake_minimum_required(VERSION 3.20)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# ============================================================
# 板子选择（env.conf 中的 BOARD 变量由 build.sh 传入）
# ============================================================
if(NOT DEFINED BOARD)
    message(FATAL_ERROR "please set -DBOARD=<板子ID> (from env.conf)")
endif()
set(_BOARD_FILE "${CMAKE_CURRENT_LIST_DIR}/cmake/boards/${BOARD}.cmake")
if(NOT EXISTS "${_BOARD_FILE}")
    message(FATAL_ERROR "BOARD=${BOARD} 未找到：${_BOARD_FILE}")
endif()
include("${_BOARD_FILE}")

# ============================================================
# Cube 根目录 —— 由 build.sh 从 env.conf 注入
# ============================================================
if(BOARD_CHIP STREQUAL "F1" AND NOT DEFINED CUBE_F1_DIR)
    message(FATAL_ERROR "缺少 -DCUBE_F1_DIR（请在 env.conf 中填写 CUBE_F1_DIR 并由 build.sh 注入）")
elseif(BOARD_CHIP STREQUAL "F4" AND NOT DEFINED CUBE_F4_DIR)
    message(FATAL_ERROR "缺少 -DCUBE_F4_DIR（请在 env.conf 中填写 CUBE_F4_DIR 并由 build.sh 注入）")
endif()

if(BOARD_CHIP STREQUAL "F1")
    set(CUBE_LIB_DIR "${CUBE_F1_DIR}")
elseif(BOARD_CHIP STREQUAL "F4")
    set(CUBE_LIB_DIR "${CUBE_F4_DIR}")
endif()

if(NOT IS_DIRECTORY "${CUBE_LIB_DIR}")
    message(FATAL_ERROR "CUBE_LIB_DIR 路径无效：${CUBE_LIB_DIR} — 请检查 env.conf 中对应变量")
endif()

project(ll_${BOARD_CHIP} LANGUAGES C ASM)

message(STATUS "=== Board=${BOARD_NAME}  core=${BOARD_MCU_CORE}  cube=${CUBE_LIB_DIR} ===")

# ============================================================
# MCU 编译标志
# ============================================================
set(_MCU_FLAGS "-mcpu=${BOARD_MCU_CORE} -mthumb -mfloat-abi=${BOARD_MCU_FLOAT}")
if(BOARD_CHIP STREQUAL "F4")
    string(APPEND _MCU_FLAGS " -mfpu=fpv4-sp-d16")
endif()
set(CMAKE_C_FLAGS   "${_MCU_FLAGS} -Wall -Og -g")
set(CMAKE_ASM_FLAGS "${_MCU_FLAGS}")

# ============================================================
# Cube 内部子路径（STM32CubeF1 / STM32CubeF4 官方包通用布局）
# ============================================================
string(TOLOWER "${BOARD_CHIP}" _chip_lower)
set(_CUBE_LL_DIR         "${CUBE_LIB_DIR}/Drivers/STM32F${BOARD_CHIP_NUMBER}xx_HAL_Driver")
set(_CUBE_CMSIS_DIR      "${CUBE_LIB_DIR}/Drivers/CMSIS")
set(_CUBE_DEV_DIR        "${_CUBE_CMSIS_DIR}/Device/ST/STM32F${BOARD_CHIP_NUMBER}xx")

set(BOARD_LL_DIR         "${_CUBE_LL_DIR}/Inc")
set(BOARD_CMSIS_DIR      "${_CUBE_CMSIS_DIR}/Include")
set(BOARD_DEV_DIR        "${_CUBE_DEV_DIR}/Include")
set(BOARD_SYSTEM_SOURCE  "${_CUBE_DEV_DIR}/Source/Templates/system_stm32f${BOARD_CHIP_NUMBER}xx.c")
set(BOARD_STARTUP_SOURCE "${_CUBE_DEV_DIR}/Source/Templates/gcc/startup_${BOARD_MCU_DEFINE}.s")

# 链接脚本：
#   F1 — 直接取官方包模板（STM32F103XB_FLASH.ld，拷贝到 build/ 并改 Flash 为 64K）
#   F4 — BOARD_*.cmake 直接提供工程内 linker/<board>.ld 的路径
if(DEFINED BOARD_LINKER_IN)
    # F4：工程内已备好的 linker/<board>.ld 路径
    set(_LINKER_IN "${BOARD_LINKER_IN}")
elseif(DEFINED BOARD_LINKER_FILE)
    # F1：Cube 包内的模板名（STM32F103XB_FLASH.ld 等，由板级 cmake 直接声明）
    set(_LINKER_IN "${_CUBE_DEV_DIR}/Source/Templates/gcc/linker/${BOARD_LINKER_FILE}")
else()
    message(FATAL_ERROR "Neither BOARD_LINKER_IN nor BOARD_LINKER_FILE is defined — please add one in cmake/boards/${BOARD}.cmake")
endif()
set(BOARD_LINKER_OUT "${CMAKE_BINARY_DIR}/${BOARD_NAME}.ld")

configure_file("${_LINKER_IN}" "${BOARD_LINKER_OUT}" COPYONLY)
file(READ "${BOARD_LINKER_OUT}" _LD)
if(BOARD_CHIP STREQUAL "F1")
    string(REPLACE "ORIGIN = 0x08000000, LENGTH = 128K"
                    "ORIGIN = 0x08000000, LENGTH = 64K" _LD "${_LD}")
    string(REPLACE "LENGTH = 128K"                 "LENGTH = 64K" _LD "${_LD}")
endif()

# 注入 PHDRS，分离 RWX（仅当未含 PHDRS 时执行）
if(NOT _LD MATCHES "PHDRS")
    string(REPLACE "MEMORY"
"PHDRS
{
  flash PT_LOAD FLAGS(5);
  ram   PT_LOAD FLAGS(6);
}

MEMORY" _LD "${_LD}")
    string(REPLACE "} >FLASH\n"  "} >FLASH :flash\n"  _LD "${_LD}")
    string(REPLACE "} >RAM\n"    "} >RAM :ram\n"      _LD "${_LD}")
    # 修复 GCC 14 + PHDR 后 .data 被污染成 segment 0 的机制：
    #   原始 STM32Cube .data 段为    "} >RAM AT> FLASH\n"
    #   PHDRS + LOAD 段限制使其需带 " :ram" 限定符
    string(REPLACE "AT> FLASH\n"  "AT> FLASH :ram\n" _LD "${_LD}")
endif()
file(WRITE "${BOARD_LINKER_OUT}" "${_LD}")

set(CMAKE_EXE_LINKER_FLAGS
    "${_MCU_FLAGS} -T${BOARD_LINKER_OUT} -Wl,-Map=app.map,--gc-sections"
)

# ============================================================
# 源文件（通用）
# ============================================================
file(GLOB_RECURSE APP_SRC    "${CMAKE_CURRENT_SOURCE_DIR}/src/app/*.c")
file(GLOB_RECURSE DRIVER_SRC "${CMAKE_CURRENT_SOURCE_DIR}/src/drivers/*.c")

add_executable(app.elf
    ${APP_SRC}
    ${DRIVER_SRC}
    "${BOARD_STARTUP_SOURCE}"
    "${BOARD_SYSTEM_SOURCE}"
    "${_CUBE_LL_DIR}/Src/${BOARD_LL_PREFIX}xx_ll_gpio.c"
)

# ============================================================
# 头文件（通用）
# ============================================================
target_include_directories(app.elf PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/src/app"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/drivers"
    "${BOARD_LL_DIR}"
    "${BOARD_CMSIS_DIR}"
    "${BOARD_DEV_DIR}"
)

# ============================================================
# 编译宏
# ============================================================
target_compile_definitions(app.elf PRIVATE
    ${BOARD_MCU_DEFINE}
    USE_FULL_LL_DRIVER
    STM32_LL_GPIO_H="stm32${_chip_lower}xx_ll_gpio.h"
    STM32_LL_BUS_H="stm32${_chip_lower}xx_ll_bus.h"
)

# 板级硬件宏 → 生成 build/include/board_defs.h（避免 CMake 把 () 当 list 分隔）
configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/src/app/board_defs.h.in"
    "${CMAKE_BINARY_DIR}/include/board_defs.h"
    @ONLY
)
target_include_directories(app.elf PRIVATE
    "${CMAKE_BINARY_DIR}/include"
)

if(SD_SIZE)
    message(STATUS "===  SD size: ${SD_SIZE} ===")
    target_compile_definitions(app.elf PRIVATE SD_SIZE="${SD_SIZE}")
endif()

# ============================================================
# bin / hex / size
# ============================================================
find_program(ARM_OBJCOPY NAMES arm-none-eabi-objcopy REQUIRED)
find_program(ARM_SIZE   NAMES arm-none-eabi-size   REQUIRED)

add_custom_command(TARGET app.elf POST_BUILD
    COMMAND ${ARM_OBJCOPY} -O binary app.elf app.bin
    COMMAND ${ARM_OBJCOPY} -O ihex   app.elf app.hex
    COMMAND ${ARM_SIZE} app.elf
    COMMENT "Generating app.bin / app.hex for ${BOARD_NAME}"
)

# ============================================================
# pyOCD flash target
# ============================================================
add_custom_target(flash
    COMMAND pyocd flash -e sector -t ${BOARD_PYOCD_TARGET} ${CMAKE_BINARY_DIR}/app.elf
    DEPENDS app.elf
    COMMENT "Flashing ${BOARD_NAME} via pyOCD (target=${BOARD_PYOCD_TARGET})"
)
