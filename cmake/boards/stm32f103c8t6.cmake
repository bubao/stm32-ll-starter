# STM32F103C8T6 板级参数（本机路径无关；STM32CubeF1 官网下载）
# 本机 Cube 根路径由 env.conf 注入：CUBE_F1_DIR
set(BOARD_NAME          "STM32F103C8T6")
set(BOARD_CHIP          "F1")
set(BOARD_CHIP_NUMBER   "1")
set(BOARD_LL_PREFIX     "stm32f1")
set(BOARD_MCU_CORE      "cortex-m3")
set(BOARD_MCU_FLOAT     "soft")
set(BOARD_MCU_DEFINE    "STM32F103xB")
# F1 Cube 包里提供的 linker 文件名（STM32F1xx 官方模板）—— 与 F4 不同在命名里没有额外 F，故直接声明文件名
# https://oshwhub.com/li-chuang-kai-fa-ban/lichuang-gekuo-star-stm32f103c8t6-development-board
set(BOARD_LINKER_FILE   "STM32F103XB_FLASH.ld")
set(BOARD_LED_CLK_EN    "LL_APB2_GRP1_EnableClock(LL_APB2_GRP1_PERIPH_GPIOC)")
if(SYS_CLK_FREQ)
    set(BOARD_SYS_CLK   ${SYS_CLK_FREQ})
else()
    set(BOARD_SYS_CLK   8000000U)
endif()
set(BOARD_PYOCD_TARGET  "stm32f103c8")
