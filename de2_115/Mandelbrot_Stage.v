// ============================================================================
// File Name   : Mandelbrot_Stage.v
// Author      : Brandon Hoo
// Description : Single iteration of the Mandelbrot recurrence Z = Z^2 + C.
//               Performs three Q4.14 multiplications, computes the next Z,
//               and tests escape against |Z|^2 > 4. State (C, Z, sync, valid,
//               escape) is registered and propagated to the next pipeline
//               stage. Once a pixel escapes, escape stays sticky and the
//               iteration count at escape is latched.
// ============================================================================

module Mandelbrot_Stage #(
    parameter ITER = 32,
    parameter STAGE = 0                             // Index of this stage in the pipeline
)
(
    input                       i_Clk,              // 25MHz pixel clock
    input signed [17:0]         i_C_Real,           // C real component (constant per pixel)
    input signed [17:0]         i_C_Imag,           // C imaginary component
    input signed [17:0]         i_Z_Real,           // Z real component from previous stage
    input signed [17:0]         i_Z_Imag,           // Z imaginary component from previous stage
    input                       i_HSync,            // HSync from previous stage
    input                       i_VSync,            // VSync from previous stage
    input                       i_Valid,            // Valid from previous stage
    input                       i_Escape,           // Sticky escape flag
    input [$clog2(ITER):0]      i_Iter_Escape,      // Iteration index when escape first occurred

    output reg signed [17:0]    o_C_Real,           // C real propagated forward
    output reg signed [17:0]    o_C_Imag,           // C imaginary propagated forward
    output reg signed [17:0]    o_Z_Real,           // Z real after this iteration
    output reg signed [17:0]    o_Z_Imag,           // Z imaginary after this iteration
    output reg                  o_HSync,            // HSync delayed by 1 cycle
    output reg                  o_VSync,            // VSync delayed by 1 cycle
    output reg                  o_Valid,            // Valid delayed by 1 cycle
    output reg                  o_Escape,           // Escape flag (sticky)
    output reg [$clog2(ITER):0] o_Iter_Escape       // Iteration index where escape occurred
);


// Q4.14 multiplications produce 36-bit signed intermediate results
wire signed [35:0] w_Z_Real_Sq = i_Z_Real * i_Z_Real;
wire signed [35:0] w_Z_Imag_Sq = i_Z_Imag * i_Z_Imag;
wire signed [35:0] w_Z_Cross   = i_Z_Real * i_Z_Imag;

// Truncate back to 18-bit Q4.14 by dropping 14 fractional bits
wire signed [17:0] w_Z_Real_Sq_18 = w_Z_Real_Sq >>> 14;
wire signed [17:0] w_Z_Imag_Sq_18 = w_Z_Imag_Sq >>> 14;
wire signed [17:0] w_Z_Cross_18   = w_Z_Cross   >>> 14;

// Z_next = (Zr^2 - Zi^2 + Cr) + j(2*Zr*Zi + Ci)
wire signed [17:0] w_Z_Real_Next = w_Z_Real_Sq_18 - w_Z_Imag_Sq_18 + i_C_Real;
wire signed [17:0] w_Z_Imag_Next = (w_Z_Cross_18 <<< 1) + i_C_Imag;

always @(posedge i_Clk)
    begin
        // Propagate constant-per-pixel signals
        o_C_Real <= i_C_Real;
        o_C_Imag <= i_C_Imag;
        o_HSync <= i_HSync;
        o_VSync <= i_VSync;
        o_Valid <= i_Valid;

        // Escape test: |Z|^2 > 4.0 in Q4.14 (4.0 = 18'sd65536)
        if (i_Escape == 1'b1 || (w_Z_Real_Sq_18 + w_Z_Imag_Sq_18 > 18'sd65536))
        begin
            o_Escape <= 1'b1;
            o_Z_Real <= i_Z_Real;
            o_Z_Imag <= i_Z_Imag;

            // Latch the iteration index when escape first occurred
            if (i_Escape == 0)
                o_Iter_Escape <= STAGE;
            else
                o_Iter_Escape <= i_Iter_Escape;
        end
        else
        begin
            // Still bounded: continue iterating
            o_Escape <= 1'b0;
            o_Iter_Escape <= ITER;
            o_Z_Real <= w_Z_Real_Next;
            o_Z_Imag <= w_Z_Imag_Next;
        end
    end
endmodule
