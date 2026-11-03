`timescale 1ns/1ps
module tb_hex;
    reg [3:0] digit;
    wire [6:0] HEX0;
    digit_to_hex0 dut (.digit(digit), .HEX0(HEX0));
    initial begin
        digit=4'd0; #1; if (HEX0 !== 7'b1000000) $fatal(1,"bad 0");
        digit=4'd7; #1; if (HEX0 !== 7'b1111000) $fatal(1,"bad 7");
        digit=4'd8; #1; if (HEX0 !== 7'b0000000) $fatal(1,"bad 8");
        digit=4'd9; #1; if (HEX0 !== 7'b0010000) $fatal(1,"bad 9");
        digit=4'd10; #1; if (HEX0 !== 7'b1111111) $fatal(1,"bad blank");
        $display("PASS tb_hex"); $finish;
    end
endmodule
