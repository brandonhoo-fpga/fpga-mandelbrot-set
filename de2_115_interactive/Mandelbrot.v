// ============================================================================
// File Name   : Mandelbrot.v
// Author      : Brandon Hoo
// Description : Top-level module for the DE2-115 port of the Mandelbrot
//               visualizer. Divides the board's 50MHz input clock down to
//               25MHz, instantiates the VGA timing pipeline and the
//               Mandelbrot engine, and drives the ADV7123 video DAC pins
//               at 8 bits per channel with a 64-stage iteration depth.
//
//               Note: The toggle-flop clock divider used here is bad
//               practice. A proper PLL (ALTPLL) would route a true 25MHz
//               clock through the dedicated clock tree.
// ============================================================================

module Mandelbrot(
    input i_Clk,                    // 50MHz onboard oscillator

    input i_Switch,                 // Switch for interactive pan
    input i_Button1,                // Push button for interactive pan
    input i_Button2,                // Push button for interactive pan
    input i_Button3,                // Push button for interactive zoom
    input i_Button4,                // Push button for interactive zoom

    output o_VGA_HSync,             // VGA horizontal sync
    output o_VGA_VSync,             // VGA vertical sync
    output o_VGA_Red_0,             // Red channel bit 0 (LSB)
    output o_VGA_Red_1,             // Red channel bit 1
    output o_VGA_Red_2,             // Red channel bit 2
    output o_VGA_Red_3,             // Red channel bit 3
    output o_VGA_Red_4,             // Red channel bit 4
    output o_VGA_Red_5,             // Red channel bit 5
    output o_VGA_Red_6,             // Red channel bit 6
    output o_VGA_Red_7,             // Red channel bit 7 (MSB)
    output o_VGA_Grn_0,             // Green channel bit 0 (LSB)
    output o_VGA_Grn_1,             // Green channel bit 1
    output o_VGA_Grn_2,             // Green channel bit 2
    output o_VGA_Grn_3,             // Green channel bit 3
    output o_VGA_Grn_4,             // Green channel bit 4
    output o_VGA_Grn_5,             // Green channel bit 5
    output o_VGA_Grn_6,             // Green channel bit 6
    output o_VGA_Grn_7,             // Green channel bit 7 (MSB)
    output o_VGA_Blu_0,             // Blue channel bit 0 (LSB)
    output o_VGA_Blu_1,             // Blue channel bit 1
    output o_VGA_Blu_2,             // Blue channel bit 2
    output o_VGA_Blu_3,             // Blue channel bit 3
    output o_VGA_Blu_4,             // Blue channel bit 4
    output o_VGA_Blu_5,             // Blue channel bit 5
    output o_VGA_Blu_6,             // Blue channel bit 6
    output o_VGA_Blu_7,             // Blue channel bit 7 (MSB)

    output o_VGA_Clk,               // ADV7123 pixel clock input
    output o_VGA_Blank_n,           // ADV7123 active-low blanking
    output o_VGA_Sync_n             // ADV7123 sync-on-green disable (tied low)
);

// VGA 640x480 @ 60Hz timing
parameter c_VIDEO_WIDTH = 8;        // 8 bits per channel via ADV7123 DAC
parameter c_TOTAL_COLS = 800;
parameter c_TOTAL_ROWS = 525;
parameter c_ACTIVE_COLS = 640;
parameter c_ACTIVE_ROWS = 480;
parameter c_ITERATION_COUNT = 64;   // 64-stage pipeline (192 DSP blocks total)


wire [c_VIDEO_WIDTH-1:0] w_Red_Final;
wire [c_VIDEO_WIDTH-1:0] w_Grn_Final;
wire [c_VIDEO_WIDTH-1:0] w_Blu_Final;

wire [9:0] w_Row_Count;
wire [9:0] w_Col_Count;

wire w_HSync_Start, w_HSync_Porch, w_HSync_Final;
wire w_VSync_Start, w_VSync_Porch, w_VSync_Final;

wire w_Clk_25MHz;
wire w_PLL_Locked;

PLL_25MHz PLL_Inst (
    .inclk0 (i_Clk),
    .c0     (w_Clk_25MHz),
    .locked (w_PLL_Locked)
);

// Wires for debounced button inputs
wire w_Button1;
wire w_Button2;
wire w_Button3;
wire w_Button4;

// Instantiation of Debounce Module for Button 1
Debounce Debounce_Inst1(
    .i_Clk(w_Clk_25MHz),
    .i_Switch(~i_Button1),
    .o_Switch(w_Button1)
);

// Instantiation of Debounce Module for Button 2
Debounce Debounce_Inst2(
    .i_Clk(w_Clk_25MHz),
    .i_Switch(~i_Button2),
    .o_Switch(w_Button2)
);

// Instantiation of Debounce Module for Button 3
Debounce Debounce_Inst3(
    .i_Clk(w_Clk_25MHz),
    .i_Switch(~i_Button3),
    .o_Switch(w_Button3)
);

