# FPGA Mandelbrot Set Visualizer (VGA Output)
A real-time hardware Mandelbrot Set renderer that outputs over VGA. Operates pixel-by-pixel using a deeply pipelined arithmetic engine: 64 stages of complex multiply-and-add, with one finished pixel produced per clock once the pipeline is full.

**Note:** This was my **second independent FPGA project**, built right after the Morse Code Decoder. It is the project where I first learned about deep pipelining, fixed-point arithmetic, and the difference between what a specific FPGA can and cannot fit. It is also the project where I had to switch hardware mid-development to actually finish the design.

## Hardware Demonstration
<img width="4079" height="3059" alt="Fractal" src="https://github.com/user-attachments/assets/2acb5382-f626-4133-bb56-cd1b1e7af9fd" />
The fractal renders continuously across the full 640x480 frame at 60Hz. Points inside the Mandelbrot set appear black, with a bright yellow halo at the boundary (points that take many iterations to escape) fading through red to black as the escape happens faster. 

## Interactive Extension (Pan + Zoom)

<img width="697" height="532" alt="Mandelbrot" src="https://github.com/user-attachments/assets/0e88e335-50ef-4228-9289-a0f803088978" />

After the base renderer was working, I extended the design in `de2_115_interactive/` so the board's pushbuttons drive pan and zoom in real time. KEY0 / KEY1 pan one axis, KEY2 / KEY3 zoom, and SW0 picks between horizontal and vertical panning.

### How It Works
The pixel-to-coordinate math in `Pixels_to_Coords.v` originally used three hardcoded constants: an upper-left offset (real and imaginary) and a per-pixel step. The interactive version promotes those constants to registers and updates them four times per second through a divide-by-15 counter on the 60Hz VSync rising edges. Updating only on VSync edges guarantees the entire window is consistent within each frame, so the screen never tears mid-update.

Each tick while a button is held:
* **Zoom**: the step shrinks by 1/8 (geometric, multiply by 7/8). The offset registers are simultaneously nudged by `delta_step * 320` and `delta_step * 240` so the screen *center* stays fixed during zoom, rather than the upper-left corner.
* **Pan**: the offset shifts by 64 pixels' worth of the current step. Because the pan distance scales with the step, panning at deep zoom moves the same number of screen pixels per press as panning at default zoom.
* The step is clamped above the Q4.14 resolution floor — once the per-pixel delta approaches `1/16384`, adjacent pixels start mapping to the same complex value and zooming further has no effect.

All of the per-tick math uses arithmetic shifts (`>>>`, `<<<`) instead of multipliers, so the addition uses zero new DSP blocks on top of the 192 already consumed by the iteration pipeline.

### Clock Cleanup (ALTPLL)
While I was in the project I also replaced the toggle-flop clock divider with a proper ALTPLL block. The toggle-flop produced a 25MHz clock from the routing fabric, which works visually but has high jitter. The PLL routes its 25MHz output through the dedicated clock tree and closes timing cleanly across all paths.

## Background & Migration Story
This project started as another Nandland Go Board target, the same board I had used for the Morse Code Decoder. Once the iteration pipeline started taking shape, the resource budget told me a different story:

* **iCE40HX1K (Go Board):** ~1280 LUTs, **8 DSP blocks** (16x16 multipliers).
* **Cyclone IV EP4CE115 (DE2-115):** ~114K LUTs, **266 DSP blocks** (18x18 multipliers).

Each pipeline stage needs three multiplications (Zr², Zi², Zr*Zi). With 64 stages, that is 192 multipliers, more than twenty times what the Go Board has. There was no way to fit the design on the iCE40 without serializing the iteration loop, which would have killed the per-pixel-per-clock throughput VGA needs.

The DE2-115 was the right move. Its 18x18 DSP blocks also align exactly with my Q4.14 fixed-point representation, so each multiplier maps cleanly to one DSP without LUT decomposition.

The migration required a few changes to the original Go Board code:
* **Clock divider:** the DE2-115's onboard oscillator is 50MHz, double the VGA pixel clock. I added a toggle-flop divider to halve it down to 25MHz. This is bad practice (later replaced with ALTPLL, see [Interactive Extension](#-interactive-extension-pan--zoom)), but the design works and I am keeping it as-is to reflect what I actually shipped.
* **ADV7123 video DAC pins:** the DE2-115 routes VGA through a video DAC that requires `o_VGA_Clk`, `o_VGA_Blank_n`, and `o_VGA_Sync_n` pins in addition to RGB and sync. The Go Board drives VGA directly from FPGA pins.
* **Top-level naming:** the apio toolchain expected a module named `main`. Quartus does not, so the top-level was renamed to `Mandelbrot`.

