# Final Project - Celeste on FPGA

We made a 2D pixel game the Classic Celeste(pico-8 version). In this game, you are going to control the hero Madline to climb up the mountain, pass through obstacles and find the tophill flag.

Madline can move left and right and has the ability of jumping and dashing, which are controlled by 6 keys in total.

Our design includes hardware part that deals with video output with some visual effects and audio output that can play a squarewave, and software part that handles the game logic. Hardware uses on-chip memory to implement double frame buffer and store the sprite table. Software runs on SDRAM. We use USB keyboard as input and display hero and map using VGA output.

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
