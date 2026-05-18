// ============================================================================
// File Name   : Mandelbrot_Set.v
// Author      : Brandon Hoo
// Description : Top-level module for the original Nandland Go Board attempt
//               at the Mandelbrot visualizer. The Go Board's 25MHz clock is
//               consumed directly (no divider needed) and its 3-bit-per-
//               channel VGA output drives the visible pixels.
//
//               Note: This was the initial port target before realizing
//               the iCE40HX1K's resource budget (8 DSP blocks, ~1280 LUTs)
//               could not host the 32-stage pipeline. Project was migrated
//               to the DE2-115 (Cyclone IV EP4CE115).
// ============================================================================

module main(
    input i_Clk,                    // 25MHz onboard clock

    output o_VGA_HSync,             // VGA horizontal sync
    output o_VGA_VSync,             // VGA vertical sync
    output o_VGA_Red_0,             // Red channel bit 0 (LSB)
    output o_VGA_Red_1,             // Red channel bit 1
    output o_VGA_Red_2,             // Red channel bit 2 (MSB)
    output o_VGA_Grn_0,             // Green channel bit 0 (LSB)
    output o_VGA_Grn_1,             // Green channel bit 1
    output o_VGA_Grn_2,             // Green channel bit 2 (MSB)
    output o_VGA_Blu_0,             // Blue channel bit 0 (LSB)
    output o_VGA_Blu_1,             // Blue channel bit 1
    output o_VGA_Blu_2              // Blue channel bit 2 (MSB)
);

// VGA 640x480 @ 60Hz timing
parameter c_VIDEO_WIDTH = 3;
parameter c_TOTAL_COLS = 800;
parameter c_TOTAL_ROWS = 525;
parameter c_ACTIVE_COLS = 640;
parameter c_ACTIVE_ROWS = 480;
parameter c_ITERATION_COUNT = 32;


wire [c_VIDEO_WIDTH-1:0] w_Red_Final;
wire [c_VIDEO_WIDTH-1:0] w_Grn_Final;
wire [c_VIDEO_WIDTH-1:0] w_Blu_Final;

wire [9:0] w_Row_Count;
wire [9:0] w_Col_Count;

wire w_HSync_Start, w_HSync_Porch, w_HSync_Final;
wire w_VSync_Start, w_VSync_Porch, w_VSync_Final;


// VGA pixel/row counter and active-region sync generator
VGA_Sync_Pulses #(
    .TOTAL_COLS(c_TOTAL_COLS),
    .TOTAL_ROWS(c_TOTAL_ROWS),
    .ACTIVE_COLS(c_ACTIVE_COLS),
    .ACTIVE_ROWS(c_ACTIVE_ROWS)
    )
VGA_Sync_Pulses_Inst (
    .i_Clk(i_Clk),
    .o_HSync(w_HSync_Start),
    .o_VSync(w_VSync_Start),
    .o_Col_Count(w_Col_Count),
    .o_Row_Count(w_Row_Count)
    );

// Generates VGA-spec HSync/VSync that the monitor locks onto
// Video gating path unused (handled by iteration pipeline's valid signal)
VGA_Sync_Porch #(
    .VIDEO_WIDTH(c_VIDEO_WIDTH),
    .TOTAL_COLS(c_TOTAL_COLS),
    .TOTAL_ROWS(c_TOTAL_ROWS),
    .ACTIVE_COLS(c_ACTIVE_COLS),
    .ACTIVE_ROWS(c_ACTIVE_ROWS)
    )
VGA_Sync_Porch_Inst (
    .i_Clk(i_Clk),
    .i_Col_Count(w_Col_Count),
    .i_Row_Count(w_Row_Count),
    .i_HSync(w_HSync_Start),
    .i_VSync(w_VSync_Start),
    .i_Red_Video(3'b000),
    .i_Grn_Video(3'b000),
    .i_Blu_Video(3'b000),
    .o_HSync(w_HSync_Porch),
    .o_VSync(w_VSync_Porch),
    .o_Red_Video(),
    .o_Grn_Video(),
    .o_Blu_Video()
    );

// Mandelbrot compute pipeline
Mandelbrot_Engine #(
    .VIDEO_WIDTH(c_VIDEO_WIDTH),
    .TOTAL_COLS(c_TOTAL_COLS),
    .TOTAL_ROWS(c_TOTAL_ROWS),
    .ACTIVE_COLS(c_ACTIVE_COLS),
    .ACTIVE_ROWS(c_ACTIVE_ROWS),
    .ITERATION_COUNT(c_ITERATION_COUNT)
    )
Mandelbrot_Engine_Inst (
    .i_Clk(i_Clk),
    .i_Col_Count(w_Col_Count),
    .i_Row_Count(w_Row_Count),
    .i_HSync(w_HSync_Porch),
    .i_VSync(w_VSync_Porch),
    .o_Valid(),
    .o_HSync(w_HSync_Final),
    .o_VSync(w_VSync_Final),
    .o_Red_Video(w_Red_Final),
    .o_Grn_Video(w_Grn_Final),
    .o_Blu_Video(w_Blu_Final)
    );


// Sync and RGB outputs
assign o_VGA_HSync = w_HSync_Final;
assign o_VGA_VSync = w_VSync_Final;

assign o_VGA_Red_0 = w_Red_Final[0];
assign o_VGA_Red_1 = w_Red_Final[1];
assign o_VGA_Red_2 = w_Red_Final[2];

assign o_VGA_Grn_0 = w_Grn_Final[0];
assign o_VGA_Grn_1 = w_Grn_Final[1];
assign o_VGA_Grn_2 = w_Grn_Final[2];

assign o_VGA_Blu_0 = w_Blu_Final[0];
assign o_VGA_Blu_1 = w_Blu_Final[1];
assign o_VGA_Blu_2 = w_Blu_Final[2];

endmodule
