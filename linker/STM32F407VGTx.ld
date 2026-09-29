/* STM32F407VGTx — 1 MB Flash, 128 KB SRAM, 64 KB CCM
 * Generated for LL+DMA PHDR（flash R+E, ram R+W, ccmram R+W）
 */
MEMORY
{
  RAM     (xrw)  : ORIGIN = 0x20000000, LENGTH = 128K
  CCMRAM  (xrw)  : ORIGIN = 0x10000000, LENGTH = 64K
  FLASH   (rx)   : ORIGIN = 0x08000000, LENGTH = 1024K
}

STACK_SIZE = 0x1000;

_estack     = ORIGIN(RAM) + LENGTH(RAM);
_Min_Heap_Size = 0x200;

ENTRY(Reset_Handler)

PHDRS
{
  flash    PT_LOAD FLAGS(5);  /* PF_R | PF_X */
  ram      PT_LOAD FLAGS(6);  /* PF_R | PF_W */
  ccmram   PT_LOAD FLAGS(6);
}

SECTIONS
{
  /* .isr_vector 只读，但需要被放在 FLASH 最头 */
  .isr_vector :
  {
    . = ALIGN(4);
    KEEP(*(.isr_vector))
    . = ALIGN(4);
  } >FLASH :flash

  .text :
  {
    . = ALIGN(4);
    *(.text)
    *(.text*)
    *(.glue_7)
    *(.glue_7t)
    *(.eh_frame)
    KEEP(*(.init))
    KEEP(*(.fini))
    . = ALIGN(4);
    _etext = .;
  } >FLASH :flash

  .rodata :
  {
    . = ALIGN(4);
    *(.rodata)
    *(.rodata*)
    . = ALIGN(4);
  } >FLASH :flash

  .ARM.extab   : { *(.ARM.extab* .gnu.linkonce.armextab.*) } >FLASH :flash
  .ARM : {
    __exidx_start = .;
    *(.ARM.exidx*)
    __exidx_end = .;
  } >FLASH :flash

  .preinit_array :
  {
    PROVIDE_HIDDEN (__preinit_array_start = .);
    KEEP(*(.preinit_array*))
    PROVIDE_HIDDEN (__preinit_array_end = .);
  } >FLASH :flash

  .init_array :
  {
    PROVIDE_HIDDEN (__init_array_start = .);
    KEEP(*(SORT(.init_array.*)))
    KEEP(*(.init_array*))
    PROVIDE_HIDDEN (__init_array_end = .);
  } >FLASH :flash

  .fini_array :
  {
    PROVIDE_HIDDEN (__fini_array_start = .);
    KEEP(*(.fini_array*))
    KEEP(*(SORT(.fini_array.*)))
    PROVIDE_HIDDEN (__fini_array_end = .);
  } >FLASH :flash

  /* 数据从 FLASH 搬运到 RAM */
  _sidata = LOADADDR(.data);
  .data :
  {
    . = ALIGN(4);
    _sdata = .;
    *(.data)
    *(.data*)
    . = ALIGN(4);
    _edata = .;
  } >RAM AT> FLASH :ram

  . = ALIGN(4);
  .bss :
  {
    _sbss = .;
    __bss_start__ = _sbss;
    *(.bss)
    *(.bss*)
    *(COMMON)
    . = ALIGN(4);
    _ebss = .;
    __bss_end__ = _ebss;
  } >RAM :ram

  ._user_heap_stack :
  {
    . = ALIGN(8);
    PROVIDE(end = .);
    PROVIDE(_end = .);
    . = . + _Min_Heap_Size;
    . = . + STACK_SIZE;
    . = ALIGN(8);
  } >RAM :ram
}
