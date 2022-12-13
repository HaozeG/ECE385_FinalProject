// ECE 385 USB Host Shield code
// based on Circuits-at-home USB Host code 1.x
// to be used for ECE 385 course materials
// Revised October 2020 - Zuofu Cheng

#include "altera_avalon_pio_regs.h"
#include "altera_avalon_spi.h"
#include "altera_avalon_spi_regs.h"
#include "map_ram.h"
#include "sgtl5000/sgtl5000.h"
#include "sys/alt_irq.h"
#include "system.h"
#include "usb_kb/GenericMacros.h"
#include "usb_kb/GenericTypeDefs.h"
#include "usb_kb/HID.h"
#include "usb_kb/MAX3421E.h"
#include "usb_kb/USB.h"
#include "usb_kb/transfer.h"
#include "usb_kb/usb_ch9.h"
#include <math.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

#define level_tot 7

extern HID_DEVICE hid_device;

static BYTE addr = 1; // hard-wired USB address
const char *const devclasses[] = {" Uninitialized", " HID Keyboard",
                                  " HID Mouse", " Mass storage"};

BYTE GetDriverandReport()
{
  BYTE i;
  BYTE rcode;
  BYTE device = 0xFF;
  BYTE tmpbyte;

  DEV_RECORD *tpl_ptr;
  printf("Reached USB_STATE_RUNNING (0x40)\n");
  for (i = 1; i < USB_NUMDEVICES; i++)
  {
    tpl_ptr = GetDevtable(i);
    if (tpl_ptr->epinfo != NULL)
    {
      printf("Device: %d", i);
      printf("%s \n", devclasses[tpl_ptr->devclass]);
      device = tpl_ptr->devclass;
    }
  }
  // Query rate and protocol
  rcode = XferGetIdle(addr, 0, hid_device.interface, 0, &tmpbyte);
  if (rcode)
  { // error handling
    printf("GetIdle Error. Error code: ");
    printf("%x \n", rcode);
  }
  else
  {
    printf("Update rate: ");
    printf("%x \n", tmpbyte);
  }
  printf("Protocol: ");
  rcode = XferGetProto(addr, 0, hid_device.interface, &tmpbyte);
  if (rcode)
  { // error handling
    printf("GetProto Error. Error code ");
    printf("%x \n", rcode);
  }
  else
  {
    printf("%d \n", tmpbyte);
  }
  return device;
}

void setHERO(BYTE HERO_INDEX, BYTE HERO_X, BYTE HERO_Y, BOOL HERO_FLIP,
             BYTE HERO_HAIR, BOOL SHAKE_EN, BOOL SOUND_EN)
{
  IOWR_ALTERA_AVALON_PIO_DATA(HERO_BASE,
                              (SOUND_EN | SHAKE_EN << 1 | (HERO_HAIR) << 2) |
                                  HERO_FLIP << 4 | HERO_Y << 5 | HERO_X << 13 |
                                  HERO_INDEX << 21);
}

void setLED(int LED)
{
  IOWR_ALTERA_AVALON_PIO_DATA(
      LEDS_PIO_BASE,
      (IORD_ALTERA_AVALON_PIO_DATA(LEDS_PIO_BASE) | (0x001 << LED)));
}

void clearLED(int LED)
{
  IOWR_ALTERA_AVALON_PIO_DATA(
      LEDS_PIO_BASE,
      (IORD_ALTERA_AVALON_PIO_DATA(LEDS_PIO_BASE) & ~(0x001 << LED)));
}

void printSignedHex0(signed char value)
{
  BYTE tens = 0;
  BYTE ones = 0;
  WORD pio_val = IORD_ALTERA_AVALON_PIO_DATA(HEX_DIGITS_PIO_BASE);
  if (value < 0)
  {
    setLED(11);
    value = -value;
  }
  else
  {
    clearLED(11);
  }
  // handled hundreds
  if (value / 100)
    setLED(13);
  else
    clearLED(13);

  value = value % 100;
  tens = value / 10;
  ones = value % 10;

  pio_val &= 0x00FF;
  pio_val |= (tens << 12);
  pio_val |= (ones << 8);

  IOWR_ALTERA_AVALON_PIO_DATA(HEX_DIGITS_PIO_BASE, pio_val);
}

void printSignedHex1(signed char value)
{
  BYTE tens = 0;
  BYTE ones = 0;
  DWORD pio_val = IORD_ALTERA_AVALON_PIO_DATA(HEX_DIGITS_PIO_BASE);
  if (value < 0)
  {
    setLED(10);
    value = -value;
  }
  else
  {
    clearLED(10);
  }
  // handled hundreds
  if (value / 100)
    setLED(12);
  else
    clearLED(12);

  value = value % 100;
  tens = value / 10;
  ones = value % 10;
  tens = value / 10;
  ones = value % 10;

  pio_val &= 0xFF00;
  pio_val |= (tens << 4);
  pio_val |= (ones << 0);

  IOWR_ALTERA_AVALON_PIO_DATA(HEX_DIGITS_PIO_BASE, pio_val);
}

void setKeycode(WORD keycode)
{
  IOWR_ALTERA_AVALON_PIO_DATA(KEYCODE_BASE, keycode);
}

