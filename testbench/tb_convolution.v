`timescale 1ns/1ps
module tb_convolution;
    reg clk=0, reset_n=0, start=0;
    always #5 clk=~clk;
    wire done;
    wire [9:0] act_address;
    wire act_wren;
    reg [7:0] act_q;
    wire [8:0] wgt_address;
    wire wgt_rden;
    reg [7:0] wgt_q;
    wire [12:0] out_wraddress;
    wire [7:0] out_data;
    wire out_wren;
    wire [9:0] offset_k;
    wire [4:0] k;
    reg [7:0] image [0:783];
    reg [7:0] weights [0:511];
    integer i;
    integer write_count=0;
    reg [7:0] expected;

    // One-cycle synchronous input RAM and convolution weight ROM.
    always @(posedge clk) begin
        act_q <= image[act_address];
        if(wgt_rden) wgt_q <= weights[wgt_address];
    end

    // Check all 8 x 24 x 24 addresses and output values, in order.
    always @(posedge clk) if(out_wren && reset_n) begin
        if (out_wraddress !== write_count[12:0])
            $fatal(1,"output address: got %0d expected %0d",out_wraddress,write_count);
        if (write_count / 576 == 0) expected=50;
        else if (write_count / 576 == 2) expected=100;
        else if (write_count / 576 == 3) expected=255;
        else expected=0;
        if (out_data !== expected)
            $fatal(1,"output value: address %0d got %0d expected %0d",out_wraddress,out_data,expected);
        write_count=write_count+1;
    end

    cnn_conv5x5_core dut (
        .clk(clk),.reset_n(reset_n),.start(start),.done(done),
        .act_address(act_address),.act_wren(act_wren),.act_q(act_q),
        .wgt_address(wgt_address),.wgt_rden(wgt_rden),.wgt_q(wgt_q),
        .out_wraddress(out_wraddress),.out_data(out_data),.out_wren(out_wren),
        .offset_k(offset_k),.k(k));

    task kick;
        begin @(negedge clk); start=1; @(negedge clk); start=0; end
    endtask

    initial begin
        for(i=0;i<784;i=i+1) image[i]=2;
        for(i=0;i<512;i=i+1) weights[i]=0;
        for(i=0;i<25;i=i+1) begin
            weights[i]    = 1;    // 25*2 = 50
            weights[i+25] = 8'hFF; // -1 => ReLU 0
            weights[i+50] = 2;    // 25*2*2 = 100
            weights[i+75] = 6;    // 300 => clamp to 255
        end
        repeat(3) @(negedge clk); reset_n=1;
        kick(); wait(done); #1;
        if(write_count !== 4608) $fatal(1,"missing outputs: %0d",write_count);
        repeat(3) @(negedge clk);
        write_count=0; kick(); wait(done); #1;
        if(write_count !== 4608) $fatal(1,"second run missing outputs: %0d",write_count);
        $display("PASS tb_convolution"); $finish;
    end
    initial begin #12000000; $fatal(1,"timeout tb_convolution"); end
endmodule
