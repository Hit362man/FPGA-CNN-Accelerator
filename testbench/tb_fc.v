`timescale 1ns/1ps
module tb_fc;
    reg clk=0, reset_n=0, start=0;
    always #5 clk=~clk;
    wire done; wire [3:0] digit;
    wire [6:0] fc_addr; wire fc_rden;
    reg [7:0] fc_q;
    reg [7:0] rom[0:127];
    integer i;
    // Synchronous output ROM analogous to vendor fc_rom.
    always @(posedge clk) if(fc_rden) fc_q<=rom[fc_addr];
    cnn_fc_classifier dut(
        .clk(clk),.reset_n(reset_n),.start(start),.done(done),
        .filter_sum_0(19'd100),.filter_sum_1(19'd0),
        .filter_sum_2(19'd0),.filter_sum_3(19'd0),
        .filter_sum_4(19'd0),.filter_sum_5(19'd0),
        .filter_sum_6(19'd0),.filter_sum_7(19'd0),
        .fc_addr(fc_addr),.fc_rden(fc_rden),.fc_q(fc_q),.predicted_digit(digit));
    task kick;
        begin @(negedge clk); start=1; @(negedge clk); start=0; end
    endtask
    initial begin
        for(i=0;i<128;i=i+1) rom[i]=0;
        rom[0]=1; rom[72]=2;  // class 9 wins only on FINAL comparison
        repeat(3) @(negedge clk); reset_n=1;
        kick(); wait(done); #1;
        if (digit!==9) $fatal(1,"expected class 9; got %0d",digit);
        rom[72]=0; rom[24]=3; // second frame should return class 3
        repeat(3) @(negedge clk); kick(); wait(done); #1;
        if (digit!==3) $fatal(1,"expected class 3 on second run; got %0d",digit);
        $display("PASS tb_fc"); $finish;
    end
    initial begin #20000; $fatal(1,"timeout tb_fc"); end
endmodule
