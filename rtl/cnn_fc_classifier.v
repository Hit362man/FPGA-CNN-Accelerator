module cnn_fc_classifier (
    input              clk,
    input              reset_n,        // active-low reset
    input              start,          // start FC computation
    output reg         done,           // goes high when classification is finished

    // 8 filter sums (19-bit) from predictor
    input      [18:0]  filter_sum_0,
    input      [18:0]  filter_sum_1,
    input      [18:0]  filter_sum_2,
    input      [18:0]  filter_sum_3,
    input      [18:0]  filter_sum_4,
    input      [18:0]  filter_sum_5,
    input      [18:0]  filter_sum_6,
    input      [18:0]  filter_sum_7,

    // Connection to fc_rom (128x8, fc_weights.mif)
    output reg [6:0]   fc_addr,
    output reg         fc_rden,
    input      [7:0]   fc_q,

    // Final predicted digit (0..9)
    output reg [3:0]   predicted_digit
);

    localparam NUM_CLASSES    = 10;
    localparam NUM_FILTERS    = 8;
    localparam WEIGHTS_BASE   = 7'd0;
    localparam BIASES_BASE    = 7'd80;

    // fc_rom has a clocked output. Requests are issued by one state,
    // clocked into the ROM by the next, and consumed by a later state.
    localparam S_IDLE         = 3'd0;
    localparam S_REQ_WEIGHT   = 3'd1;
    localparam S_WAIT_WEIGHT  = 3'd2;
    localparam S_ACCUM_WEIGHT = 3'd3;
    localparam S_REQ_BIAS     = 3'd4;
    localparam S_WAIT_BIAS    = 3'd5;
    localparam S_COMPARE      = 3'd6;
    localparam S_DONE         = 3'd7;

    reg [2:0]  state;
    reg [3:0]  class_idx;       // 0..9
    reg [2:0]  weight_idx;      // 0..7
    reg signed [31:0] acc;
    reg signed [31:0] best_score;
    reg [3:0]  best_class;

    // Mux for current filter_sum
    wire [18:0] current_filter_sum =
        (weight_idx == 3'd0) ? filter_sum_0 :
        (weight_idx == 3'd1) ? filter_sum_1 :
        (weight_idx == 3'd2) ? filter_sum_2 :
        (weight_idx == 3'd3) ? filter_sum_3 :
        (weight_idx == 3'd4) ? filter_sum_4 :
        (weight_idx == 3'd5) ? filter_sum_5 :
        (weight_idx == 3'd6) ? filter_sum_6 :
                               filter_sum_7;

    // Filter sums are nonnegative unsigned activations; zero extend them.
    wire signed [31:0] sum_sext    = {13'b0, current_filter_sum};
    wire signed [31:0] weight_sext = { {24{fc_q[7]}}, fc_q };                              // 8  -> 32
    wire signed [31:0] product     = sum_sext * weight_sext;
    wire signed [31:0] bias_sext   = {{24{fc_q[7]}}, fc_q};
    wire signed [31:0] class_score = acc + bias_sext;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state           <= S_IDLE;
            done            <= 1'b0;
            fc_addr         <= 7'd0;
            fc_rden         <= 1'b0;
            class_idx       <= 4'd0;
            weight_idx      <= 3'd0;
            acc             <= 32'sd0;
            best_score      <= 32'sh8000_0000;
            best_class      <= 4'd0;
            predicted_digit <= 4'd0;
        end else begin
            fc_rden <= 1'b0;
            done    <= 1'b0;
            case (state)
                S_IDLE: begin
                    if (start) begin
                        class_idx  <= 4'd0;
                        weight_idx <= 3'd0;
                        acc        <= 32'sd0;
                        best_score <= 32'sh8000_0000;
                        best_class <= 4'd0;
                        state      <= S_REQ_WEIGHT;
                    end
                end

                // Issue a weight read to the synchronous Intel ROM.
                S_REQ_WEIGHT: begin
                    fc_addr <= WEIGHTS_BASE + class_idx * NUM_FILTERS + weight_idx;
                    fc_rden <= 1'b1;
                    state   <= S_WAIT_WEIGHT;
                end

                // The ROM samples address/rden on this clock.
                S_WAIT_WEIGHT: begin
                    state <= S_ACCUM_WEIGHT;
                end

                S_ACCUM_WEIGHT: begin
                    acc <= acc + product;
                    if (weight_idx < NUM_FILTERS - 1) begin
                        weight_idx <= weight_idx + 3'd1;
                        state      <= S_REQ_WEIGHT;
                    end else begin
                        state <= S_REQ_BIAS;
                    end
                end

                S_REQ_BIAS: begin
                    fc_addr <= BIASES_BASE + class_idx;
                    fc_rden <= 1'b1;
                    state   <= S_WAIT_BIAS;
                end

                S_WAIT_BIAS: begin
                    state <= S_COMPARE;
                end

                S_COMPARE: begin
                    if (class_score > best_score) begin
                        best_score <= class_score;
                        best_class <= class_idx;
                    end

                    if (class_idx < NUM_CLASSES - 1) begin
                        class_idx  <= class_idx + 4'd1;
                        weight_idx <= 3'd0;
                        acc        <= 32'sd0;
                        state      <= S_REQ_WEIGHT;
                    end else begin
                        // Do not use the stale, nonblocking best_class value
                        // if the final class (9) has the best score.
                        predicted_digit <= (class_score > best_score)
                                           ? class_idx : best_class;
                        done  <= 1'b1;
                        state <= S_DONE;
                    end
                end

                S_DONE: begin
                    state <= S_IDLE;  // accept another start without reset
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
