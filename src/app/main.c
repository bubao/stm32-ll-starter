/* 由 CMake 根据板子配置自动注入当前系列的头文件名和硬件宏 */
#include STM32_LL_GPIO_H
#include STM32_LL_BUS_H
#include "board_defs.h"

/* LED 引脚 */
#define LED_PORT        GPIOC
#define LED_PIN         LL_GPIO_PIN_13

static void led_init(void)
{
    /* 使能 GPIO 时钟（板级宏） */
    BOARD_LED_CLK_EN;

    /* 配置 PC13 为推挽输出 */
    LL_GPIO_InitTypeDef GPIO_InitStruct = {0};
    GPIO_InitStruct.Pin        = LED_PIN;
    GPIO_InitStruct.Mode       = LL_GPIO_MODE_OUTPUT;
    GPIO_InitStruct.Speed      = LL_GPIO_SPEED_FREQ_HIGH;
    GPIO_InitStruct.OutputType = LL_GPIO_OUTPUT_PUSHPULL;
    LL_GPIO_Init(LED_PORT, &GPIO_InitStruct);

    LL_GPIO_SetOutputPin(LED_PORT, LED_PIN);   /* LED 默认灭 */
}

/* 系统时钟频率（由板级配置注入，F1=72MHz，F4=168MHz） */
static void delay_ms(uint32_t ms)
{
    SysTick->LOAD  = (SYSTEM_CLOCK_FREQ / 1000U) - 1;
    SysTick->VAL   = 0;
    SysTick->CTRL  = SysTick_CTRL_ENABLE_Msk | SysTick_CTRL_CLKSOURCE_Msk;

    for (uint32_t i = 0; i < ms; i++) {
        while (!(SysTick->CTRL & SysTick_CTRL_COUNTFLAG_Msk));
    }
    SysTick->CTRL = 0;
}

int main(void)
{
    led_init();

    while (1) {
        LL_GPIO_ResetOutputPin(LED_PORT, LED_PIN);   /* LED 亮 */
        delay_ms(500);
        LL_GPIO_SetOutputPin(LED_PORT, LED_PIN);     /* LED 灭 */
        delay_ms(500);
    }
}
