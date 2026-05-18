// ============================================================================
// File Name   : Mandelbrot_Iterations.v
// Author      : Brandon Hoo
// Description : Generate-loop that builds the deeply pipelined iteration
//               engine. ITER stages of Mandelbrot_Stage are chained together
//               with mem_* arrays carrying state from one stage to the next.
//               After all ITER iterations complete, the final stage's escape
//               flag and iter-escape count drive the color output:
//                 - Never escaped (in the set): black
//                 - Escaped quickly: dark
//                 - Escaped slowly: bright (white at the boundary)
// ============================================================================

module Mandelbrot_Iterations #(
    parameter VIDEO_WIDTH = 3,
    parameter ITER = 32                             // Pipeline depth
    )
    (
    input                           i_Clk,          // 25MHz pixel clock
    input                           i_HSync,        // VGA-spec HSync
    input                           i_VSync,        // VGA-spec VSync
    input signed [17:0]             i_C_Real,       // Q4.14 real component
    input signed [17:0]             i_C_Imag,       // Q4.14 imaginary component
    input                           i_Valid,        // Active region indicator
    output reg                      o_Valid,        // Valid delayed by ITER cycles
    output reg                      o_HSync,        // HSync delayed by ITER cycles
    output reg                      o_VSync,        // VSync delayed by ITER cycles
    output reg [VIDEO_WIDTH-1:0]    o_Red_Video,    // Red channel
    output reg [VIDEO_WIDTH-1:0]    o_Grn_Video,    // Green channel
    output reg [VIDEO_WIDTH-1:0]    o_Blu_Video     // Blue channel
    );

// Pipeline state buses (ITER+1 deep so each stage gets input + output slot)
wire signed [17:0] mem_C_Real [0: ITER];
wire signed [17:0] mem_C_Imag [0: ITER];

wire signed [17:0] mem_Z_Real [0: ITER];
wire signed [17:0] mem_Z_Imag [0: ITER];

wire mem_HSync [0 :ITER];
wire mem_VSync [0 :ITER];

wire mem_Valid [0 :ITER];

wire mem_Escape [0 :ITER];
wire [$clog2(ITER):0] mem_Iter_Escape [0 :ITER];


// Pipeline entry: seed Z = 0, attach incoming C and sync signals
assign mem_C_Real[0] = i_C_Real;
assign mem_C_Imag[0] = i_C_Imag;
assign mem_Z_Real[0] = 18'sd0;
assign mem_Z_Imag[0] = 18'sd0;
assign mem_HSync[0] = i_HSync;
assign mem_VSync[0] = i_VSync;
assign mem_Valid[0] = i_Valid;
assign mem_Escape [0] = 1'b0;
assign mem_Iter_Escape[0] = 0;


// Build the pipeline
generate
    genvar i;
    for (i = 0; i < ITER; i = i + 1) begin : pipeline
        Mandelbrot_Stage #(
            .ITER(ITER),
            .STAGE(i)
        )
        Mandelbrot_Stage_Inst
        (
            .i_Clk(i_Clk),
            .i_C_Real(mem_C_Real[i]),
            .i_C_Imag(mem_C_Imag[i]),
            .i_Z_Real(mem_Z_Real[i]),
            .i_Z_Imag(mem_Z_Imag[i]),
            .i_HSync(mem_HSync[i]),
            .i_VSync(mem_VSync[i]),
            .i_Valid(mem_Valid[i]),
            .i_Escape(mem_Escape[i]),
            .i_Iter_Escape(mem_Iter_Escape[i]),

            .o_C_Real(mem_C_Real[i+1]),
            .o_C_Imag(mem_C_Imag[i+1]),
            .o_Z_Real(mem_Z_Real[i+1]),
            .o_Z_Imag(mem_Z_Imag[i+1]),
            .o_HSync(mem_HSync[i+1]),
            .o_VSync(mem_VSync[i+1]),
            .o_Valid(mem_Valid[i+1]),
            .o_Escape(mem_Escape[i+1]),
            .o_Iter_Escape(mem_Iter_Escape[i+1])
        );
    end
endgenerate



localparam TOTAL_COLOR_BITS = VIDEO_WIDTH * 3;

// Map iter_escape (0..ITER) to a shift amount across all RGB bits
wire [$clog2(TOTAL_COLOR_BITS + 1) - 1: 0] w_Shift_Amount = (mem_Iter_Escape[ITER] * TOTAL_COLOR_BITS) / ITER;

// Inverted gradient: fast escape = dark, slow escape = bright
wire [TOTAL_COLOR_BITS - 1 : 0] w_Gradient_Color = ~({TOTAL_COLOR_BITS{1'b1}} >> w_Shift_Amount);


always @(posedge i_Clk)
begin
    o_Valid <= mem_Valid[ITER];
    o_HSync <= mem_HSync[ITER];
    o_VSync <= mem_VSync[ITER];

    if(mem_Valid[ITER] == 1'b1)
    begin
        if(mem_Escape[ITER] == 1'b0)
        begin
            // Never escaped (in the set): black
            o_Red_Video <= {VIDEO_WIDTH{1'b0}};
            o_Grn_Video <= {VIDEO_WIDTH{1'b0}};
            o_Blu_Video <= {VIDEO_WIDTH{1'b0}};
        end
        else
        begin
            o_Red_Video <= w_Gradient_Color[TOTAL_COLOR_BITS - 1 : VIDEO_WIDTH * 2];
            o_Grn_Video <= w_Gradient_Color[(VIDEO_WIDTH*2) - 1 : VIDEO_WIDTH];
            o_Blu_Video <= w_Gradient_Color[VIDEO_WIDTH - 1 : 0];
        end
    end
    else
    begin
        // Outside active region: black
        o_Red_Video <= {VIDEO_WIDTH{1'b0}};
        o_Grn_Video <= {VIDEO_WIDTH{1'b0}};
        o_Blu_Video <= {VIDEO_WIDTH{1'b0}};
    end

end


endmodule
