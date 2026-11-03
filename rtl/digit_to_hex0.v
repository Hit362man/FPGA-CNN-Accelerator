// =====================================
// digit_to_hex0.v
// Decode a 4-bit decimal digit (0..9) to HEX0
// Active-low segments: 0 = ON, 1 = OFF
// =====================================
module digit_to_hex0 (
    input      [3:0] digit,   // 0..9
    output reg [6:0] HEX0     // {g,f,e,d,c,b,a}
);

    always @(*) begin
        case (digit)
            4'd0: HEX0 = 7'b1000000; // displays "0"
            4'd1: HEX0 = 7'b1111001; // "1"
            4'd2: HEX0 = 7'b0100100; // "2"
            4'd3: HEX0 = 7'b0110000; // "3"
            4'd4: HEX0 = 7'b0011001; // "4"
            4'd5: HEX0 = 7'b0010010; // "5"
            4'd6: HEX0 =  7'b0000010; // "6"
            4'd7: HEX0 = 7'b1111000; // "7"

            4'd8: HEX0 = 7'b0000000; // "8"
            4'd9: HEX0 = 7'b0010000; // "9"

            // default: turn all segments off
            default: HEX0 = 7'b1111111;
        endcase
    end

endmodule

