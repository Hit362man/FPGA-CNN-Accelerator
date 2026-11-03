module cnn_predictor (
    input        clk,
    input        reset_n,         // active-low reset
    input        start,           // start prediction after convolution is done
    output reg   done,            // goes high when prediction is finished
    output reg [2:0] digit,       // predicted digit = best filter index (0..7)

    // ---- Connection to out_buf read port ----
    output reg [12:0] rdaddress,  // connect to out_buf.rdaddress
    output reg        rden,       // connect to out_buf.rden
    input      [7:0]  q,          // connect to out_buf.q (read data)

    // ---- Sums per filter for FC layer ----
    output reg [18:0] filter_sum_0,
    output reg [18:0] filter_sum_1,
    output reg [18:0] filter_sum_2,
    output reg [18:0] filter_sum_3,
    output reg [18:0] filter_sum_4,
    output reg [18:0] filter_sum_5,
    output reg [18:0] filter_sum_6,
    output reg [18:0] filter_sum_7
);

    localparam NUM_FILTERS    = 8;
    localparam OUT_H          = 24;
    localparam OUT_W          = 24;
    localparam OUT_PER_FILTER = OUT_H * OUT_W;   // 576

    localparam S_IDLE      = 3'd0;
    localparam S_ADDR      = 3'd1;
    localparam S_WAIT_ADDR = 3'd2;
    localparam S_WAIT_DATA = 3'd3;
    localparam S_ACCUM     = 3'd4;
    localparam S_NEXT_FILT = 3'd5;
    localparam S_DONE      = 3'd6;

    reg [2:0]  state;
    reg [2:0]  filter_idx;   // 0..7
    reg [9:0]  pixel_idx;    // 0..575
    reg [18:0] current_sum;

    // Address for given filter/pixel
    wire [12:0] feat_addr = filter_idx * OUT_PER_FILTER + pixel_idx;

    // Argmax helper (over the 8 sums)
    function [2:0] find_max;
        input [18:0] s0, s1, s2, s3, s4, s5, s6, s7;
        reg   [18:0] max_sum;
        reg   [2:0]  max_idx;
        begin
            max_sum = s0;
            max_idx = 3'd0;

            if (s1 > max_sum) begin max_sum = s1; max_idx = 3'd1; end
            if (s2 > max_sum) begin max_sum = s2; max_idx = 3'd2; end
            if (s3 > max_sum) begin max_sum = s3; max_idx = 3'd3; end
            if (s4 > max_sum) begin max_sum = s4; max_idx = 3'd4; end
            if (s5 > max_sum) begin max_sum = s5; max_idx = 3'd5; end
            if (s6 > max_sum) begin max_sum = s6; max_idx = 3'd6; end
            if (s7 > max_sum) begin max_sum = s7; max_idx = 3'd7; end

            find_max = max_idx;
        end
    endfunction

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state        <= S_IDLE;
            done         <= 1'b0;
            digit        <= 3'd0;
            filter_idx   <= 3'd0;
            pixel_idx    <= 10'd0;
            current_sum  <= 19'd0;
            rdaddress    <= 13'd0;
            rden         <= 1'b0;
            filter_sum_0 <= 19'd0;
            filter_sum_1 <= 19'd0;
            filter_sum_2 <= 19'd0;
            filter_sum_3 <= 19'd0;
            filter_sum_4 <= 19'd0;
            filter_sum_5 <= 19'd0;
            filter_sum_6 <= 19'd0;
            filter_sum_7 <= 19'd0;
        end else begin
            rden <= 1'b0;
            done <= 1'b0;

            case (state)
                // ------------------
                S_IDLE: begin
                    if (start) begin
                        filter_idx  <= 3'd0;
                        pixel_idx   <= 10'd0;
                        current_sum <= 19'd0;
                        filter_sum_0 <= 19'd0;
                        filter_sum_1 <= 19'd0;
                        filter_sum_2 <= 19'd0;
                        filter_sum_3 <= 19'd0;
                        filter_sum_4 <= 19'd0;
                        filter_sum_5 <= 19'd0;
                        filter_sum_6 <= 19'd0;
                        filter_sum_7 <= 19'd0;
                        state       <= S_ADDR;
                    end
                end

                // ------------------
                // Drive the registered output-RAM read address and enable.
                // The Intel out_buf has BOTH a registered read address and
                // a registered data output, so the value is not ready here.
                // ------------------
                S_ADDR: begin
                    rdaddress <= feat_addr;
                    rden      <= 1'b1;
                    state     <= S_WAIT_ADDR;
                end

                // RAM captures the read request.
                S_WAIT_ADDR: begin
                    state <= S_WAIT_DATA;
                end

                // RAM output register receives the data.
                S_WAIT_DATA: begin
                    state <= S_ACCUM;
                end

                // Accumulate only when q corresponds to rdaddress.
                S_ACCUM: begin
                    current_sum <= current_sum + q;

                    if (pixel_idx < OUT_PER_FILTER - 1) begin
                        pixel_idx <= pixel_idx + 10'd1;
                        state     <= S_ADDR;
                    end else begin
                        // End of this filter: store sum
                        case (filter_idx)
                            3'd0: filter_sum_0 <= current_sum + q;
                            3'd1: filter_sum_1 <= current_sum + q;
                            3'd2: filter_sum_2 <= current_sum + q;
                            3'd3: filter_sum_3 <= current_sum + q;
                            3'd4: filter_sum_4 <= current_sum + q;
                            3'd5: filter_sum_5 <= current_sum + q;
                            3'd6: filter_sum_6 <= current_sum + q;
                            3'd7: filter_sum_7 <= current_sum + q;
                        endcase
                        state <= S_NEXT_FILT;
                    end
                end

                // ------------------
                // Move to next filter or finish
                // ------------------
                S_NEXT_FILT: begin
                    if (filter_idx < NUM_FILTERS - 1) begin
                        filter_idx  <= filter_idx + 3'd1;
                        pixel_idx   <= 10'd0;
                        current_sum <= 19'd0;
                        state       <= S_ADDR;
                    end else begin
                        // All sums ready → argmax to produce a rough digit (0..7)
                        digit <= find_max(
                            filter_sum_0,
                            filter_sum_1,
                            filter_sum_2,
                            filter_sum_3,
                            filter_sum_4,
                            filter_sum_5,
                            filter_sum_6,
                            filter_sum_7
                        );
                        done  <= 1'b1;
                        state <= S_DONE;
                    end
                end

                S_DONE: begin
                    state <= S_IDLE;  // re-arm for next captured image
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule



