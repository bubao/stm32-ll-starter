# STM32F407VGTx 板级参数（本机路径无关；STM32CubeF4 官网下载）
# 本机 Cube 根路径由 env.conf 注入：CUBE_F4_DIR
set(BOARD_NAME          "STM32F407VGTx")
set(BOARD_CHIP          "F4")
set(BOARD_CHIP_NUMBER   "4")
set(BOARD_LL_PREFIX     "stm32f4")
set(BOARD_MCU_CORE      "cortex-m4")
set(BOARD_MCU_FLOAT     "hard")
set(BOARD_MCU_DEFINE    "STM32F407xx")
set(BOARD_LED_CLK_EN    "LL_AHB1_GRP1_EnableClock(LL_AHB1_GRP1_PERIPH_GPIOC)")
set(BOARD_SYS_CLK       168000000U)
set(BOARD_PYOCD_TARGET  "stm32f407vg")
# F4 官方包在 Drivers/CMSIS 不提供通用 linker，故板级 cmake 直接提供工程内可文件的相对路径
set(BOARD_LINKER_IN     "${CMAKE_CURRENT_LIST_DIR}/../../linker/STM32F407VGTx.ld")
