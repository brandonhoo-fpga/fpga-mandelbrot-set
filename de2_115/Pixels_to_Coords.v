// ============================================================================
// File Name   : Pixels_to_Coords.v
// Author      : Brandon Hoo
// Description : Combinational converter from VGA pixel coordinates to a
//               point in the complex plane. Maps the 640x480 active region
//               to roughly the [-2.0, +1.0] x [-1.125, +1.125] window of the
//               Mandelbrot set in Q4.14 fixed point.
//
//               Constants: -32768 = -2.0, -18432 = -1.125, 77 ~= 0.0047
//               (per-pixel step sized to span ~3 units across 640 columns
//               and ~2.25 units across 480 rows).
// ============================================================================

module Pixels_to_Coords
    (
    input [9:0]             i_X_Value,      // VGA column 0..639
    input [9:0]             i_Y_Value,      // VGA row 0..479
    output signed [17:0]    o_C_Real,       // Q4.14 real component
    output signed [17:0]    o_C_Imag        // Q4.14 imaginary component
    );

assign o_C_Real = -18'sd32768 + ($signed({8'b0, i_X_Value}) * 18'sd77);
assign o_C_Imag = -18'sd18432 + ($signed({8'b0, i_Y_Value}) * 18'sd77);

endmodule
