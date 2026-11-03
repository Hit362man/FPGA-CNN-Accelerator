`timescale 1ns/1ps
module tb_predictor;
    reg clk=0, reset_n=0, start=0;
    always #5 clk=~clk;
    wire done; wire [2:0] digit;
    wire [12:0] rdaddress; wire rden;
    reg [7:0] q;
    wire [18:0] s0,s1,s2,s3,s4,s5,s6,s7;
    reg [7:0] ram[0:4607];
    reg [12:0] read_addr;
    reg read_valid;
    integer i, k;
    // Mimic out_buf: clocked address and clocked output data.
    always @(posedge clk) begin
        read_valid <= rden;
        if (rden) read_addr <= rdaddress;
        if (read_valid) q <= ram[read_addr];
    end
    cnn_predictor dut(
        .clk(clk),.reset_n(reset_n),.start(start),.done(done),.digit(digit),
        .rdaddress(rdaddress),.rden(rden),.q(q),
        .filter_sum_0(s0),.filter_sum_1(s1),.filter_sum_2(s2),.filter_sum_3(s3),
        .filter_sum_4(s4),.filter_sum_5(s5),.filter_sum_6(s6),.filter_sum_7(s7));
    task kick;
        begin @(negedge clk); start=1; @(negedge clk); start=0; end
    endtask
    initial begin
        for(i=0;i<4608;i=i+1) ram[i]=i/576+1;
        repeat(3) @(negedge clk); reset_n=1;
        kick(); wait(done); #1;
        if (s0 !== 576 || s1 !== 1152 || s2 !== 1728 || s3 !== 2304 ||
            s4 !== 2880 || s5 !== 3456 || s6 !== 4032 || s7 !== 4608 || digit !== 7)
            $fatal(1,"sum or argmax incorrect (s7=%0d,digit=%0d)",s7,digit);
        // Verify a second frame works without reset and clears old sums.
        for(i=0;i<4608;i=i+1) ram[i]=(i/576==2)?4:0;
        repeat(3) @(negedge clk); kick(); wait(done); #1;
        if (s0 !== 0 || s2 !== 2304 || s7 !== 0 || digit !== 2)
            $fatal(1,"second run incorrect (s2=%0d,digit=%0d)",s2,digit);
        $display("PASS tb_predictor"); $finish;
    end
    initial begin #600000; $fatal(1,"timeout tb_predictor"); end
endmodule
