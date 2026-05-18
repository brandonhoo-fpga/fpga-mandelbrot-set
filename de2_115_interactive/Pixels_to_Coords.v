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
    input                   i_Clk,          // 25MHz Clock
    input                   i_VSync,        // VSync to Update at New Frame
    input [9:0]             i_X_Value,      // VGA column 0..639
    input [9:0]             i_Y_Value,      // VGA row 0..479
    input                   i_Pan_Dir,      // Pan Direction (UL/DR)
    input                   i_Pan_UL,       // Pan Up or Left
    input                   i_Pan_DR,       // Pan Down or Right
    input                   i_Zoom_In,      // Zoom In
    input                   i_Zoom_Out,     // Zoom Out
    output signed [17:0]    o_C_Real,       // Q4.14 real component
    output signed [17:0]    o_C_Imag        // Q4.14 imaginary component
    );

// Detect Rising Edge of Vsync
reg r_VSync;
wire w_VSync_Rising = i_VSync & ~r_VSync;

// Counter for tick once per second 60Hz -> 1Hz
reg[5:0] r_VSync_Counter = 6'd0;
wire w_Tick = w_VSync_Rising & (r_VSync_Counter == 6'd14);

// Registers for Default Window
reg signed [17:0]   r_Offset_Real = -18'sd32768;
reg signed [17:0]   r_Offset_Imag = -18'sd18432;
reg signed [17:0]   r_Step        =  18'sd77;

always @(posedge i_Clk) 
begin
    r_VSync <= i_VSync;

    // Counter for w_Tick
    if (w_VSync_Rising)
    begin
        if (r_VSync_Counter == 14)
            r_VSync_Counter <= 0;
        else
            r_VSync_Counter <= r_VSync_Counter + 1;
    end

    // Apply pan/zoom once per second while button is held
    if (w_Tick)
    begin
        
        // Zoom In or Out
        if (i_Zoom_In && r_Step > 18'sd2)
        begin
            r_Offset_Real <= r_Offset_Real + ((r_Step >>> 3) * 18'sd320);
            r_Offset_Imag <= r_Offset_Imag + ((r_Step >>> 3) * 18'sd240);
            r_Step <= r_Step - (r_Step >>> 3);
        end
        else if (i_Zoom_Out)
        begin
            r_Offset_Real <= r_Offset_Real - ((r_Step >>> 3) * 18'sd320);
            r_Offset_Imag <= r_Offset_Imag - ((r_Step >>> 3) * 18'sd240);
            r_Step <= r_Step + (r_Step >>> 3);
        end

        // Pan UL or DR
        if (i_Pan_UL) 
        begin
            if (i_Pan_Dir)
                r_Offset_Imag <= r_Offset_Imag - (r_Step <<< 6);
            else
                r_Offset_Real <= r_Offset_Real - (r_Step <<< 6);
        end
        else if (i_Pan_DR)
        begin
            if (i_Pan_Dir)
                r_Offset_Imag <= r_Offset_Imag + (r_Step <<< 6);
            else
                r_Offset_Real <= r_Offset_Real + (r_Step <<< 6);
        end
    end
end

assign o_C_Real = r_Offset_Real + ($signed({8'b0, i_X_Value}) * r_Step);
assign o_C_Imag = r_Offset_Imag + ($signed({8'b0, i_Y_Value}) * r_Step);

endmodule