int SGTL5000_init()
{
  ALT_AVALON_I2C_DEV_t *i2c_dev; // pointer to instance structure
  // get a pointer to the Avalon i2c instance
  i2c_dev = alt_avalon_i2c_open(
      "/dev/i2c_0");   // this has to reflect Platform Designer name
  if (NULL == i2c_dev) // check the BSP if unsure
  {
    printf("Error: Cannot find /dev/i2c_0\n");
    return 1;
  }
  printf("I2C Test Program\n");

  alt_avalon_i2c_master_target_set(i2c_dev, 0xA); // CODEC at address 0b0001010
  // print device ID (verify I2C is working)
  printf("Device ID register: %x\n",
         SGTL5000_Reg_Rd(i2c_dev, SGTL5000_CHIP_ID));

  // configure PLL, input frequency is 12.5 MHz, output frequency is 180.6336
  // MHz if 44.1kHz is desired or 196.608 MHz else
  BYTE int_divisor = 180633600 / 12500000;
  WORD frac_divisor =
      (WORD)(((180633600.0f / 12500000.0f) - (float)int_divisor) * 2048.0f);
  printf("Programming PLL with integer divisor: %d, fractional divisor %d\n",
         int_divisor, frac_divisor);
  SGTL5000_Reg_Wr(i2c_dev, SGTL5000_CHIP_PLL_CTRL,
                  int_divisor << SGTL5000_PLL_INT_DIV_SHIFT |
                      frac_divisor << SGTL5000_PLL_FRAC_DIV_SHIFT);
  printf("CHIP_PLL_CTRL register: %x\n",
         SGTL5000_Reg_Rd(i2c_dev, SGTL5000_CHIP_PLL_CTRL));

  // configure power control, disable internal VDDD, VDDIO=3.3V, VDDA=VDDD=1.8V
  // (ext)
  SGTL5000_Reg_Wr(i2c_dev, SGTL5000_CHIP_ANA_POWER,
                  SGTL5000_DAC_STEREO | SGTL5000_PLL_POWERUP |
                      SGTL5000_VCOAMP_POWERUP | SGTL5000_VAG_POWERUP |
                      SGTL5000_ADC_STEREO | SGTL5000_REFTOP_POWERUP |
                      SGTL5000_HP_POWERUP | SGTL5000_DAC_POWERUP |
                      SGTL5000_CAPLESS_HP_POWERUP | SGTL5000_ADC_POWERUP);
  printf("CHIP_ANA_POWER register: %x\n",
         SGTL5000_Reg_Rd(i2c_dev, SGTL5000_CHIP_ANA_POWER));

  // select internal ground bias to .9V (1.8V/2)
  SGTL5000_Reg_Wr(i2c_dev, SGTL5000_CHIP_REF_CTRL, 0x004E);
  printf("CHIP_REF_CTRL register: %x\n",
         SGTL5000_Reg_Rd(i2c_dev, SGTL5000_CHIP_REF_CTRL));

  // enable core modules
  SGTL5000_Reg_Wr(
      i2c_dev, SGTL5000_CHIP_DIG_POWER,
      SGTL5000_ADC_EN | SGTL5000_DAC_EN |
          // SGTL5000_DAP_POWERUP| //disable digital audio processor in CODEC
          SGTL5000_I2S_OUT_POWERUP | SGTL5000_I2S_IN_POWERUP);
  printf("CHIP_DIG_POWER register: %x\n",
         SGTL5000_Reg_Rd(i2c_dev, SGTL5000_CHIP_DIG_POWER));

  // MCLK is 12.5 MHz, configure clocks to use PLL
  SGTL5000_Reg_Wr(i2c_dev, SGTL5000_CHIP_CLK_CTRL,
                  SGTL5000_SYS_FS_44_1k << SGTL5000_SYS_FS_SHIFT |
                      SGTL5000_MCLK_FREQ_PLL << SGTL5000_MCLK_FREQ_SHIFT);
  printf("CHIP_CLK_CTRL register: %x\n",
         SGTL5000_Reg_Rd(i2c_dev, SGTL5000_CHIP_CLK_CTRL));

  // Set as I2S master
  SGTL5000_Reg_Wr(i2c_dev, SGTL5000_CHIP_I2S_CTRL, SGTL5000_I2S_MASTER);
  printf("CHIP_I2S_CTRL register: %x\n",
         SGTL5000_Reg_Rd(i2c_dev, SGTL5000_CHIP_I2S_CTRL));

  // ADC input from Line
  SGTL5000_Reg_Wr(i2c_dev, SGTL5000_CHIP_ANA_CTRL,
                  SGTL5000_ADC_SEL_LINE_IN << SGTL5000_ADC_SEL_SHIFT);
  printf("CHIP_ANA_CTRL register: %x\n",
         SGTL5000_Reg_Rd(i2c_dev, SGTL5000_CHIP_ANA_CTRL));

  // ADC -> I2S out, I2S in -> DAC
  SGTL5000_Reg_Wr(i2c_dev, SGTL5000_CHIP_SSS_CTRL,
                  SGTL5000_DAC_SEL_I2S_IN << SGTL5000_DAC_SEL_SHIFT |
                      SGTL5000_I2S_OUT_SEL_ADC << SGTL5000_I2S_OUT_SEL_SHIFT);
  printf("CHIP_SSS_CTRL register: %x\n",
         SGTL5000_Reg_Rd(i2c_dev, SGTL5000_CHIP_SSS_CTRL));

  printf("CHIP_ANA_CTRL register: %x\n",
         SGTL5000_Reg_Rd(i2c_dev, SGTL5000_CHIP_ANA_CTRL));

  // ADC -> I2S out, I2S in -> DAC
  SGTL5000_Reg_Wr(i2c_dev, SGTL5000_CHIP_ADCDAC_CTRL, 0x0000);
  printf("CHIP_ADCDAC_CTRL register: %x\n",
         SGTL5000_Reg_Rd(i2c_dev, SGTL5000_CHIP_ADCDAC_CTRL));
  printf("CHIP_PAD_STRENGTH register: %x\n",
         SGTL5000_Reg_Rd(i2c_dev, SGTL5000_CHIP_PAD_STRENGTH));
}

// start