Once on the DE2-115, I also expanded the design beyond what the Go Board could hold. The iteration depth went from 32 to 64 stages, using 192 of the EP4CE115's 266 DSP blocks. The color depth went from 3 to 8 bits per channel via the ADV7123 video DAC, which eliminated the visible color banding from the 3-bit version.

## How It Works (System Architecture)
The design is split into a video-timing pipeline and a Mandelbrot compute pipeline.

### 1. Pixel-to-Coordinate Mapping
`Pixels_to_Coords.v` is a small combinational module that converts a VGA (col, row) into a complex C in Q4.14 fixed point. The mapping covers roughly the [-2.0, +1.0] x [-1.125, +1.125] window, which fits the classic Mandelbrot view. The math is just a constant offset plus a multiply by 77, no divisions or LUTs.

### 2. Iteration Pipeline
`Mandelbrot_Iterations.v` instantiates 64 copies of `Mandelbrot_Stage.v` in a generate loop, chaining them together with `mem_*` arrays that pass state from one stage to the next. Each stage performs one iteration of `Z = Z² + C` and tests escape against the standard `|Z|² > 4` boundary. Once a pixel escapes, the escape flag and iteration index become sticky and propagate unchanged through the remaining stages.

After all 64 stages, the final stage's `escape` flag and `iter_escape` count drive the color output:
* Never escaped (in the set): **black**
* Escaped slowly (boundary): **bright yellow**
* Escaped quickly: **red, fading to black** along a gradient

This was originally a fast-escape-bright gradient. I flipped it later with a single bitwise NOT, which gave the warm yellow/red halo that reads well on a real monitor.

### 3. Video Timing
`VGA_Sync_Pulses.v` and `VGA_Sync_Porch.v` were created when learning about VGA and follow the standard 800x525 / 640x480 VGA timing:

* **`VGA_Sync_Pulses`** generates row/col counters and an "active region" indicator that is high while the beam is inside the visible 640x480 area. This is a display-enable signal, not a real VGA sync signal.
* **`VGA_Sync_Porch`** takes the row/col counts from `VGA_Sync_Pulses` and generates the proper VGA-spec sync: `o_HSync` is low only during the 96-pixel sync pulse window (16 pixels of front porch after the active region ends, then 96 pixels of pulse), and high everywhere else. `o_VSync` does the same on the vertical axis. This is what the monitor actually locks onto.

The porch also offers an RGB gating path that blacks out video during blanking, but I deliberately route the color around it. The reason is the pipeline's 64-cycle latency: a pixel enters the iteration engine at time T and its color emerges at time T+64, while the porch's gating uses the current pixel position. Sending the color through the porch would gate it based on "is pixel T+64 in the active region?" while the actual color belongs to pixel T, misaligning the blanking by 64 pixels. Instead, the iteration pipeline carries a `valid` signal alongside each pixel through all 64 stages, and the final color logic uses that delayed valid to gate. Color, sync, and gating are all naturally aligned at the output.

## Tools & Hardware
* **Language:** Verilog
* **Primary Target:** Altera Cyclone IV (Terasic DE2-115)
* **Original Target:** Lattice iCE40HX1K (Nandland Go Board, abandoned mid-development)
* **Synthesis:** Intel Quartus II (DE2-115), Yosys / NextPNR / IceStorm (Go Board attempt)
* **Display:** VGA monitor at 640x480 @ 60Hz
* **Pixel Clock:** 25MHz
* **Color Depth:** 8 bits per channel (24-bit RGB) via ADV7123 video DAC

## Lessons Learned
This project taught me that **knowing the FPGA family matters as much as knowing Verilog**. The same RTL that compiled and worked on the DE2-115 was completely infeasible on the Go Board, and the limit was not in the code, it was in the chip. Picking the right hardware for a workload is part of the design.

It also taught me that **pipelining is the answer to "this is too slow."** Each Mandelbrot stage on its own is trivial (three multiplies and some adds), but iterating it 64 times sequentially per pixel would be far too slow for a 25MHz pixel clock. Spreading those 64 iterations across 64 hardware stages means the throughput is one finished pixel per clock, which exactly matches VGA. That tradeoff (more chip area for more parallelism) is one of the things FPGAs are actually good at.

Finally, this project reminded me that **fixed-point arithmetic is a real skill**. Picking Q4.14 deliberately and reasoning about how multiplications scale through the format takes some getting used to. Floating point would have been wildly out of scope for this project and totally unnecessary.
