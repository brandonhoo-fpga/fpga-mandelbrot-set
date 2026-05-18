// ============================================================================
// File Name   : Mandelbrot_Engine.v
// Author      : Brandon Hoo
// Description : Glue module that ties pixel coordinates to the Mandelbrot
//               iteration pipeline. Maps the current VGA (col, row) to a
//               complex C value via Pixels_to_Coords, then feeds it into
//               the Mandelbrot_Iterations pipeline along with the active
//               region valid signal.
// ============================================================================

module Mandelbrot_Engine #(
    parameter VIDEO_WIDTH = 3,
    parameter ACTIVE_COLS = 640,
    parameter ACTIVE_ROWS = 480,
    parameter ITERATION_COUNT = 32
    )
    (
    input                       i_Clk,              // 25MHz pixel clock
    input [9:0]                 i_Col_Count,        // Current pixel column from VGA timing
    input [9:0]                 i_Row_Count,        // Current pixel row from VGA timing
    input                       i_HSync,            // VGA-spec HSync from porch
    input                       i_VSync,            // VGA-spec VSync from porch
    output                      o_Valid,            // High while pixel is in active region
    output                      o_HSync,            // HSync delayed to align with color output
    output                      o_VSync,            // VSync delayed to align with color output
    output [VIDEO_WIDTH-1:0]    o_Red_Video,        // Red channel
    output [VIDEO_WIDTH-1:0]    o_Grn_Video,        // Green channel
    output [VIDEO_WIDTH-1:0]    o_Blu_Video         // Blue channel
    );

// C value for the current pixel (Q4.14 fixed point)
wire signed [17:0] w_C_Real;
wire signed [17:0] w_C_Imag;

// Active video region indicator (input to iteration pipeline)
wire w_Active_Start = (i_Col_Count < ACTIVE_COLS) && (i_Row_Count < ACTIVE_ROWS);

// Map (col, row) -> complex C
Pixels_to_Coords Pixels_to_Coords_Inst (
    .i_X_Value(i_Col_Count),
    .i_Y_Value(i_Row_Count),
    .o_C_Real(w_C_Real),
    .o_C_Imag(w_C_Imag)
    );

// Pipelined iteration engine
Mandelbrot_Iterations #(
    .VIDEO_WIDTH(VIDEO_WIDTH),
    .ITER(ITERATION_COUNT)
    )
Mandelbrot_Iterations_Inst (
    .i_Clk(i_Clk),
    .i_HSync(i_HSync),
    .i_VSync(i_VSync),
    .i_C_Real(w_C_Real),
    .i_C_Imag(w_C_Imag),
    .i_Valid(w_Active_Start),
    .o_Valid(o_Valid),
    .o_HSync(o_HSync),
    .o_VSync(o_VSync),
    .o_Red_Video(o_Red_Video),
    .o_Grn_Video(o_Grn_Video),
    .o_Blu_Video(o_Blu_Video)
    );

endmodule