// Instantiation of Debounce Module for Button 4
Debounce Debounce_Inst4(
    .i_Clk(w_Clk_25MHz),
    .i_Switch(~i_Button4),
    .o_Switch(w_Button4)
);

// VGA pixel/row counter and active-region sync generator
VGA_Sync_Pulses #(
    .TOTAL_COLS(c_TOTAL_COLS),
    .TOTAL_ROWS(c_TOTAL_ROWS),
    .ACTIVE_COLS(c_ACTIVE_COLS),
    .ACTIVE_ROWS(c_ACTIVE_ROWS)
    )
VGA_Sync_Pulses_Inst (
    .i_Clk(w_Clk_25MHz),
    .o_HSync(w_HSync_Start),
    .o_VSync(w_VSync_Start),
    .o_Col_Count(w_Col_Count),
    .o_Row_Count(w_Row_Count)
    );

// Generates VGA-spec HSync/VSync that the monitor locks onto
// Video gating path unused here: RGB inputs tied to 0, outputs left dangling
// (the iteration pipeline does its own active-region masking via the valid signal)
VGA_Sync_Porch #(
    .VIDEO_WIDTH(c_VIDEO_WIDTH),
    .TOTAL_COLS(c_TOTAL_COLS),
    .TOTAL_ROWS(c_TOTAL_ROWS),
    .ACTIVE_COLS(c_ACTIVE_COLS),
    .ACTIVE_ROWS(c_ACTIVE_ROWS)
    )
VGA_Sync_Porch_Inst (
    .i_Clk(w_Clk_25MHz),
    .i_Col_Count(w_Col_Count),
    .i_Row_Count(w_Row_Count),
    .i_HSync(w_HSync_Start),
    .i_VSync(w_VSync_Start),
    .i_Red_Video({c_VIDEO_WIDTH{1'b0}}),
    .i_Grn_Video({c_VIDEO_WIDTH{1'b0}}),
    .i_Blu_Video({c_VIDEO_WIDTH{1'b0}}),
    .o_HSync(w_HSync_Porch),
    .o_VSync(w_VSync_Porch),
    .o_Red_Video(),
    .o_Grn_Video(),
    .o_Blu_Video()
    );

// Mandelbrot compute pipeline
Mandelbrot_Engine #(
    .VIDEO_WIDTH(c_VIDEO_WIDTH),
    .ACTIVE_COLS(c_ACTIVE_COLS),
    .ACTIVE_ROWS(c_ACTIVE_ROWS),
    .ITERATION_COUNT(c_ITERATION_COUNT)
    )
Mandelbrot_Engine_Inst (
    .i_Clk(w_Clk_25MHz),
    .i_Pan_Dir(i_Switch),
    .i_Pan_UL(w_Button1),
    .i_Pan_DR(w_Button2),
    .i_Zoom_In(w_Button3),
    .i_Zoom_Out(w_Button4),
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


// ADV7123 control pins
assign o_VGA_Clk = w_Clk_25MHz;
assign o_VGA_Blank_n = 1'b1;
assign o_VGA_Sync_n  = 1'b0;

// Sync and RGB outputs
assign o_VGA_HSync = w_HSync_Final;
assign o_VGA_VSync = w_VSync_Final;

assign o_VGA_Red_0 = w_Red_Final[0];
assign o_VGA_Red_1 = w_Red_Final[1];
assign o_VGA_Red_2 = w_Red_Final[2];
assign o_VGA_Red_3 = w_Red_Final[3];
assign o_VGA_Red_4 = w_Red_Final[4];
assign o_VGA_Red_5 = w_Red_Final[5];
assign o_VGA_Red_6 = w_Red_Final[6];
assign o_VGA_Red_7 = w_Red_Final[7];

assign o_VGA_Grn_0 = w_Grn_Final[0];
assign o_VGA_Grn_1 = w_Grn_Final[1];
assign o_VGA_Grn_2 = w_Grn_Final[2];
assign o_VGA_Grn_3 = w_Grn_Final[3];
assign o_VGA_Grn_4 = w_Grn_Final[4];
assign o_VGA_Grn_5 = w_Grn_Final[5];
assign o_VGA_Grn_6 = w_Grn_Final[6];
assign o_VGA_Grn_7 = w_Grn_Final[7];

assign o_VGA_Blu_0 = w_Blu_Final[0];
assign o_VGA_Blu_1 = w_Blu_Final[1];
assign o_VGA_Blu_2 = w_Blu_Final[2];
assign o_VGA_Blu_3 = w_Blu_Final[3];
assign o_VGA_Blu_4 = w_Blu_Final[4];
assign o_VGA_Blu_5 = w_Blu_Final[5];
assign o_VGA_Blu_6 = w_Blu_Final[6];
assign o_VGA_Blu_7 = w_Blu_Final[7];

endmodule
