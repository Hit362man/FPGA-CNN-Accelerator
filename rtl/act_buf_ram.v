module act_buf_ram (
    input  wire        clk,
    
    // Port A: writes from Arduino capture
    input  wire        we_a,
    input  wire [9:0]  addr_a,
    input  wire [7:0]  din_a,

    // Port B: reads by convolution core
    input  wire [9:0]  addr_b,
    output reg  [7:0]  dout_b
);

    reg [7:0] mem [0:783];  // 784 bytes

    always @(posedge clk) begin
        if (we_a)
            mem[addr_a] <= din_a;
        dout_b <= mem[addr_b];
    end

endmodule