// global
bool key_pressed[6] = {false};
int map[level_tot][16][16] = {{{36, 49, 37, 37, 72, 37, 37, 50, 50, 50, 50, 50, 51, 0, 0, 36},
                               {37, 35, 49, 50, 50, 50, 51, 41, 0, 0, 40, 41, 0, 0, 0, 36},
                               {37, 37, 35, 32, 16, 40, 56, 0, 0, 0, 42, 0, 0, 0, 61, 36},
                               {50, 50, 51, 40, 40, 40, 41, 0, 0, 0, 0, 0, 63, 32, 32, 36},
                               {35, 64, 40, 56, 40, 41, 58, 40, 57, 0, 0, 0, 52, 53, 34, 37},
                               {38, 58, 40, 40, 40, 16, 40, 41, 0, 0, 0, 0, 0, 0, 49, 37},
                               {37, 34, 53, 53, 54, 40, 40, 0, 0, 0, 0, 0, 0, 58, 40, 36},
                               {37, 51, 56, 40, 40, 41, 0, 0, 0, 0, 0, 0, 0, 40, 56, 36},
                               {38, 0, 0, 42, 40, 0, 0, 0, 0, 58, 40, 58, 40, 40, 40, 36},
                               {51, 0, 0, 0, 40, 103, 88, 0, 0, 40, 16, 40, 40, 52, 34, 37},
                               {0, 0, 0, 58, 40, 40, 56, 62, 58, 40, 40, 40, 56, 40, 36, 37},
                               {0, 0, 0, 40, 56, 40, 40, 33, 35, 40, 0, 0, 42, 40, 36, 37},
                               {0, 0, 58, 33, 35, 40, 42, 49, 51, 41, 0, 17, 17, 17, 36, 37},
                               {34, 34, 34, 37, 38, 41, 0, 33, 35, 17, 17, 33, 34, 34, 37, 37},
                               {37, 72, 37, 37, 38, 17, 17, 36, 37, 34, 34, 37, 37, 37, 72, 37},
                               {37, 37, 37, 37, 37, 34, 34, 37, 37, 37, 37, 37, 37, 37, 37, 37}},
                              {{37, 38, 36, 37, 37, 38, 49, 50, 50, 50, 37, 38, 40, 40, 40, 36},
                               {37, 38, 49, 50, 50, 51, 40, 40, 0, 40, 36, 38, 42, 16, 40, 36},
                               {37, 37, 35, 32, 16, 40, 41, 41, 0, 40, 36, 38, 0, 58, 56, 36},
                               {72, 37, 38, 40, 40, 41, 0, 0, 0, 42, 36, 51, 0, 0, 42, 36},
                               {37, 72, 38, 41, 0, 0, 0, 0, 0, 0, 55, 0, 0, 0, 0, 36},
                               {37, 50, 51, 0, 0, 0, 0, 17, 0, 0, 55, 0, 0, 0, 62, 36},
                               {38, 0, 61, 0, 58, 57, 0, 39, 0, 0, 55, 0, 0, 0, 33, 37},
                               {37, 35, 32, 32, 16, 41, 0, 48, 57, 0, 0, 0, 0, 88, 36, 72},
                               {37, 37, 34, 35, 40, 57, 0, 55, 40, 88, 57, 0, 104, 40, 49, 50},
                               {37, 37, 72, 38, 40, 40, 103, 32, 40, 40, 40, 56, 40, 40, 33, 34},
                               {72, 37, 37, 38, 0, 42, 40, 39, 41, 0, 42, 40, 40, 52, 50, 37},
                               {50, 50, 37, 38, 0, 58, 40, 48, 0, 0, 0, 0, 42, 40, 40, 36},
                               {0, 40, 49, 38, 58, 56, 41, 48, 0, 0, 0, 0, 0, 0, 42, 49},
                               {0, 42, 56, 55, 40, 41, 0, 48, 17, 17, 17, 0, 0, 0, 58, 40},
                               {0, 0, 42, 40, 40, 103, 63, 36, 34, 34, 35, 0, 0, 0, 56, 40},
                               {34, 34, 34, 34, 34, 34, 34, 37, 37, 72, 38, 103, 88, 104, 40, 40}},
                              {{50, 51, 0, 0, 0, 36, 50, 50, 50, 51, 49, 50, 50, 50, 37, 37},
                               {40, 16, 0, 0, 0, 55, 40, 41, 0, 0, 0, 0, 42, 40, 49, 72},
                               {56, 40, 57, 62, 0, 58, 40, 0, 0, 0, 0, 0, 0, 40, 0, 36},
                               {42, 40, 40, 52, 53, 54, 41, 0, 0, 0, 0, 0, 0, 40, 57, 36},
                               {0, 16, 40, 40, 40, 41, 0, 0, 0, 0, 17, 17, 58, 40, 40, 49},
                               {42, 40, 40, 41, 0, 0, 0, 0, 0, 0, 33, 35, 40, 56, 40, 41},
                               {0, 42, 0, 0, 0, 0, 17, 17, 0, 0, 36, 38, 16, 40, 41, 0},
                               {0, 0, 0, 0, 0, 0, 52, 54, 0, 58, 36, 38, 40, 40, 0, 0},
                               {0, 0, 0, 0, 0, 0, 32, 56, 40, 40, 49, 37, 35, 0, 0, 0},
                               {0, 0, 0, 0, 0, 0, 39, 40, 40, 42, 40, 49, 51, 57, 0, 0},
                               {0, 0, 0, 0, 0, 0, 55, 40, 0, 0, 0, 42, 40, 40, 57, 0},
                               {0, 0, 63, 0, 0, 0, 32, 41, 0, 0, 0, 0, 56, 40, 0, 0},
                               {53, 53, 53, 54, 0, 0, 32, 0, 0, 0, 0, 61, 42, 40, 103, 0},
                               {42, 40, 32, 57, 0, 58, 32, 0, 0, 58, 0, 52, 53, 53, 53, 53},
                               {0, 56, 32, 40, 57, 40, 39, 0, 0, 40, 103, 104, 32, 40, 40, 40},
                               {0, 42, 32, 40, 16, 40, 48, 0, 58, 40, 40, 40, 32, 40, 40, 40}},
                              {{99, 99, 99, 100, 82, 83, 83, 83, 84, 85, 0, 0, 0, 85, 82, 83},
                               {0, 0, 0, 0, 98, 99, 99, 99, 100, 85, 0, 0, 0, 85, 82, 83},
                               {0, 0, 0, 0, 0, 0, 0, 0, 0, 101, 0, 0, 0, 85, 98, 99},
                               {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 101, 0, 0},
                               {0, 0, 0, 0, 0, 0, 0, 0, 57, 0, 0, 0, 0, 0, 0, 0},
                               {0, 0, 0, 0, 57, 0, 0, 104, 40, 0, 0, 58, 0, 0, 0, 0},
                               {0, 0, 58, 88, 40, 40, 104, 40, 40, 40, 40, 40, 57, 0, 0, 0},
                               {104, 57, 40, 40, 40, 40, 16, 41, 0, 0, 42, 16, 40, 58, 103, 104},
                               {40, 40, 40, 42, 56, 40, 40, 0, 102, 0, 0, 0, 40, 40, 40, 40},
                               {40, 40, 41, 0, 40, 40, 41, 0, 0, 0, 0, 58, 40, 56, 40, 42},
                               {56, 40, 0, 0, 42, 40, 61, 0, 0, 0, 63, 40, 40, 41, 0, 0},
                               {40, 40, 57, 0, 0, 40, 33, 34, 35, 40, 0, 0, 58},
                               {16, 41, 0, 0, 0, 32, 49, 50, 51, 36, 72, 38, 40, 66, 67, 67},
                               {40, 0, 0, 0, 0, 33, 34, 34, 34, 37, 37, 37, 35, 82, 83, 83},
                               {67, 67, 67, 68, 36, 37, 72, 37, 37, 37, 37, 38, 82, 83, 83},
                               {83, 83, 83, 84, 36, 37, 37, 37, 37, 37, 72, 38, 82, 83, 83}},
                              {{37, 72, 37, 37, 38, 43, 0, 0, 0, 0, 0, 0, 36, 37, 37, 37},
                               {37, 37, 37, 72, 38, 43, 0, 0, 0, 0, 0, 0, 36, 37, 72, 37},
                               {37, 37, 37, 50, 51, 43, 0, 0, 0, 17, 17, 32, 36, 37, 37, 37},
                               {37, 37, 51, 0, 0, 0, 0, 0, 0, 33, 34, 34, 37, 37, 37, 37},
                               {72, 38, 0, 0, 0, 0, 0, 0, 0, 33, 34, 34, 37, 72, 37, 37},
                               {37, 38, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 49, 50, 50, 50},
                               {37, 38, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
                               {37, 38, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
                               {37, 38, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
                               {72, 38, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
                               {37, 38, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
                               {50, 51, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
                               {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
                               {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
                               {0, 0, 0, 33, 54, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
                               {0, 0, 0, 48, 66, 68, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}},
                              {{38, 40, 40, 40, 36, 37, 72, 37, 37, 37, 72, 37, 37, 37, 37, 37},
                               {38, 40, 56, 40, 49, 50, 50, 50, 50, 50, 50, 50, 37, 37, 72, 37},
                               {38, 16, 41, 0, 40, 41, 0, 0, 0, 0, 42, 40, 49, 37, 37, 37},
                               {38, 40, 0, 0, 42, 0, 17, 17, 17, 0, 0, 40, 56, 36, 37, 37},
                               {38, 41, 0, 0, 0, 17, 66, 67, 68, 0, 0, 42, 40, 36, 37, 72},
                               {38, 17, 17, 17, 17, 66, 83, 83, 84, 0, 0, 0, 33, 37, 37, 37},
                               {37, 34, 34, 34, 35, 98, 99, 99, 100, 0, 0, 59, 36, 37, 37, 37},
                               {37, 37, 72, 37, 37, 35, 40, 56, 41, 0, 0, 59, 36, 72, 37, 37},
                               {37, 37, 37, 37, 37, 38, 16, 42, 0, 0, 0, 59, 36, 37, 37, 37},
                               {37, 72, 37, 37, 37, 38, 41, 0, 0, 17, 17, 17, 36, 37, 37, 37},
                               {37, 37, 37, 37, 72, 38, 0, 0, 59, 33, 34, 35, 49, 37, 72, 37},
                               {50, 50, 50, 50, 50, 51, 0, 0, 59, 36, 37, 37, 35, 49, 37, 37},
                               {56, 40, 40, 41, 0, 0, 0, 0, 59, 36, 37, 72, 37, 35, 49, 50},
                               {40, 41, 0, 0, 0, 0, 57, 0, 59, 36, 37, 37, 37, 37, 34, 34},
                               {40, 0, 61, 62, 0, 58, 40, 0, 59, 36, 37, 37, 37, 72, 37, 37},
                               {34, 34, 34, 35, 16, 40, 56, 57, 59, 36, 37, 37, 37, 37, 37, 37}},
                              {{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
                               {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
                               {0, 0, 0, 0, 0, 0, 58, 0, 0, 0, 0, 0, 0, 0, 0, 0},
                               {0, 0, 0, 0, 0, 0, 16, 0, 0, 57, 0, 0, 0, 0, 0, 0},
                               {0, 0, 0, 0, 58, 0, 40, 0, 0, 56, 0, 0, 0, 0, 0, 0},
                               {0, 0, 0, 0, 40, 103, 40, 0, 0, 16, 0, 57, 0, 0, 0, 0},
                               {0, 0, 0, 0, 40, 56, 40, 118, 0, 40, 103, 40, 0, 0, 0, 0},
                               {0, 0, 0, 0, 42, 40, 40, 33, 35, 40, 56, 41, 0, 0, 0, 0},
                               {0, 0, 0, 104, 56, 40, 33, 37, 37, 35, 40, 57, 58, 0, 0, 0},
                               {0, 0, 0, 42, 40, 33, 37, 72, 37, 37, 35, 40, 56, 104, 0, 0},
                               {88, 88, 104, 40, 41, 36, 37, 37, 37, 37, 38, 16, 40, 40, 104, 0},
                               {40, 16, 40, 56, 0, 49, 50, 37, 37, 72, 38, 41, 0, 42, 40, 0},
                               {0, 42, 40, 57, 63, 33, 35, 36, 37, 50, 51, 32, 0, 0, 40, 0},
                               {0, 0, 33, 34, 34, 37, 38, 49, 51, 33, 34, 35, 40, 57, 40, 103},
                               {0, 0, 49, 37, 37, 72, 37, 34, 34, 37, 37, 37, 35, 16, 56, 40},
                               {33, 34, 35, 36, 37, 37, 37, 37, 37, 37, 72, 37, 37, 34, 34, 35}}};
int collide_box[128][4][4] = {0};
int collision[64][64] = {0};
int birth[level_tot][2];

int level_index = 0;
int max_dashes = 1;
bool has_key = false;
bool has_dashed = false;
int berry_tot = 0;
int death_tot = 0;

void key_detect(BOOT_KBD_REPORT kbdbuf)
{
  for (int j = 0; j < 6; j++)
  {
    key_pressed[j] = false;
  }

  for (int i = 0; i < 6; i++)
  {
    if (kbdbuf.keycode[i] == 26)
      key_pressed[0] = true;
    else if (kbdbuf.keycode[i] == 4)
      key_pressed[1] = true;
    else if (kbdbuf.keycode[i] == 22)
      key_pressed[2] = true;
    else if (kbdbuf.keycode[i] == 7)
      key_pressed[3] = true;
    else if (kbdbuf.keycode[i] == 44)
      key_pressed[4] = true;
    else if (kbdbuf.keycode[i] == 14)
      key_pressed[5] = true;
  }
}
// void setHERO(bool hero_en, int index, int HEROX, int HEROY, bool flip, int
// hair_color, bool shake, bool sound); hero_en: 1bit. 1
// 杈撳嚭姝prite锛�0涓嶈緭鍑� index: 3bit. sprite index, 0-7
// HEROX: 8bit. 0-255
// HEROY: 8bit. 0-255
// flip: 1bit. 1 姘村钩缈昏浆锛�0 淇濇寔鍘熸牱
// hair_color: 2bit. 1 绾㈣壊锛�0 钃濊壊
// shake: 1bit. 1 闇囧姩锛�0 涓嶉渿鍔�
// sound: 1bit. 1 鏈夊０闊筹紝 0 娌℃湁澹伴煶

struct Player
{
  // basic
  bool dead;
  bool dead2;
  int x, y; // position
  int spdX, spdY;
  int moveX, moveY; // expected moving pixels in one step
  int flipX;        // sign(hero->spdX)
  bool shake;

  // player
  bool hero_en;
  bool flip;       // flip sprite or not
  int hero_index;  // sprite index
  int hair_color;  // 1:red, 0:blue, 2: green
  int walk_offset; // used for sprite changing when walking

  bool p_jump;   // check if jump was pressed previously
  bool p_dash;   // check if dash was pressed previously
  int grace;     // Coyote time = 6 frames
  int jbuffer;   // jump buffer = 4 frames
  int dashes;    // maximum dash times in the air
  int dash_time; // if dash_time > 0 , meaning Madline is dashing. one dash is 4
                 // frames
  // int dash_effect_time; // used in collision with the fake wall

  // // dash direction and acceleration (8 directions total)
  int dash_target_x;
  int dash_target_y;
  int dash_accel_x;
  int dash_accel_y;

  bool was_on_ground; // if the player was on ground in the last step
  bool on_ground;     // if the player is on ground
  bool on_ice;        // if the player is on ice

  bool dash; // press dash and no_dash on previous frame
  int dash_spd;
  bool jump; // press jump and no_jump on previous frame

  int h_maxspd; // Max horizontal speed when moving. default = 1
  int h_accel;
  int h_deccel;

  int v_maxspd; // Max Vertical speed when falling. default = 2, if wall_slide,
                // 0.4
  int v_accel;  // gravity = 0.21, if madeline is on top of her jump, gravity
                // would be half
  int v_deccel;

  int wall_dir; // 0: no wall jump; 1: wall is on the righ; -1: wall is on the
                // left
};

void collision_fill(int level)
{
  for (int i = 0; i < 64; i++)
  {
    for (int j = 0; j < 64; j++)
    {
      collision[i][j] = 0;
    }
  }

  for (int i = 0; i < 16; i++)
  {
    for (int j = 0; j < 16; j++)
    {
      int spr_index = map[level][i][j];
      int col0 = j * 4;
      int row0 = i * 4;
      for (int row = 0; row < 4; row++)
      {
        for (int col = 0; col < 4; col++)
        {
          collision[row0 + row][col0 + col] = collide_box[spr_index][row][col];
        }
      }
    }
  }
}

int is_solid(int x0, int y0)
{
  int collide_xl = (x0 + 2) / 4;
  if (collide_xl >= 63)
    collide_xl = 63;
  int collide_xh = (x0 + 13) / 4;
  if (collide_xh >= 63)
    collide_xh = 63;
  int collide_yl = (y0 + 6) / 4;
  if (collide_yl >= 63)
    collide_yl = 63;
  int collide_yh = (y0 + 15) / 4;
  if (collide_yh >= 63)
    collide_yh = 63;
  int result = 0;
  for (int i = collide_yl; i < collide_yh + 1; i++)
  {
    for (int j = collide_xl; j < collide_xh + 1; j++)
    {
      if (collision[i][j] == -1)
      {
        result = -1;
        break;
      }
      else if (collision[i][j] == 2)
      {
        result = 2;
        break;
      }
      else if (collision[i][j] == 1)
      {
        result = 1;
        break;
      }
      else if (collision[i][j] == 4) // green orb, max dash = 2
      {
        result = 4;
        break;
      }
    }
  }
  return result;
}

void clear_active(int x0, int y0)
{
  int collide_xl = (x0 + 2) / 4;
  if (collide_xl >= 63)
    collide_xl = 63;
  int collide_xh = (x0 + 13) / 4;
  if (collide_xh >= 63)
    collide_xh = 63;
  int collide_yl = (y0 + 6) / 4;
  if (collide_yl >= 63)
    collide_yl = 63;
  int collide_yh = (y0 + 15) / 4;
  if (collide_yh >= 63)
    collide_yh = 63;
  for (int i = collide_yl; i < collide_yh + 1; i++)
  {
    for (int j = collide_xl; j < collide_xh + 1; j++)
    {
      if (collision[i][j] == 4)
      {
        int row = i / 4;
        int col = j / 4;
        setMAP(row * 16 + col, 0);
        for (int i = 0; i < 4; i++)
        {
          for (int j = 0; j < 4; j++)
          {
            collision[row * 4 + i][col * 4 + j] = 0;
          }
        }
        break;
      }
    }
  }
}

int spd_change(int spd, int target, int accel)
{
  if (spd == target)
  {
    return spd;
  }
  int speed =
      (abs(spd + accel - target) < abs(spd - accel - target) ? spd + accel
                                                             : spd - accel);

  if ((spd < target && speed > target) || (spd > target && speed < target))
  {
    speed = target;
  }

  return speed;
}

void player_init(struct Player *hero, int x0, int y0)
{
  // basic
  hero->hero_en = true;
  hero->dead = false;
  hero->dead2 = false;
  hero->x = x0;
  hero->y = y0;
  hero->spdX = 0;
  hero->spdY = 0;
  hero->moveX = 0;
  hero->moveY = 0;
  hero->flipX = 1;
  hero->flip = false;

  // player
  hero->hero_index = 1;
  hero->walk_offset = 0;
  hero->hair_color = 1;
  hero->p_jump = false;
  hero->p_dash = false;
  hero->grace = 0;
  hero->jbuffer = 0;
  hero->dashes = 1;
  hero->dash_time = 0;
  hero->dash_target_x = 0;
  hero->dash_target_y = 0;
  hero->dash_accel_x = 0;
  hero->dash_accel_y = 0;
  hero->was_on_ground = false;
  hero->on_ground = false;
  hero->on_ice = false;
  hero->dash = false;
  hero->jump = false;
  hero->h_maxspd = 0;
  hero->h_accel = 0;
  hero->h_deccel = 0;
  hero->v_maxspd = 0;
  hero->v_accel = 0;
  hero->v_deccel = 0;
  hero->wall_dir = 0;
}

void move(struct Player *hero)
{
  // X axis
  hero->moveX = hero->spdX; 
  int stepX = (hero->moveX > 0 ? 1 : -1);

  // Actor : detect collision at each pixel (not efficient but precise)

  while (hero->moveX != 0)
  {
    if ((is_solid(hero->x + stepX, hero->y) == 1) || (is_solid(hero->x + stepX, hero->y) == 2))
    {
      // Hit a solid!
      hero->spdX = 0;
      break;
    }
    else
    {
      // There is no wall immediately beside us
      hero->x += stepX;
      hero->moveX -= stepX;
    }
  }

  // Y axis
  hero->moveY = hero->spdY; 
  int stepY = (hero->moveY > 0 ? 1 : -1);

  // Actor : detect collision at each pixel (not efficient but precise)
  while (hero->moveY != 0)
  {
    if ((is_solid(hero->x, hero->y + stepY) == 1) || (is_solid(hero->x, hero->y + stepY) == 2))
    {
      // Hit a solid!
      hero->spdY = 0;
      break;
    }
    else
    {
      // There is no wall immediately beside us
      hero->y += stepY;
      hero->moveY -= stepY;
    }
  }
}

void Playerstep(struct Player *hero)
{
  move(hero);
  hero->shake = 0;
  // limit position horizontally
  if (hero->x < 0)
  {
    hero->x = 0;
    hero->spdX = 0;
    // printf("here\n");
  }
  else if (hero->x > 242)
  {
    hero->x = 242;
    hero->spdX = 0;
  }
  else if (hero->y <= 0 && level_index == level_tot - 1)
  {
    hero->y = 0;
    hero->spdY = 0;
  }

  // judge death
  if (is_solid(hero->x, hero->y) == -1) // collide with spike or drop down out of screen
  {
    death_tot++;
    hero->dead = true;
    return;
    // kill_player(); // restart room
    // restart room after 0.5 second
    // hero_en = false;
  }
  else if (hero->y > 256)
  {
    death_tot++;
    hero->dead2 = true;
    return;
  }

  // judge balloon
  // if (is_solid(hero->x, hero->y) == 3)
  // {
  //   hero->dashes = max_dashes;
  //   clear_active(hero->x, hero->y);
  // }
  // judge orb
  if (is_solid(hero->x, hero->y) == 4)
  {
    max_dashes = 2;
    hero->dashes = max_dashes;
    clear_active(hero->x, hero->y);
  }

  hero->flip = false;
  if (hero->spdX != 0) // sign(spdX)
    hero->flipX = (hero->spdX < 0 ? -1 : 1);

  hero->on_ground = (is_solid(hero->x, hero->y + 1) == 1 ||
                     is_solid(hero->x, hero->y + 1) ==
                         2); // 鑴氫笅1鍍忕礌鏄惁鏄痵olid
  hero->on_ice = is_solid(hero->x, hero->y + 1) == 2;
  hero->jump = key_pressed[4] && !hero->p_jump;
  hero->p_jump = key_pressed[4];

  if (hero->jump)
    hero->jbuffer = 4;
  else if (hero->jbuffer > 0)
    hero->jbuffer--;

  hero->dash = key_pressed[5] && !hero->p_dash;
  hero->p_dash = key_pressed[5];

  if (hero->on_ground)
  {
    hero->grace = 6;
    if (hero->dashes < max_dashes) // recover dash
      hero->dashes = max_dashes;
  }
  else if (hero->grace > 0)
    hero->grace--;

  // judge movements and change speed
  if (hero->dash_time > 0)
  {
    // if just dashed before (in 4 frames)
    hero->dash_time--;
    hero->spdX =
        spd_change(hero->spdX, hero->dash_target_x, hero->dash_accel_x);
    hero->spdY =
        spd_change(hero->spdY, hero->dash_target_y, hero->dash_accel_y);
  }
  else
  {
    // move
    hero->h_maxspd = 6;
    hero->h_deccel = 3;
    if (!hero->on_ground)
      hero->h_accel = 2;
    else if (hero->on_ice)
      hero->h_accel = 1;
    else
      hero->h_accel = 3;

    if (abs(hero->spdX) > hero->h_maxspd)
      hero->spdX =
          spd_change(hero->spdX, hero->flipX * hero->h_maxspd, hero->h_deccel);
    else if (key_pressed[3]) // pressed right
      hero->spdX = spd_change(hero->spdX, hero->h_maxspd, hero->h_accel);
    else if (key_pressed[1]) // pressed left
      hero->spdX = spd_change(hero->spdX, -hero->h_maxspd, hero->h_accel);
    else
      hero->spdX = spd_change(hero->spdX, 0, hero->h_accel);

    // fall
    hero->v_maxspd = 8;
    hero->v_accel = 2; // TODO:
    if (abs(hero->spdY) <= 1)
      hero->v_accel *= 0.5; // half gravity at top
    if (key_pressed[3] && (is_solid(hero->x + 1, hero->y) == 1) ||
        key_pressed[1] && (is_solid(hero->x - 1, hero->y) ==
                           1)) // press against wall, fall slower
      hero->v_maxspd = 3;
    if (!hero->on_ground)
      hero->spdY = spd_change(hero->spdY, hero->v_maxspd, hero->v_accel);

    // jump
    if (hero->jbuffer > 0)
    {
      if (hero->grace > 0) // jump from ground
      {
        hero->jbuffer = 0;
        hero->grace = 0;
        hero->spdY = -12;
      }
      else // wall jump
      {
        if (is_solid(hero->x - 5, hero->y))
          hero->wall_dir = -1; // left wall
        else if (is_solid(hero->x + 5, hero->y))
          hero->wall_dir = 1; // right wall
        else
          hero->wall_dir = 0; // no wall
        if (hero->wall_dir != 0)
        {
          // printf("kaka\n");
          hero->jbuffer = 0;
          hero->spdY = -12;
          hero->spdX = -hero->wall_dir * (hero->h_maxspd + 6);
        }
      }
    }

    // dash
    if (hero->dashes > 0 && hero->dash)
    {
      hero->shake = 1;

      hero->dashes--;
      hero->dash_time = 4;
      has_dashed = true;
      hero->dash_spd = 20;

      // 8 dash directions
      if (key_pressed[0] && key_pressed[3])
      {
        hero->spdX = hero->dash_spd * 0.7; // TODO:
        hero->spdY = -hero->dash_spd * 0.7;
      }
      else if (key_pressed[2] && key_pressed[3])
      {
        hero->spdX = hero->dash_spd * 0.7;
        hero->spdY = hero->dash_spd * 0.7;
      }
      else if (key_pressed[0] && key_pressed[1])
      {
        hero->spdX = -hero->dash_spd * 0.7;
        hero->spdY = -hero->dash_spd * 0.7;
      }
      else if (key_pressed[1] && key_pressed[2])
      {
        hero->spdX = -hero->dash_spd * 0.7;
        hero->spdY = hero->dash_spd * 0.7;
      }
      else if (key_pressed[0])
      {
        hero->spdX = 0;
        hero->spdY = -hero->dash_spd;
      }
      else if (key_pressed[1])
      {
        hero->spdX = -hero->dash_spd;
        hero->spdY = 0;
      }
      else if (key_pressed[2])
      {
        hero->spdX = 0;
        hero->spdY = hero->dash_spd;
      }
      else if (key_pressed[3])
      {
        hero->spdX = hero->dash_spd;
        hero->spdY = 0;
      }

      // update dash target and accel
      if (hero->spdX == 0)
        hero->dash_target_x = 0;
      else if (hero->spdX > 0)
        hero->dash_target_x = 8;
      else
        hero->dash_target_x = -8;
      if (hero->spdY == 0)
        hero->dash_target_y = 0;
      else if (hero->spdY > 0)
        hero->dash_target_y = 8;
      else
        hero->dash_target_y = -6;
      hero->dash_accel_x = (hero->spdY == 0 ? 6 : (6 * sqrt(2) / 2));
      hero->dash_accel_y = (hero->spdX == 0 ? 6 : (6 * sqrt(2) / 2));
    }
  }

  // judge sprite index
  if (!hero->on_ground) // in the air
  {
    hero->hero_index = 3;
    if (is_solid(hero->x + 1, hero->y))
      hero->hero_index = 5;
    else if (is_solid(hero->x - 1, hero->y))
    {
      hero->hero_index = 5;
      hero->flip = true;
    }
    else if (key_pressed[3])
      hero->hero_index = 3;
    else if (key_pressed[1])
    {
      hero->hero_index = 3;
      hero->flip = true;
    }
  }
  else if (key_pressed[2])
  {
    hero->hero_index = 6;
    if (key_pressed[1])
      hero->flip = true;
  }
  else if (key_pressed[0])
  {
    hero->hero_index = 7;
    if (key_pressed[1])
      hero->flip = true;
  }
  else if (hero->spdX == 0 || (!key_pressed[1]) && (!key_pressed[3]))
    hero->hero_index = 1;
  else // walking
  {
    hero->walk_offset += 1;
    if (hero->walk_offset > 4)
      hero->walk_offset = 0;
    hero->hero_index = (hero->walk_offset < 2 ? 2 : 4);
    if (key_pressed[1])
      hero->flip = true;
  }

  // judge color
  hero->hair_color = hero->dashes;

  // next level
  if (hero->y < -8 && level_index < level_tot - 1) // level_tot =2
  {
    level_index++;
    collision_fill(level_index);
    // set map
    for (int i = 0; i < 16; i++)
    {
      for (int j = 0; j < 16; j++)
      {
        setMAP(i * 16 + j, map[level_index][i][j]);
      }
    }
    hero->hero_index = 0;
    setHERO(hero->hero_index, hero->x, hero->y, hero->flip, hero->hair_color, 0,
            0);
    player_init(hero, birth[level_index][0], birth[level_index][1]);
    usleep(100000);
    // TODO:
  }
}

int main()
{
  SGTL5000_init();
  printf("SGTL5000 initialized!\n");
  BYTE rcode;
  BOOT_MOUSE_REPORT buf; // USB mouse report
  BOOT_KBD_REPORT kbdbuf;

  BYTE runningdebugflag = 0; // flag to dump out a bunch of information when we
                             // first get to USB_STATE_RUNNING
  BYTE errorflag = 0;        // flag once we get an error device so we don't keep
                             // dumping out state info
  BYTE device;
  WORD keycode;

  printf("initializing MAX3421E...\n");
  MAX3421E_init();
  printf("initializing USB...\n");
  USB_init();

  // init collide_box
  // wall
  for (int i = 0; i < 4; i++)
  {
    for (int j = 0; j < 4; j++)
    {
      collide_box[32][i][j] = 1;
      collide_box[33][i][j] = 1;
      collide_box[34][i][j] = 1;
      collide_box[35][i][j] = 1;
      collide_box[36][i][j] = 1;
      collide_box[37][i][j] = 1;
      collide_box[38][i][j] = 1;
      collide_box[39][i][j] = 1;
      collide_box[48][i][j] = 1;
      collide_box[49][i][j] = 1;
      collide_box[50][i][j] = 1;
      collide_box[51][i][j] = 1;
      collide_box[52][i][j] = 1;
      collide_box[53][i][j] = 1;
      collide_box[54][i][j] = 1;
      collide_box[55][i][j] = 1;
      collide_box[64][i][j] = 1;
      collide_box[65][i][j] = 1;
      collide_box[80][i][j] = 1;
      collide_box[81][i][j] = 1;
      collide_box[72][i][j] = 1;
    }
  }
  // spike
  for (int i = 0; i < 4; i++)
  {
    collide_box[17][3][i] = -1;
    collide_box[27][0][i] = -1;
    collide_box[43][i][0] = -1;
    collide_box[59][i][3] = -1;
  }
  // ice
  for (int i = 0; i < 4; i++)
  {
    for (int j = 0; j < 4; j++)
    {
      collide_box[66][i][j] = 2;
      collide_box[67][i][j] = 2;
      collide_box[68][i][j] = 2;
      collide_box[69][i][j] = 2;
      collide_box[82][i][j] = 2;
      collide_box[83][i][j] = 2;
      collide_box[84][i][j] = 2;
      collide_box[85][i][j] = 2;
      collide_box[98][i][j] = 2;
      collide_box[99][i][j] = 2;
      collide_box[100][i][j] = 2;
      collide_box[101][i][j] = 2;
      collide_box[114][i][j] = 2;
      collide_box[115][i][j] = 2;
      collide_box[116][i][j] = 2;
      collide_box[117][i][j] = 2;
      // collide_box[22][i][j] = 3;  // balloon
      collide_box[102][i][j] = 4; // two dashes
    }
  }

  // init birth
  birth[0][0] = 4;
  birth[0][1] = 181;
  birth[1][0] = 16;
  birth[1][1] = 208;
  birth[2][0] = 32;
  birth[2][1] = 152;
  birth[3][0] = 32;
  birth[3][1] = 196;
  birth[4][0] = 64;
  birth[4][1] = 192;
  birth[5][0] = 16;
  birth[5][1] = 208;
  birth[6][0] = 0;
  birth[6][1] = 216;

  // set collision
  collision_fill(0);

  // set map
  for (int i = 0; i < 16; i++)
  {
    for (int j = 0; j < 16; j++)
    {
      setMAP(i * 16 + j, map[0][i][j]);
    }
  }

  struct Player hero;

  player_init(&hero, birth[0][0], birth[0][1]);

  BYTE HERO_X, HERO_Y;
  int flag_cnt = 0; // (0~14)/5

  while (1)
  {
    usleep(8000);

    if (level_index == level_tot - 1) // flag animation
    {
      int temp = flag_cnt / 5;
      setMAP(103, 118 + temp);
      flag_cnt++;
      if (flag_cnt == 15)
        flag_cnt = 0;
    }

    key_detect(kbdbuf);

    // printf("x = %d\n", hero.x);
    // printf("y = %d\n", hero.y);
    // printf("spdX = %d\n", hero.spdX);
    // printf("spdY = %d\n", hero.spdY);

    Playerstep(&hero);

    if (hero.dead || hero.dead2)
    {
      if (hero.dead)
        hero.hero_index = 2;
      else
        hero.hero_index = 0;
      setHERO(hero.hero_index, hero.x, hero.y, 0, 1, 1, 1);
      usleep(120000); // half second
      player_init(&hero, birth[level_index][0], birth[level_index][1]);
    }

    HERO_X = hero.x;
    HERO_Y = hero.y;
    setHERO(hero.hero_index, hero.x, hero.y, hero.flip, hero.hair_color,
            hero.shake, hero.shake);

    printSignedHex0(death_tot);
    //    setHERO(HERO_X, HERO_Y);

    USB_Task();
    BYTE TaskState = GetUsbTaskState();
    if (TaskState == USB_STATE_RUNNING)
    {
      rcode = kbdPoll(&kbdbuf);
    }
  }
  return 0;
}
