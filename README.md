# Final Project - Celeste on FPGA

## Implemented Functions

- 256x256 60Hz display supporting sixteen 24-bit colors
- 100MHz NIOS II
- Support displaying 128 different tiles
- Multiple Maps that can customize
- Dynamic Background with random moving clouds
- Double buffering for better video rendering output
- Hero death count
- Score Keeping
- Beeping with 440Hz square wave
- Screen shaking effect
- Hero Appearance change
- Advanced hero movements including jump, dash & double dash
- Optimization of hero movements such as coyoto time and jump buffering
- Map objects interactions like spike and skill upgrader (green ball)

## Basic Usage

1. Program hardware part with `.soc`  in Quartus. 
2. Plug in keyboard to the USB port on provided shield.
3. Run software part with `.elf` in Eclipse. 
4. Plug in VGA cable for video output.
5. Plug in 3.5mm audio cable for audio output.